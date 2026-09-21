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



/++
    Constructs a vertical-strip decomposition.

    Every strip spans the complete requested height.

    The final strip may be narrower than `nominalStripWidth`.
+/
private Region2D[] makeVerticalStrips(
    Region2D requestedOutput,
    size_t nominalStripWidth
)
@safe
{
    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || nominalStripWidth == 0
    )
    {
        return null;
    }

    const completeStripCount =
        requestedOutput.width
        / nominalStripWidth;

    const remainder =
        requestedOutput.width
        % nominalStripWidth;

    const stripCount =
        completeStripCount
        + (remainder == 0 ? 0 : 1);

    assert(stripCount != 0);

    auto tasks =
        new Region2D[stripCount];

    size_t currentX =
        requestedOutput.x;

    size_t remainingWidth =
        requestedOutput.width;

    foreach (ref task; tasks)
    {
        const width =
            remainingWidth < nominalStripWidth
            ? remainingWidth
            : nominalStripWidth;

        assert(width != 0);

        task =
            Region2D(
                currentX,
                requestedOutput.y,
                width,
                requestedOutput.height
            );

        currentX +=
            width;

        remainingWidth -=
            width;
    }

    assert(remainingWidth == 0);

    assert(
        currentX
        == requestedOutput.x
            + requestedOutput.width
    );

    return tasks;
}


/*
 * E3.3.7 vertical-strip streamed equivalence.
 *
 * This exercises seams orthogonal to E3.3.6 while reusing the same
 * decomposition, task execution, reassembly and comparison paths.
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
        makeVerticalStrips(
            requestedOutput,
            128
        );

    assert(tasks.length == 8);

    foreach (index; 0 .. 7)
    {
        assert(tasks[index].width == 128);
        assert(tasks[index].height == 769);
    }

    assert(tasks[7].width == 125);
    assert(tasks[7].height == 769);


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
     * Requested output is unchanged by decomposition.
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
     * Seven complete 128-column strips each require:
     *
     *     130 x 771
     *
     * source samples.
     *
     * The final 125-column strip requires:
     *
     *     127 x 771
     */
    enum size_t largestStripSourcePixels =
        130 * 771;

    enum size_t finalStripSourcePixels =
        127 * 771;

    enum size_t expectedMaterializedSourcePixels =
        7 * largestStripSourcePixels
        + finalStripSourcePixels;

    assert(
        largestStripSourcePixels
        == 100_230
    );

    assert(
        finalStripSourcePixels
        == 97_917
    );

    assert(
        expectedMaterializedSourcePixels
        == 799_527
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
        == 8
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == expectedMaterializedSourcePixels
    );


    /*
     * Oracle payloads remain separate from raster residency.
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
     * Vertical streaming:
     *
     *     799,527
     *
     * Difference:
     *
     *     10,794
     *
     * This is exactly:
     *
     *     7 internal seams
     *   x 2 overlapping halo columns
     *   x 771 source rows
     */
    enum size_t wholeSourcePixels =
        1023 * 771;

    enum size_t expectedHaloDuplication =
        7 * 2 * 771;

    assert(
        wholeSourcePixels
        == 788_733
    );

    assert(
        expectedHaloDuplication
        == 10_794
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
            - wholeSourcePixels
        == expectedHaloDuplication
    );


    assert(
        streamed.accounting.peakResidentRasterBytes
        < whole.accounting.peakResidentRasterBytes
    );


    /*
     * Explicitly exercise both columns adjacent to every internal seam.
     */
    foreach (seamIndex; 1 .. 8)
    {
        const seamRelativeX =
            seamIndex * 128;

        if (seamRelativeX >= requestedOutput.width)
        {
            break;
        }

        assert(seamRelativeX != 0);

        const leftX =
            seamRelativeX - 1;

        const rightX =
            seamRelativeX;

        foreach (y; 0 .. requestedOutput.height)
        {
            const leftIndex =
                y * requestedOutput.width
                + leftX;

            const rightIndex =
                y * requestedOutput.width
                + rightX;

            assert(
                streamed.output[leftIndex]
                == whole.execution.output[leftIndex]
            );

            assert(
                streamed.output[rightIndex]
                == whole.execution.output[rightIndex]
            );
        }
    }
}



/++
    Constructs a regular rectangular output-tile decomposition.

    Interior tiles have exactly:

        nominalTileWidth x nominalTileHeight

    The final column and final row may be smaller.
