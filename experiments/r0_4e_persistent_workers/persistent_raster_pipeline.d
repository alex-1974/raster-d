module persistent_raster_pipeline;

import core.thread :
    Thread;

import raster.region :
    Region2D;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import synchronous_execution :
    executeSynchronousNeighbourhood;

import pipeline_raster_fixture :
    PipelineRasterFixture,
    tryCommitTaskOutput;

import bounded_stage_mailbox :
    BoundedStageMailbox,
    QueuedStageWork,
    StageMailboxPopKind,
    StageMailboxPushError;

import worker_vocabulary :
    PersistentWorkerLifecycle,
    PersistentWorkerRole,
    StableWorkerIdentity,
    StageQueueKind;


/*
 * R0.4e-3 deliberately proves only one request on one fixed pair of stage
 * workers. Cross-request reuse belongs to R0.4e-4.
 */

private final class PersistentMaterializationWorker
{
    StableWorkerIdentity identity =
        StableWorkerIdentity(
            1,
            PersistentWorkerRole.materialization
        );

    PersistentWorkerLifecycle lifecycle =
        PersistentWorkerLifecycle.notStarted;

    BoundedStageMailbox inbox;
    BoundedStageMailbox computeInbox;

    PipelineRasterFixture[] fixtures;

    size_t runEntries;
    size_t jobsExecuted;
    size_t[16] executionTrace;
    size_t executionTraceLength;

    bool failed;


    this(
        BoundedStageMailbox inbox,
        BoundedStageMailbox computeInbox,
        PipelineRasterFixture[] fixtures
    )
    {
        this.inbox = inbox;
        this.computeInbox = computeInbox;
        this.fixtures = fixtures;
    }


    void run()
    {
        ++runEntries;
        lifecycle = PersistentWorkerLifecycle.running;

        for (;;)
        {
            lifecycle = PersistentWorkerLifecycle.waiting;

            auto popped = inbox.waitPop();

            if (
                popped.kind
                == StageMailboxPopKind.closed
            )
            {
                lifecycle =
                    PersistentWorkerLifecycle.shutdownObserved;

                return;
            }

            lifecycle = PersistentWorkerLifecycle.running;

            const index =
                popped.work.stableWorkUnitId;

            if (
                index >= fixtures.length
                || fixtures[index] is null
            )
            {
                failed = true;
                return;
            }

            fixtures[index].materialize();

            if (!fixtures[index].materializationCompleted)
            {
                failed = true;
                return;
            }

            if (executionTraceLength >= executionTrace.length)
            {
                failed = true;
                return;
            }

            executionTrace[executionTraceLength] = index;
            ++executionTraceLength;
            ++jobsExecuted;

            auto pushError =
                computeInbox.tryPush(
                    QueuedStageWork(
                        index,
                        popped.work.readyOrdinal
                    )
                );

            if (
                pushError
                != StageMailboxPushError.none
            )
            {
                failed = true;
                return;
            }
        }
    }


    void markJoined()
    {
        if (
            lifecycle
            == PersistentWorkerLifecycle.shutdownObserved
        )
        {
            lifecycle =
                PersistentWorkerLifecycle.joined;
        }
    }
}


private final class PersistentComputeWorker
{
    StableWorkerIdentity identity =
        StableWorkerIdentity(
            2,
            PersistentWorkerRole.compute
        );

    PersistentWorkerLifecycle lifecycle =
        PersistentWorkerLifecycle.notStarted;

    BoundedStageMailbox inbox;

    PipelineRasterFixture[] fixtures;

    size_t runEntries;
    size_t jobsExecuted;
    size_t[16] executionTrace;
    size_t executionTraceLength;

    bool failed;


    this(
        BoundedStageMailbox inbox,
        PipelineRasterFixture[] fixtures
    )
    {
        this.inbox = inbox;
        this.fixtures = fixtures;
    }


