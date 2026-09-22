module identity_streaming;

import core.stdc.stdlib :
    free,
    malloc;

import decomposition_oracle :
    DecompositionIssue,
    tryValidateDecomposition;

import dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

import raster :
    OwnedByteResource,
    OwnedRasterImportError,
    PlaneByteLayout,
    RasterCopyError,
    RasterLease,
    Region2D,
    tryAdoptMallocResource,
    tryCopyRasterPlane,
    tryImportOwnedRaster;

import procedural_source :
    ProceduralMaterializationError,
    materializeProcedural,
    proceduralValue;

import std.algorithm.mutation :
    move;

import std.format :
    format;


/++
    E3.2.2 identity-execution failure category.

    This remains research diagnostics rather than a proposed production error
    hierarchy.
+/
enum IdentityExecutionError : ubyte
{
    none,

    invalidRequest,
    invalidDecomposition,

    dependencyDerivationFailed,
    dependencyContractMismatch,

    sourceMaterializationFailed,

    destinationLayoutNotRepresentable,
    destinationAllocationFailed,
    destinationAdoptionFailed,
    destinationImportFailed,
    destinationWritableBorrowFailed,
    destinationInitializationFailed,

    rasterCopyFailed,
    sampleReadFailed,

    internalFailure
}


/++
    Raster-residency and oracle accounting for one identity execution.

    Oracle memory is intentionally reported separately from resident raster
    storage.
+/
struct IdentityExecutionAccounting
{
    size_t requestedOutputBytes;

    size_t sourceResidentBytes;
    size_t destinationResidentBytes;

    size_t currentResidentRasterBytes;
    size_t peakResidentRasterBytes;

    size_t sourceMaterializations;
    size_t totalMaterializedSourcePixels;

    /*
     * Experiment/oracle payload accounting.
     *
     * These values are deliberately separate from resident raster storage.
     * They are structural payload sizes, not total allocator/process-memory
     * measurements and not necessarily simultaneously live.
     */
    size_t outputOracleBytes;
    size_t peakDecompositionCoverageOracleBytes;
    size_t decompositionMetadataPayloadBytes;
}


/++
    Result of one E3.2.2 identity execution.
+/
struct IdentityExecutionResult
{
    IdentityExecutionError error =
        IdentityExecutionError.internalFailure;

    ProceduralMaterializationError sourceError =
        ProceduralMaterializationError.none;

    OwnedRasterImportError destinationImportError =
        OwnedRasterImportError.none;

    RasterCopyError copyError =
        RasterCopyError.none;

    DecompositionIssue decompositionIssue =
        DecompositionIssue.none;

    IdentityExecutionAccounting accounting;

    ubyte[] output;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == IdentityExecutionError.none;
    }
}


/++
    Result category for exact whole/reference versus decomposed-output
    comparison.

    This remains research diagnostics rather than production API.
+/
enum IdentityComparisonIssue : ubyte
{
    none,
    invalidRequest,
    lengthMismatch,
    reassemblyMismatch
}


/++
    First exact pixel mismatch found by the E3.2 comparison oracle.
+/
struct IdentityMismatch
{
    size_t relativeX;
    size_t relativeY;

    size_t logicalX;
    size_t logicalY;

    ubyte expected;
    ubyte actual;
}


/++
    Result of one exact identity-output comparison.
+/
struct IdentityComparisonResult
{
    IdentityComparisonIssue issue =
        IdentityComparisonIssue.invalidRequest;

    size_t requiredLength;
    size_t expectedLength;
    size_t actualLength;

    IdentityMismatch mismatch;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return issue
            == IdentityComparisonIssue.none;
    }
}


/++
    Compares two complete requested-output buffers exactly.

    On the first pixel mismatch, diagnostics identify:

    - output-relative x/y;
    - logical x/y;
    - expected byte;
    - actual byte.

    No tolerance is permitted for identity on ubyte data.
+/
IdentityComparisonResult compareIdentityOutputs(
    Region2D requestedOutput,
    scope const(ubyte)[] expected,
    scope const(ubyte)[] actual
)
@safe
pure
nothrow
@nogc
{
    IdentityComparisonResult result;

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
            IdentityComparisonIssue.invalidRequest;

        return result;
    }


    if (
        requestedOutput.width != 0
        && requestedOutput.height
            > size_t.max / requestedOutput.width
    )
    {
        result.issue =
            IdentityComparisonIssue.invalidRequest;

        return result;
    }


    const requiredLength =
        requestedOutput.width
        * requestedOutput.height;

    result.requiredLength =
        requiredLength;


    if (
        expected.length != requiredLength
        || actual.length != requiredLength
    )
    {
        result.issue =
            IdentityComparisonIssue.lengthMismatch;

        return result;
    }


    foreach (index; 0 .. requiredLength)
    {
        if (expected[index] == actual[index])
        {
            continue;
        }


        const relativeY =
            index / requestedOutput.width;

        const relativeX =
            index % requestedOutput.width;


        /*
         * Requested-output representability proves both additions safe.
         */
        result.mismatch.relativeX =
            relativeX;

        result.mismatch.relativeY =
            relativeY;

        result.mismatch.logicalX =
            requestedOutput.x + relativeX;

        result.mismatch.logicalY =
            requestedOutput.y + relativeY;

        result.mismatch.expected =
            expected[index];

        result.mismatch.actual =
            actual[index];


        result.issue =
            IdentityComparisonIssue.reassemblyMismatch;

        return result;
    }


    result.issue =
        IdentityComparisonIssue.none;

    return result;
}


/++
    Formats an E3.2 comparison failure for unittest diagnostics.
