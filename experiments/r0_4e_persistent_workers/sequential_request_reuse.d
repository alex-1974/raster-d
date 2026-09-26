module sequential_request_reuse;

import core.thread :
    Thread;

import raster.region :
    Region2D;

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
    StableRequestIdentity,
    StableWorkerIdentity,
    StageQueueKind;


/*
 * R0.4e-4 — reuse one live materialization/compute worker pair across
 * multiple sequential raster requests.
 *
 * This slice keeps requests strictly sequential. It does not add concurrent
 * multi-request scheduling or recovery semantics.
 */

private final class ReusableRequestSlot
{
    StableRequestIdentity requestIdentity;

    Region2D requestedOutput;

    PipelineRasterFixture[] fixtures;

    ubyte[] output;
    ubyte[] completedCoverage;

    size_t workUnitsCompleted;

    bool active;
    bool completed;


    void reset(
        StableRequestIdentity requestIdentity,
        Region2D requestedOutput,
        PipelineRasterFixture[] fixtures
    )
    {
        this.requestIdentity =
            requestIdentity;

        this.requestedOutput =
            requestedOutput;

        this.fixtures =
            fixtures;

        const sampleCount =
            requestedOutput.width
            * requestedOutput.height;

        output =
            new ubyte[sampleCount];

        completedCoverage =
            new ubyte[sampleCount];

        workUnitsCompleted = 0;
        active = true;
        completed = false;
    }


    void finish()
    {
        active = false;
        completed = true;
    }
}


private final class ReusableMaterializationWorker
{
    StableWorkerIdentity identity =
        StableWorkerIdentity(
            101,
            PersistentWorkerRole.materialization
        );

    PersistentWorkerLifecycle lifecycle =
        PersistentWorkerLifecycle.notStarted;

    BoundedStageMailbox inbox;
    BoundedStageMailbox computeInbox;

    ReusableRequestSlot slot;

    size_t runEntries;
    size_t jobsExecuted;

    size_t[32] requestTrace;
    size_t requestTraceLength;

    bool failed;


    this(
        BoundedStageMailbox inbox,
        BoundedStageMailbox computeInbox,
        ReusableRequestSlot slot
    )
    {
        this.inbox = inbox;
        this.computeInbox = computeInbox;
        this.slot = slot;
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
                !slot.active
                || index >= slot.fixtures.length
                || slot.fixtures[index] is null
            )
            {
                failed = true;
                return;
            }

            slot.fixtures[index].materialize();

            if (!slot.fixtures[index].materializationCompleted)
            {
                failed = true;
                return;
            }

            if (requestTraceLength >= requestTrace.length)
            {
                failed = true;
                return;
            }

            requestTrace[requestTraceLength] =
                slot.requestIdentity.stableRequestId;

            ++requestTraceLength;
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


private final class ReusableComputeWorker
{
    StableWorkerIdentity identity =
        StableWorkerIdentity(
            102,
            PersistentWorkerRole.compute
        );

    PersistentWorkerLifecycle lifecycle =
        PersistentWorkerLifecycle.notStarted;

    BoundedStageMailbox inbox;

    ReusableRequestSlot slot;

    size_t runEntries;
    size_t jobsExecuted;

    size_t[32] requestTrace;
    size_t requestTraceLength;

    bool failed;


    this(
        BoundedStageMailbox inbox,
        ReusableRequestSlot slot
    )
    {
        this.inbox = inbox;
        this.slot = slot;
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
                !slot.active
                || index >= slot.fixtures.length
                || slot.fixtures[index] is null
            )
            {
                failed = true;
                return;
            }

            slot.fixtures[index].compute();

            if (!slot.fixtures[index].computeCompleted)
            {
                failed = true;
                return;
            }

            if (requestTraceLength >= requestTrace.length)
            {
                failed = true;
                return;
            }

            requestTrace[requestTraceLength] =
                slot.requestIdentity.stableRequestId;

            ++requestTraceLength;
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


private bool executeRequest(
    ReusableRequestSlot slot,
    StableRequestIdentity requestIdentity,
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks,
    BoundedStageMailbox materializationInbox,
    ReusableMaterializationWorker materializationWorker,
    ReusableComputeWorker computeWorker
)
{
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
            return false;
        }
    }

    slot.reset(
        requestIdentity,
        requestedOutput,
        fixtures
    );

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

        while (!fixtures[index].computeCompleted)
        {
            if (
                materializationWorker.failed
                || computeWorker.failed
            )
            {
                return false;
            }

            Thread.yield();
        }

        if (!tryCommitTaskOutput(
            requestedOutput,
            tasks[index],
            fixtures[index].output,
            slot.output,
            slot.completedCoverage
        ))
        {
            return false;
        }

        fixtures[index].releaseResident();

        ++slot.workUnitsCompleted;
    }

    foreach (fixture; fixtures)
    {
        if (
            fixture is null
            || fixture.residentBytes != 0
        )
        {
            return false;
        }
    }

    if (!allCovered(slot.completedCoverage))
    {
        return false;
    }

    slot.finish();

    return true;
}


