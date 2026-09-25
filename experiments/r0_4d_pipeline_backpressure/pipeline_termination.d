module pipeline_termination;

import core.sync.barrier :
    Barrier;

import core.thread :
    Thread;

import raster.region :
    Region2D;

import pipeline_vocabulary :
    PipelineLimits,
    PipelineStage;

import pipeline_state_machine :
    PipelineAccounting,
    PipelineStateMachine,
    PipelineTransitionError,
    PipelineWorkState;

import pipeline_raster_fixture :
    PipelineRasterFixture,
    tryCommitTaskOutput;


/++
    R0.4d research-local request termination reason.
+/
enum PipelineTerminationReason : ubyte
{
    open,
    failed,
    cancelled
}


/++
    Minimal request-level stage-start gate.

    The first terminal reason is retained.

    This is not a public cancellation token.
+/
struct PipelineTerminationGate
{
    PipelineTerminationReason reason =
        PipelineTerminationReason.open;


    @property
    bool closed() const
    @safe
    pure
    nothrow
    @nogc
    {
        return reason
            != PipelineTerminationReason.open;
    }


    void observeFailure()
    @safe
    pure
    nothrow
    @nogc
    {
        if (!closed)
        {
            reason =
                PipelineTerminationReason.failed;
        }
    }


    void observeCancellation()
    @safe
    pure
    nothrow
    @nogc
    {
        if (!closed)
        {
            reason =
                PipelineTerminationReason.cancelled;
        }
    }
}


/++
    Result from a gate-protected stage-start attempt.
+/
enum GatedStageStartError : ubyte
{
    none,
    dispatchClosed,
    transitionRejected
}


struct GatedStageStartResult
{
    GatedStageStartError error =
        GatedStageStartError.transitionRejected;

    PipelineTransitionError transitionError =
        PipelineTransitionError.none;


    @property
    bool started() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == GatedStageStartError.none;
    }
}


/++
    Request termination is checked before new work-unit admission.
+/
GatedStageStartResult tryStartMaterializationIfOpen(
    scope const(PipelineTerminationGate) gate,
    ref PipelineStateMachine machine,
    ref PipelineWorkState work
)
@safe
pure
nothrow
@nogc
{
    GatedStageStartResult result;


    if (gate.closed)
    {
        result.error =
            GatedStageStartError.dispatchClosed;

        return result;
    }


    const transitionError =
        machine.tryStartMaterialization(
            work
        );


    if (
        transitionError
        != PipelineTransitionError.none
    )
    {
        result.error =
            GatedStageStartError.transitionRejected;

        result.transitionError =
            transitionError;

        return result;
    }


    result.error =
        GatedStageStartError.none;

    return result;
}


/++
    Request termination is checked before a queued work unit may start compute.
+/
GatedStageStartResult tryStartComputeIfOpen(
    scope const(PipelineTerminationGate) gate,
    ref PipelineStateMachine machine,
    ref PipelineWorkState work
)
@safe
pure
nothrow
@nogc
{
    GatedStageStartResult result;


    if (gate.closed)
    {
        result.error =
            GatedStageStartError.dispatchClosed;

        return result;
    }


    const transitionError =
        machine.tryStartCompute(
            work
        );


    if (
        transitionError
        != PipelineTransitionError.none
    )
    {
        result.error =
            GatedStageStartError.transitionRejected;

        result.transitionError =
            transitionError;

        return result;
    }


    result.error =
        GatedStageStartError.none;

    return result;
}


/*
 * Real materialization stage held in flight by explicit barriers.
 */
private class HeldMaterializationWorker
{
    PipelineRasterFixture fixture;

    Barrier enteredGate;
    Barrier releaseGate;

    bool entered;
    bool returned;


    this(
        PipelineRasterFixture fixture,
        Barrier enteredGate,
        Barrier releaseGate
    )
    {
        this.fixture =
            fixture;

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

        fixture.materialize();

        returned = true;
    }
}


/*
 * Real compute stage held in flight by explicit barriers.
 */
private class HeldComputeWorker
{
    PipelineRasterFixture fixture;

    Barrier enteredGate;
    Barrier releaseGate;

    bool entered;
    bool returned;


    this(
        PipelineRasterFixture fixture,
        Barrier enteredGate,
        Barrier releaseGate
    )
    {
        this.fixture =
            fixture;

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

        fixture.compute();

        returned = true;
    }
}


private size_t coveredCount(
    scope const(ubyte)[] coverage
)
@safe
pure
nothrow
@nogc
{
    size_t result;


    foreach (covered; coverage)
    {
        if (covered == 1)
        {
            ++result;
        }
    }


    return result;
}