+/
string formatIdentityComparisonFailure(
    IdentityComparisonResult result
)
{
    final switch (result.issue)
    {
        case IdentityComparisonIssue.none:
            return "identity comparison succeeded";

        case IdentityComparisonIssue.invalidRequest:
            return "identity comparison failed: invalid requested output";

        case IdentityComparisonIssue.lengthMismatch:
            return format(
                "identity comparison length mismatch: "
                ~ "required=%s expected=%s actual=%s",
                result.requiredLength,
                result.expectedLength,
                result.actualLength
            );

        case IdentityComparisonIssue.reassemblyMismatch:
            return format(
                "identity reassembly mismatch: "
                ~ "relative=(%s,%s) "
                ~ "logical=(%s,%s) "
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
 * E3.2 comparison oracle diagnostics.
 */
unittest
{
    const requestedOutput =
        Region2D(
            37,
            29,
            3,
            2
        );

    const ubyte[6] expected =
    [
        10,
        20,
        30,
        40,
        50,
        60
    ];

    ubyte[6] actual =
        expected;

    actual[4] = 99;


    const mismatch =
        compareIdentityOutputs(
            requestedOutput,
            expected[],
            actual[]
        );

    assert(!mismatch.ok);

    assert(
        mismatch.issue
        == IdentityComparisonIssue.reassemblyMismatch
    );

    assert(mismatch.mismatch.relativeX == 1);
    assert(mismatch.mismatch.relativeY == 1);

    assert(mismatch.mismatch.logicalX == 38);
    assert(mismatch.mismatch.logicalY == 30);

    assert(mismatch.mismatch.expected == 50);
    assert(mismatch.mismatch.actual == 99);

    assert(
        formatIdentityComparisonFailure(
            mismatch
        )
        ==
        "identity reassembly mismatch: "
        ~ "relative=(1,1) "
        ~ "logical=(38,30) "
        ~ "expected=50 actual=99"
    );


    const ubyte[5] shortActual =
    [
        10,
        20,
        30,
        40,
        50
    ];

    const lengthMismatch =
        compareIdentityOutputs(
            requestedOutput,
            expected[],
            shortActual[]
        );

    assert(!lengthMismatch.ok);

    assert(
        lengthMismatch.issue
        == IdentityComparisonIssue.lengthMismatch
    );

    assert(lengthMismatch.requiredLength == 6);
    assert(lengthMismatch.expectedLength == 6);
    assert(lengthMismatch.actualLength == 5);
}


/++
    Internal result for one blank writable resident destination.
+/
private
struct BlankResidentResult
{
    IdentityExecutionError error =
        IdentityExecutionError.internalFailure;

    OwnedRasterImportError importError =
        OwnedRasterImportError.none;

    RasterLease!ubyte lease;

    size_t residentBytes;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == IdentityExecutionError.none;
    }
}


/++
    Allocates one blank retained single-plane ubyte raster.

    The caller supplies resident dimensions only. The resulting raster always
    begins at resident descriptor-space origin `(0, 0)`.

    Raw malloc ownership crosses only this narrow trusted boundary.
+/
private
BlankResidentResult allocateBlankResident(
    size_t width,
    size_t height
)
@trusted
{
    BlankResidentResult result;

    if (
        width == 0
        || height == 0
    )
    {
        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }

    if (
        width != 0
        && height > size_t.max / width
    )
    {
        result.error =
            IdentityExecutionError
                .destinationLayoutNotRepresentable;

        return result;
    }

    const sampleCount =
        width * height;

    if (
        width > cast(size_t) ptrdiff_t.max
        || sampleCount - 1
            > cast(size_t) ptrdiff_t.max
    )
    {
        result.error =
            IdentityExecutionError
                .destinationLayoutNotRepresentable;

        return result;
    }

    void* memory =
        malloc(sampleCount);

    if (memory is null)
    {
        result.error =
            IdentityExecutionError
                .destinationAllocationFailed;

        return result;
    }

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(
        memory,
        sampleCount,
        resource
    ))
    {
        /*
         * Adoption failed, so ownership never transferred to resource.
         */
        free(memory);

        result.error =
            IdentityExecutionError
                .destinationAdoptionFailed;

        return result;
    }

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t) width,
            1
        )
    ];

    RasterLease!ubyte lease;

    const importResult =
        tryImportOwnedRaster!ubyte(
            resource,
            layouts[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );

    if (!importResult.ok)
    {
        /*
         * Failed import leaves the resource owned by the local token.
         */
        result.error =
            IdentityExecutionError
                .destinationImportFailed;

        result.importError =
            importResult.error;

        return result;
    }

    assert(!resource.ownsResource);

    result.error =
        IdentityExecutionError.none;

    result.residentBytes =
        sampleCount;

    result.lease =
        move(lease);

    return result;
}


/++
    Executes identity once for one complete logical output request.

    E3.2.2a deliberately uses one member equal to the entire requested output.
    Later E3.2.2 stages reuse the same execution path for streamed
    decompositions.

    Processing path:

        validate whole-request decomposition
            ->
        derive zero-margin dependency
            ->
        materialize procedural source
            ->
        allocate distinct writable destination
            ->
        initialize destination with sentinel data
            ->
        tryCopyRasterPlane()
            ->
        inspect result through RasterView.trySample()
            ->
        return ordinary oracle buffer

    The logical request origin never becomes resident RasterView geometry.
