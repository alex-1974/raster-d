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

import imagery.raster :
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

    size_t oracleBytes;
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

    result.accounting.oracleBytes =
        sampleCount;


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
        result.accounting.oracleBytes
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
