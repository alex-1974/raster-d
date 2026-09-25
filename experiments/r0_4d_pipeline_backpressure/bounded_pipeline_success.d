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


/*
 * R0.4d deliberately reuses the same exact 3 x 3 dependency margins as the
 * established R0.3/R0.4a/R0.4b neighbourhood operation.
 */
private DependencyMargins neighbourhoodMargins()
@safe
pure
nothrow
@nogc
{
    return DependencyMargins(
        1,
        1,
        1,
        1
    );
}


/*
 * Experiment-local resident compute orchestration.
 *
 * R0.4a/R0.4b keep equivalent orchestration private to their historical
 * modules. R0.4d therefore reconstructs only the logical-to-resident mapping
 * needed to execute the already-established public weighted kernel against an
 * already materialized source.
 *
 * This is not a production primitive.
 */
private bool tryExecuteResidentNeighbourhood(
    Region2D outputTask,
    ExpandedDependency dependency,
    ref MaterializedUbyteRaster source,
    ref ubyte[] output
)
@safe
{
    if (
        source.logicalRequest
        != dependency.validInput
    )
    {
        return false;
    }


    auto sourceView =
        source.lease.view();

    const expectedResidentRegion =
        Region2D(
            0,
            0,
            dependency.validInput.width,
            dependency.validInput.height
        );


    if (
        sourceView.region
        != expectedResidentRegion
    )
    {
        return false;
    }


    if (
        dependency.validInput.x > outputTask.x
        || dependency.validInput.y > outputTask.y
    )
    {
        return false;
    }


    const sourceBaseX =
        outputTask.x
        - dependency.validInput.x;

    const sourceBaseY =
        outputTask.y
        - dependency.validInput.y;


    if (
        sourceBaseX < 1
        || sourceBaseY < 1
        || sourceBaseX >= sourceView.region.width
        || sourceBaseY >= sourceView.region.height
    )
    {
        return false;
    }


    const availableFromBaseX =
        sourceView.region.width
        - sourceBaseX;

    const availableFromBaseY =
        sourceView.region.height
        - sourceBaseY;


    if (
        outputTask.width >= availableFromBaseX
        || outputTask.height >= availableFromBaseY
    )
    {
        return false;
    }


    if (
        outputTask.width != 0
        && outputTask.height
            > size_t.max / outputTask.width
    )
    {
        return false;
    }


    const sampleCount =
        outputTask.width
        * outputTask.height;


    if (sampleCount == 0)
    {
        return false;
    }


    output =
        new ubyte[sampleCount];


    foreach (localY; 0 .. outputTask.height)
    {
        const centerY =
            sourceBaseY
            + localY;


        foreach (localX; 0 .. outputTask.width)
        {
            const centerX =
                sourceBaseX
                + localX;


            ubyte northWest;
            ubyte north;
            ubyte northEast;

            ubyte west;
            ubyte center;
            ubyte east;

            ubyte southWest;
            ubyte south;
            ubyte southEast;


            if (
                !sourceView.trySample(
                    0,
                    centerX - 1,
                    centerY - 1,
                    northWest
                )
                || !sourceView.trySample(
                    0,
                    centerX,
                    centerY - 1,
                    north
                )
                || !sourceView.trySample(
                    0,
                    centerX + 1,
                    centerY - 1,
                    northEast
                )
                || !sourceView.trySample(
                    0,
                    centerX - 1,
                    centerY,
                    west
                )
                || !sourceView.trySample(
                    0,
                    centerX,
                    centerY,
                    center
                )
                || !sourceView.trySample(
                    0,
                    centerX + 1,
                    centerY,
                    east
                )
                || !sourceView.trySample(
                    0,
                    centerX - 1,
                    centerY + 1,
                    southWest
                )
                || !sourceView.trySample(
                    0,
                    centerX,
                    centerY + 1,
                    south
                )
                || !sourceView.trySample(
                    0,
                    centerX + 1,
                    centerY + 1,
                    southEast
                )
            )
            {
                return false;
            }


            const outputIndex =
                localY * outputTask.width
                + localX;


            output[outputIndex] =
                weightedNeighbourhood3x3(
                    northWest,
                    north,
                    northEast,
                    west,
                    center,
                    east,
                    southWest,
                    south,
                    southEast
                );
        }
    }


    return true;
}