+/
IdentityExecutionResult executeWholeIdentity(
    Region2D logicalExtent,
    Region2D requestedOutput
)
@safe
{
    IdentityExecutionResult result;

    /*
     * Whatever path leaves this function, no task raster remains logically
     * resident after the call has completed.
     */
    scope(exit)
    {
        result.accounting.currentResidentRasterBytes = 0;
    }

    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
    )
    {
        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }

    const Region2D[1] wholeDecomposition =
    [
        requestedOutput
    ];

    DecompositionIssue decompositionIssue;

    if (!tryValidateDecomposition(
        requestedOutput,
        wholeDecomposition[],
        decompositionIssue
    ))
    {
        result.error =
            IdentityExecutionError.invalidDecomposition;

        result.decompositionIssue =
            decompositionIssue;

        return result;
    }

    assert(
        decompositionIssue
        == DecompositionIssue.none
    );

    result.decompositionIssue =
        decompositionIssue;


    ExpandedDependency dependency;

    if (!tryExpandDependency(
        logicalExtent,
        requestedOutput,
        DependencyMargins.init,
        dependency
    ))
    {
        result.error =
            IdentityExecutionError
                .dependencyDerivationFailed;

        return result;
    }

    if (
        dependency.validInput
            != requestedOutput
        || dependency.contextDeficit
            != ContextDeficit.init
    )
    {
        result.error =
            IdentityExecutionError
                .dependencyContractMismatch;

        return result;
    }


    auto source =
        materializeProcedural(
            logicalExtent,
            dependency.validInput
        );

    if (!source.ok)
    {
        result.error =
            IdentityExecutionError
                .sourceMaterializationFailed;

        result.sourceError =
            source.error;

        return result;
    }

    assert(
        source.materialized.logicalRequest
        == requestedOutput
    );

    auto sourceView =
        source.materialized.lease.view();

    assert(
        sourceView.region
        == Region2D(
            0,
            0,
            requestedOutput.width,
            requestedOutput.height
        )
    );


    auto destination =
        allocateBlankResident(
            requestedOutput.width,
            requestedOutput.height
        );

    if (!destination.ok)
    {
        result.error =
            destination.error;

        result.destinationImportError =
            destination.importError;

        return result;
    }

    auto destinationView =
        destination.lease.view();

    assert(
        destinationView.region
        == sourceView.region
    );


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    assert(
        sampleCount
        == source.materialized.residentBytes
    );

    assert(
        sampleCount
        == destination.residentBytes
    );


    result.accounting.requestedOutputBytes =
        sampleCount;

    result.accounting.sourceResidentBytes =
        source.materialized.residentBytes;

    result.accounting.destinationResidentBytes =
        destination.residentBytes;

    result.accounting.sourceMaterializations = 1;

    result.accounting.totalMaterializedSourcePixels =
        sampleCount;

    result.accounting.outputOracleBytes =
        sampleCount;

    /*
     * tryValidateDecomposition() uses one ubyte per target pixel.
     */
    result.accounting.peakDecompositionCoverageOracleBytes =
        sampleCount;

    result.accounting.decompositionMetadataPayloadBytes =
        wholeDecomposition.length * Region2D.sizeof;


    result.accounting.currentResidentRasterBytes =
        result.accounting.sourceResidentBytes;

    result.accounting.peakResidentRasterBytes =
        result.accounting.currentResidentRasterBytes;

    result.accounting.currentResidentRasterBytes +=
        result.accounting.destinationResidentBytes;

    if (
        result.accounting.currentResidentRasterBytes
        > result.accounting.peakResidentRasterBytes
    )
    {
        result.accounting.peakResidentRasterBytes =
            result.accounting.currentResidentRasterBytes;
    }


    {
        bool writableSuccess;

        scope auto writable =
            destination.lease.tryWritableView(
                writableSuccess
            );

        if (!writableSuccess)
        {
            result.error =
                IdentityExecutionError
                    .destinationWritableBorrowFailed;

            return result;
        }

        /*
         * Sentinel initialization prevents an accidentally skipped copy from
         * inheriting a correct procedural result by construction.
         *
         * This loop is test setup, not the identity operation under test.
         */
        enum ubyte sentinel = 0xA5;

        foreach (y; 0 .. requestedOutput.height)
        {
            foreach (x; 0 .. requestedOutput.width)
            {
                if (!writable.trySetSample(
                    0,
                    x,
                    y,
                    sentinel
                ))
                {
                    result.error =
                        IdentityExecutionError
                            .destinationInitializationFailed;

                    return result;
                }
            }
        }


        RasterCopyError copyError;

        if (!tryCopyRasterPlane(
            sourceView,
            0,
            writable,
            0,
            copyError
        ))
        {
            result.error =
                IdentityExecutionError
                    .rasterCopyFailed;

            result.copyError =
                copyError;

            return result;
        }

        assert(
            copyError
            == RasterCopyError.none
        );

        result.copyError =
            copyError;
    }


    /*
     * The writable borrow has ended before the ordinary read-only result view
     * is obtained.
     */
    destinationView =
        destination.lease.view();

    result.output =
        new ubyte[sampleCount];

    foreach (y; 0 .. requestedOutput.height)
    {
        foreach (x; 0 .. requestedOutput.width)
        {
            ubyte value;

            if (!destinationView.trySample(
                0,
                x,
                y,
                value
            ))
            {
                result.error =
                    IdentityExecutionError
                        .sampleReadFailed;

                return result;
            }

            const index =
                y * requestedOutput.width
                + x;

            result.output[index] =
                value;
        }
    }


    result.error =
        IdentityExecutionError.none;

    return result;
}


/*
 * E3.2.2a whole-request identity execution.
 *
 * This uses the principal non-zero-origin fixture from the E3.2 contract.
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
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(result.ok);

    assert(
        result.error
        == IdentityExecutionError.none
    );

    assert(
        result.decompositionIssue
        == DecompositionIssue.none
    );

    assert(
        result.sourceError
        == ProceduralMaterializationError.none
    );

    assert(
        result.destinationImportError
        == OwnedRasterImportError.none
    );

    assert(
        result.copyError
        == RasterCopyError.none
    );


    const sampleCount =
        requestedOutput.width
        * requestedOutput.height;

    assert(
        result.output.length
        == sampleCount
    );

    foreach (localY; 0 .. requestedOutput.height)
    {
        foreach (localX; 0 .. requestedOutput.width)
        {
            const index =
                localY * requestedOutput.width
                + localX;

            assert(
                result.output[index]
                ==
                proceduralValue(
                    requestedOutput.x + localX,
                    requestedOutput.y + localY
                )
            );
        }
    }


    assert(
        result.accounting.requestedOutputBytes
        == sampleCount
    );

    assert(
        result.accounting.sourceResidentBytes
        == sampleCount
    );

    assert(
        result.accounting.destinationResidentBytes
        == sampleCount
    );

    assert(
        result.accounting.sourceMaterializations
        == 1
    );

    assert(
        result.accounting.totalMaterializedSourcePixels
        == sampleCount
    );

    assert(
        result.accounting.outputOracleBytes
        == sampleCount
    );

    assert(
        result.accounting.peakResidentRasterBytes
        == sampleCount * 2
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );
}


/*
 * Empty output remains outside the resident execution path.
 */
unittest
{
    const result =
        executeWholeIdentity(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 0, 5)
        );

    assert(!result.ok);

    assert(
        result.error
        == IdentityExecutionError.invalidRequest
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );

    assert(
        result.accounting.peakResidentRasterBytes
        == 0
    );
}



