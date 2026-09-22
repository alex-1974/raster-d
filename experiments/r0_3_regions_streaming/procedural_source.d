module procedural_source;

import core.stdc.stdlib :
    free,
    malloc;

import raster :
    OwnedByteResource,
    OwnedRasterImportError,
    PlaneByteLayout,
    RasterLease,
    Region2D,
    tryAdoptMallocResource,
    tryImportOwnedRaster;

import region_algebra :
    tryContainsAbsolute;

import std.algorithm.mutation :
    move;


/++
    E3.2.1 materialization failure category.

    This is research diagnostics, not a proposed production error hierarchy.
+/
enum ProceduralMaterializationError : ubyte
{
    none,

    invalidLogicalExtent,
    invalidRequest,
    requestOutsideLogicalExtent,

    sampleCountOverflow,
    residentLayoutNotRepresentable,

    allocationFailed,
    adoptionFailed,
    importFailed,
    writableBorrowFailed,
    sampleWriteFailed,

    internalFailure
}


/++
    One resident raster materialized from a logical procedural-source request.

    `logicalRequest` remains separate from the resident RasterLease geometry.

    The retained raster itself always uses resident descriptor-space origin
    `(0, 0)`.
+/
struct MaterializedUbyteRaster
{
    Region2D logicalRequest;

    RasterLease!ubyte lease;

    size_t residentBytes;
}


/++
    Result of one procedural-source materialization attempt.

    `importError` is meaningful only when `error == importFailed`.
+/
struct ProceduralMaterializationResult
{
    ProceduralMaterializationError error =
        ProceduralMaterializationError.internalFailure;

    OwnedRasterImportError importError =
        OwnedRasterImportError.none;

    MaterializedUbyteRaster materialized;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error
            == ProceduralMaterializationError.none;
    }
}


/++
    Deterministic procedural ubyte value for one logical image coordinate.

    Coordinate components are reduced before multiplication and addition, so
    the mixing arithmetic remains bounded independently of the original
    `size_t` coordinate magnitude.
+/
ubyte proceduralValue(
    size_t logicalX,
    size_t logicalY
)
@safe
pure
nothrow
@nogc
{
    enum size_t modulus = 251;

    const x =
        logicalX % modulus;

    const y =
        logicalY % modulus;

    /*
     * Maximum intermediate:
     *
     *     250 * 17
     *   + 250 * 29
     *   + 37
     *   = 11_537
     *
     * This is independent of size_t width.
     */
    const mixed =
        (
            x * 17
            + y * 29
            + 37
        )
        % modulus;

    return cast(ubyte) mixed;
}


private
ProceduralMaterializationResult failure(
    ProceduralMaterializationError error,
    OwnedRasterImportError importError =
        OwnedRasterImportError.none
)
@safe
nothrow
@nogc
{
    ProceduralMaterializationResult result;

    result.error =
        error;

    result.importError =
        importError;

    return result;
}


/++
    Narrow allocation/adoption boundary.

    On success `owned` owns the malloc-compatible allocation.

    On adoption failure this helper retains responsibility for the raw malloc
    allocation and frees it before returning.
+/
private
ProceduralMaterializationError tryAllocateOwnedBytes(
    size_t byteLength,
    ref OwnedByteResource owned
)
@trusted
nothrow
@nogc
{
    assert(byteLength != 0);
    assert(!owned.ownsResource);

    void* memory =
        malloc(byteLength);

    if (memory is null)
    {
        return ProceduralMaterializationError.allocationFailed;
    }

    if (!tryAdoptMallocResource(
        memory,
        byteLength,
        owned
    ))
    {
        free(memory);

        return ProceduralMaterializationError.adoptionFailed;
    }

    return ProceduralMaterializationError.none;
}


/++
    Materializes one non-empty logical request into a retained single-plane
    resident ubyte raster.

    The logical request is validated in logical-image coordinates.

    The resulting RasterLease always represents:

        Region2D(0, 0, request.width, request.height)

    Pixel values are generated from the original logical coordinates and
    written through the public WritableRasterView semantic API.
