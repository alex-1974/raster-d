module pipeline_state_machine;

import pipeline_vocabulary :
    PipelineLimits,
    PipelineStage;


/++
    R0.4d research-local per-work-unit state.

    stableWorkUnitId exists only to make deterministic test traces and
    diagnostics possible. It is not promoted into raster geometry or views.
+/
struct PipelineWorkState
{
    size_t stableWorkUnitId;

    PipelineStage stage =
        PipelineStage.notAdmitted;
}


/++
    Research-local transition result.

    Limit and stage failures are expected deterministic outcomes, not
    exceptions.
+/
enum PipelineTransitionError : ubyte
{
    none,

    wrongStage,

    activeLimitReached,
    materializingLimitReached,
    computingLimitReached,
    handoffCapacityReached,

    invalidAccounting,

    internalFailure
}


/++
    Current and peak count evidence for the deterministic pipeline model.
+/
struct PipelineAccounting
{
    size_t activeWorkUnits;

    size_t materializing;
    size_t readyForCompute;
    size_t computing;

    size_t completedPendingRelease;

    size_t handoffCreditsInUse;


    size_t peakActiveWorkUnits;

    size_t peakMaterializing;
    size_t peakReadyForCompute;
    size_t peakComputing;

    size_t peakHandoffCreditsInUse;
}


private bool tryAdd(
    size_t left,
    size_t right,
    out size_t result
)
@safe
pure
nothrow
@nogc
{
    if (
        right
        > size_t.max - left
    )
    {
        return false;
    }


    result =
        left + right;

    return true;
}


/++
    Single-threaded R0.4d-1 state machine.

    It proves transition and count semantics only.

    It is not a queue, worker pool, scheduler or production executor.
+/
struct PipelineStateMachine
{
    PipelineLimits limits;

    PipelineAccounting accounting;


    /++
        Verifies the exact research accounting identities and configured bounds.
    +/
    @property
    bool invariantsHold() const
    @safe
    pure
    nothrow
    @nogc
    {
        size_t handoffExpected;

        if (
            !tryAdd(
                accounting.materializing,
                accounting.readyForCompute,
                handoffExpected
            )
        )
        {
            return false;
        }


        if (
            handoffExpected
            != accounting.handoffCreditsInUse
        )
        {
            return false;
        }


        size_t activeExpected;

        if (
            !tryAdd(
                handoffExpected,
                accounting.computing,
                activeExpected
            )
        )
        {
            return false;
        }


        if (
            !tryAdd(
                activeExpected,
                accounting.completedPendingRelease,
                activeExpected
            )
        )
        {
            return false;
        }


        if (
            activeExpected
            != accounting.activeWorkUnits
        )
        {
            return false;
        }


        if (
            accounting.activeWorkUnits
                > limits.maxActiveWorkUnits
            || accounting.materializing
                > limits.maxMaterializing
            || accounting.computing
                > limits.maxComputing
            || accounting.handoffCreditsInUse
                > limits.handoffCapacity
        )
        {
            return false;
        }


        if (
            accounting.peakActiveWorkUnits
                < accounting.activeWorkUnits
            || accounting.peakMaterializing
                < accounting.materializing
            || accounting.peakReadyForCompute
                < accounting.readyForCompute
            || accounting.peakComputing
                < accounting.computing
            || accounting.peakHandoffCreditsInUse
                < accounting.handoffCreditsInUse
        )
        {
            return false;
        }


        if (
            accounting.peakActiveWorkUnits
                > limits.maxActiveWorkUnits
            || accounting.peakMaterializing
                > limits.maxMaterializing
            || accounting.peakComputing
                > limits.maxComputing
            || accounting.peakHandoffCreditsInUse
                > limits.handoffCapacity
        )
        {
            return false;
        }


        return true;
    }


    private void updatePeaks()
    @safe
    pure
    nothrow
    @nogc
    {
        if (
            accounting.activeWorkUnits
            > accounting.peakActiveWorkUnits
        )
        {
            accounting.peakActiveWorkUnits =
                accounting.activeWorkUnits;
        }


        if (
            accounting.materializing
            > accounting.peakMaterializing
        )
        {
            accounting.peakMaterializing =
                accounting.materializing;
        }


        if (
            accounting.readyForCompute
            > accounting.peakReadyForCompute
        )
        {
            accounting.peakReadyForCompute =
                accounting.readyForCompute;
        }


        if (
            accounting.computing
            > accounting.peakComputing
        )
        {
            accounting.peakComputing =
                accounting.computing;
        }


        if (
            accounting.handoffCreditsInUse
            > accounting.peakHandoffCreditsInUse
        )
        {
            accounting.peakHandoffCreditsInUse =
                accounting.handoffCreditsInUse;
        }
    }


