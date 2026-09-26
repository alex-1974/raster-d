module termination_recovery;

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
 * R0.4e-5 — request-local termination recovery.
 *
 * This slice proves two controlled termination classes:
 *
 * 1. cooperative cancellation before a later work unit begins;
 * 2. controlled materialization failure for one work unit.
 *
 * In both cases the request-local state is cleaned, the persistent worker
 * threads stay alive, and a later request succeeds on the same worker set.
 */

private enum RequestTerminationKind : ubyte
{
    completed,
    cancelled,
    failed
}


private struct TerminationPlan
{
    size_t cancelBeforeWorkUnitOrdinal;
    size_t failMaterializationWorkUnitOrdinal;
}


private final class RecoveryRequestSlot
{
    StableRequestIdentity requestIdentity;

    Region2D requestedOutput;
    PipelineRasterFixture[] fixtures;

    ubyte[] output;
    ubyte[] completedCoverage;

    size_t nextOrdinal;
    size_t completedWorkUnits;

    TerminationPlan plan;
    RequestTerminationKind termination;

    bool active;
    bool stopAdmission;


    void reset(
        StableRequestIdentity requestIdentity,
        Region2D requestedOutput,
        PipelineRasterFixture[] fixtures,
        TerminationPlan plan
    )
    {
        this.requestIdentity = requestIdentity;
        this.requestedOutput = requestedOutput;
        this.fixtures = fixtures;
        this.plan = plan;

        const sampleCount =
            requestedOutput.width
            * requestedOutput.height;

        output =
            new ubyte[sampleCount];

        completedCoverage =
            new ubyte[sampleCount];

        nextOrdinal = 1;
        completedWorkUnits = 0;

        termination = RequestTerminationKind.failed;

        active = true;
        stopAdmission = false;
    }


    void markCompleted()
    {
        active = false;
        stopAdmission = true;
        termination = RequestTerminationKind.completed;
    }


    void markCancelled()
    {
        active = false;
        stopAdmission = true;
        termination = RequestTerminationKind.cancelled;
    }


    void markFailed()
    {
        active = false;
        stopAdmission = true;
        termination = RequestTerminationKind.failed;
    }
}


private final class RecoveryMaterializationWorker
{
    StableWorkerIdentity identity =
        StableWorkerIdentity(
            201,
            PersistentWorkerRole.materialization
        );

    PersistentWorkerLifecycle lifecycle =
        PersistentWorkerLifecycle.notStarted;

    BoundedStageMailbox inbox;
    BoundedStageMailbox computeInbox;

    RecoveryRequestSlot slot;

    size_t runEntries;
    size_t jobsStarted;
    size_t jobsCompleted;

    bool failed;


