module final_integration;

import core.sync.barrier :
    Barrier;

import core.thread :
    Thread;

import raster.region :
    Region2D;

import synchronous_execution :
    executeSynchronousNeighbourhood;

import bounded_parallel_execution :
    executeBoundedParallelNeighbourhood;

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
 * R0.4e-6 — final shutdown/integration proof.
 *
 * This slice deliberately does not invent a new executor. It closes the
 * remaining worker-set lifecycle gates and rechecks exact raster semantics
 * against immutable historical references.
 */

private final class ShutdownProbeWorker
{
    StableWorkerIdentity identity;

    PersistentWorkerLifecycle lifecycle =
        PersistentWorkerLifecycle.notStarted;

    BoundedStageMailbox inbox;

    Barrier waitingObservation;

    size_t runEntries;
    size_t jobsStarted;
    size_t jobsCompleted;

    bool shutdownObserved;


    this(
        StableWorkerIdentity identity,
        BoundedStageMailbox inbox,
        Barrier waitingObservation
    )
    {
        this.identity = identity;
        this.inbox = inbox;
        this.waitingObservation = waitingObservation;
    }


    void run()
    {
        ++runEntries;
        lifecycle = PersistentWorkerLifecycle.running;

        bool publishedWait;

        for (;;)
        {
            lifecycle = PersistentWorkerLifecycle.waiting;

            auto popped =
                inbox.waitPop(
                    publishedWait
                        ? null
                        : waitingObservation
                );

            publishedWait = true;

            if (
                popped.kind
                == StageMailboxPopKind.closed
            )
            {
                shutdownObserved = true;

                lifecycle =
                    PersistentWorkerLifecycle.shutdownObserved;

                return;
            }

            lifecycle = PersistentWorkerLifecycle.running;

            ++jobsStarted;
            ++jobsCompleted;
        }
    }


    void markJoined()
    {
        assert(
            lifecycle
            == PersistentWorkerLifecycle.shutdownObserved
        );

        lifecycle =
            PersistentWorkerLifecycle.joined;
    }
}


/*
 * One blocked persistent worker is woken by close(), exits, is joined, and
 * cannot receive later work because producer admission remains permanently
 * closed.
 */
unittest
{
    auto inbox =
        new BoundedStageMailbox(
            StageQueueKind.compute,
            1
        );

    auto waitingObservation =
        new Barrier(2);

    auto worker =
        new ShutdownProbeWorker(
            StableWorkerIdentity(
                901,
                PersistentWorkerRole.compute
            ),
            inbox,
            waitingObservation
        );

    auto thread =
        new Thread(
            &worker.run
        );

    thread.start();

    /*
     * Deterministically prove the worker reached the empty/open wait boundary.
     */
    waitingObservation.wait();

    assert(worker.runEntries == 1);
    assert(worker.jobsStarted == 0);
    assert(worker.jobsCompleted == 0);

    assert(
        worker.lifecycle
        == PersistentWorkerLifecycle.waiting
    );

    /*
     * Close wakes the blocked worker.
     */
    assert(inbox.close());

    thread.join();
    worker.markJoined();

    assert(worker.shutdownObserved);
    assert(worker.runEntries == 1);
    assert(worker.jobsStarted == 0);
    assert(worker.jobsCompleted == 0);

    assert(
        worker.lifecycle
        == PersistentWorkerLifecycle.joined
    );

    /*
     * No work may start after shutdown because closed producer admission is
     * permanent.
     */
    assert(
        inbox.tryPush(
            QueuedStageWork(
                777,
                0
            )
        )
        == StageMailboxPushError.closed
    );

    assert(worker.jobsStarted == 0);
    assert(worker.jobsCompleted == 0);

    auto snapshot =
        inbox.snapshot();

    assert(snapshot.closed);
    assert(snapshot.currentCount == 0);
    assert(snapshot.rejectedClosedPushes == 1);
}


/*
 * Final semantic integration against the immutable historical references.
 *
 * The persistent-worker-specific execution/recovery proofs live in e3-e5.
 * Here we intentionally recheck that the canonical raster result remains
 * exactly identical to the synchronous and bounded-parallel references while
 * closing R0.4e.
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

    auto bounded =
        executeBoundedParallelNeighbourhood(
            logicalExtent,
            requestedOutput,
            tasks[],
            2
        );

    assert(synchronous.ok);
    assert(synchronous.requestCompleted);

    assert(bounded.ok);
    assert(bounded.requestCompleted);

    assert(
        bounded.output
        == synchronous.output
    );

    assert(
        bounded.completedCoverage
        == synchronous.completedCoverage
    );

    assert(
        synchronous.accounting.currentResidentRasterBytes
        == 0
    );

    assert(
        bounded.accounting.currentResidentRasterBytes
        == 0
    );
}