unittest
{
    const logicalExtent =
        Region2D(
            1000,
            2000,
            100,
            100
        );

    const firstRequestedOutput =
        Region2D(
            1020,
            2030,
            8,
            4
        );

    const Region2D[4] firstTasks =
    [
        Region2D(1020, 2030, 8, 1),
        Region2D(1020, 2031, 3, 2),
        Region2D(1023, 2031, 5, 2),
        Region2D(1020, 2033, 8, 1)
    ];

    const secondRequestedOutput =
        Region2D(
            1040,
            2050,
            6,
            3
        );

    const Region2D[3] secondTasks =
    [
        Region2D(1040, 2050, 2, 3),
        Region2D(1042, 2050, 2, 3),
        Region2D(1044, 2050, 2, 3)
    ];

    auto firstReference =
        executeSynchronousNeighbourhood(
            logicalExtent,
            firstRequestedOutput,
            firstTasks[]
        );

    auto secondReference =
        executeSynchronousNeighbourhood(
            logicalExtent,
            secondRequestedOutput,
            secondTasks[]
        );

    assert(firstReference.ok);
    assert(secondReference.ok);

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

    auto slot =
        new ReusableRequestSlot;

    auto materializationWorker =
        new ReusableMaterializationWorker(
            materializationInbox,
            computeInbox,
            slot
        );

    auto computeWorker =
        new ReusableComputeWorker(
            computeInbox,
            slot
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

    const firstRequest =
        StableRequestIdentity(1001);

    const secondRequest =
        StableRequestIdentity(1002);

    assert(
        executeRequest(
            slot,
            firstRequest,
            logicalExtent,
            firstRequestedOutput,
            firstTasks[],
            materializationInbox,
            materializationWorker,
            computeWorker
        )
    );

    assert(slot.completed);
    assert(!slot.active);

    assert(
        slot.output
        == firstReference.output
    );

    assert(
        slot.completedCoverage
        == firstReference.completedCoverage
    );

    assert(
        slot.workUnitsCompleted
        == firstTasks.length
    );

    /*
     * Request-local result state is captured before the same slot is reused.
     */
    auto firstOutput =
        slot.output.dup;

    auto firstCoverage =
        slot.completedCoverage.dup;

    assert(
        executeRequest(
            slot,
            secondRequest,
            logicalExtent,
            secondRequestedOutput,
            secondTasks[],
            materializationInbox,
            materializationWorker,
            computeWorker
        )
    );

    assert(slot.completed);
    assert(!slot.active);

    assert(
        slot.output
        == secondReference.output
    );

    assert(
        slot.completedCoverage
        == secondReference.completedCoverage
    );

    assert(
        slot.workUnitsCompleted
        == secondTasks.length
    );

    /*
     * The first request's copied result remains unchanged after request-local
     * slot reuse.
     */
    assert(
        firstOutput
        == firstReference.output
    );

    assert(
        firstCoverage
        == firstReference.completedCoverage
    );

    /*
     * The same worker threads have stayed alive across both requests.
     */
    assert(
        materializationWorker.runEntries
        == 1
    );

    assert(
        computeWorker.runEntries
        == 1
    );

    assert(
        materializationWorker.jobsExecuted
        == firstTasks.length
            + secondTasks.length
    );

    assert(
        computeWorker.jobsExecuted
        == firstTasks.length
            + secondTasks.length
    );

    assert(
        materializationWorker.requestTraceLength
        == firstTasks.length
            + secondTasks.length
    );

    assert(
        computeWorker.requestTraceLength
        == firstTasks.length
            + secondTasks.length
    );

    foreach (
        requestId;
        materializationWorker.requestTrace[
            0 .. firstTasks.length
        ]
    )
    {
        assert(
            requestId
            == firstRequest.stableRequestId
        );
    }

    foreach (
        requestId;
        materializationWorker.requestTrace[
            firstTasks.length
            .. firstTasks.length
                + secondTasks.length
        ]
    )
    {
        assert(
            requestId
            == secondRequest.stableRequestId
        );
    }

    foreach (
        requestId;
        computeWorker.requestTrace[
            0 .. firstTasks.length
        ]
    )
    {
        assert(
            requestId
            == firstRequest.stableRequestId
        );
    }

    foreach (
        requestId;
        computeWorker.requestTrace[
            firstTasks.length
            .. firstTasks.length
                + secondTasks.length
        ]
    )
    {
        assert(
            requestId
            == secondRequest.stableRequestId
        );
    }

    /*
     * Shutdown remains after both successful requests.
     */
    assert(materializationInbox.close());
    materializationThread.join();

    assert(computeInbox.close());
    computeThread.join();

    materializationWorker.markJoined();
    computeWorker.markJoined();

    assert(
        materializationWorker.lifecycle
        == PersistentWorkerLifecycle.joined
    );

    assert(
        computeWorker.lifecycle
        == PersistentWorkerLifecycle.joined
    );

    auto materializationSnapshot =
        materializationInbox.snapshot();

    auto computeSnapshot =
        computeInbox.snapshot();

    assert(
        materializationSnapshot.peakCount
        <= 1
    );

    assert(
        computeSnapshot.peakCount
        <= 1
    );

    assert(
        materializationSnapshot.currentCount
        == 0
    );

    assert(
        computeSnapshot.currentCount
        == 0
    );

    assert(!materializationWorker.failed);
    assert(!computeWorker.failed);
}