+/
private Region2D[] makeRegularTiles(
    Region2D requestedOutput,
    size_t nominalTileWidth,
    size_t nominalTileHeight
)
@safe
{
    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
        || nominalTileWidth == 0
        || nominalTileHeight == 0
    )
    {
        return null;
    }


    const completeColumnCount =
        requestedOutput.width
        / nominalTileWidth;

    const columnRemainder =
        requestedOutput.width
        % nominalTileWidth;

    const columnCount =
        completeColumnCount
        + (columnRemainder == 0 ? 0 : 1);


    const completeRowCount =
        requestedOutput.height
        / nominalTileHeight;

    const rowRemainder =
        requestedOutput.height
        % nominalTileHeight;

    const rowCount =
        completeRowCount
        + (rowRemainder == 0 ? 0 : 1);


    assert(columnCount != 0);
    assert(rowCount != 0);


    if (
        rowCount != 0
        && columnCount
            > size_t.max / rowCount
    )
    {
        return null;
    }


    auto tasks =
        new Region2D[
            columnCount * rowCount
        ];

    size_t taskIndex = 0;

    size_t currentY =
        requestedOutput.y;

    size_t remainingHeight =
        requestedOutput.height;


    foreach (row; 0 .. rowCount)
    {
        const height =
            remainingHeight < nominalTileHeight
            ? remainingHeight
            : nominalTileHeight;

        assert(height != 0);


        size_t currentX =
            requestedOutput.x;

        size_t remainingWidth =
            requestedOutput.width;


        foreach (column; 0 .. columnCount)
        {
            const width =
                remainingWidth < nominalTileWidth
                ? remainingWidth
                : nominalTileWidth;

            assert(width != 0);

            tasks[taskIndex] =
                Region2D(
                    currentX,
                    currentY,
                    width,
                    height
                );

            ++taskIndex;

            currentX +=
                width;

            remainingWidth -=
                width;
        }


        assert(remainingWidth == 0);

        assert(
            currentX
            == requestedOutput.x
                + requestedOutput.width
        );


        currentY +=
            height;

        remainingHeight -=
            height;
    }


    assert(taskIndex == tasks.length);
    assert(remainingHeight == 0);

    assert(
        currentY
        == requestedOutput.y
            + requestedOutput.height
    );

    return tasks;
}


