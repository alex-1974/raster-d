module bounded_pipeline_success;

import core.sync.barrier :
    Barrier;

import core.thread :
    Thread;

import raster.region :
    Region2D;

import dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import procedural_source :
    MaterializedUbyteRaster,
    ProceduralMaterializationResult,
    materializeProcedural;

import neighbourhood_kernel :
    weightedNeighbourhood3x3;

import synchronous_execution :
    executeSynchronousNeighbourhood;

import pipeline_vocabulary :
    PipelineLimits,
    PipelineStage;

import pipeline_state_machine :
    PipelineStateMachine,
    PipelineTransitionError,
    PipelineWorkState;


import pipeline_raster_fixture :
    PipelineRasterFixture,
    tryCommitTaskOutput;


/*
 * R0.4d deliberately reuses the same exact 3 x 3 dependency margins as the
 * established R0.3/R0.4a/R0.4b neighbourhood operation.
 */
/*
 * One deterministic stage worker.
 *
 * stageEnteredGate proves both different stage bodies have been entered.
 * stageReleaseGate holds both active until the coordinator has observed the
 * overlap.
 */
private class StageWorker
{
    PipelineRasterFixture fixture;

    bool executeCompute;

    Barrier stageEnteredGate;
    Barrier stageReleaseGate;

    bool stageEntered;
    bool stageBodyReturned;


    this(
        PipelineRasterFixture fixture,
        bool executeCompute,
        Barrier stageEnteredGate,
        Barrier stageReleaseGate
    )
    {
        this.fixture =
            fixture;

        this.executeCompute =
            executeCompute;

        this.stageEnteredGate =
            stageEnteredGate;

        this.stageReleaseGate =
            stageReleaseGate;
    }


    void run()
    {
        stageEntered = true;

        stageEnteredGate.wait();

        stageReleaseGate.wait();


        if (executeCompute)
        {
            fixture.compute();
        }
        else
        {
            fixture.materialize();
        }


        stageBodyReturned = true;
    }
}


/*
 * Writes one task-local output into the complete requested-output buffer.
 */