/++
    Executes identity for one already-defined decomposition of a requested
    output.

    The complete decomposition is validated before any resident raster is
    materialized.

    Tasks are then processed sequentially through the already proven
    whole-request task path.

    `sourceResidentBytes` and `destinationResidentBytes` report the largest
    corresponding single-task materialization for a decomposed execution.

    `peakResidentRasterBytes` reports the largest simultaneously resident
    source-plus-destination task pair.

    `outputOracleBytes` reports the returned reassembled output buffer only.

    `peakDecompositionCoverageOracleBytes` reports the largest E3.1.3 ubyte
    coverage-bitmap payload used during the execution. It is a peak payload,
    not a sum across sequential validations.

    `decompositionMetadataPayloadBytes` reports the Region2D task payload. It
    does not claim allocator overhead or total process memory.

    All oracle/metadata accounting is deliberately separate from resident
    raster accounting.
+/
IdentityExecutionResult executeIdentityDecomposition(
    Region2D logicalExtent,
    Region2D requestedOutput,
    scope const(Region2D)[] tasks
)
@safe
{
    IdentityExecutionResult result;

    if (
        !requestedOutput.hasRepresentableExtent()
        || requestedOutput.empty()
    )
    {
        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }


    DecompositionIssue decompositionIssue;

    if (!tryValidateDecomposition(
        requestedOutput,
        tasks,
        decompositionIssue
    ))
    {
        result.error =
            IdentityExecutionError.invalidDecomposition;

        result.decompositionIssue =
            decompositionIssue;

        return result;
    }

    assert(
        decompositionIssue
        == DecompositionIssue.none
    );

    result.decompositionIssue =
        decompositionIssue;


    /*
     * Successful bounded decomposition validation already checked this
     * multiplication before constructing its coverage oracle.
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

    /*
     * The top-level E3.1.3 validation covers the complete requested output
     * and therefore allocates one coverage byte per requested pixel.
     *
     * Task-local executeWholeIdentity() validations cover only individual
     * decomposition members, so none can exceed this bitmap payload.
     */
    result.accounting.peakDecompositionCoverageOracleBytes =
        sampleCount;

    assert(
        tasks.length
        <= size_t.max / Region2D.sizeof
    );

    result.accounting.decompositionMetadataPayloadBytes =
        tasks.length * Region2D.sizeof;


    foreach (const task; tasks)
    {
        if (task.empty())
        {
            /*
             * The decomposition oracle permits empty members because they
             * contribute no coverage. They require no resident execution.
             */
            continue;
        }

        auto taskResult =
            executeWholeIdentity(
                logicalExtent,
                task
            );

        if (!taskResult.ok)
        {
            result.error =
                taskResult.error;

            result.sourceError =
                taskResult.sourceError;

            result.destinationImportError =
                taskResult.destinationImportError;

            result.copyError =
                taskResult.copyError;

            /*
             * The complete decomposition itself was already valid. Preserve
             * that diagnostic instead of replacing it with the task-local
             * one-member validation result.
             */
            return result;
        }

        assert(
            taskResult.accounting
                .currentResidentRasterBytes
            == 0
        );


        if (
            taskResult.accounting.sourceResidentBytes
            > result.accounting.sourceResidentBytes
        )
        {
            result.accounting.sourceResidentBytes =
                taskResult.accounting.sourceResidentBytes;
        }

        if (
            taskResult.accounting.destinationResidentBytes
            > result.accounting.destinationResidentBytes
        )
        {
            result.accounting.destinationResidentBytes =
                taskResult.accounting.destinationResidentBytes;
        }

        if (
            taskResult.accounting.peakResidentRasterBytes
            > result.accounting.peakResidentRasterBytes
        )
        {
            result.accounting.peakResidentRasterBytes =
                taskResult.accounting.peakResidentRasterBytes;
        }


        result.accounting.sourceMaterializations +=
            taskResult.accounting.sourceMaterializations;

        result.accounting.totalMaterializedSourcePixels +=
            taskResult.accounting.totalMaterializedSourcePixels;


        /*
         * Exact decomposition containment proves both subtractions safe.
         */
        const relativeX =
            task.x - requestedOutput.x;

        const relativeY =
            task.y - requestedOutput.y;


        assert(
            taskResult.output.length
            == task.width * task.height
        );

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
     * Every task-local resident source/destination pair was destroyed before
     * the next task was entered.
     */
    result.accounting.currentResidentRasterBytes = 0;

    result.error =
        IdentityExecutionError.none;

    return result;
}


/++
    Constructs a horizontal-strip decomposition.

    Every strip spans the complete requested width. The final strip may be
    shorter than `nominalStripHeight`.

    Invalid or empty input, or a zero nominal strip height, produces no tasks.
+/
private
Region2D[] makeHorizontalStrips(
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

        /*
         * requestedOutput representability proves this addition safe.
         */
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


/++
    Executes identity as sequential horizontal strips.
+/
IdentityExecutionResult executeHorizontalStripIdentity(
    Region2D logicalExtent,
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
        IdentityExecutionResult result;

        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }

    const tasks =
        makeHorizontalStrips(
            requestedOutput,
            nominalStripHeight
        );

    assert(tasks.length != 0);

    return executeIdentityDecomposition(
        logicalExtent,
        requestedOutput,
        tasks
    );
}


/*
 * E3.2.3 horizontal-strip streamed equivalence.
 *
 * The principal fixture height is 769. A nominal strip height of 128 creates:
 *
 *     6 * 128 + 1
 *
 * so the final strip is deliberately smaller than the nominal task height.
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

    enum size_t nominalStripHeight =
        128;


    const tasks =
        makeHorizontalStrips(
            requestedOutput,
            nominalStripHeight
        );

    assert(tasks.length == 7);

    foreach (const task; tasks)
    {
        assert(
            task.width
            == requestedOutput.width
        );

        assert(
            task.height
            <= nominalStripHeight
        );
    }

    assert(
        tasks[$ - 1].height
        == 1
    );


    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks,
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );


    auto reference =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(reference.ok);


    auto streamed =
        executeHorizontalStripIdentity(
            logicalExtent,
            requestedOutput,
            nominalStripHeight
        );

    assert(streamed.ok);

    assert(
        streamed.error
        == IdentityExecutionError.none
    );

    assert(
        streamed.decompositionIssue
        == DecompositionIssue.none
    );


    assert(
        streamed.output.length
        == reference.output.length
    );


    const comparison =
        compareIdentityOutputs(
            requestedOutput,
            reference.output,
            streamed.output
        );

    assert(
        comparison.ok,
        formatIdentityComparisonFailure(
            comparison
        )
    );

    /*
     * Identity on ubyte pixels is exact. No tolerance is permitted.
     *
     * Keep the coordinate-aware loop rather than relying only on array
     * equality so any future assertion failure can be localized directly.
     */
    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            const index =
                relativeY * requestedOutput.width
                + relativeX;

            const expected =
                reference.output[index];

            const actual =
                streamed.output[index];

            assert(
                actual
                == expected
            );

            assert(
                actual
                ==
                proceduralValue(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY
                )
            );
        }
    }


    const requestedPixels =
        requestedOutput.width
        * requestedOutput.height;

    const largestTaskPixels =
        requestedOutput.width
        * nominalStripHeight;


    assert(
        streamed.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.outputOracleBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.sourceMaterializations
        == tasks.length
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == requestedPixels
    );


    assert(
        streamed.accounting.sourceResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.destinationResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == largestTaskPixels * 2
    );

    assert(
        streamed.accounting.currentResidentRasterBytes
        == 0
    );


    /*
     * This is the first actual streamed-residency result:
     *
     * the complete requested output remains much larger than one resident
     * strip, while raster residency is bounded by the current task pair.
     */
    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        reference.accounting.peakResidentRasterBytes
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        requestedPixels
    );
}