    void run()
    {
        ++runEntries;
        lifecycle = PersistentWorkerLifecycle.running;

        for (;;)
        {
            lifecycle = PersistentWorkerLifecycle.waiting;

            auto popped = inbox.waitPop();

            if (
                popped.kind
                == StageMailboxPopKind.closed
            )
            {
                lifecycle =
                    PersistentWorkerLifecycle.shutdownObserved;

                return;
            }

            lifecycle = PersistentWorkerLifecycle.running;

            const index =
                popped.work.stableWorkUnitId;

            if (
                index >= fixtures.length
                || fixtures[index] is null
            )
            {
                failed = true;
                return;
            }

            fixtures[index].compute();

            if (!fixtures[index].computeCompleted)
            {
                failed = true;
                return;
            }

            if (executionTraceLength >= executionTrace.length)
            {
                failed = true;
                return;
            }

            executionTrace[executionTraceLength] = index;
            ++executionTraceLength;
            ++jobsExecuted;
        }
    }


    void markJoined()
    {
        if (
            lifecycle
            == PersistentWorkerLifecycle.shutdownObserved
        )
        {
            lifecycle =
                PersistentWorkerLifecycle.joined;
        }
    }
}


private bool allCovered(
    scope const(ubyte)[] coverage
)
@safe
pure
nothrow
@nogc
{
    foreach (covered; coverage)
    {
        if (covered != 1)
        {
            return false;
        }
    }

    return true;
}


private struct PersistentPipelineResult
{
    bool requestCompleted;

    ubyte[] output;
    ubyte[] completedCoverage;

    size_t materializationWorkerRunEntries;
    size_t computeWorkerRunEntries;

    size_t materializationJobs;
    size_t computeJobs;

    size_t materializationQueuePeak;
    size_t computeQueuePeak;

    size_t currentResidentRasterBytes;

    bool workersJoined;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return requestCompleted
            && currentResidentRasterBytes == 0
            && workersJoined;
    }
}