+/
ProceduralMaterializationResult materializeProcedural(
    Region2D logicalExtent,
    Region2D request
)
@safe
{
    if (!logicalExtent.hasRepresentableExtent())
    {
        return failure(
            ProceduralMaterializationError.invalidLogicalExtent
        );
    }

    if (
        !request.hasRepresentableExtent()
        || request.empty()
    )
    {
        return failure(
            ProceduralMaterializationError.invalidRequest
        );
    }

    bool contained;

    if (!tryContainsAbsolute(
        logicalExtent,
        request,
        contained
    ))
    {
        /*
         * Both inputs were explicitly checked above.
         * Reaching this branch would contradict the E3.1.1 contract.
         */
        return failure(
            ProceduralMaterializationError.internalFailure
        );
    }

    if (!contained)
    {
        return failure(
            ProceduralMaterializationError.requestOutsideLogicalExtent
        );
    }

    if (
        request.width != 0
        && request.height
            > size_t.max / request.width
    )
    {
        return failure(
            ProceduralMaterializationError.sampleCountOverflow
        );
    }

    const sampleCount =
        request.width * request.height;

    assert(sampleCount != 0);

    /*
     * The imported resident raster is contiguous:
     *
     *     rowStride = request.width
     *     sampleStride = 1
     *
     * PlaneByteLayout stores signed strides, and the backing validator later
     * proves coordinate/stride products in ptrdiff_t.
     *
     * Reject unsupported resident layouts explicitly here rather than relying
     * on a less specific downstream import error.
     */
    if (
        request.width
            > cast(size_t) ptrdiff_t.max
        || sampleCount - 1
            > cast(size_t) ptrdiff_t.max
    )
    {
        return failure(
            ProceduralMaterializationError
                .residentLayoutNotRepresentable
        );
    }

    OwnedByteResource resource;

    const allocationError =
        tryAllocateOwnedBytes(
            sampleCount,
            resource
        );

    if (
        allocationError
        != ProceduralMaterializationError.none
    )
    {
        return failure(
            allocationError
        );
    }

    assert(resource.ownsResource);
    assert(resource.byteLength == sampleCount);

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t) request.width,
            1
        )
    ];

    const residentRegion =
        Region2D(
            0,
            0,
            request.width,
            request.height
        );

    RasterLease!ubyte lease;

    const importResult =
        tryImportOwnedRaster!ubyte(
            resource,
            layouts[],
            residentRegion,
            lease
        );

    if (!importResult.ok)
    {
        return failure(
            ProceduralMaterializationError.importFailed,
            importResult.error
        );
    }

    assert(!resource.ownsResource);

    bool writableSuccess;

    {
        scope auto writable =
            lease.tryWritableView(
                writableSuccess
            );

        if (!writableSuccess)
        {
            return failure(
                ProceduralMaterializationError
                    .writableBorrowFailed
            );
        }

        if (writable.region != residentRegion)
        {
            return failure(
                ProceduralMaterializationError.internalFailure
            );
        }

        foreach (localY; 0 .. request.height)
        {
            /*
             * request representability proves this addition cannot overflow.
             */
            const logicalY =
                request.y + localY;

            foreach (localX; 0 .. request.width)
            {
                const logicalX =
                    request.x + localX;

                if (!writable.trySetSample(
                    0,
                    localX,
                    localY,
                    proceduralValue(
                        logicalX,
                        logicalY
                    )
                ))
                {
                    return failure(
                        ProceduralMaterializationError
                            .sampleWriteFailed
                    );
                }
            }
        }
    }

    /*
     * The writable borrow has ended before the retained lease is moved into
     * the result.
     */
    ProceduralMaterializationResult result;

    result.error =
        ProceduralMaterializationError.none;

    result.importError =
        OwnedRasterImportError.none;

    result.materialized.logicalRequest =
        request;

    result.materialized.residentBytes =
        sampleCount;

    result.materialized.lease =
        move(lease);

    return result;
}


/*
 * The procedural function is deterministic and remains safe at maximum
 * size_t coordinates.
 */
unittest
{
    assert(
        proceduralValue(0, 0)
        == 37
    );

    const reducedMax =
        size_t.max % 251;

    assert(
        proceduralValue(
            size_t.max,
            size_t.max
        )
        ==
        proceduralValue(
            reducedMax,
            reducedMax
        )
    );
}