    /++
        Admission + materialization start.

        One handoff credit is reserved before entering materializing.
    +/
    PipelineTransitionError tryStartMaterialization(
        ref PipelineWorkState work
    )
    @safe
    pure
    nothrow
    @nogc
    {
        if (!invariantsHold)
        {
            return PipelineTransitionError.invalidAccounting;
        }


        if (
            work.stage
            != PipelineStage.notAdmitted
        )
        {
            return PipelineTransitionError.wrongStage;
        }


        if (
            accounting.activeWorkUnits
            >= limits.maxActiveWorkUnits
        )
        {
            return PipelineTransitionError.activeLimitReached;
        }


        if (
            accounting.materializing
            >= limits.maxMaterializing
        )
        {
            return PipelineTransitionError.materializingLimitReached;
        }


        if (
            accounting.handoffCreditsInUse
            >= limits.handoffCapacity
        )
        {
            return PipelineTransitionError.handoffCapacityReached;
        }


        const previousWork =
            work;

        const previousAccounting =
            accounting;


        work.stage =
            PipelineStage.materializing;

        ++accounting.activeWorkUnits;
        ++accounting.materializing;
        ++accounting.handoffCreditsInUse;

        updatePeaks();


        if (!invariantsHold)
        {
            work =
                previousWork;

            accounting =
                previousAccounting;

            return PipelineTransitionError.internalFailure;
        }


        return PipelineTransitionError.none;
    }


    /++
        Completes materialization.

        The reserved handoff credit remains occupied while the work waits for
        compute.
    +/
    PipelineTransitionError finishMaterialization(
        ref PipelineWorkState work
    )
    @safe
    pure
    nothrow
    @nogc
    {
        if (!invariantsHold)
        {
            return PipelineTransitionError.invalidAccounting;
        }


        if (
            work.stage
            != PipelineStage.materializing
        )
        {
            return PipelineTransitionError.wrongStage;
        }


        if (
            accounting.materializing == 0
        )
        {
            return PipelineTransitionError.invalidAccounting;
        }


        const previousWork =
            work;

        const previousAccounting =
            accounting;


        work.stage =
            PipelineStage.readyForCompute;

        --accounting.materializing;
        ++accounting.readyForCompute;

        updatePeaks();


        if (!invariantsHold)
        {
            work =
                previousWork;

            accounting =
                previousAccounting;

            return PipelineTransitionError.internalFailure;
        }


        return PipelineTransitionError.none;
    }


    /++
        Starts compute.

        Compute consumes one ready item and releases that item's handoff credit.
    +/
    PipelineTransitionError tryStartCompute(
        ref PipelineWorkState work
    )
    @safe
    pure
    nothrow
    @nogc
    {
        if (!invariantsHold)
        {
            return PipelineTransitionError.invalidAccounting;
        }


        if (
            work.stage
            != PipelineStage.readyForCompute
        )
        {
            return PipelineTransitionError.wrongStage;
        }


        if (
            accounting.readyForCompute == 0
            || accounting.handoffCreditsInUse == 0
        )
        {
            return PipelineTransitionError.invalidAccounting;
        }


        if (
            accounting.computing
            >= limits.maxComputing
        )
        {
            return PipelineTransitionError.computingLimitReached;
        }


        const previousWork =
            work;

        const previousAccounting =
            accounting;


        work.stage =
            PipelineStage.computing;

        --accounting.readyForCompute;
        --accounting.handoffCreditsInUse;
        ++accounting.computing;

        updatePeaks();


        if (!invariantsHold)
        {
            work =
                previousWork;

            accounting =
                previousAccounting;

            return PipelineTransitionError.internalFailure;
        }


        return PipelineTransitionError.none;
    }


    /++
        Completes compute.

        The work unit remains active until the explicit release transition.
    +/
    PipelineTransitionError finishCompute(
        ref PipelineWorkState work
    )
    @safe
    pure
    nothrow
    @nogc
    {
        if (!invariantsHold)
        {
            return PipelineTransitionError.invalidAccounting;
        }


        if (
            work.stage
            != PipelineStage.computing
        )
        {
            return PipelineTransitionError.wrongStage;
        }


        if (
            accounting.computing == 0
        )
        {
            return PipelineTransitionError.invalidAccounting;
        }


        const previousWork =
            work;

        const previousAccounting =
            accounting;


        work.stage =
            PipelineStage.completed;

        --accounting.computing;
        ++accounting.completedPendingRelease;

        updatePeaks();


        if (!invariantsHold)
        {
            work =
                previousWork;

            accounting =
                previousAccounting;

            return PipelineTransitionError.internalFailure;
        }


        return PipelineTransitionError.none;
    }