/*
 * A zero strip height cannot define a streaming decomposition.
 */
unittest
{
    const result =
        executeHorizontalStripIdentity(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 10, 10),
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == IdentityExecutionError.invalidRequest
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );
}



/++
    Constructs a vertical-strip decomposition.

    Every strip spans the complete requested height. The final strip may be
    narrower than `nominalStripWidth`.

    Invalid or empty input, or a zero nominal strip width, produces no tasks.
+/
private
Region2D[] makeVerticalStrips(
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

        /*
         * requestedOutput representability proves this addition safe.
         */
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


/++
    Executes identity as sequential vertical strips.
+/
IdentityExecutionResult executeVerticalStripIdentity(
    Region2D logicalExtent,
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
        IdentityExecutionResult result;

        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }

    const tasks =
        makeVerticalStrips(
            requestedOutput,
            nominalStripWidth
        );

    assert(tasks.length != 0);

    return executeIdentityDecomposition(
        logicalExtent,
        requestedOutput,
        tasks
    );
}


/*
 * E3.2.4 vertical-strip streamed equivalence.
 *
 * The principal fixture width is 1021. A nominal strip width of 128 creates:
 *
 *     7 * 128 + 125
 *
 * so the final strip is deliberately narrower than the nominal task width.
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

    enum size_t nominalStripWidth =
        128;


    const tasks =
        makeVerticalStrips(
            requestedOutput,
            nominalStripWidth
        );

    assert(tasks.length == 8);

    foreach (const task; tasks)
    {
        assert(
            task.height
            == requestedOutput.height
        );

        assert(
            task.width
            <= nominalStripWidth
        );
    }

    assert(
        tasks[$ - 1].width
        == 125
    );


    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks,
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );


    auto reference =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(reference.ok);


    auto streamed =
        executeVerticalStripIdentity(
            logicalExtent,
            requestedOutput,
            nominalStripWidth
        );

    assert(streamed.ok);

    assert(
        streamed.error
        == IdentityExecutionError.none
    );

    assert(
        streamed.decompositionIssue
        == DecompositionIssue.none
    );


    assert(
        streamed.output.length
        == reference.output.length
    );


    const comparison =
        compareIdentityOutputs(
            requestedOutput,
            reference.output,
            streamed.output
        );

    assert(
        comparison.ok,
        formatIdentityComparisonFailure(
            comparison
        )
    );

    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            const index =
                relativeY * requestedOutput.width
                + relativeX;

            const expected =
                reference.output[index];

            const actual =
                streamed.output[index];

            assert(
                actual
                == expected
            );

            assert(
                actual
                ==
                proceduralValue(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY
                )
            );
        }
    }


    const requestedPixels =
        requestedOutput.width
        * requestedOutput.height;

    const largestTaskPixels =
        nominalStripWidth
        * requestedOutput.height;


    assert(
        streamed.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.outputOracleBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.sourceMaterializations
        == tasks.length
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == requestedPixels
    );


    assert(
        streamed.accounting.sourceResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.destinationResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == largestTaskPixels * 2
    );

    assert(
        streamed.accounting.currentResidentRasterBytes
        == 0
    );


    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        reference.accounting.peakResidentRasterBytes
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        requestedPixels
    );
}


/*
 * A zero strip width cannot define a streaming decomposition.
 */
unittest
{
    const result =
        executeVerticalStripIdentity(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 10, 10),
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == IdentityExecutionError.invalidRequest
    );

    assert(
        result.accounting.currentResidentRasterBytes
        == 0
    );
}



/++
    Constructs a row-major regular rectangular tile decomposition.

    Interior tiles use the requested nominal dimensions. Tiles on the right
    and bottom edges may be smaller.

    Invalid or empty input, zero nominal dimensions, or an unrepresentable
    task-count product produces no tasks.
+/
private
Region2D[] makeRegularTiles(
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

    const remainderWidth =
        requestedOutput.width
        % nominalTileWidth;

    const columnCount =
        completeColumnCount
        + (remainderWidth == 0 ? 0 : 1);


    const completeRowCount =
        requestedOutput.height
        / nominalTileHeight;

    const remainderHeight =
        requestedOutput.height
        % nominalTileHeight;

    const rowCount =
        completeRowCount
        + (remainderHeight == 0 ? 0 : 1);


    assert(columnCount != 0);
    assert(rowCount != 0);

    if (
        rowCount
        > size_t.max / columnCount
    )
    {
        return null;
    }

    const tileCount =
        columnCount * rowCount;

    auto tasks =
        new Region2D[tileCount];


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

            assert(taskIndex < tasks.length);

            tasks[taskIndex] =
                Region2D(
                    currentX,
                    currentY,
                    width,
                    height
                );

            ++taskIndex;

            /*
             * requestedOutput representability proves this addition safe.
             */
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


/++
    Executes identity as sequential regular rectangular tiles.
+/
IdentityExecutionResult executeRegularTileIdentity(
    Region2D logicalExtent,
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
        IdentityExecutionResult result;

        result.error =
            IdentityExecutionError.invalidRequest;

        return result;
    }


    const tasks =
        makeRegularTiles(
            requestedOutput,
            nominalTileWidth,
            nominalTileHeight
        );

    if (tasks.length == 0)
    {
        IdentityExecutionResult result;

        result.error =
            IdentityExecutionError.invalidDecomposition;

        return result;
    }


    return executeIdentityDecomposition(
        logicalExtent,
        requestedOutput,
        tasks
    );
}


