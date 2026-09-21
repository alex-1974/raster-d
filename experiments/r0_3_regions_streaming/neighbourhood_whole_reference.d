module neighbourhood_whole_reference;

import raster.region : Region2D;

import neighbourhood_kernel :
    weightedNeighbourhood3x3;

import neighbourhood_task_execution :
    NeighbourhoodTaskResult,
    executeNeighbourhoodTask;

import procedural_source :
    proceduralValue;


/++
    E3.3 whole-request accounting.

    These fields describe experiment payloads, not total process memory.

    In E3.3.5 the task executor has one resident source raster and an ordinary
    ubyte[] output buffer.

    Therefore `peakResidentRasterBytes` deliberately counts only the resident
    source raster.

    `outputOracleBytes` is separate and must not be added to raster residency
    merely because it exists simultaneously as ordinary test/result storage.
+/
struct NeighbourhoodWholeAccounting
{
    size_t requestedOutputBytes;

    size_t sourceResidentBytes;

    size_t currentResidentRasterBytes;
    size_t peakResidentRasterBytes;

    size_t sourceMaterializations;
    size_t totalMaterializedSourcePixels;
    size_t totalOutputPixels;

    size_t outputOracleBytes;
}


/++
    Result of one whole-request neighbourhood execution.

    The execution itself is delegated to the already proven E3.3.4
    single-task path.
+/
struct NeighbourhoodWholeResult
{
    NeighbourhoodTaskResult execution;

    NeighbourhoodWholeAccounting accounting;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return execution.ok;
    }
}


/++
    Executes one requested output as a single E3.3 neighbourhood task and
    records the whole-request accounting baseline.

    On success:

        sourceMaterializations == 1

    and, because the procedural source is ubyte:

        totalMaterializedSourcePixels
            == sourceResidentBytes

    The resident source has already been released when this function receives
    the completed task result, so:

        currentResidentRasterBytes == 0

    while:

        peakResidentRasterBytes
            == sourceResidentBytes

    for the current source-only resident execution path.
+/
NeighbourhoodWholeResult executeWholeNeighbourhood(
    Region2D logicalExtent,
    Region2D requestedOutput
)
@safe
{
    NeighbourhoodWholeResult result;

    result.execution =
        executeNeighbourhoodTask(
            logicalExtent,
            requestedOutput
        );

    if (!result.execution.ok)
    {
        return result;
    }

    result.accounting.requestedOutputBytes =
        result.execution.output.length;

    result.accounting.sourceResidentBytes =
        result.execution.sourceResidentBytes;

    result.accounting.currentResidentRasterBytes =
        0;

    result.accounting.peakResidentRasterBytes =
        result.execution.sourceResidentBytes;

    result.accounting.sourceMaterializations =
        1;

    result.accounting.totalMaterializedSourcePixels =
        result.execution.sourceResidentBytes;

    result.accounting.totalOutputPixels =
        result.execution.output.length;

    result.accounting.outputOracleBytes =
        result.execution.output.length;

    return result;
}


/*
 * Independent logical-coordinate oracle used to establish the E3.3 whole
 * reference before any decomposed comparison exists.
 */
private ubyte expectedLogicalNeighbourhood(
    size_t logicalX,
    size_t logicalY
)
@safe
pure
nothrow
@nogc
{
    assert(logicalX != 0);
    assert(logicalY != 0);

    return weightedNeighbourhood3x3(
        proceduralValue(
            logicalX - 1,
            logicalY - 1
        ),
        proceduralValue(
            logicalX,
            logicalY - 1
        ),
        proceduralValue(
            logicalX + 1,
            logicalY - 1
        ),

        proceduralValue(
            logicalX - 1,
            logicalY
        ),
        proceduralValue(
            logicalX,
            logicalY
        ),
        proceduralValue(
            logicalX + 1,
            logicalY
        ),

        proceduralValue(
            logicalX - 1,
            logicalY + 1
        ),
        proceduralValue(
            logicalX,
            logicalY + 1
        ),
        proceduralValue(
            logicalX + 1,
            logicalY + 1
        )
    );
}


/*
 * Principal E3.3 whole-request fixture.
 *
 * This establishes the exact byte reference that later streamed
 * decompositions must reproduce.
 */
unittest
{
    const logicalExtent =
        Region2D(
            0,
            0,
            8192,
            6144
        );

    const requestedOutput =
        Region2D(
            1733,
            911,
            1021,
            769
        );

    auto result =
        executeWholeNeighbourhood(
            logicalExtent,
            requestedOutput
        );

    assert(result.ok);

    assert(
        result.execution.dependency.validInput
        == Region2D(
            1732,
            910,
            1023,
            771
        )
    );

    const expectedOutputPixels =
        requestedOutput.width
        * requestedOutput.height;

    const expectedSourcePixels =
        result.execution.dependency.validInput.width
        * result.execution.dependency.validInput.height;

    assert(
        result.execution.output.length
        == expectedOutputPixels
    );

    assert(
        result.execution.sourceResidentBytes
        == expectedSourcePixels
    );


    /*
     * Whole-request accounting baseline.
     */
    assert(
        result.accounting.requestedOutputBytes
        == expectedOutputPixels
    );

    assert(
        result.accounting.sourceResidentBytes
        == expectedSourcePixels
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );

    assert(
        result.accounting.peakResidentRasterBytes
        == expectedSourcePixels
    );

    assert(
        result.accounting.sourceMaterializations
        == 1
    );

    assert(
        result.accounting.totalMaterializedSourcePixels
        == expectedSourcePixels
    );

    assert(
        result.accounting.totalOutputPixels
        == expectedOutputPixels
    );

    assert(
        result.accounting.outputOracleBytes
        == expectedOutputPixels
    );


    /*
     * Verify every output byte against the direct logical-coordinate oracle.
     *
     * This is deliberately exhaustive: later decomposed execution will use
     * this whole output as its byte-for-byte reference.
     */
    foreach (localY; 0 .. requestedOutput.height)
    {
        const logicalY =
            requestedOutput.y
            + localY;

        foreach (localX; 0 .. requestedOutput.width)
        {
            const logicalX =
                requestedOutput.x
                + localX;

            const outputIndex =
                localY * requestedOutput.width
                + localX;

            assert(
                result.execution.output[outputIndex]
                == expectedLogicalNeighbourhood(
                    logicalX,
                    logicalY
                )
            );
        }
    }
}


/*
 * A whole request that touches the logical-image boundary remains an explicit
 * unsatisfied-context failure.
 *
 * Whole-reference wrapping does not invent border semantics.
 */
unittest
{
    const logicalExtent =
        Region2D(
            100,
            200,
            20,
            20
        );

    const requestedOutput =
        Region2D(
            100,
            200,
            5,
            4
        );

    auto result =
        executeWholeNeighbourhood(
            logicalExtent,
            requestedOutput
        );

    assert(!result.ok);

    assert(result.execution.output.length == 0);

    assert(
        result.accounting
        == NeighbourhoodWholeAccounting.init
    );
}
