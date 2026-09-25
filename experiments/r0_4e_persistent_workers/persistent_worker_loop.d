module persistent_worker_loop;

import core.sync.barrier :
    Barrier;

import core.thread :
    Thread;

import worker_vocabulary :
    PersistentWorkerLifecycle,
    PersistentWorkerRole,
    StableWorkerIdentity;


/++
    R0.4e-1 research-local command.

    There is deliberately no queue in this slice.

    The coordinator exposes at most one command between explicit barrier
    boundaries.
+/
private enum PersistentWorkerCommand : ubyte
{
    none,
    executeJob,
    shutdown
}


/++
    One persistent research worker.

    The same thread enters run() exactly once and remains alive across multiple
    job boundaries.

    This is not a production worker-pool type.
+/
private class PersistentWorkerLoop
{
    StableWorkerIdentity identity;

    PersistentWorkerLifecycle lifecycle =
        PersistentWorkerLifecycle.notStarted;


    Barrier waitingGate;
    Barrier commandGate;
    Barrier completionGate;


    PersistentWorkerCommand pendingCommand =
        PersistentWorkerCommand.none;

    size_t pendingJobId;


    size_t runEntries;
    size_t waitEntries;
    size_t jobsExecuted;

    size_t[4] executionTrace;
    size_t executionTraceLength;

    bool shutdownWasObserved;


    this(
        StableWorkerIdentity identity,
        Barrier waitingGate,
        Barrier commandGate,
        Barrier completionGate
    )
    {
        this.identity =
            identity;

        this.waitingGate =
            waitingGate;

        this.commandGate =
            commandGate;

        this.completionGate =
            completionGate;
    }


    /++
        Persistent worker loop.

        The loop blocks only on explicit barriers.

        It contains no sleep, timeout or polling.
    +/
    void run()
    {
        ++runEntries;

        lifecycle =
            PersistentWorkerLifecycle.running;


        for (;;)
        {
            lifecycle =
                PersistentWorkerLifecycle.waiting;

            ++waitEntries;


            /*
             * The coordinator joins this gate to prove that the worker has
             * reached a waiting boundary.
             */
            waitingGate.wait();


            /*
             * The worker then blocks here until exactly one command is made
             * visible by the coordinator.
             */
            commandGate.wait();


            const command =
                pendingCommand;


            if (
                command
                == PersistentWorkerCommand.shutdown
            )
            {
                lifecycle =
                    PersistentWorkerLifecycle.shutdownObserved;

                shutdownWasObserved =
                    true;

                pendingCommand =
                    PersistentWorkerCommand.none;


                /*
                 * Publish the shutdown observation before returning from the
                 * one persistent run() invocation.
                 */
                completionGate.wait();

                return;
            }


            assert(
                command
                == PersistentWorkerCommand.executeJob
            );


            lifecycle =
                PersistentWorkerLifecycle.running;


            assert(
                executionTraceLength
                < executionTrace.length
            );


            executionTrace[
                executionTraceLength
            ] =
                pendingJobId;

            ++executionTraceLength;
            ++jobsExecuted;


            pendingCommand =
                PersistentWorkerCommand.none;

            pendingJobId =
                0;


            /*
             * One deterministic job boundary.
             */
            completionGate.wait();
        }
    }


    /++
        Records the observer-side join transition.

        Calling Thread.join() itself is owned by the coordinator/test.
    +/
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
 * R0.4e-1 — one OS thread is created once and reused for multiple jobs.
 */
unittest
{
    auto waitingGate =
        new Barrier(2);

    auto commandGate =
        new Barrier(2);

    auto completionGate =
        new Barrier(2);


    auto worker =
        new PersistentWorkerLoop(
            StableWorkerIdentity(
                7,
                PersistentWorkerRole.compute
            ),
            waitingGate,
            commandGate,
            completionGate
        );


    auto thread =
        new Thread(
            &worker.run
        );


    assert(
        worker.lifecycle
        == PersistentWorkerLifecycle.notStarted
    );

    assert(worker.runEntries == 0);
    assert(worker.jobsExecuted == 0);


    /*
     * The worker thread is created and started exactly once.
     */
    thread.start();


    /*
     * First waiting boundary.
     */
    waitingGate.wait();


    assert(worker.runEntries == 1);
    assert(worker.waitEntries == 1);
    assert(worker.jobsExecuted == 0);

    assert(
        worker.lifecycle
        == PersistentWorkerLifecycle.waiting
    );


    /*
     * Job 101.
     */
    worker.pendingCommand =
        PersistentWorkerCommand.executeJob;

    worker.pendingJobId =
        101;


    commandGate.wait();
    completionGate.wait();


    assert(worker.runEntries == 1);
    assert(worker.jobsExecuted == 1);
    assert(worker.executionTraceLength == 1);
    assert(worker.executionTrace[0] == 101);


    /*
     * The same still-live worker returns to waiting.
     */
    waitingGate.wait();


    assert(worker.runEntries == 1);
    assert(worker.waitEntries == 2);

    assert(
        worker.lifecycle
        == PersistentWorkerLifecycle.waiting
    );


    /*
     * Job 202 on the same persistent run() invocation.
     */
    worker.pendingCommand =
        PersistentWorkerCommand.executeJob;

    worker.pendingJobId =
        202;


    commandGate.wait();
    completionGate.wait();


    assert(worker.runEntries == 1);
    assert(worker.jobsExecuted == 2);
    assert(worker.executionTraceLength == 2);

    assert(worker.executionTrace[0] == 101);
    assert(worker.executionTrace[1] == 202);


    /*
     * The worker reaches a third waiting boundary before shutdown.
     */
    waitingGate.wait();


    assert(worker.runEntries == 1);
    assert(worker.waitEntries == 3);

    assert(
        worker.lifecycle
        == PersistentWorkerLifecycle.waiting
    );


    /*
     * Cooperative shutdown wakes the waiting worker.
     */
    worker.pendingCommand =
        PersistentWorkerCommand.shutdown;


    commandGate.wait();
    completionGate.wait();


    assert(worker.runEntries == 1);
    assert(worker.jobsExecuted == 2);
    assert(worker.shutdownWasObserved);

    assert(
        worker.lifecycle
        == PersistentWorkerLifecycle.shutdownObserved
    );


    /*
     * The same single thread exits and is joined.
     */
    thread.join();

    worker.markJoined();


    assert(
        worker.lifecycle
        == PersistentWorkerLifecycle.joined
    );

    assert(worker.runEntries == 1);
    assert(worker.waitEntries == 3);
    assert(worker.jobsExecuted == 2);
    assert(worker.executionTraceLength == 2);

    assert(worker.executionTrace[0] == 101);
    assert(worker.executionTrace[1] == 202);

    assert(worker.identity.stableWorkerId == 7);

    assert(
        worker.identity.role
        == PersistentWorkerRole.compute
    );
}