/*
 * One research-local work fixture.
 *
 * The materialized source is retained explicitly across the handoff into the
 * compute stage.
 */
private class PipelineFixture
{
    Region2D logicalExtent;
    Region2D outputTask;

    ExpandedDependency dependency;

    ProceduralMaterializationResult sourceResult;

    ubyte[] output;

    bool dependencyReady;
    bool materializationCompleted;
    bool computeCompleted;


    this(
        Region2D logicalExtent,
        Region2D outputTask
    )
    {
        this.logicalExtent =
            logicalExtent;

        this.outputTask =
            outputTask;
    }


    bool prepareDependency()
    {
        if (
            !outputTask.hasRepresentableExtent()
            || outputTask.empty()
        )
        {
            return false;
        }


        if (!tryExpandDependency(
            logicalExtent,
            outputTask,
            neighbourhoodMargins(),
            dependency
        ))
        {
            return false;
        }


        if (
            dependency.contextDeficit
            != ContextDeficit.init
        )
        {
            return false;
        }


        dependencyReady = true;

        return true;
    }


    void materialize()
    {
        if (!dependencyReady)
        {
            return;
        }


        sourceResult =
            materializeProcedural(
                logicalExtent,
                dependency.validInput
            );


        materializationCompleted =
            sourceResult.ok;
    }


    void compute()
    {
        if (
            !materializationCompleted
            || !sourceResult.ok
        )
        {
            return;
        }


        computeCompleted =
            tryExecuteResidentNeighbourhood(
                outputTask,
                dependency,
                sourceResult.materialized,
                output
            );
    }


    @property
    size_t residentBytes() const
    {
        if (!sourceResult.ok)
        {
            return 0;
        }


        return sourceResult.materialized.residentBytes;
    }


    void releaseResident()
    {
        sourceResult =
            ProceduralMaterializationResult.init;
    }
}


/*
 * One deterministic stage worker.
 *
 * stageEnteredGate proves both different stage bodies have been entered.
 * stageReleaseGate holds both active until the coordinator has observed the
 * overlap.
 */
private class StageWorker
{
    PipelineFixture fixture;

    bool executeCompute;

    Barrier stageEnteredGate;
    Barrier stageReleaseGate;

    bool stageEntered;
    bool stageBodyReturned;


    this(
        PipelineFixture fixture,
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
private bool tryCommitTaskOutput(
    Region2D requestedOutput,
    Region2D outputTask,
    scope const(ubyte)[] taskOutput,
    ref ubyte[] completeOutput,
    ref ubyte[] completedCoverage
)
@safe
{
    if (
        outputTask.x < requestedOutput.x
        || outputTask.y < requestedOutput.y
    )
    {
        return false;
    }


    if (
        taskOutput.length
        != outputTask.width * outputTask.height
    )
    {
        return false;
    }


    const baseX =
        outputTask.x
        - requestedOutput.x;

    const baseY =
        outputTask.y
        - requestedOutput.y;


    foreach (localY; 0 .. outputTask.height)
    {
        foreach (localX; 0 .. outputTask.width)
        {
            const requestedX =
                baseX + localX;

            const requestedY =
                baseY + localY;


            if (
                requestedX >= requestedOutput.width
                || requestedY >= requestedOutput.height
            )
            {
                return false;
            }


            const taskIndex =
                localY * outputTask.width
                + localX;

            const completeIndex =
                requestedY * requestedOutput.width
                + requestedX;


            if (
                completeIndex >= completeOutput.length
                || completeIndex >= completedCoverage.length
                || completedCoverage[completeIndex] != 0
            )
            {
                return false;
            }


            completeOutput[completeIndex] =
                taskOutput[taskIndex];

            completedCoverage[completeIndex] = 1;
        }
    }


    return true;
}


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
        new PipelineFixture(
            logicalExtent,
            tasks[0]
        );

    auto second =
        new PipelineFixture(
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