    /++
        Releases one successfully completed work unit.

        Active-work ownership ends here.
    +/
    PipelineTransitionError releaseCompleted(
        ref PipelineWorkState work
    )
    @safe
    pure
    nothrow
    @nogc
    {
        if (!invariantsHold)
        {
            return PipelineTransitionError.invalidAccounting;
        }


        if (
            work.stage
            != PipelineStage.completed
        )
        {
            return PipelineTransitionError.wrongStage;
        }


        if (
            accounting.completedPendingRelease == 0
            || accounting.activeWorkUnits == 0
        )
        {
            return PipelineTransitionError.invalidAccounting;
        }


        const previousWork =
            work;

        const previousAccounting =
            accounting;


        work.stage =
            PipelineStage.released;

        --accounting.completedPendingRelease;
        --accounting.activeWorkUnits;

        updatePeaks();


        if (!invariantsHold)
        {
            work =
                previousWork;

            accounting =
                previousAccounting;

            return PipelineTransitionError.internalFailure;
        }


        return PipelineTransitionError.none;
    }
}


/*
 * Complete single-work success lifecycle.
 */
unittest
{
    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            1,
            1,
            1,
            1
        );


    PipelineWorkState work;

    work.stableWorkUnitId = 10;


    assert(machine.invariantsHold);


    assert(
        machine.tryStartMaterialization(work)
        == PipelineTransitionError.none
    );

    assert(
        work.stage
        == PipelineStage.materializing
    );

    assert(machine.accounting.activeWorkUnits == 1);
    assert(machine.accounting.materializing == 1);
    assert(machine.accounting.handoffCreditsInUse == 1);
    assert(machine.invariantsHold);


    assert(
        machine.finishMaterialization(work)
        == PipelineTransitionError.none
    );

    assert(
        work.stage
        == PipelineStage.readyForCompute
    );

    assert(machine.accounting.materializing == 0);
    assert(machine.accounting.readyForCompute == 1);
    assert(machine.accounting.handoffCreditsInUse == 1);
    assert(machine.invariantsHold);


    assert(
        machine.tryStartCompute(work)
        == PipelineTransitionError.none
    );

    assert(
        work.stage
        == PipelineStage.computing
    );

    assert(machine.accounting.readyForCompute == 0);
    assert(machine.accounting.computing == 1);
    assert(machine.accounting.handoffCreditsInUse == 0);
    assert(machine.invariantsHold);


    assert(
        machine.finishCompute(work)
        == PipelineTransitionError.none
    );

    assert(
        work.stage
        == PipelineStage.completed
    );

    assert(machine.accounting.computing == 0);
    assert(machine.accounting.completedPendingRelease == 1);
    assert(machine.accounting.activeWorkUnits == 1);
    assert(machine.invariantsHold);


    assert(
        machine.releaseCompleted(work)
        == PipelineTransitionError.none
    );

    assert(
        work.stage
        == PipelineStage.released
    );

    assert(machine.accounting.activeWorkUnits == 0);
    assert(machine.accounting.completedPendingRelease == 0);
    assert(machine.accounting.handoffCreditsInUse == 0);
    assert(machine.invariantsHold);


    assert(machine.accounting.peakActiveWorkUnits == 1);
    assert(machine.accounting.peakMaterializing == 1);
    assert(machine.accounting.peakReadyForCompute == 1);
    assert(machine.accounting.peakComputing == 1);
    assert(machine.accounting.peakHandoffCreditsInUse == 1);
}


/*
 * Handoff credit is reserved before materialization and blocks a second
 * upstream admission until compute starts for the first ready item.
 */
unittest
{
    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            3,
            2,
            1,
            1
        );


    PipelineWorkState first;
    PipelineWorkState second;

    first.stableWorkUnitId = 20;
    second.stableWorkUnitId = 21;


    assert(
        machine.tryStartMaterialization(first)
        == PipelineTransitionError.none
    );


    const beforeBlockedWork =
        second;

    const beforeBlockedAccounting =
        machine.accounting;


    assert(
        machine.tryStartMaterialization(second)
        == PipelineTransitionError.handoffCapacityReached
    );

    assert(second == beforeBlockedWork);
    assert(machine.accounting == beforeBlockedAccounting);


    assert(
        machine.finishMaterialization(first)
        == PipelineTransitionError.none
    );


    /*
     * Credit remains occupied while first waits for compute.
     */
    assert(machine.accounting.handoffCreditsInUse == 1);


    assert(
        machine.tryStartMaterialization(second)
        == PipelineTransitionError.handoffCapacityReached
    );


    assert(
        machine.tryStartCompute(first)
        == PipelineTransitionError.none
    );


    /*
     * Compute start releases the handoff credit.
     */
    assert(machine.accounting.handoffCreditsInUse == 0);


    assert(
        machine.tryStartMaterialization(second)
        == PipelineTransitionError.none
    );

    assert(
        second.stage
        == PipelineStage.materializing
    );

    assert(machine.invariantsHold);
}


