module neighbourhood_streaming;

import std.format : format;

import imagery.raster.region : Region2D;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import neighbourhood_task_execution :
    NeighbourhoodTaskError,
    executeNeighbourhoodTask;

import neighbourhood_whole_reference :
    executeWholeNeighbourhood;


/++
    E3.3 decomposed-execution failure category.

    Research diagnostics only.
+/
enum NeighbourhoodDecompositionError : ubyte
{
    none,

    invalidRequest,
    invalidDecomposition,

    taskExecutionFailed,
    taskOutputContractMismatch,

    accountingOverflow,

    internalFailure
}


/++
    Accounting for one decomposed E3.3 execution.

    These are experiment payload measurements, not total process memory.

    `sourceResidentBytes` is the largest single task source raster.

    In the current source-only resident execution path:

        peakResidentRasterBytes == sourceResidentBytes

    The reassembled `output` is ordinary oracle/result storage and is reported
    separately as `outputOracleBytes`.

    Repeated halo pixels across adjacent tasks are intentionally counted in:

        totalMaterializedSourcePixels

    because E3.3 has no cache reuse.
+/
struct NeighbourhoodDecompositionAccounting
{
    size_t requestedOutputBytes;

    size_t sourceResidentBytes;

    size_t currentResidentRasterBytes;
    size_t peakResidentRasterBytes;

    size_t sourceMaterializations;
    size_t totalMaterializedSourcePixels;
    size_t totalOutputPixels;

    size_t outputOracleBytes;

    size_t peakDecompositionCoverageOracleBytes;
    size_t decompositionMetadataPayloadBytes;
}


/++
    Result of executing one exact output decomposition sequentially.
+/
struct NeighbourhoodDecompositionResult
{
    NeighbourhoodDecompositionError error =
        NeighbourhoodDecompositionError.internalFailure;

    DecompositionIssue decompositionIssue =
        DecompositionIssue.none;

    NeighbourhoodTaskError taskError =
        NeighbourhoodTaskError.none;

    ubyte[] output;

    NeighbourhoodDecompositionAccounting accounting;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == NeighbourhoodDecompositionError.none;
    }
}


/++
    Executes an already-defined output decomposition sequentially.

    The complete output decomposition is validated through E3.1.3 before any
    task executes.

    Each non-empty task then executes independently through the proven E3.3.4
    path, deriving and materializing its own halo.

    Output tasks must not overlap.

    Their input dependencies may overlap and normally do overlap.
