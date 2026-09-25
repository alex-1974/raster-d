module reuse_probe;

import raster.region :
    Region2D;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import synchronous_execution :
    executeSynchronousNeighbourhood;

import bounded_parallel_execution :
    executeBoundedParallelNeighbourhood;

import scheduling_policy_oracle :
    PolicyClass,
    ReadyWork,
    dispatchFifo;

import pipeline_vocabulary :
    PipelineLimits,
    PipelineStage;


/*
 * R0.4d-0 historical-reference reuse probe.
 *
 * This is not a pipeline implementation.
 *
 * It proves only that R0.4d can compile and call the immutable R0.4a,
 * R0.4b and selected R0.4c research references while defining its own
 * research-local stage/backpressure vocabulary.
 */
unittest
{
    const limits =
        PipelineLimits(
            2,
            1,
            1,
            1
        );


    assert(limits.maxActiveWorkUnits == 2);
    assert(limits.maxMaterializing == 1);
    assert(limits.maxComputing == 1);
    assert(limits.handoffCapacity == 1);


    const initialStage =
        PipelineStage.notAdmitted;

    assert(
        initialStage
        == PipelineStage.notAdmitted
    );


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


    const Region2D[2] decomposition =
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
            decomposition[],
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
            decomposition[]
        );

    assert(synchronous.ok);
    assert(synchronous.requestCompleted);

    assert(
        synchronous.accounting.currentResidentRasterBytes
        == 0
    );


    auto bounded =
        executeBoundedParallelNeighbourhood(
            logicalExtent,
            requestedOutput,
            decomposition[],
            limits.maxActiveWorkUnits
        );

    assert(bounded.ok);
    assert(bounded.requestCompleted);

    assert(
        bounded.accounting.maxActiveWorkUnits
        == limits.maxActiveWorkUnits
    );

    assert(
        bounded.accounting.peakActiveWorkUnits
        <= bounded.accounting.maxActiveWorkUnits
    );

    assert(
        bounded.accounting.currentResidentRasterBytes
        == 0
    );


    assert(
        bounded.output
        == synchronous.output
    );

    assert(
        bounded.completedCoverage
        == synchronous.completedCoverage
    );


    /*
     * R0.4c remains a separate policy reference.
     *
     * R0.4d-0 does not copy or promote its policy machinery.
     */
    const ReadyWork[2] ready =
    [
        ReadyWork(
            0,
            0,
            PolicyClass.throughput,
            100
        ),

        ReadyWork(
            1,
            1,
            PolicyClass.interactive,
            -100
        )
    ];


    auto fifo =
        dispatchFifo(
            ready[]
        );

    assert(fifo.ok);


    const size_t[2] expectedOrder =
    [
        0,
        1
    ];


    assert(
        fifo.workUnitIds
        == expectedOrder[]
    );
}
