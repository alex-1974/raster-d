module reuse_probe;

import raster.region :
    Region2D;

import synchronous_execution :
    executeSynchronousNeighbourhood;

import bounded_parallel_execution :
    executeBoundedParallelNeighbourhood;

import scheduling_policy_oracle :
    PolicyClass,
    ReadyWork,
    dispatchFifo;

import pipeline_vocabulary :
    PipelineLimits;

import pipeline_state_machine :
    PipelineStateMachine,
    PipelineTransitionError,
    PipelineWorkState;

import worker_vocabulary :
    PersistentWorkerLifecycle,
    PersistentWorkerRole,
    StableRequestIdentity,
    StableWorkerIdentity,
    StageQueueLimits;


/*
 * R0.4e-0 imports and exercises the immutable execution references without
 * creating persistent threads or queues.
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
            2
        );


    const Region2D[2] tasks =
    [
        Region2D(
            1020,
            2030,
            3,
            2
        ),

        Region2D(
            1023,
            2030,
            5,
            2
        )
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
        bounded.accounting.peakActiveWorkUnits
        <= bounded.accounting.maxActiveWorkUnits
    );

    assert(
        bounded.accounting.currentResidentRasterBytes
        == 0
    );


    /*
     * R0.4c stable FIFO reference remains independently reusable.
     */
    const ReadyWork[2] ready =
    [
        ReadyWork(
            20,
            1,
            PolicyClass.interactive,
            100
        ),

        ReadyWork(
            10,
            0,
            PolicyClass.throughput,
            -100
        )
    ];


    auto fifo =
        dispatchFifo(
            ready[]
        );


    assert(fifo.ok);
    assert(fifo.workUnitIds.length == 2);
    assert(fifo.workUnitIds[0] == 10);
    assert(fifo.workUnitIds[1] == 20);


    /*
     * R0.4d stage-accounting semantics remain independently reusable.
     */
    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            1,
            1,
            1,
            1
        );


    PipelineWorkState work;

    work.stableWorkUnitId = 30;


    assert(
        machine.tryStartMaterialization(work)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishMaterialization(work)
        == PipelineTransitionError.none
    );

    assert(
        machine.tryStartCompute(work)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishCompute(work)
        == PipelineTransitionError.none
    );

    assert(
        machine.releaseCompleted(work)
        == PipelineTransitionError.none
    );


    assert(machine.accounting.activeWorkUnits == 0);
    assert(machine.accounting.handoffCreditsInUse == 0);
    assert(machine.invariantsHold);


    /*
     * New R0.4e vocabulary remains separate from historical execution state.
     */
    const worker =
        StableWorkerIdentity(
            1,
            PersistentWorkerRole.materialization
        );

    const request =
        StableRequestIdentity(1);

    const queueLimits =
        StageQueueLimits(
            1,
            1
        );


    assert(worker.stableWorkerId == 1);
    assert(request.stableRequestId == 1);

    assert(
        PersistentWorkerLifecycle.notStarted
        != PersistentWorkerLifecycle.joined
    );

    assert(queueLimits.materializationQueueCapacity == 1);
    assert(queueLimits.computeQueueCapacity == 1);
}
