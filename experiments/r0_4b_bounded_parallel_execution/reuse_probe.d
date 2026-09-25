module reuse_probe;

import raster.region :
    Region2D;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import neighbourhood_task_execution :
    executeNeighbourhoodTask;

import synchronous_execution :
    executeSynchronousNeighbourhood;


/*
 * R0.4b sibling-research-module reuse probe.
 *
 * This is not the bounded-parallel executor.
 *
 * It proves only that the new R0.4b experiment can compile and call:
 *
 * - the immutable R0.4a synchronous strategy oracle;
 * - the selected immutable R0.3 research modules;
 * - the production raster-d Region2D API;
 *
 * without modifying or copying the historical research implementations.
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
            4,
            2
        );


    const Region2D[1] decomposition =
    [
        requestedOutput
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


    auto r03Oracle =
        executeNeighbourhoodTask(
            logicalExtent,
            requestedOutput
        );

    assert(r03Oracle.ok);

    assert(
        synchronous.output
        == r03Oracle.output
    );
}