/*
 * Materialization capacity is independent of handoff capacity.
 */
unittest
{
    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            4,
            1,
            2,
            3
        );


    PipelineWorkState first;
    PipelineWorkState second;

    first.stableWorkUnitId = 30;
    second.stableWorkUnitId = 31;


    assert(
        machine.tryStartMaterialization(first)
        == PipelineTransitionError.none
    );


    const before =
        machine.accounting;


    assert(
        machine.tryStartMaterialization(second)
        == PipelineTransitionError.materializingLimitReached
    );

    assert(
        second.stage
        == PipelineStage.notAdmitted
    );

    assert(machine.accounting == before);
    assert(machine.invariantsHold);
}


/*
 * Compute capacity is independently bounded.
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

    first.stableWorkUnitId = 40;
    second.stableWorkUnitId = 41;


    assert(
        machine.tryStartMaterialization(first)
        == PipelineTransitionError.none
    );

    assert(
        machine.tryStartMaterialization(second)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishMaterialization(first)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishMaterialization(second)
        == PipelineTransitionError.none
    );


    assert(
        machine.tryStartCompute(first)
        == PipelineTransitionError.none
    );


    const beforeSecondCompute =
        machine.accounting;


    assert(
        machine.tryStartCompute(second)
        == PipelineTransitionError.computingLimitReached
    );

    assert(
        second.stage
        == PipelineStage.readyForCompute
    );

    assert(machine.accounting == beforeSecondCompute);


    assert(
        machine.finishCompute(first)
        == PipelineTransitionError.none
    );


    assert(
        machine.tryStartCompute(second)
        == PipelineTransitionError.none
    );

    assert(machine.invariantsHold);
}


/*
 * Completed work remains active until explicit release.
 */
unittest
{
    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            1,
            1,
            1,
            1
        );


    PipelineWorkState first;
    PipelineWorkState second;

    first.stableWorkUnitId = 50;
    second.stableWorkUnitId = 51;


    assert(
        machine.tryStartMaterialization(first)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishMaterialization(first)
        == PipelineTransitionError.none
    );

    assert(
        machine.tryStartCompute(first)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishCompute(first)
        == PipelineTransitionError.none
    );


    assert(machine.accounting.activeWorkUnits == 1);
    assert(machine.accounting.completedPendingRelease == 1);


    assert(
        machine.tryStartMaterialization(second)
        == PipelineTransitionError.activeLimitReached
    );


    assert(
        machine.releaseCompleted(first)
        == PipelineTransitionError.none
    );


    assert(
        machine.tryStartMaterialization(second)
        == PipelineTransitionError.none
    );

    assert(machine.invariantsHold);
}


/*
 * Wrong-stage transitions are rejected without mutation.
 */
unittest
{
    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            2,
            1,
            1,
            1
        );


    PipelineWorkState work;

    work.stableWorkUnitId = 60;


    const initialWork =
        work;

    const initialAccounting =
        machine.accounting;


    assert(
        machine.finishMaterialization(work)
        == PipelineTransitionError.wrongStage
    );

    assert(work == initialWork);
    assert(machine.accounting == initialAccounting);


    assert(
        machine.tryStartCompute(work)
        == PipelineTransitionError.wrongStage
    );

    assert(work == initialWork);
    assert(machine.accounting == initialAccounting);


    assert(
        machine.finishCompute(work)
        == PipelineTransitionError.wrongStage
    );

    assert(work == initialWork);
    assert(machine.accounting == initialAccounting);


    assert(
        machine.releaseCompleted(work)
        == PipelineTransitionError.wrongStage
    );

    assert(work == initialWork);
    assert(machine.accounting == initialAccounting);

    assert(machine.invariantsHold);
}


/*
 * Zero-work state requires no special execution path.

 * Zero configured capacity plus zero admitted work is internally consistent.
 */
unittest
{
    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            0,
            0,
            0,
            0
        );


    assert(machine.invariantsHold);

    assert(machine.accounting == PipelineAccounting.init);


    PipelineWorkState work;

    work.stableWorkUnitId = 70;


    assert(
        machine.tryStartMaterialization(work)
        == PipelineTransitionError.activeLimitReached
    );

    assert(
        work.stage
        == PipelineStage.notAdmitted
    );

    assert(machine.accounting == PipelineAccounting.init);
    assert(machine.invariantsHold);
}
