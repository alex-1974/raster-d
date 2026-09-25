module stage_order_independence;

import core.sync.barrier :
    Barrier;

import core.thread :
    Thread;

import raster.region :
    Region2D;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import synchronous_execution :
    executeSynchronousNeighbourhood;

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


/*
 * One compute worker whose completion is controlled entirely by explicit
 * barriers.
 *
 * Every worker first reaches the shared allEnteredGate. It then waits on its
 * private releaseGate. After real raster compute returns, it reaches its
 * private completedGate so the coordinator can prove that completion before
 * releasing the other worker.
 */
private class OrderedComputeWorker
{
    PipelineRasterFixture fixture;

    Barrier allEnteredGate;
    Barrier releaseGate;
    Barrier completedGate;

    bool entered;
    bool computeReturned;


    this(
        PipelineRasterFixture fixture,
        Barrier allEnteredGate,
        Barrier releaseGate,
        Barrier completedGate
    )
    {
        this.fixture =
            fixture;

        this.allEnteredGate =
            allEnteredGate;

        this.releaseGate =
            releaseGate;

        this.completedGate =
            completedGate;
    }


    void run()
    {
        entered = true;

        allEnteredGate.wait();

        releaseGate.wait();

        fixture.compute();

        computeReturned = true;

        completedGate.wait();
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


private struct CompletionOrderResult
{
    bool requestCompleted;
    bool requestCompletedAfterFirst;

    size_t[] completionOrder;

    ubyte[] output;
    ubyte[] completedCoverage;

    PipelineAccounting finalAccounting;

    size_t finalResidentRasterBytes;
}


/*
 * Executes the same real two-work-unit raster request while forcing one of two
 * compute-completion orders.
 *
 * firstCompletesFirst == true:
 *
 *     0 then 1
 *
 * firstCompletesFirst == false:
 *
 *     1 then 0
 */
private CompletionOrderResult runForcedCompletionOrder(
    bool firstCompletesFirst
)
{
    CompletionOrderResult result;


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


    DecompositionIssue decompositionIssue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks[],
            decompositionIssue
        )
    );