+/
NeighbourhoodDecompositionResult executeNeighbourhoodDecomposition(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks
)
@safe
{
    NeighbourhoodDecompositionResult result;

    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
    )
    {
        result.error =
            NeighbourhoodDecompositionError.invalidRequest;

        return result;
    }


    if (!tryValidateDecomposition(
        requestedOutput,
        tasks,
        result.decompositionIssue
    ))
    {
        result.error =
            NeighbourhoodDecompositionError.invalidDecomposition;

        return result;
    }

    assert(
        result.decompositionIssue
        == DecompositionIssue.none
    );


    /*
     * Successful bounded decomposition validation already proved that the
     * target pixel count is representable.
     */
    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    result.output =
        new ubyte[sampleCount];

    result.accounting.requestedOutputBytes =
        sampleCount;

    result.accounting.outputOracleBytes =
        sampleCount;

    result.accounting.peakDecompositionCoverageOracleBytes =
        sampleCount;


    if (
        tasks.length != 0
        && tasks.length
            > size_t.max / Region2D.sizeof
    )
    {
        result.error =
            NeighbourhoodDecompositionError.accountingOverflow;

        return result;
    }

    result.accounting.decompositionMetadataPayloadBytes =
        tasks.length
        * Region2D.sizeof;


    foreach (const task; tasks)
    {
        if (task.empty())
        {
            /*
             * E3.1.3 permits empty members because they contribute no output
             * coverage. They require no execution or halo materialization.
             */
            continue;
        }


        auto taskResult =
            executeNeighbourhoodTask(
                logicalExtent,
                task
            );

        if (!taskResult.ok)
        {
            result.error =
                NeighbourhoodDecompositionError.taskExecutionFailed;

            result.taskError =
                taskResult.error;

            return result;
        }


        if (
            task.width != 0
            && task.height
                > size_t.max / task.width
        )
        {
            result.error =
                NeighbourhoodDecompositionError
                    .taskOutputContractMismatch;

            return result;
        }

        const taskPixels =
            task.width
            * task.height;

        if (
            taskResult.output.length
            != taskPixels
        )
        {
            result.error =
                NeighbourhoodDecompositionError
                    .taskOutputContractMismatch;

            return result;
        }


        if (
            taskResult.sourceResidentBytes
            > result.accounting.sourceResidentBytes
        )
        {
            result.accounting.sourceResidentBytes =
                taskResult.sourceResidentBytes;
        }

        if (
            taskResult.sourceResidentBytes
            > result.accounting.peakResidentRasterBytes
        )
        {
            result.accounting.peakResidentRasterBytes =
                taskResult.sourceResidentBytes;
        }


        if (
            result.accounting.sourceMaterializations
            == size_t.max
            || taskResult.sourceResidentBytes
                > size_t.max
                    - result.accounting
                        .totalMaterializedSourcePixels
            || taskResult.output.length
                > size_t.max
                    - result.accounting.totalOutputPixels
        )
        {
            result.error =
                NeighbourhoodDecompositionError.accountingOverflow;

            return result;
        }

        result.accounting.sourceMaterializations +=
            1;

        result.accounting.totalMaterializedSourcePixels +=
            taskResult.sourceResidentBytes;

        result.accounting.totalOutputPixels +=
            taskResult.output.length;


        /*
         * Exact decomposition containment proves these subtractions safe.
         */
        const relativeX =
            task.x
            - requestedOutput.x;

        const relativeY =
            task.y
            - requestedOutput.y;


        foreach (localY; 0 .. task.height)
        {
            foreach (localX; 0 .. task.width)
            {
                const taskIndex =
                    localY * task.width
                    + localX;

                const outputIndex =
                    (relativeY + localY)
                        * requestedOutput.width
                    + relativeX
                    + localX;

                assert(
                    outputIndex
                    < result.output.length
                );

                result.output[outputIndex] =
                    taskResult.output[taskIndex];
            }
        }
    }


    /*
     * Every task source has been released before the next task is entered and
     * before this function returns.
     */
    result.accounting.currentResidentRasterBytes =
        0;

    result.error =
        NeighbourhoodDecompositionError.none;

    return result;
}


/++
    Constructs a horizontal-strip decomposition.

    Every strip spans the complete requested width.

    The final strip may be shorter than `nominalStripHeight`.
+/
private Region2D[] makeHorizontalStrips(
    Region2D requestedOutput,
    size_t nominalStripHeight
)
@safe
{
    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || nominalStripHeight == 0
    )
    {
        return null;
    }

    const completeStripCount =
        requestedOutput.height
        / nominalStripHeight;

    const remainder =
        requestedOutput.height
        % nominalStripHeight;

    const stripCount =
        completeStripCount
        + (remainder == 0 ? 0 : 1);

    assert(stripCount != 0);

    auto tasks =
        new Region2D[stripCount];

    size_t currentY =
        requestedOutput.y;

    size_t remainingHeight =
        requestedOutput.height;

    foreach (ref task; tasks)
    {
        const height =
            remainingHeight < nominalStripHeight
            ? remainingHeight
            : nominalStripHeight;

        assert(height != 0);

        task =
            Region2D(
                requestedOutput.x,
                currentY,
                requestedOutput.width,
                height
            );

        currentY +=
            height;

        remainingHeight -=
            height;
    }

    assert(remainingHeight == 0);

    assert(
        currentY
        == requestedOutput.y
            + requestedOutput.height
    );

    return tasks;
}


/*
 * Exact output comparison diagnostics for E3.3.
 */
enum NeighbourhoodComparisonIssue : ubyte
{
    none,

    invalidRequest,
    lengthMismatch,
    outputMismatch
}


