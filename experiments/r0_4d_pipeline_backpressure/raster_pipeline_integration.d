module raster_pipeline_integration;

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

import bounded_parallel_execution :
    executeBoundedParallelNeighbourhood;

import pipeline_vocabulary :
    PipelineLimits;

import pipeline_state_machine :
    PipelineAccounting,
    PipelineStateMachine,
    PipelineTransitionError,
    PipelineWorkState;

import pipeline_raster_fixture :
    PipelineRasterFixture,
    tryCommitTaskOutput;


/*
 * One real compute-stage worker.
 */
private class IntegrationComputeWorker
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


/*
 * One real materialization-stage worker.
 */
private class IntegrationMaterializeWorker
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


private size_t currentResidentRasterBytes(
    scope PipelineRasterFixture[] fixtures
)
{
    size_t result;


    foreach (fixture; fixtures)
    {
        if (fixture !is null)
        {
            result +=
                fixture.residentBytes;
        }
    }


    return result;
}


private void updatePeak(
    ref size_t peak,
    size_t current
)
@safe
pure
nothrow
@nogc
{
    if (current > peak)
    {
        peak = current;
    }
}


private struct IntegratedPipelineResult
{
    bool requestCompleted;

    ubyte[] output;
    ubyte[] completedCoverage;

    PipelineAccounting accounting;

    size_t crossStageOverlapPairs;

    size_t currentResidentRasterBytes;
    size_t peakResidentRasterBytes;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return requestCompleted
            && accounting.activeWorkUnits == 0
            && accounting.handoffCreditsInUse == 0
            && currentResidentRasterBytes == 0;
    }
}


/*
 * Research-local bounded staged raster runner used only for R0.4d-6.
 *
 * The runner is intentionally linear:
 *
 *     prime materialization(0)
 *
 *     compute(0) || materialize(1)
 *     compute(1) || materialize(2)
 *     ...
 *     compute(n-2) || materialize(n-1)
 *
 *     drain compute(n-1)
 *
 * It is not a general scheduler or reusable production executor.
 */