    assert(
        decompositionIssue
        == DecompositionIssue.none
    );


    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            2,
            2,
            2,
            2
        );


    PipelineWorkState firstState;
    PipelineWorkState secondState;

    firstState.stableWorkUnitId = 0;
    secondState.stableWorkUnitId = 1;


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


    /*
     * Materialize and retain both work-unit sources.
     */
    assert(
        machine.tryStartMaterialization(firstState)
        == PipelineTransitionError.none
    );

    assert(
        machine.tryStartMaterialization(secondState)
        == PipelineTransitionError.none
    );


    first.materialize();
    second.materialize();

    assert(first.materializationCompleted);
    assert(second.materializationCompleted);

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


    /*
     * Both compute stages become active before either worker body is released.
     */
    assert(
        machine.tryStartCompute(firstState)
        == PipelineTransitionError.none
    );

    assert(
        machine.tryStartCompute(secondState)
        == PipelineTransitionError.none
    );


    assert(
        firstState.stage
        == PipelineStage.computing
    );

    assert(
        secondState.stage
        == PipelineStage.computing
    );

    assert(machine.accounting.activeWorkUnits == 2);
    assert(machine.accounting.computing == 2);
    assert(machine.accounting.handoffCreditsInUse == 0);
    assert(machine.invariantsHold);


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    result.output =
        new ubyte[sampleCount];

    result.completedCoverage =
        new ubyte[sampleCount];

    result.completionOrder =
        new size_t[2];


    auto allEnteredGate =
        new Barrier(3);

    auto firstReleaseGate =
        new Barrier(2);

    auto firstCompletedGate =
        new Barrier(2);

    auto secondReleaseGate =
        new Barrier(2);

    auto secondCompletedGate =
        new Barrier(2);


    auto firstWorker =
        new OrderedComputeWorker(
            first,
            allEnteredGate,
            firstReleaseGate,
            firstCompletedGate
        );

    auto secondWorker =
        new OrderedComputeWorker(
            second,
            allEnteredGate,
            secondReleaseGate,
            secondCompletedGate
        );


    auto firstThread =
        new Thread(
            &firstWorker.run
        );

    auto secondThread =
        new Thread(
            &secondWorker.run
        );


    firstThread.start();
    secondThread.start();


    /*
     * Both worker bodies are now entered and waiting on their private release
     * gates.
     */
    allEnteredGate.wait();


    assert(firstWorker.entered);
    assert(secondWorker.entered);

    assert(!firstWorker.computeReturned);
    assert(!secondWorker.computeReturned);


    if (firstCompletesFirst)
    {
        /*
         * Force work 0 to complete while work 1 is still held before compute.
         */
        firstReleaseGate.wait();
        firstCompletedGate.wait();

        assert(firstWorker.computeReturned);
        assert(first.computeCompleted);
        assert(!secondWorker.computeReturned);

        assert(
            machine.finishCompute(firstState)
            == PipelineTransitionError.none
        );

        assert(
            tryCommitTaskOutput(
                requestedOutput,
                tasks[0],
                first.output,
                result.output,
                result.completedCoverage
            )
        );

        first.releaseResident();

        assert(
            machine.releaseCompleted(firstState)
            == PipelineTransitionError.none
        );

        result.completionOrder[0] = 0;


        result.requestCompletedAfterFirst =
            allCovered(result.completedCoverage)
            && machine.accounting.activeWorkUnits == 0;


        assert(!result.requestCompletedAfterFirst);


        secondReleaseGate.wait();
        secondCompletedGate.wait();

        assert(secondWorker.computeReturned);
        assert(second.computeCompleted);

        assert(
            machine.finishCompute(secondState)
            == PipelineTransitionError.none
        );

        assert(
            tryCommitTaskOutput(
                requestedOutput,
                tasks[1],
                second.output,
                result.output,
                result.completedCoverage
            )
        );

        second.releaseResident();

        assert(
            machine.releaseCompleted(secondState)
            == PipelineTransitionError.none
        );

        result.completionOrder[1] = 1;
    }
    else
    {
        /*
         * Force work 1 to complete while work 0 is still held before compute.
         */
        secondReleaseGate.wait();
        secondCompletedGate.wait();

        assert(secondWorker.computeReturned);
        assert(second.computeCompleted);
        assert(!firstWorker.computeReturned);

        assert(
            machine.finishCompute(secondState)
            == PipelineTransitionError.none
        );

        assert(
            tryCommitTaskOutput(
                requestedOutput,
                tasks[1],
                second.output,
                result.output,
                result.completedCoverage
            )
        );

        second.releaseResident();

        assert(
            machine.releaseCompleted(secondState)
            == PipelineTransitionError.none
        );

        result.completionOrder[0] = 1;


        result.requestCompletedAfterFirst =
            allCovered(result.completedCoverage)
            && machine.accounting.activeWorkUnits == 0;


        assert(!result.requestCompletedAfterFirst);


        firstReleaseGate.wait();
        firstCompletedGate.wait();

        assert(firstWorker.computeReturned);
        assert(first.computeCompleted);

        assert(
            machine.finishCompute(firstState)
            == PipelineTransitionError.none
        );

        assert(
            tryCommitTaskOutput(
                requestedOutput,
                tasks[0],
                first.output,
                result.output,
                result.completedCoverage
            )
        );

        first.releaseResident();

        assert(
            machine.releaseCompleted(firstState)
            == PipelineTransitionError.none
        );

        result.completionOrder[1] = 0;
    }


    firstThread.join();
    secondThread.join();


    assert(firstWorker.computeReturned);
    assert(secondWorker.computeReturned);


    result.requestCompleted =
        allCovered(result.completedCoverage)
        && machine.accounting.activeWorkUnits == 0;


    result.finalAccounting =
        machine.accounting;

    result.finalResidentRasterBytes =
        first.residentBytes
        + second.residentBytes;


    assert(result.requestCompleted);
    assert(result.finalResidentRasterBytes == 0);

    assert(machine.accounting.activeWorkUnits == 0);
    assert(machine.accounting.materializing == 0);
    assert(machine.accounting.readyForCompute == 0);
    assert(machine.accounting.computing == 0);
    assert(machine.accounting.completedPendingRelease == 0);
    assert(machine.accounting.handoffCreditsInUse == 0);

    assert(machine.invariantsHold);


    assert(machine.accounting.peakActiveWorkUnits == 2);
    assert(machine.accounting.peakReadyForCompute == 2);
    assert(machine.accounting.peakComputing == 2);
    assert(machine.accounting.peakHandoffCreditsInUse == 2);


    return result;
}


/*
 * R0.4d-4 — exact raster result and request completion are independent of the
 * forced compute-completion order.
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

    assert(synchronous.ok);
    assert(synchronous.requestCompleted);


    auto firstThenSecond =
        runForcedCompletionOrder(
            true
        );

    auto secondThenFirst =
        runForcedCompletionOrder(
            false
        );


    const size_t[2] expectedForward =
    [
        0,
        1
    ];

    const size_t[2] expectedReverse =
    [
        1,
        0
    ];


    assert(
        firstThenSecond.completionOrder
        == expectedForward[]
    );

    assert(
        secondThenFirst.completionOrder
        == expectedReverse[]
    );

    assert(
        firstThenSecond.completionOrder
        != secondThenFirst.completionOrder
    );


    assert(!firstThenSecond.requestCompletedAfterFirst);
    assert(!secondThenFirst.requestCompletedAfterFirst);

    assert(firstThenSecond.requestCompleted);
    assert(secondThenFirst.requestCompleted);


    assert(
        firstThenSecond.output
        == synchronous.output
    );

    assert(
        secondThenFirst.output
        == synchronous.output
    );

    assert(
        firstThenSecond.output
        == secondThenFirst.output
    );


    assert(
        firstThenSecond.completedCoverage
        == synchronous.completedCoverage
    );

    assert(
        secondThenFirst.completedCoverage
        == synchronous.completedCoverage
    );

    assert(
        firstThenSecond.completedCoverage
        == secondThenFirst.completedCoverage
    );


    assert(
        firstThenSecond.finalResidentRasterBytes
        == 0
    );

    assert(
        secondThenFirst.finalResidentRasterBytes
        == 0
    );


    assert(
        firstThenSecond.finalAccounting.activeWorkUnits
        == 0
    );

    assert(
        secondThenFirst.finalAccounting.activeWorkUnits
        == 0
    );

    assert(
        firstThenSecond.finalAccounting.handoffCreditsInUse
        == 0
    );

    assert(
        secondThenFirst.finalAccounting.handoffCreditsInUse
        == 0
    );
}