/*
 * R0.4d-5 failure while one materialization stage is already running.
 *
 * The running materialization is non-preemptive. It may finish, but the closed
 * request gate prevents the later compute start. Its retained raster is then
 * released through readyForCompute -> released cleanup.
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

    const firstTask =
        Region2D(
            1020,
            2030,
            3,
            2
        );


    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            2,
            2,
            1,
            2
        );


    PipelineTerminationGate gate;


    PipelineWorkState firstState;
    PipelineWorkState secondState;

    firstState.stableWorkUnitId = 0;
    secondState.stableWorkUnitId = 1;


    auto first =
        new PipelineRasterFixture(
            logicalExtent,
            firstTask
        );

    assert(first.prepareDependency());


    auto startFirst =
        tryStartMaterializationIfOpen(
            gate,
            machine,
            firstState
        );

    assert(startFirst.started);

    assert(
        firstState.stage
        == PipelineStage.materializing
    );


    auto enteredGate =
        new Barrier(2);

    auto releaseGate =
        new Barrier(2);


    auto worker =
        new HeldMaterializationWorker(
            first,
            enteredGate,
            releaseGate
        );


    auto thread =
        new Thread(
            &worker.run
        );


    thread.start();

    enteredGate.wait();


    assert(worker.entered);
    assert(!worker.returned);


    /*
     * Failure is observed while materialization remains in flight.
     */
    gate.observeFailure();

    assert(gate.closed);

    assert(
        gate.reason
        == PipelineTerminationReason.failed
    );


    /*
     * A new otherwise-admissible work unit cannot enter the pipeline.
     */
    const secondBefore =
        secondState;

    const PipelineAccounting accountingBeforeSecond =
        machine.accounting;


    auto startSecond =
        tryStartMaterializationIfOpen(
            gate,
            machine,
            secondState
        );


    assert(!startSecond.started);

    assert(
        startSecond.error
        == GatedStageStartError.dispatchClosed
    );

    assert(secondState == secondBefore);

    assert(
        machine.accounting
        == accountingBeforeSecond
    );


    /*
     * The already-running materializer is not preempted.
     */
    releaseGate.wait();

    thread.join();


    assert(worker.returned);
    assert(first.materializationCompleted);
    assert(first.residentBytes != 0);


    assert(
        machine.finishMaterialization(firstState)
        == PipelineTransitionError.none
    );

    assert(
        firstState.stage
        == PipelineStage.readyForCompute
    );


    /*
     * The closed request prevents this retained item from starting compute.
     */
    const firstBeforeCompute =
        firstState;

    const PipelineAccounting accountingBeforeCompute =
        machine.accounting;


    auto startCompute =
        tryStartComputeIfOpen(
            gate,
            machine,
            firstState
        );


    assert(!startCompute.started);

    assert(
        startCompute.error
        == GatedStageStartError.dispatchClosed
    );

    assert(
        firstState
        == firstBeforeCompute
    );

    assert(
        machine.accounting
        == accountingBeforeCompute
    );

    assert(!first.computeCompleted);


    /*
     * Retained raster ownership and handoff credit are both released.
     */
    first.releaseResident();

    assert(first.residentBytes == 0);


    assert(
        machine.releaseReadyWithoutCompute(firstState)
        == PipelineTransitionError.none
    );


    assert(
        firstState.stage
        == PipelineStage.released
    );

    assert(machine.accounting.activeWorkUnits == 0);
    assert(machine.accounting.materializing == 0);
    assert(machine.accounting.readyForCompute == 0);
    assert(machine.accounting.computing == 0);
    assert(machine.accounting.completedPendingRelease == 0);
    assert(machine.accounting.handoffCreditsInUse == 0);

    assert(machine.invariantsHold);
}