/*
 * E3.3.8 regular-tile streamed equivalence.
 *
 * This is the first E3.3 decomposition with simultaneous horizontal and
 * vertical task boundaries.
 *
 * It therefore exercises:
 *
 *     vertical seams
 *     horizontal seams
 *     halo corners at seam intersections
 *
 * through the same common decomposed execution path.
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
        makeRegularTiles(
            requestedOutput,
            128,
            96
        );


    /*
     * 1021 pixels:
     *
     *     7 x 128 + 125
     *
     * 769 pixels:
     *
     *     8 x 96 + 1
     */
    enum size_t columnCount = 8;
    enum size_t rowCount = 9;

    assert(
        tasks.length
        == columnCount * rowCount
    );

    assert(tasks.length == 72);


    /*
     * First eight rows:
     *
     *     seven 128 x 96 tiles
     *     one   125 x 96 tile
     */
    foreach (row; 0 .. 8)
    {
        foreach (column; 0 .. 8)
        {
            const index =
                row * columnCount
                + column;

            const expectedWidth =
                column < 7
                ? 128
                : 125;

            assert(
                tasks[index].width
                == expectedWidth
            );

            assert(
                tasks[index].height
                == 96
            );
        }
    }


    /*
     * Final row:
     *
     *     seven 128 x 1 tiles
     *     one   125 x 1 tile
     */
    foreach (column; 0 .. 8)
    {
        const index =
            8 * columnCount
            + column;

        const expectedWidth =
            column < 7
            ? 128
            : 125;

        assert(
            tasks[index].width
            == expectedWidth
        );

        assert(
            tasks[index].height
            == 1
        );
    }


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
     * Source-dependency classes.
     *
     * Full tile:
     *
     *     128 x 96 output
     *     130 x 98 source
     *
     * Final column:
     *
     *     125 x 96 output
     *     127 x 98 source
     *
     * Final row:
     *
     *     128 x 1 output
     *     130 x 3 source
     *
     * Final corner:
     *
     *     125 x 1 output
     *     127 x 3 source
     */
    enum size_t fullTileSourcePixels =
        130 * 98;

    enum size_t finalColumnSourcePixels =
        127 * 98;

    enum size_t finalRowSourcePixels =
        130 * 3;

    enum size_t finalCornerSourcePixels =
        127 * 3;


    assert(
        fullTileSourcePixels
        == 12_740
    );

    assert(
        finalColumnSourcePixels
        == 12_446
    );

    assert(
        finalRowSourcePixels
        == 390
    );

    assert(
        finalCornerSourcePixels
        == 381
    );


    /*
     * Tile classes:
     *
     *     56 full tiles
     *      8 final-column tiles
     *      7 final-row tiles
     *      1 final-corner tile
     */
    enum size_t expectedMaterializedSourcePixels =
          56 * fullTileSourcePixels
        +  8 * finalColumnSourcePixels
        +  7 * finalRowSourcePixels
        +      finalCornerSourcePixels;

    assert(
        expectedMaterializedSourcePixels
        == 816_119
    );


    /*
     * Equivalent factorized form:
     *
     * Sum of source widths over tile columns:
     *
     *     output width + 2 halo columns per tile column
     *     1021 + 2*8 = 1037
     *
     * Sum of source heights over tile rows:
     *
     *     output height + 2 halo rows per tile row
     *     769 + 2*9 = 787
     *
     * Cartesian tile grid:
     *
     *     1037 * 787 = 816119
     */
    assert(
        expectedMaterializedSourcePixels
        == (1021 + 2 * columnCount)
            * (769 + 2 * rowCount)
    );


    assert(
        streamed.accounting.sourceResidentBytes
        == fullTileSourcePixels
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == fullTileSourcePixels
    );

    assert(
        streamed.accounting.currentResidentRasterBytes
        == 0
    );

    assert(
        streamed.accounting.sourceMaterializations
        == 72
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == expectedMaterializedSourcePixels
    );


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
     * Halo duplication relative to one whole materialization.
     */
    enum size_t wholeSourcePixels =
        1023 * 771;

    enum size_t expectedHaloDuplication =
        expectedMaterializedSourcePixels
        - wholeSourcePixels;

    assert(
        wholeSourcePixels
        == 788_733
    );

    assert(
        expectedHaloDuplication
        == 27_386
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
            - wholeSourcePixels
        == expectedHaloDuplication
    );


    /*
     * Regular tiling sharply bounds source raster residency.
     */
    assert(
        streamed.accounting.peakResidentRasterBytes
        == 12_740
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        < whole.accounting.peakResidentRasterBytes
    );


    /*
     * Explicitly inspect all internal seam intersections.
     *
     * Seven vertical seams:
     *
     *     x = 128, 256, ... 896
     *
     * Eight horizontal seams:
     *
     *     y = 96, 192, ... 768
     *
     * At every crossing, verify the four output pixels surrounding the seam
     * intersection against the whole reference.
     *
     * These are the output locations whose source neighbourhoods exercise the
     * four adjacent tile halos around a task-grid corner.
     */
    foreach (verticalSeam; 1 .. columnCount)
    {
        const seamRelativeX =
            verticalSeam * 128;

        assert(
            seamRelativeX
            < requestedOutput.width
        );

        foreach (horizontalSeam; 1 .. rowCount)
        {
            const seamRelativeY =
                horizontalSeam * 96;

            assert(
                seamRelativeY
                < requestedOutput.height
            );


            const leftX =
                seamRelativeX - 1;

            const rightX =
                seamRelativeX;

            const aboveY =
                seamRelativeY - 1;

            const belowY =
                seamRelativeY;


            const aboveLeft =
                aboveY * requestedOutput.width
                + leftX;

            const aboveRight =
                aboveY * requestedOutput.width
                + rightX;

            const belowLeft =
                belowY * requestedOutput.width
                + leftX;

            const belowRight =
                belowY * requestedOutput.width
                + rightX;


            assert(
                streamed.output[aboveLeft]
                == whole.execution.output[aboveLeft]
            );

            assert(
                streamed.output[aboveRight]
                == whole.execution.output[aboveRight]
            );

            assert(
                streamed.output[belowLeft]
                == whole.execution.output[belowLeft]
            );

            assert(
                streamed.output[belowRight]
                == whole.execution.output[belowRight]
            );
        }
    }
}