private PersistentPipelineResult executePersistentRasterPipeline(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks
)
{
    PersistentPipelineResult result;

    if (
        !logicalExtent.hasRepresentableExtent()
        || !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || tasks.length == 0
    )
    {
        return result;
    }

    DecompositionIssue issue;

    if (!tryValidateDecomposition(
        requestedOutput,
        tasks,
        issue
    ))
    {
        return result;
    }

    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    result.output =
        new ubyte[sampleCount];

    result.completedCoverage =
        new ubyte[sampleCount];

    auto fixtures =
        new PipelineRasterFixture[tasks.length];

    foreach (index; 0 .. tasks.length)
    {
        fixtures[index] =
            new PipelineRasterFixture(
                logicalExtent,
                tasks[index]
            );

        if (!fixtures[index].prepareDependency())
        {
            return PersistentPipelineResult.init;
        }
    }

    auto materializationInbox =
        new BoundedStageMailbox(
            StageQueueKind.materialization,
            1
        );

    auto computeInbox =
        new BoundedStageMailbox(
            StageQueueKind.compute,
            1
        );

    auto materializationWorker =
        new PersistentMaterializationWorker(
            materializationInbox,
            computeInbox,
            fixtures
        );

    auto computeWorker =
        new PersistentComputeWorker(
            computeInbox,
            fixtures
        );

    auto materializationThread =
        new Thread(
            &materializationWorker.run
        );

    auto computeThread =
        new Thread(
            &computeWorker.run
        );

    materializationThread.start();
    computeThread.start();

    /*
     * Capacity-one staging is intentional for this first integration proof.
     * The coordinator admits one work unit and waits until its compute result
     * exists before reusing the same live worker pair for the next unit.
     *
     * R0.4e-3 proves worker reuse + real raster semantics, not throughput.
     */
    foreach (index; 0 .. tasks.length)
    {
        while (
            materializationInbox.tryPush(
                QueuedStageWork(
                    index,
                    index
                )
            )
            == StageMailboxPushError.full
        )
        {
            Thread.yield();
        }

        /*
         * Wait for this work unit to pass both persistent stages.
         *
         * No elapsed-time threshold participates in correctness.
         */
        while (!fixtures[index].computeCompleted)
        {
            if (
                materializationWorker.failed
                || computeWorker.failed
            )
            {
                materializationInbox.close();
                computeInbox.close();

                materializationThread.join();
                computeThread.join();

                return PersistentPipelineResult.init;
            }

            Thread.yield();
        }

        if (!tryCommitTaskOutput(
            requestedOutput,
            tasks[index],
            fixtures[index].output,
            result.output,
            result.completedCoverage
        ))
        {
            materializationInbox.close();
            computeInbox.close();

            materializationThread.join();
            computeThread.join();

            return PersistentPipelineResult.init;
        }

        fixtures[index].releaseResident();
    }

    materializationInbox.close();
    materializationThread.join();

    computeInbox.close();
    computeThread.join();

    materializationWorker.markJoined();
    computeWorker.markJoined();

    foreach (fixture; fixtures)
    {
        if (fixture !is null)
        {
            result.currentResidentRasterBytes +=
                fixture.residentBytes;
        }
    }

    auto materializationSnapshot =
        materializationInbox.snapshot();

    auto computeSnapshot =
        computeInbox.snapshot();

    result.materializationWorkerRunEntries =
        materializationWorker.runEntries;

    result.computeWorkerRunEntries =
        computeWorker.runEntries;

    result.materializationJobs =
        materializationWorker.jobsExecuted;

    result.computeJobs =
        computeWorker.jobsExecuted;

    result.materializationQueuePeak =
        materializationSnapshot.peakCount;

    result.computeQueuePeak =
        computeSnapshot.peakCount;

    result.workersJoined =
        materializationWorker.lifecycle
            == PersistentWorkerLifecycle.joined
        && computeWorker.lifecycle
            == PersistentWorkerLifecycle.joined;

    result.requestCompleted =
        allCovered(
            result.completedCoverage
        )
        && !materializationWorker.failed
        && !computeWorker.failed;

    return result;
}


/*
 * R0.4e-3 — real raster work on one persistent materialization worker and one
 * persistent compute worker.
 */
unittest
{
    const logicalExtent =
        Region2D(
            1000,
            2000,
            100,
            100
        );

    const requestedOutput =
        Region2D(
            1020,
            2030,
            8,
            6
        );

    const Region2D[6] tasks =
    [
        Region2D(1020, 2030, 8, 1),
        Region2D(1020, 2031, 3, 2),
        Region2D(1023, 2031, 5, 2),
        Region2D(1020, 2033, 5, 2),
        Region2D(1025, 2033, 3, 2),
        Region2D(1020, 2035, 8, 1)
    ];

    auto synchronous =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            tasks[]
        );

    auto persistent =
        executePersistentRasterPipeline(
            logicalExtent,
            requestedOutput,
            tasks[]
        );

    assert(synchronous.ok);
    assert(synchronous.requestCompleted);

    assert(persistent.ok);
    assert(persistent.requestCompleted);

    assert(
        persistent.output
        == synchronous.output
    );

    assert(
        persistent.completedCoverage
        == synchronous.completedCoverage
    );

    assert(
        persistent.materializationWorkerRunEntries
        == 1
    );

    assert(
        persistent.computeWorkerRunEntries
        == 1
    );

    assert(
        persistent.materializationJobs
        == tasks.length
    );

    assert(
        persistent.computeJobs
        == tasks.length
    );

    assert(
        persistent.materializationQueuePeak
        <= 1
    );

    assert(
        persistent.computeQueuePeak
        <= 1
    );

    assert(
        persistent.currentResidentRasterBytes
        == 0
    );

    assert(persistent.workersJoined);
}