/*
 * R0.4d-5 cancellation while one compute stage is already running and another
 * retained work unit is queued at readyForCompute.
 *
 * The running compute may finish and publish partial coverage.
 *
 * The queued work unit may not start compute and must release retained state.
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


    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            3,
            2,
            1,
            2
        );


    PipelineTerminationGate gate;


    PipelineWorkState firstState;
    PipelineWorkState secondState;
    PipelineWorkState thirdState;

    firstState.stableWorkUnitId = 0;
    secondState.stableWorkUnitId = 1;
    thirdState.stableWorkUnitId = 2;


    auto first =
        new PipelineRasterFixture(
            logicalExtent,
            tasks[0]
        );

    auto second =
        new PipelineRasterFixture(
            logicalExtent,
            tasks[1]
        );


    assert(first.prepareDependency());
    assert(second.prepareDependency());


    assert(
        tryStartMaterializationIfOpen(
            gate,
            machine,
            firstState
        ).started
    );

    assert(
        tryStartMaterializationIfOpen(
            gate,
            machine,
            secondState
        ).started
    );


    first.materialize();
    second.materialize();

    assert(first.materializationCompleted);
    assert(second.materializationCompleted);

    assert(first.residentBytes != 0);
    assert(second.residentBytes != 0);


    assert(
        machine.finishMaterialization(firstState)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishMaterialization(secondState)
        == PipelineTransitionError.none
    );


    assert(machine.accounting.readyForCompute == 2);
    assert(machine.accounting.handoffCreditsInUse == 2);


    assert(
        tryStartComputeIfOpen(
            gate,
            machine,
            firstState
        ).started
    );


    assert(
        firstState.stage
        == PipelineStage.computing
    );

    assert(
        secondState.stage
        == PipelineStage.readyForCompute
    );


    auto computeEnteredGate =
        new Barrier(2);

    auto computeReleaseGate =
        new Barrier(2);


    auto worker =
        new HeldComputeWorker(
            first,
            computeEnteredGate,
            computeReleaseGate
        );


    auto thread =
        new Thread(
            &worker.run
        );


    thread.start();

    computeEnteredGate.wait();


    assert(worker.entered);
    assert(!worker.returned);


    /*
     * Cancellation is observed while the first compute body remains in flight.
     */
    gate.observeCancellation();

    assert(gate.closed);

    assert(
        gate.reason
        == PipelineTerminationReason.cancelled
    );


    /*
     * The retained second item is not allowed to enter compute.
     */
    const secondBeforeCompute =
        secondState;

    const PipelineAccounting accountingBeforeSecondCompute =
        machine.accounting;


    auto secondComputeStart =
        tryStartComputeIfOpen(
            gate,
            machine,
            secondState
        );


    assert(!secondComputeStart.started);

    assert(
        secondComputeStart.error
        == GatedStageStartError.dispatchClosed
    );

    assert(
        secondState
        == secondBeforeCompute
    );

    assert(
        machine.accounting
        == accountingBeforeSecondCompute
    );


    /*
     * New upstream work is closed as well.
     */
    auto thirdStart =
        tryStartMaterializationIfOpen(
            gate,
            machine,
            thirdState
        );


    assert(!thirdStart.started);

    assert(
        thirdStart.error
        == GatedStageStartError.dispatchClosed
    );

    assert(
        thirdState.stage
        == PipelineStage.notAdmitted
    );


    /*
     * The running compute remains non-preemptive.
     */
    computeReleaseGate.wait();

    thread.join();


    assert(worker.returned);
    assert(first.computeCompleted);


    assert(
        machine.finishCompute(firstState)
        == PipelineTransitionError.none
    );


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    auto output =
        new ubyte[sampleCount];

    auto completedCoverage =
        new ubyte[sampleCount];


    assert(
        tryCommitTaskOutput(
            requestedOutput,
            tasks[0],
            first.output,
            output,
            completedCoverage
        )
    );


    const firstCovered =
        coveredCount(
            completedCoverage
        );


    assert(
        firstCovered
        == tasks[0].width * tasks[0].height
    );

    assert(
        firstCovered
        < sampleCount
    );


    first.releaseResident();

    assert(
        machine.releaseCompleted(firstState)
        == PipelineTransitionError.none
    );


    /*
     * The queued retained item never computes and is released directly.
     */
    assert(!second.computeCompleted);

    second.releaseResident();

    assert(second.residentBytes == 0);


    assert(
        machine.releaseReadyWithoutCompute(secondState)
        == PipelineTransitionError.none
    );


    const bool requestCompleted =
        coveredCount(completedCoverage)
            == sampleCount
        && machine.accounting.activeWorkUnits == 0;


    assert(!requestCompleted);


    assert(first.residentBytes == 0);
    assert(second.residentBytes == 0);

    assert(machine.accounting.activeWorkUnits == 0);
    assert(machine.accounting.materializing == 0);
    assert(machine.accounting.readyForCompute == 0);
    assert(machine.accounting.computing == 0);
    assert(machine.accounting.completedPendingRelease == 0);
    assert(machine.accounting.handoffCreditsInUse == 0);

    assert(machine.invariantsHold);
}


/*
 * The first observed terminal reason is stable.
 */
unittest
{
    PipelineTerminationGate failureFirst;

    failureFirst.observeFailure();
    failureFirst.observeCancellation();

    assert(
        failureFirst.reason
        == PipelineTerminationReason.failed
    );


    PipelineTerminationGate cancellationFirst;

    cancellationFirst.observeCancellation();
    cancellationFirst.observeFailure();

    assert(
        cancellationFirst.reason
        == PipelineTerminationReason.cancelled
    );
}