    this(
        BoundedStageMailbox inbox,
        BoundedStageMailbox computeInbox,
        RecoveryRequestSlot slot
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

            if (!slot.active)
            {
                continue;
            }

            const index =
                popped.work.stableWorkUnitId;

            const ordinal =
                popped.work.readyOrdinal + 1;

            if (
                index >= slot.fixtures.length
                || slot.fixtures[index] is null
            )
            {
                failed = true;
                slot.markFailed();
                continue;
            }

            ++jobsStarted;

            if (
                slot.plan.failMaterializationWorkUnitOrdinal != 0
                && ordinal
                    == slot.plan.failMaterializationWorkUnitOrdinal
            )
            {
                slot.markFailed();
                continue;
            }

            slot.fixtures[index].materialize();

            if (!slot.fixtures[index].materializationCompleted)
            {
                failed = true;
                slot.markFailed();
                continue;
            }

            ++jobsCompleted;

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
                slot.markFailed();
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


private final class RecoveryComputeWorker
{
    StableWorkerIdentity identity =
        StableWorkerIdentity(
            202,
            PersistentWorkerRole.compute
        );

    PersistentWorkerLifecycle lifecycle =
        PersistentWorkerLifecycle.notStarted;

    BoundedStageMailbox inbox;
    RecoveryRequestSlot slot;

    size_t runEntries;
    size_t jobsStarted;
    size_t jobsCompleted;

    bool failed;


    this(
        BoundedStageMailbox inbox,
        RecoveryRequestSlot slot
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

            if (!slot.active)
            {
                continue;
            }

            const index =
                popped.work.stableWorkUnitId;

            if (
                index >= slot.fixtures.length
                || slot.fixtures[index] is null
            )
            {
                failed = true;
                slot.markFailed();
                continue;
            }

            ++jobsStarted;

            slot.fixtures[index].compute();

            if (!slot.fixtures[index].computeCompleted)
            {
                failed = true;
                slot.markFailed();
                continue;
            }

            ++jobsCompleted;
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


private size_t residentBytes(
    scope PipelineRasterFixture[] fixtures
)
{
    size_t result;

    foreach (fixture; fixtures)
    {
        if (fixture !is null)
        {
            result += fixture.residentBytes;
        }
    }

    return result;
}


private void cleanupRequestFixtures(
    RecoveryRequestSlot slot
)
{
    foreach (fixture; slot.fixtures)
    {
        if (fixture !is null)
        {
            fixture.releaseResident();
        }
    }
}


private RequestTerminationKind executeRequest(
    RecoveryRequestSlot slot,
    StableRequestIdentity requestIdentity,
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks,
    TerminationPlan plan,
    BoundedStageMailbox materializationInbox,
    RecoveryMaterializationWorker materializationWorker,
    RecoveryComputeWorker computeWorker
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
            return RequestTerminationKind.failed;
        }
    }

    slot.reset(
        requestIdentity,
        requestedOutput,
        fixtures,
        plan
    );

    foreach (index; 0 .. tasks.length)
    {
        const ordinal = index + 1;

        if (
            plan.cancelBeforeWorkUnitOrdinal != 0
            && ordinal
                == plan.cancelBeforeWorkUnitOrdinal
        )
        {
            slot.markCancelled();
            break;
        }

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

        for (;;)
        {
            if (!slot.active)
            {
                break;
            }

            if (fixtures[index].computeCompleted)
            {
                break;
            }

            Thread.yield();
        }

        if (!slot.active)
        {
            break;
        }

        if (!tryCommitTaskOutput(
            requestedOutput,
            tasks[index],
            fixtures[index].output,
            slot.output,
            slot.completedCoverage
        ))
        {
            slot.markFailed();
            break;
        }

        fixtures[index].releaseResident();

        ++slot.completedWorkUnits;
        slot.nextOrdinal = ordinal + 1;
    }

    if (slot.active)
    {
        if (allCovered(slot.completedCoverage))
        {
            slot.markCompleted();
        }
        else
        {
            slot.markFailed();
        }
    }

    cleanupRequestFixtures(slot);

    return slot.termination;
}


private void verifyRecoveryRequest(
    RecoveryRequestSlot slot,
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks
)
{
    auto reference =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            tasks
        );

    assert(reference.ok);
    assert(reference.requestCompleted);

    assert(
        slot.termination
        == RequestTerminationKind.completed
    );

    assert(
        slot.output
        == reference.output
    );

    assert(
        slot.completedCoverage
        == reference.completedCoverage
    );

    assert(
        residentBytes(slot.fixtures)
        == 0
    );
}


/*
 * Cancellation between work units, then successful recovery request.
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
            4
        );

    const Region2D[4] tasks =
    [
        Region2D(1020, 2030, 8, 1),
        Region2D(1020, 2031, 3, 2),
        Region2D(1023, 2031, 5, 2),
        Region2D(1020, 2033, 8, 1)
    ];

    const recoveryOutput =
        Region2D(
            1050,
            2060,
            6,
            2
        );

    const Region2D[2] recoveryTasks =
    [
        Region2D(1050, 2060, 3, 2),
        Region2D(1053, 2060, 3, 2)
    ];

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
        new RecoveryRequestSlot;

    auto materializationWorker =
        new RecoveryMaterializationWorker(
            materializationInbox,
            computeInbox,
            slot
        );

    auto computeWorker =
        new RecoveryComputeWorker(
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

    auto cancelled =
        executeRequest(
            slot,
            StableRequestIdentity(2001),
            logicalExtent,
            requestedOutput,
            tasks[],
            TerminationPlan(
                3,
                0
            ),
            materializationInbox,
            materializationWorker,
            computeWorker
        );

    assert(
        cancelled
        == RequestTerminationKind.cancelled
    );

    assert(slot.completedWorkUnits == 2);

    assert(
        residentBytes(slot.fixtures)
        == 0
    );

    auto recovered =
        executeRequest(
            slot,
            StableRequestIdentity(2002),
            logicalExtent,
            recoveryOutput,
            recoveryTasks[],
            TerminationPlan.init,
            materializationInbox,
            materializationWorker,
            computeWorker
        );

    assert(
        recovered
        == RequestTerminationKind.completed
    );

    verifyRecoveryRequest(
        slot,
        logicalExtent,
        recoveryOutput,
        recoveryTasks[]
    );

    assert(
        materializationWorker.runEntries
        == 1
    );

    assert(
        computeWorker.runEntries
        == 1
    );

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
}


/*
 * Controlled materialization failure, then successful recovery request.
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
            4
        );

    const Region2D[4] tasks =
    [
        Region2D(1020, 2030, 8, 1),
        Region2D(1020, 2031, 3, 2),
        Region2D(1023, 2031, 5, 2),
        Region2D(1020, 2033, 8, 1)
    ];

    const recoveryOutput =
        Region2D(
            1060,
            2070,
            4,
            3
        );

    const Region2D[3] recoveryTasks =
    [
        Region2D(1060, 2070, 4, 1),
        Region2D(1060, 2071, 4, 1),
        Region2D(1060, 2072, 4, 1)
    ];

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
        new RecoveryRequestSlot;

    auto materializationWorker =
        new RecoveryMaterializationWorker(
            materializationInbox,
            computeInbox,
            slot
        );

    auto computeWorker =
        new RecoveryComputeWorker(
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

    auto failedRequest =
        executeRequest(
            slot,
            StableRequestIdentity(3001),
            logicalExtent,
            requestedOutput,
            tasks[],
            TerminationPlan(
                0,
                3
            ),
            materializationInbox,
            materializationWorker,
            computeWorker
        );

    assert(
        failedRequest
        == RequestTerminationKind.failed
    );

    assert(slot.completedWorkUnits == 2);

    assert(
        residentBytes(slot.fixtures)
        == 0
    );

    /*
     * The injected failure is request-local evidence, not a poisoned worker.
     */
    materializationWorker.failed = false;
    computeWorker.failed = false;

    auto recovered =
        executeRequest(
            slot,
            StableRequestIdentity(3002),
            logicalExtent,
            recoveryOutput,
            recoveryTasks[],
            TerminationPlan.init,
            materializationInbox,
            materializationWorker,
            computeWorker
        );

    assert(
        recovered
        == RequestTerminationKind.completed
    );

    verifyRecoveryRequest(
        slot,
        logicalExtent,
        recoveryOutput,
        recoveryTasks[]
    );

    assert(
        materializationWorker.runEntries
        == 1
    );

    assert(
        computeWorker.runEntries
        == 1
    );

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
}