private IntegratedPipelineResult executeIntegratedPipeline(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks
)
{
    IntegratedPipelineResult result;


    if (
        !logicalExtent.hasRepresentableExtent()
        || !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || tasks.length == 0
    )
    {
        return result;
    }


    if (
        requestedOutput.width != 0
        && requestedOutput.height
            > size_t.max / requestedOutput.width
    )
    {
        return result;
    }


    DecompositionIssue decompositionIssue;

    if (!tryValidateDecomposition(
        requestedOutput,
        tasks,
        decompositionIssue
    ))
    {
        return result;
    }


    PipelineStateMachine machine;

    machine.limits =
        PipelineLimits(
            2,
            1,
            1,
            1
        );


    auto states =
        new PipelineWorkState[tasks.length];

    auto fixtures =
        new PipelineRasterFixture[tasks.length];


    foreach (index; 0 .. tasks.length)
    {
        states[index].stableWorkUnitId =
            index;

        fixtures[index] =
            new PipelineRasterFixture(
                logicalExtent,
                tasks[index]
            );


        if (!fixtures[index].prepareDependency())
        {
            return IntegratedPipelineResult.init;
        }
    }


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    result.output =
        new ubyte[sampleCount];

    result.completedCoverage =
        new ubyte[sampleCount];


    /*
     * Prime the linear pipeline with work 0.
     */
    if (
        machine.tryStartMaterialization(
            states[0]
        )
        != PipelineTransitionError.none
    )
    {
        return IntegratedPipelineResult.init;
    }


    fixtures[0].materialize();


    if (!fixtures[0].materializationCompleted)
    {
        return IntegratedPipelineResult.init;
    }


    if (
        machine.finishMaterialization(
            states[0]
        )
        != PipelineTransitionError.none
    )
    {
        return IntegratedPipelineResult.init;
    }


    result.currentResidentRasterBytes =
        currentResidentRasterBytes(
            fixtures
        );

    updatePeak(
        result.peakResidentRasterBytes,
        result.currentResidentRasterBytes
    );


    foreach (index; 0 .. tasks.length)
    {
        /*
         * The current ready item enters compute, releasing its handoff credit.
         */
        if (
            machine.tryStartCompute(
                states[index]
            )
            != PipelineTransitionError.none
        )
        {
            return IntegratedPipelineResult.init;
        }


        const hasSuccessor =
            index + 1 < tasks.length;


        if (hasSuccessor)
        {
            /*
             * The released credit admits exactly one successor
             * materialization while current compute remains active.
             */
            if (
                machine.tryStartMaterialization(
                    states[index + 1]
                )
                != PipelineTransitionError.none
            )
            {
                return IntegratedPipelineResult.init;
            }


            if (
                machine.accounting.activeWorkUnits != 2
                || machine.accounting.computing != 1
                || machine.accounting.materializing != 1
                || machine.accounting.handoffCreditsInUse != 1
            )
            {
                return IntegratedPipelineResult.init;
            }


            auto enteredGate =
                new Barrier(3);

            auto releaseGate =
                new Barrier(3);


            auto computeWorker =
                new IntegrationComputeWorker(
                    fixtures[index],
                    enteredGate,
                    releaseGate
                );

            auto materializeWorker =
                new IntegrationMaterializeWorker(
                    fixtures[index + 1],
                    enteredGate,
                    releaseGate
                );


            auto computeThread =
                new Thread(
                    &computeWorker.run
                );

            auto materializeThread =
                new Thread(
                    &materializeWorker.run
                );


            computeThread.start();
            materializeThread.start();


            /*
             * Returning proves both different stage bodies are simultaneously
             * entered and held before real work proceeds.
             */
            enteredGate.wait();


            if (
                !computeWorker.entered
                || !materializeWorker.entered
                || computeWorker.returned
                || materializeWorker.returned
            )
            {
                return IntegratedPipelineResult.init;
            }


            ++result.crossStageOverlapPairs;


            releaseGate.wait();


            computeThread.join();
            materializeThread.join();


            if (
                !computeWorker.returned
                || !materializeWorker.returned
                || !fixtures[index].computeCompleted
                || !fixtures[index + 1].materializationCompleted
            )
            {
                return IntegratedPipelineResult.init;
            }


            if (
                machine.finishCompute(
                    states[index]
                )
                != PipelineTransitionError.none
            )
            {
                return IntegratedPipelineResult.init;
            }


            if (
                machine.finishMaterialization(
                    states[index + 1]
                )
                != PipelineTransitionError.none
            )
            {
                return IntegratedPipelineResult.init;
            }


            result.currentResidentRasterBytes =
                currentResidentRasterBytes(
                    fixtures
                );

            updatePeak(
                result.peakResidentRasterBytes,
                result.currentResidentRasterBytes
            );
        }
        else
        {
            /*
             * Drain the final compute stage with no successor materialization.
             */
            fixtures[index].compute();


            if (!fixtures[index].computeCompleted)
            {
                return IntegratedPipelineResult.init;
            }


            if (
                machine.finishCompute(
                    states[index]
                )
                != PipelineTransitionError.none
            )
            {
                return IntegratedPipelineResult.init;
            }
        }


        if (!tryCommitTaskOutput(
            requestedOutput,
            tasks[index],
            fixtures[index].output,
            result.output,
            result.completedCoverage
        ))
        {
            return IntegratedPipelineResult.init;
        }


        fixtures[index].releaseResident();


        if (
            machine.releaseCompleted(
                states[index]
            )
            != PipelineTransitionError.none
        )
        {
            return IntegratedPipelineResult.init;
        }


        result.currentResidentRasterBytes =
            currentResidentRasterBytes(
                fixtures
            );


        if (!machine.invariantsHold)
        {
            return IntegratedPipelineResult.init;
        }
    }


    result.accounting =
        machine.accounting;


    result.requestCompleted =
        allCovered(
            result.completedCoverage
        )
        && result.accounting.activeWorkUnits == 0;


    result.currentResidentRasterBytes =
        currentResidentRasterBytes(
            fixtures
        );


    return result;
}