/*
 * A non-zero logical origin is preserved in generated pixels while the
 * resident RasterView itself starts at descriptor-space (0, 0).
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

    const request =
        Region2D(
            1733,
            911,
            17,
            13
        );

    auto result =
        materializeProcedural(
            logicalExtent,
            request
        );

    assert(result.ok);

    assert(
        result.error
        == ProceduralMaterializationError.none
    );

    assert(
        result.materialized.logicalRequest
        == request
    );

    assert(
        result.materialized.residentBytes
        == request.width * request.height
    );

    scope auto view =
        result.materialized.lease.view();

    assert(
        view.region
        == Region2D(
            0,
            0,
            request.width,
            request.height
        )
    );

    assert(view.planeCount == 1);

    ubyte residentOrigin;

    assert(
        view.trySample(
            0,
            0,
            0,
            residentOrigin
        )
    );

    assert(
        residentOrigin
        == proceduralValue(
            request.x,
            request.y
        )
    );

    /*
     * This fixture deliberately proves that resident local (0, 0) was not
     * mistaken for logical/global (0, 0).
     */
    assert(
        residentOrigin
        != proceduralValue(0, 0)
    );

    foreach (localY; 0 .. request.height)
    {
        foreach (localX; 0 .. request.width)
        {
            ubyte value;

            assert(
                view.trySample(
                    0,
                    localX,
                    localY,
                    value
                )
            );

            assert(
                value
                ==
                proceduralValue(
                    request.x + localX,
                    request.y + localY
                )
            );
        }
    }
}


/*
 * A very large logical image requires only request-sized resident storage.
 *
 * This test does not allocate storage proportional to the logical extent.
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

    const request =
        Region2D(
            900_003,
            800_007,
            7,
            5
        );

    auto result =
        materializeProcedural(
            logicalExtent,
            request
        );

    assert(result.ok);

    assert(
        result.materialized.residentBytes
        == 35
    );

    assert(
        logicalExtent.width
        > request.width * 1000
    );

    assert(
        logicalExtent.height
        > request.height * 1000
    );

    scope auto view =
        result.materialized.lease.view();

    assert(
        view.region
        == Region2D(0, 0, 7, 5)
    );

    ubyte last;

    assert(
        view.trySample(
            0,
            6,
            4,
            last
        )
    );

    assert(
        last
        ==
        proceduralValue(
            request.x + 6,
            request.y + 4
        )
    );
}


/*
 * Empty requests are a no-op at the streaming layer and are not
 * materialized.
 */
unittest
{
    const result =
        materializeProcedural(
            Region2D(0, 0, 100, 100),
            Region2D(10, 20, 0, 5)
        );

    assert(!result.ok);

    assert(
        result.error
        == ProceduralMaterializationError.invalidRequest
    );
}


/*
 * Requests outside the logical extent are rejected rather than clipped.
 */
unittest
{
    const result =
        materializeProcedural(
            Region2D(100, 200, 30, 40),
            Region2D(99, 210, 5, 5)
        );

    assert(!result.ok);

    assert(
        result.error
        ==
        ProceduralMaterializationError
            .requestOutsideLogicalExtent
    );
}


/*
 * Invalid logical and request geometry remain distinguishable.
 */
unittest
{
    const invalid =
        Region2D(
            size_t.max,
            0,
            1,
            1
        );

    auto result =
        materializeProcedural(
            invalid,
            Region2D(0, 0, 1, 1)
        );

    assert(!result.ok);

    assert(
        result.error
        ==
        ProceduralMaterializationError
            .invalidLogicalExtent
    );


    result =
        materializeProcedural(
            Region2D(
                0,
                0,
                size_t.max,
                2
            ),
            invalid
        );

    assert(!result.ok);

    assert(
        result.error
        ==
        ProceduralMaterializationError
            .invalidRequest
    );
}


/*
 * Pixel-count overflow is rejected before allocation.
 */
unittest
{
    const huge =
        Region2D(
            0,
            0,
            size_t.max,
            2
        );

    assert(huge.hasRepresentableExtent());

    const result =
        materializeProcedural(
            huge,
            huge
        );

    assert(!result.ok);

    assert(
        result.error
        ==
        ProceduralMaterializationError
            .sampleCountOverflow
    );
}


/*
 * A request whose contiguous row stride cannot be represented as ptrdiff_t is
 * rejected explicitly before allocation/import.
 */
unittest
{
    static if (
        size_t.max
        > cast(size_t) ptrdiff_t.max
    )
    {
        const width =
            cast(size_t) ptrdiff_t.max
            + 1;

        const huge =
            Region2D(
                0,
                0,
                width,
                1
            );

        assert(huge.hasRepresentableExtent());

        const result =
            materializeProcedural(
                huge,
                huge
            );

        assert(!result.ok);

        assert(
            result.error
            ==
            ProceduralMaterializationError
                .residentLayoutNotRepresentable
        );
    }
}