struct NeighbourhoodMismatch
{
    size_t relativeX;
    size_t relativeY;

    size_t logicalX;
    size_t logicalY;

    ubyte expected;
    ubyte actual;
}


struct NeighbourhoodComparisonResult
{
    NeighbourhoodComparisonIssue issue =
        NeighbourhoodComparisonIssue.invalidRequest;

    size_t requiredLength;
    size_t expectedLength;
    size_t actualLength;

    NeighbourhoodMismatch mismatch;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return issue
            == NeighbourhoodComparisonIssue.none;
    }
}


private NeighbourhoodComparisonResult compareNeighbourhoodOutputs(
    Region2D requestedOutput,
    scope const(ubyte)[] expected,
    scope const(ubyte)[] actual
)
@safe
pure
nothrow
@nogc
{
    NeighbourhoodComparisonResult result;

    result.expectedLength =
        expected.length;

    result.actualLength =
        actual.length;


    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
    )
    {
        result.issue =
            NeighbourhoodComparisonIssue.invalidRequest;

        return result;
    }


    if (
        requestedOutput.width != 0
        && requestedOutput.height
            > size_t.max / requestedOutput.width
    )
    {
        result.issue =
            NeighbourhoodComparisonIssue.invalidRequest;

        return result;
    }


    result.requiredLength =
        requestedOutput.width
        * requestedOutput.height;


    if (
        expected.length
            != result.requiredLength
        || actual.length
            != result.requiredLength
    )
    {
        result.issue =
            NeighbourhoodComparisonIssue.lengthMismatch;

        return result;
    }


    foreach (index; 0 .. result.requiredLength)
    {
        if (expected[index] == actual[index])
        {
            continue;
        }

        const relativeY =
            index
            / requestedOutput.width;

        const relativeX =
            index
            % requestedOutput.width;

        result.mismatch =
            NeighbourhoodMismatch(
                relativeX,
                relativeY,
                requestedOutput.x + relativeX,
                requestedOutput.y + relativeY,
                expected[index],
                actual[index]
            );

        result.issue =
            NeighbourhoodComparisonIssue.outputMismatch;

        return result;
    }


    result.issue =
        NeighbourhoodComparisonIssue.none;

    return result;
}


private string formatNeighbourhoodComparisonFailure(
    NeighbourhoodComparisonResult result
)
{
    final switch (result.issue)
    {
        case NeighbourhoodComparisonIssue.none:
            return "neighbourhood comparison succeeded";

        case NeighbourhoodComparisonIssue.invalidRequest:
            return "invalid requested output for neighbourhood comparison";

        case NeighbourhoodComparisonIssue.lengthMismatch:
            return format(
                "neighbourhood length mismatch: "
                ~ "required=%s expected=%s actual=%s",
                result.requiredLength,
                result.expectedLength,
                result.actualLength
            );

        case NeighbourhoodComparisonIssue.outputMismatch:
            return format(
                "neighbourhood output mismatch: "
                ~ "relative=(%s,%s) logical=(%s,%s) "
                ~ "expected=%s actual=%s",
                result.mismatch.relativeX,
                result.mismatch.relativeY,
                result.mismatch.logicalX,
                result.mismatch.logicalY,
                result.mismatch.expected,
                result.mismatch.actual
            );
    }
}