/*
 * E3.2.5 regular rectangular tile equivalence.
 *
 * Principal fixture:
 *
 *     requested width  = 1021 = 7 * 128 + 125
 *     requested height =  769 = 8 *  96 +   1
 *
 * Therefore:
 *
 *     columns = 8
 *     rows    = 9
 *     tasks   = 72
 *
 * The bottom-right task is deliberately reduced on both axes.
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

    enum size_t nominalTileWidth =
        128;

    enum size_t nominalTileHeight =
        96;


    const tasks =
        makeRegularTiles(
            requestedOutput,
            nominalTileWidth,
            nominalTileHeight
        );

    assert(tasks.length == 72);


    /*
     * Top-left interior tile.
     */
    assert(
        tasks[0]
        == Region2D(
            1733,
            911,
            128,
            96
        )
    );


    /*
     * Top-right edge tile.
     */
    assert(
        tasks[7]
        == Region2D(
            2629,
            911,
            125,
            96
        )
    );


    /*
     * Bottom-left edge tile.
     */
    assert(
        tasks[$ - 8]
        == Region2D(
            1733,
            1679,
            128,
            1
        )
    );


    /*
     * Bottom-right corner tile is reduced on both axes.
     */
    assert(
        tasks[$ - 1]
        == Region2D(
            2629,
            1679,
            125,
            1
        )
    );


    foreach (const task; tasks)
    {
        assert(
            task.width
            <= nominalTileWidth
        );

        assert(
            task.height
            <= nominalTileHeight
        );

        assert(!task.empty());
    }


    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks,
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );


    auto reference =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(reference.ok);


    auto streamed =
        executeRegularTileIdentity(
            logicalExtent,
            requestedOutput,
            nominalTileWidth,
            nominalTileHeight
        );

    assert(streamed.ok);

    assert(
        streamed.error
        == IdentityExecutionError.none
    );

    assert(
        streamed.decompositionIssue
        == DecompositionIssue.none
    );


    assert(
        streamed.output.length
        == reference.output.length
    );


    const comparison =
        compareIdentityOutputs(
            requestedOutput,
            reference.output,
            streamed.output
        );

    assert(
        comparison.ok,
        formatIdentityComparisonFailure(
            comparison
        )
    );


    /*
     * Exact byte identity across both reassembly axes.
     */
    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            const index =
                relativeY * requestedOutput.width
                + relativeX;

            const expected =
                reference.output[index];

            const actual =
                streamed.output[index];

            assert(
                actual
                == expected
            );

            assert(
                actual
                ==
                proceduralValue(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY
                )
            );
        }
    }


    const requestedPixels =
        requestedOutput.width
        * requestedOutput.height;

    const largestTaskPixels =
        nominalTileWidth
        * nominalTileHeight;


    assert(
        streamed.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.outputOracleBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.sourceMaterializations
        == tasks.length
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == requestedPixels
    );


    assert(
        streamed.accounting.sourceResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.destinationResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == largestTaskPixels * 2
    );

    assert(
        streamed.accounting.currentResidentRasterBytes
        == 0
    );


    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        reference.accounting.peakResidentRasterBytes
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        requestedPixels
    );
}


/*
 * Zero-sized tile dimensions cannot define a regular decomposition.
 */
unittest
{
    auto result =
        executeRegularTileIdentity(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 10, 10),
            0,
            4
        );

    assert(!result.ok);

    assert(
        result.error
        == IdentityExecutionError.invalidRequest
    );


    result =
        executeRegularTileIdentity(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 10, 10),
            4,
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == IdentityExecutionError.invalidRequest
    );
}



/*
 * E3.2.6 irregular-rectangle streamed equivalence.
 *
 * This decomposition is deliberately handwritten rather than generated.
 *
 * The requested output is partitioned into four horizontal bands:
 *
 *     y =  911, h = 137: 173 + 311 + 537
 *     y = 1048, h = 211: 401 +  97 + 523
 *     y = 1259, h = 173: 211 + 503 + 307
 *     y = 1432, h = 248:  89 + 233 + 317 + 382
 *
 * Every row therefore covers exactly 1021 pixels, but the vertical split
 * positions differ between bands.
 *
 * The task array is intentionally not in spatial or row-major order. Exact
 * reassembly must depend only on logical coordinates.
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


    const Region2D[13] tasks =
    [
        /*
         * Band 3, middle.
         */
        Region2D(
            1944,
            1259,
            503,
            173
        ),

        /*
         * Band 1, left.
         */
        Region2D(
            1733,
            911,
            173,
            137
        ),

        /*
         * Band 4, right.
         */
        Region2D(
            2372,
            1432,
            382,
            248
        ),

        /*
         * Band 2, middle.
         */
        Region2D(
            2134,
            1048,
            97,
            211
        ),

        /*
         * Band 1, right.
         */
        Region2D(
            2217,
            911,
            537,
            137
        ),

        /*
         * Band 3, left.
         */
        Region2D(
            1733,
            1259,
            211,
            173
        ),

        /*
         * Band 4, far left.
         */
        Region2D(
            1733,
            1432,
            89,
            248
        ),

        /*
         * Band 2, right.
         */
        Region2D(
            2231,
            1048,
            523,
            211
        ),

        /*
         * Band 1, middle.
         */
        Region2D(
            1906,
            911,
            311,
            137
        ),

        /*
         * Band 4, middle-right.
         */
        Region2D(
            2055,
            1432,
            317,
            248
        ),

        /*
         * Band 2, left.
         */
        Region2D(
            1733,
            1048,
            401,
            211
        ),

        /*
         * Band 3, right.
         */
        Region2D(
            2447,
            1259,
            307,
            173
        ),

        /*
         * Band 4, middle-left.
         */
        Region2D(
            1822,
            1432,
            233,
            248
        )
    ];


    /*
     * This is intentionally not row-major input.
     */
    assert(
        tasks[0].y
        != requestedOutput.y
    );

    assert(
        tasks[0].x
        != requestedOutput.x
    );


    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks[],
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );


    auto reference =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(reference.ok);


    auto irregular =
        executeIdentityDecomposition(
            logicalExtent,
            requestedOutput,
            tasks[]
        );

    assert(irregular.ok);

    assert(
        irregular.error
        == IdentityExecutionError.none
    );

    assert(
        irregular.decompositionIssue
        == DecompositionIssue.none
    );


    assert(
        irregular.output.length
        == reference.output.length
    );


    const comparison =
        compareIdentityOutputs(
            requestedOutput,
            reference.output,
            irregular.output
        );

    assert(
        comparison.ok,
        formatIdentityComparisonFailure(
            comparison
        )
    );


    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            const index =
                relativeY * requestedOutput.width
                + relativeX;

            const expected =
                reference.output[index];

            const actual =
                irregular.output[index];

            assert(
                actual
                == expected
            );

            assert(
                actual
                ==
                proceduralValue(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY
                )
            );
        }
    }


    const requestedPixels =
        requestedOutput.width
        * requestedOutput.height;

    /*
     * The largest handwritten member is:
     *
     *     523 * 211 = 110353
     */
    enum size_t largestTaskPixels =
        523 * 211;


    assert(
        irregular.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        irregular.accounting.outputOracleBytes
        == requestedPixels
    );

    assert(
        irregular.accounting.sourceMaterializations
        == tasks.length
    );

    assert(
        irregular.accounting.totalMaterializedSourcePixels
        == requestedPixels
    );


    assert(
        irregular.accounting.sourceResidentBytes
        == largestTaskPixels
    );

    assert(
        irregular.accounting.destinationResidentBytes
        == largestTaskPixels
    );

    assert(
        irregular.accounting.peakResidentRasterBytes
        == largestTaskPixels * 2
    );

    assert(
        irregular.accounting.currentResidentRasterBytes
        == 0
    );


    assert(
        irregular.accounting.peakResidentRasterBytes
        <
        reference.accounting.peakResidentRasterBytes
    );

    assert(
        irregular.accounting.peakResidentRasterBytes
        <
        requestedPixels
    );
}