/*
 * R0.4d-6 — final raster integration against both historical execution
 * references.
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


    const Region2D[6] canonicalTasks =
    [
        Region2D(
            1020,
            2030,
            8,
            1
        ),

        Region2D(
            1020,
            2031,
            3,
            2
        ),

        Region2D(
            1023,
            2031,
            5,
            2
        ),

        Region2D(
            1020,
            2033,
            5,
            2
        ),

        Region2D(
            1025,
            2033,
            3,
            2
        ),

        Region2D(
            1020,
            2035,
            8,
            1
        )
    ];


    DecompositionIssue decompositionIssue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            canonicalTasks[],
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
            canonicalTasks[]
        );


    auto bounded =
        executeBoundedParallelNeighbourhood(
            logicalExtent,
            requestedOutput,
            canonicalTasks[],
            2
        );


    auto pipeline =
        executeIntegratedPipeline(
            logicalExtent,
            requestedOutput,
            canonicalTasks[]
        );


    assert(synchronous.ok);
    assert(synchronous.requestCompleted);

    assert(bounded.ok);
    assert(bounded.requestCompleted);

    assert(pipeline.ok);
    assert(pipeline.requestCompleted);


    /*
     * Semantic result is identical across all three execution strategies.
     */
    assert(
        pipeline.output
        == synchronous.output
    );

    assert(
        pipeline.output
        == bounded.output
    );

    assert(
        bounded.output
        == synchronous.output
    );


    assert(
        pipeline.completedCoverage
        == synchronous.completedCoverage
    );

    assert(
        pipeline.completedCoverage
        == bounded.completedCoverage
    );

    assert(
        bounded.completedCoverage
        == synchronous.completedCoverage
    );


    /*
     * The linear six-work pipeline has five adjacent cross-stage overlaps.
     */
    assert(
        pipeline.crossStageOverlapPairs
        == canonicalTasks.length - 1
    );

    assert(
        pipeline.crossStageOverlapPairs
        == 5
    );


    /*
     * R0.4d configured count bounds are reached exactly and never exceeded.
     */
    assert(
        pipeline.accounting.peakActiveWorkUnits
        == 2
    );

    assert(
        pipeline.accounting.peakMaterializing
        == 1
    );

    assert(
        pipeline.accounting.peakComputing
        == 1
    );

    assert(
        pipeline.accounting.peakHandoffCreditsInUse
        == 1
    );


    assert(
        pipeline.accounting.activeWorkUnits
        == 0
    );

    assert(
        pipeline.accounting.materializing
        == 0
    );

    assert(
        pipeline.accounting.readyForCompute
        == 0
    );

    assert(
        pipeline.accounting.computing
        == 0
    );

    assert(
        pipeline.accounting.completedPendingRelease
        == 0
    );

    assert(
        pipeline.accounting.handoffCreditsInUse
        == 0
    );


    assert(
        pipeline.currentResidentRasterBytes
        == 0
    );

    assert(
        pipeline.peakResidentRasterBytes
        > 0
    );


    /*
     * Historical bounded-parallel reference remains bounded and releases all
     * resident raster state as well.
     */
    assert(
        bounded.accounting.maxActiveWorkUnits
        == 2
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
     * The pipeline deliberately overlaps two retained raster resources, so
     * its peak resident bytes exceed the synchronous one-work-at-a-time
     * reference. This is evidence only; it is not a general byte-budget claim.
     */
    assert(
        pipeline.peakResidentRasterBytes
        > synchronous.accounting
            .peakResidentRasterBytes
    );
}
