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


/*
 * R0.4c-0 sibling-research-module reuse probe.
 *
 * This is not a scheduling-policy implementation.
 *
 * It proves only that R0.4c can compile and call the immutable R0.4a
 * synchronous and R0.4b bounded-parallel reference strategies against the
 * same legal decomposition without modifying or copying historical research.
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
            2
        );

    assert(bounded.ok);
    assert(bounded.requestCompleted);

    assert(
        bounded.accounting.maxActiveWorkUnits
        == 2
    );

    assert(
        bounded.accounting.peakActiveWorkUnits
        == 2
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
}