/*
 * E3.2.7 pixel-task streamed equivalence.
 *
 * Pixel tasks are deliberately exercised only on a small fixture. Every
 * decomposition member is exactly one logical pixel and therefore produces
 * one 1x1 source raster plus one distinct 1x1 destination raster.
 *
 * This is the maximal decomposition case for the current sequential identity
 * execution model.
 */
unittest
{
    const logicalExtent =
        Region2D(
            0,
            0,
            100,
            100
        );

    const requestedOutput =
        Region2D(
            37,
            29,
            7,
            5
        );

    enum size_t pixelCount =
        7 * 5;

    static assert(pixelCount == 35);


    Region2D[pixelCount] tasks;

    size_t taskIndex = 0;

    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            assert(taskIndex < tasks.length);

            tasks[taskIndex] =
                Region2D(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY,
                    1,
                    1
                );

            ++taskIndex;
        }
    }

    assert(taskIndex == tasks.length);

    assert(
        tasks[0]
        == Region2D(
            37,
            29,
            1,
            1
        )
    );

    assert(
        tasks[$ - 1]
        == Region2D(
            43,
            33,
            1,
            1
        )
    );

    foreach (const task; tasks)
    {
        assert(task.width == 1);
        assert(task.height == 1);
        assert(!task.empty());
    }


    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks[],
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );


    auto reference =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(reference.ok);


    auto pixelStream =
        executeIdentityDecomposition(
            logicalExtent,
            requestedOutput,
            tasks[]
        );

    assert(pixelStream.ok);

    assert(
        pixelStream.error
        == IdentityExecutionError.none
    );

    assert(
        pixelStream.decompositionIssue
        == DecompositionIssue.none
    );


    assert(
        pixelStream.output.length
        == reference.output.length
    );


    const comparison =
        compareIdentityOutputs(
            requestedOutput,
            reference.output,
            pixelStream.output
        );

    assert(
        comparison.ok,
        formatIdentityComparisonFailure(
            comparison
        )
    );

    assert(
        pixelStream.output.length
        == pixelCount
    );


    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            const index =
                relativeY * requestedOutput.width
                + relativeX;

            const expected =
                reference.output[index];

            const actual =
                pixelStream.output[index];

            assert(
                actual
                == expected
            );

            assert(
                actual
                ==
                proceduralValue(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY
                )
            );
        }
    }


    assert(
        pixelStream.accounting.requestedOutputBytes
        == pixelCount
    );

    assert(
        pixelStream.accounting.outputOracleBytes
        == pixelCount
    );

    assert(
        pixelStream.accounting.sourceMaterializations
        == pixelCount
    );

    assert(
        pixelStream.accounting.totalMaterializedSourcePixels
        == pixelCount
    );


    /*
     * Every task materializes exactly one source byte and one destination
     * byte. No larger task raster is ever resident.
     */
    assert(
        pixelStream.accounting.sourceResidentBytes
        == 1
    );

    assert(
        pixelStream.accounting.destinationResidentBytes
        == 1
    );

    assert(
        pixelStream.accounting.peakResidentRasterBytes
        == 2
    );

    assert(
        pixelStream.accounting.currentResidentRasterBytes
        == 0
    );


    assert(
        reference.accounting.peakResidentRasterBytes
        == pixelCount * 2
    );

    assert(
        pixelStream.accounting.peakResidentRasterBytes
        <
        reference.accounting.peakResidentRasterBytes
    );
}



/*
 * E3.2.8 huge logical extent with bounded resident raster storage.
 *
 * The logical image contains one trillion ubyte pixels:
 *
 *     1,000,000 * 1,000,000 = 1,000,000,000,000 bytes logically
 *
 * It is never materialized as one resident image.
 *
 * Only the requested non-zero-origin region is generated, and the streamed
 * execution further bounds resident raster storage to one source/destination
 * tile pair at a time.
 */