/*
 * R0.4d-2 — bounded staged success with deterministic cross-stage overlap.
 *
 * This is deliberately a two-work-unit proof fixture, not a general executor.
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


    auto synchronous =
        executeSynchronousNeighbourhood(
            logicalExtent,
            requestedOutput,
            tasks[]
        );

    assert(synchronous.ok);
    assert(synchronous.requestCompleted);


    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            2,
            1,
            1,
            1
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
     * Prepare A through readyForCompute using the real materializer.
     */
    assert(
        machine.tryStartMaterialization(firstState)
        == PipelineTransitionError.none
    );

    first.materialize();

    assert(first.materializationCompleted);
    assert(first.residentBytes != 0);

    assert(
        machine.finishMaterialization(firstState)
        == PipelineTransitionError.none
    );


    /*
     * Compute start releases the only handoff credit.
     */
    assert(
        machine.tryStartCompute(firstState)
        == PipelineTransitionError.none
    );

    assert(machine.accounting.computing == 1);
    assert(machine.accounting.handoffCreditsInUse == 0);


    /*
     * B can now start materialization while A remains in computing.
     */
    assert(
        machine.tryStartMaterialization(secondState)
        == PipelineTransitionError.none
    );


    assert(
        firstState.stage
        == PipelineStage.computing
    );

    assert(
        secondState.stage
        == PipelineStage.materializing
    );

    assert(machine.accounting.activeWorkUnits == 2);
    assert(machine.accounting.computing == 1);
    assert(machine.accounting.materializing == 1);
    assert(machine.accounting.handoffCreditsInUse == 1);
    assert(machine.invariantsHold);


    auto stageEnteredGate =
        new Barrier(3);

    auto stageReleaseGate =
        new Barrier(3);


    auto firstComputeWorker =
        new StageWorker(
            first,
            true,
            stageEnteredGate,
            stageReleaseGate
        );

    auto secondMaterializeWorker =
        new StageWorker(
            second,
            false,
            stageEnteredGate,
            stageReleaseGate
        );


    auto firstThread =
        new Thread(
            &firstComputeWorker.run
        );

    auto secondThread =
        new Thread(
            &secondMaterializeWorker.run
        );


    firstThread.start();
    secondThread.start();


    /*
     * Returning proves both different stage worker bodies have entered.
     *
     * Both remain active at stageReleaseGate while the coordinator observes
     * the overlap.
     */
    stageEnteredGate.wait();


    assert(firstComputeWorker.stageEntered);
    assert(secondMaterializeWorker.stageEntered);

    assert(!firstComputeWorker.stageBodyReturned);
    assert(!secondMaterializeWorker.stageBodyReturned);

    assert(machine.accounting.computing == 1);
    assert(machine.accounting.materializing == 1);

    const bool crossStageOverlapObserved = true;


    stageReleaseGate.wait();


    firstThread.join();
    secondThread.join();


    assert(firstComputeWorker.stageBodyReturned);
    assert(secondMaterializeWorker.stageBodyReturned);

    assert(first.computeCompleted);
    assert(second.materializationCompleted);


    /*
     * Stage-body completion is reflected in the deterministic state machine
     * after both worker bodies have joined.
     */
    assert(
        machine.finishCompute(firstState)
        == PipelineTransitionError.none
    );

    assert(
        machine.finishMaterialization(secondState)
        == PipelineTransitionError.none
    );


    size_t currentResidentRasterBytes =
        first.residentBytes
        + second.residentBytes;

    const size_t peakResidentRasterBytes =
        currentResidentRasterBytes;


    assert(currentResidentRasterBytes != 0);


    /*
     * A is complete and can release its retained resident source.
     */
    const firstResidentBytes =
        first.residentBytes;

    first.releaseResident();

    assert(
        machine.releaseCompleted(firstState)
        == PipelineTransitionError.none
    );


    assert(
        currentResidentRasterBytes
        >= firstResidentBytes
    );

    currentResidentRasterBytes -=
        firstResidentBytes;


    /*
     * B now advances through compute.
     */
    assert(
        machine.tryStartCompute(secondState)
        == PipelineTransitionError.none
    );

    second.compute();

    assert(second.computeCompleted);

    assert(
        machine.finishCompute(secondState)
        == PipelineTransitionError.none
    );


    const secondResidentBytes =
        second.residentBytes;

    second.releaseResident();

    assert(
        machine.releaseCompleted(secondState)
        == PipelineTransitionError.none
    );


    assert(
        currentResidentRasterBytes
        >= secondResidentBytes
    );

    currentResidentRasterBytes -=
        secondResidentBytes;


    assert(currentResidentRasterBytes == 0);
    assert(peakResidentRasterBytes != 0);

    assert(machine.accounting.activeWorkUnits == 0);
    assert(machine.accounting.materializing == 0);
    assert(machine.accounting.readyForCompute == 0);
    assert(machine.accounting.computing == 0);
    assert(machine.accounting.completedPendingRelease == 0);
    assert(machine.accounting.handoffCreditsInUse == 0);

    assert(machine.invariantsHold);


    /*
     * The configured bounds were exercised exactly.
     */
    assert(machine.accounting.peakActiveWorkUnits == 2);
    assert(machine.accounting.peakMaterializing == 1);
    assert(machine.accounting.peakComputing == 1);
    assert(machine.accounting.peakHandoffCreditsInUse == 1);

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


    /*
     * Assemble the complete semantic result.
     */
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

    assert(
        tryCommitTaskOutput(
            requestedOutput,
            tasks[1],
            second.output,
            output,
            completedCoverage
        )
    );


    foreach (covered; completedCoverage)
    {
        assert(covered == 1);
    }


    assert(crossStageOverlapObserved);

    assert(
        output
        == synchronous.output
    );

    assert(
        completedCoverage
        == synchronous.completedCoverage
    );
}
