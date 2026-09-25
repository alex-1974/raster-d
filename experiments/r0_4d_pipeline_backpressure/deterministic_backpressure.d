module deterministic_backpressure;

import core.sync.barrier :
    Barrier;

import core.thread :
    Thread;

import pipeline_vocabulary :
    PipelineLimits,
    PipelineStage;

import pipeline_state_machine :
    PipelineAccounting,
    PipelineStateMachine,
    PipelineTransitionError,
    PipelineWorkState;


/*
 * One held compute-stage body.
 *
 * The worker performs no raster arithmetic because R0.4d-3 isolates
 * backpressure semantics. R0.4d-2 already proves real raster stage overlap.
 *
 * enteredGate proves the compute body is in flight.
 * releaseGate keeps it in flight until the coordinator has observed upstream
 * resumption.
 */
private class HeldComputeStage
{
    Barrier enteredGate;
    Barrier releaseGate;

    bool entered;
    bool returned;


    this(
        Barrier enteredGate,
        Barrier releaseGate
    )
    {
        this.enteredGate =
            enteredGate;

        this.releaseGate =
            releaseGate;
    }


    void run()
    {
        entered = true;

        enteredGate.wait();

        releaseGate.wait();

        returned = true;
    }
}


/*
 * R0.4d-3 — deterministic backpressure saturation and resumption.
 *
 * The state machine remains coordinator-owned. The worker thread exists only
 * to hold one already-started compute stage in flight using explicit
 * synchronization.
 */
unittest
{
    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            3,
            2,
            1,
            2
        );


    PipelineWorkState first;
    PipelineWorkState second;
    PipelineWorkState third;

    first.stableWorkUnitId = 0;
    second.stableWorkUnitId = 1;
    third.stableWorkUnitId = 2;


    /*
     * Reserve both handoff credits before either materialization finishes.
     */
    assert(
        machine.tryStartMaterialization(first)
        == PipelineTransitionError.none
    );

    assert(
        machine.tryStartMaterialization(second)
        == PipelineTransitionError.none
    );


    assert(machine.accounting.activeWorkUnits == 2);
    assert(machine.accounting.materializing == 2);
    assert(machine.accounting.handoffCreditsInUse == 2);
    assert(machine.invariantsHold);


    assert(
        machine.finishMaterialization(first)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishMaterialization(second)
        == PipelineTransitionError.none
    );


    assert(machine.accounting.activeWorkUnits == 2);
    assert(machine.accounting.materializing == 0);
    assert(machine.accounting.readyForCompute == 2);
    assert(machine.accounting.computing == 0);
    assert(machine.accounting.handoffCreditsInUse == 2);
    assert(machine.invariantsHold);


    /*
     * The third work unit is otherwise admissible:
     *
     * active:        2 < 3
     * materializing: 0 < 2
     *
     * Only handoff capacity is full.
     */
    const thirdBeforeBlockedAttempt =
        third;

    const PipelineAccounting accountingBeforeBlockedAttempt =
        machine.accounting;


    assert(
        machine.tryStartMaterialization(third)
        == PipelineTransitionError.handoffCapacityReached
    );


    assert(
        third
        == thirdBeforeBlockedAttempt
    );

    assert(
        machine.accounting
        == accountingBeforeBlockedAttempt
    );

    assert(
        third.stage
        == PipelineStage.notAdmitted
    );

    assert(machine.invariantsHold);


    /*
     * Starting compute for the first ready item consumes that ready slot and
     * releases exactly one handoff credit.
     */
    assert(
        machine.tryStartCompute(first)
        == PipelineTransitionError.none
    );


    assert(
        first.stage
        == PipelineStage.computing
    );

    assert(machine.accounting.readyForCompute == 1);
    assert(machine.accounting.computing == 1);
    assert(machine.accounting.handoffCreditsInUse == 1);
    assert(machine.invariantsHold);


    auto computeEnteredGate =
        new Barrier(2);

    auto computeReleaseGate =
        new Barrier(2);


    auto heldCompute =
        new HeldComputeStage(
            computeEnteredGate,
            computeReleaseGate
        );


    auto computeThread =
        new Thread(
            &heldCompute.run
        );


    computeThread.start();


    /*
     * Returning proves the compute-stage body is now in flight.
     *
     * The worker remains blocked at computeReleaseGate.
     */
    computeEnteredGate.wait();


    assert(heldCompute.entered);
    assert(!heldCompute.returned);

    assert(
        first.stage
        == PipelineStage.computing
    );


    /*
     * The exact same third work unit that was rejected above must now start
     * successfully because compute start released one handoff credit.
     */
    assert(
        machine.tryStartMaterialization(third)
        == PipelineTransitionError.none
    );


    assert(
        third.stage
        == PipelineStage.materializing
    );


    assert(machine.accounting.activeWorkUnits == 3);
    assert(machine.accounting.materializing == 1);
    assert(machine.accounting.readyForCompute == 1);
    assert(machine.accounting.computing == 1);
    assert(machine.accounting.handoffCreditsInUse == 2);
    assert(machine.invariantsHold);


    const bool backpressureReleasedUpstream = true;


    /*
     * Only after upstream resumption is observed do we let the held compute
     * body return.
     */
    computeReleaseGate.wait();

    computeThread.join();


    assert(heldCompute.returned);


    /*
     * Complete and release every admitted work unit so the proof also checks
     * final accounting cleanup.
     */
    assert(
        machine.finishCompute(first)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishMaterialization(third)
        == PipelineTransitionError.none
    );


    assert(
        machine.releaseCompleted(first)
        == PipelineTransitionError.none
    );


    assert(
        machine.tryStartCompute(second)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishCompute(second)
        == PipelineTransitionError.none
    );

    assert(
        machine.releaseCompleted(second)
        == PipelineTransitionError.none
    );


    assert(
        machine.tryStartCompute(third)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishCompute(third)
        == PipelineTransitionError.none
    );

    assert(
        machine.releaseCompleted(third)
        == PipelineTransitionError.none
    );


    assert(backpressureReleasedUpstream);

    assert(machine.accounting.activeWorkUnits == 0);
    assert(machine.accounting.materializing == 0);
    assert(machine.accounting.readyForCompute == 0);
    assert(machine.accounting.computing == 0);
    assert(machine.accounting.completedPendingRelease == 0);
    assert(machine.accounting.handoffCreditsInUse == 0);

    assert(machine.invariantsHold);


    /*
     * The configured bounds were reached but never exceeded.
     */
    assert(machine.accounting.peakActiveWorkUnits == 3);
    assert(machine.accounting.peakMaterializing == 2);
    assert(machine.accounting.peakReadyForCompute == 2);
    assert(machine.accounting.peakComputing == 1);
    assert(machine.accounting.peakHandoffCreditsInUse == 2);

    assert(
        machine.accounting.peakActiveWorkUnits
        <= machine.limits.maxActiveWorkUnits
    );

    assert(
        machine.accounting.peakMaterializing
        <= machine.limits.maxMaterializing
    );

    assert(
        machine.accounting.peakComputing
        <= machine.limits.maxComputing
    );

    assert(
        machine.accounting.peakHandoffCreditsInUse
        <= machine.limits.handoffCapacity
    );
}