unittest
{
    const logicalExtent =
        Region2D(
            0,
            0,
            1_000_000,
            1_000_000
        );

    const requestedOutput =
        Region2D(
            900_003,
            800_007,
            257,
            193
        );

    enum size_t nominalTileWidth =
        64;

    enum size_t nominalTileHeight =
        48;


    const ulong logicalImageBytes =
        cast(ulong) logicalExtent.width
        * cast(ulong) logicalExtent.height;

    assert(
        logicalImageBytes
        == 1_000_000_000_000UL
    );


    const tasks =
        makeRegularTiles(
            requestedOutput,
            nominalTileWidth,
            nominalTileHeight
        );

    /*
     *     width  = 4 * 64 + 1
     *     height = 4 * 48 + 1
     */
    assert(tasks.length == 25);

    assert(
        tasks[0]
        == Region2D(
            900_003,
            800_007,
            64,
            48
        )
    );

    assert(
        tasks[$ - 1]
        == Region2D(
            900_259,
            800_199,
            1,
            1
        )
    );


    DecompositionIssue issue;

    assert(
        tryValidateDecomposition(
            requestedOutput,
            tasks,
            issue
        )
    );

    assert(
        issue
        == DecompositionIssue.none
    );


    /*
     * Whole-request execution is the semantic reference only. Even this path
     * materializes the requested region rather than the trillion-pixel logical
     * image.
     */
    auto reference =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(reference.ok);


    auto streamed =
        executeRegularTileIdentity(
            logicalExtent,
            requestedOutput,
            nominalTileWidth,
            nominalTileHeight
        );

    assert(streamed.ok);

    assert(
        streamed.error
        == IdentityExecutionError.none
    );

    assert(
        streamed.decompositionIssue
        == DecompositionIssue.none
    );


    const size_t requestedPixels =
        requestedOutput.width
        * requestedOutput.height;

    assert(
        requestedPixels
        == 49_601
    );

    assert(
        streamed.output.length
        == requestedPixels
    );

    assert(
        streamed.output.length
        == reference.output.length
    );


    const comparison =
        compareIdentityOutputs(
            requestedOutput,
            reference.output,
            streamed.output
        );

    assert(
        comparison.ok,
        formatIdentityComparisonFailure(
            comparison
        )
    );


    /*
     * Exact result comparison also verifies that the procedural source used
     * global logical coordinates near the far end of the huge extent.
     */
    foreach (relativeY; 0 .. requestedOutput.height)
    {
        foreach (relativeX; 0 .. requestedOutput.width)
        {
            const index =
                relativeY * requestedOutput.width
                + relativeX;

            const expected =
                reference.output[index];

            const actual =
                streamed.output[index];

            assert(
                actual
                == expected
            );

            assert(
                actual
                ==
                proceduralValue(
                    requestedOutput.x + relativeX,
                    requestedOutput.y + relativeY
                )
            );
        }
    }


    enum size_t largestTaskPixels =
        nominalTileWidth
        * nominalTileHeight;

    static assert(
        largestTaskPixels
        == 3_072
    );


    assert(
        reference.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        reference.accounting.sourceResidentBytes
        == requestedPixels
    );

    assert(
        reference.accounting.destinationResidentBytes
        == requestedPixels
    );

    assert(
        reference.accounting.peakResidentRasterBytes
        == requestedPixels * 2
    );


    assert(
        streamed.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.outputOracleBytes
        == requestedPixels
    );

    assert(
        streamed.accounting.sourceMaterializations
        == tasks.length
    );

    assert(
        streamed.accounting.totalMaterializedSourcePixels
        == requestedPixels
    );


    assert(
        streamed.accounting.sourceResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.destinationResidentBytes
        == largestTaskPixels
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == largestTaskPixels * 2
    );

    assert(
        streamed.accounting.peakResidentRasterBytes
        == 6_144
    );

    assert(
        streamed.accounting.currentResidentRasterBytes
        == 0
    );


    /*
     * The logical image is vastly larger than the resident task pair.
     *
     * Because this experiment uses one-byte samples, logical pixel count and
     * logical image bytes are numerically identical.
     */
    assert(
        logicalImageBytes
        >
        cast(ulong)
            streamed.accounting.peakResidentRasterBytes
            * 100_000_000UL
    );

    assert(
        cast(ulong)
            streamed.accounting.totalMaterializedSourcePixels
        <
        logicalImageBytes
    );


    /*
     * Streaming reduces raster residency even relative to the already bounded
     * whole-request reference path.
     */
    assert(
        streamed.accounting.peakResidentRasterBytes
        <
        reference.accounting.peakResidentRasterBytes
    );
}



/*
 * E3.2 accounting category contract.
 *
 * Raster residency, output-oracle payload, decomposition coverage-oracle
 * payload and caller-supplied decomposition metadata remain distinct
 * quantities.
 */
unittest
{
    const logicalExtent =
        Region2D(
            0,
            0,
            20,
            20
        );

    const requestedOutput =
        Region2D(
            3,
            4,
            4,
            2
        );

    enum size_t requestedPixels =
        4 * 2;


    auto whole =
        executeWholeIdentity(
            logicalExtent,
            requestedOutput
        );

    assert(whole.ok);

    assert(
        whole.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        whole.accounting.outputOracleBytes
        == requestedPixels
    );

    assert(
        whole.accounting.peakDecompositionCoverageOracleBytes
        == requestedPixels
    );

    assert(
        whole.accounting.decompositionMetadataPayloadBytes
        == Region2D.sizeof
    );

    assert(
        whole.accounting.peakResidentRasterBytes
        == requestedPixels * 2
    );


    const Region2D[2] tasks =
    [
        Region2D(
            3,
            4,
            4,
            1
        ),

        Region2D(
            3,
            5,
            4,
            1
        )
    ];


    auto decomposed =
        executeIdentityDecomposition(
            logicalExtent,
            requestedOutput,
            tasks[]
        );

    assert(decomposed.ok);

    assert(
        decomposed.accounting.requestedOutputBytes
        == requestedPixels
    );

    assert(
        decomposed.accounting.outputOracleBytes
        == requestedPixels
    );

    assert(
        decomposed.accounting.peakDecompositionCoverageOracleBytes
        == requestedPixels
    );

    assert(
        decomposed.accounting.decompositionMetadataPayloadBytes
        == tasks.length * Region2D.sizeof
    );

    /*
     * Each streamed task contains four pixels:
     *
     *     source      = 4 bytes
     *     destination = 4 bytes
     *
     * giving eight simultaneously resident raster bytes.
     */
    assert(
        decomposed.accounting.peakResidentRasterBytes
        == 8
    );

    assert(
        decomposed.accounting.currentResidentRasterBytes
        == 0
    );
}