/*
 * E3.3.6 horizontal-strip streamed equivalence.
 *
 * This is the first true task-boundary seam test.
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


    auto whole =
        executeWholeNeighbourhood(
            logicalExtent,
            requestedOutput
        );

    assert(whole.ok);


    auto tasks =
        makeHorizontalStrips(
            requestedOutput,
            128
        );

    assert(tasks.length == 7);

    foreach (index; 0 .. 6)
    {
        assert(tasks[index].width == 1021);
        assert(tasks[index].height == 128);
    }

    assert(tasks[6].width == 1021);
    assert(tasks[6].height == 1);


    auto streamed =
        executeNeighbourhoodDecomposition(
            logicalExtent,
            requestedOutput,
            tasks
        );

    assert(streamed.ok);


    const comparison =
        compareNeighbourhoodOutputs(
            requestedOutput,
            whole.execution.output,
            streamed.output
        );

    assert(
        comparison.ok,
        formatNeighbourhoodComparisonFailure(
            comparison
        )
    );


    /*
     * Requested-output accounting.
     */
    enum size_t expectedOutputPixels =
        785_149;

    assert(
        streamed.accounting.requestedOutputBytes
        == expectedOutputPixels
    );

    assert(
        streamed.accounting.totalOutputPixels
        == expectedOutputPixels
    );

    assert(
        streamed.accounting.outputOracleBytes
        == expectedOutputPixels
    );


    /*
     * Six complete 128-row strips each require:
     *
     *     1023 x 130
     *
     * source samples.
     *
     * The final one-row strip requires:
     *
     *     1023 x 3
     */
    enum size_t largestStripSourcePixels =
        1023 * 130;

    enum size_t finalStripSourcePixels =
        1023 * 3;

    enum size_t expectedMaterializedSourcePixels =
        6 * largestStripSourcePixels
        + finalStripSourcePixels;

    assert(
        largestStripSourcePixels
        == 132_990
    );

    assert(
        finalStripSourcePixels
        == 3_069
    );

    assert(
        expectedMaterializedSourcePixels
        == 801_009
    );


    assert(
        streamed.accounting.sourceResidentBytes
        == largestStripSourcePixels
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == largestStripSourcePixels
    );

    assert(
        streamed.accounting.currentResidentRasterBytes
        == 0
    );

    assert(
        streamed.accounting.sourceMaterializations
        == 7
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == expectedMaterializedSourcePixels
    );


    /*
     * The top-level decomposition oracle covers the requested output exactly
     * once and remains separate from raster residency.
     */
    assert(
        streamed.accounting
            .peakDecompositionCoverageOracleBytes
        == expectedOutputPixels
    );

    assert(
        streamed.accounting
            .decompositionMetadataPayloadBytes
        == tasks.length * Region2D.sizeof
    );


    /*
     * Halo duplication overhead.
     *
     * Whole source:
     *
     *     1023 x 771 = 788,733
     *
     * Horizontal streaming:
     *
     *     801,009
     *
     * Difference:
     *
     *     12,276
     *
     * This is exactly:
     *
     *     6 internal seams
     *   x 2 overlapping halo rows
     *   x 1023 source columns
     */
    enum size_t wholeSourcePixels =
        1023 * 771;

    enum size_t expectedHaloDuplication =
        6 * 2 * 1023;

    assert(
        wholeSourcePixels
        == 788_733
    );

    assert(
        expectedHaloDuplication
        == 12_276
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
            - wholeSourcePixels
        == expectedHaloDuplication
    );


    /*
     * Streaming bounds raster residency even though it rematerializes halo
     * pixels around internal processing boundaries.
     */
    assert(
        streamed.accounting.peakResidentRasterBytes
        < whole.accounting.peakResidentRasterBytes
    );

    assert(
        whole.accounting.peakResidentRasterBytes
        == wholeSourcePixels
    );


    /*
     * Explicitly inspect the rows around every internal strip boundary.
     *
     * Full-output comparison above already proves equality everywhere; this
     * loop documents and exercises the exact seam locations directly.
     */
    foreach (seamIndex; 1 .. 7)
    {
        const seamRelativeY =
            seamIndex * 128;

        if (seamRelativeY >= requestedOutput.height)
        {
            break;
        }

        assert(seamRelativeY != 0);

        const aboveY =
            seamRelativeY - 1;

        const belowY =
            seamRelativeY;

        foreach (x; 0 .. requestedOutput.width)
        {
            const aboveIndex =
                aboveY * requestedOutput.width
                + x;

            const belowIndex =
                belowY * requestedOutput.width
                + x;

            assert(
                streamed.output[aboveIndex]
                == whole.execution.output[aboveIndex]
            );

            assert(
                streamed.output[belowIndex]
                == whole.execution.output[belowIndex]
            );
        }
    }
}
