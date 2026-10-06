/++
    v0.2 allocating point-transform convenience API.

    The caller-controlled transformInto() operation remains the fundamental
    performance-oriented primitive. This module adds an explicit allocating
    convenience that materializes one selected source plane into a newly owned
    compact one-plane RasterLease.

    The retained owner type is RasterLease until the designed v0.2 Raster!T
    owner is promoted to production. No second storage/lifetime architecture
    is introduced.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.transform_allocated;

import core.stdc.stdlib :
    free,
    malloc;

import std.algorithm.mutation :
    move;

import raster.backing :
    RasterLease;

import raster.byte_layout :
    PlaneByteLayout;

import raster.construction :
    constructRetainedRaster;

import raster.descriptor :
    PlaneDescriptor;

import raster.import_owned :
    tryImportOwnedRaster;

import raster.internal.compact_allocation :
    CompactAllocationError,
    allocateCompactRaster;

import raster.owned_resource :
    OwnedByteResource,
    tryAdoptMallocResource;

import raster.region :
    Region2D;

import raster.resource :
    ResourceEntry;

import raster.sample :
    isRasterSampleType;

import raster.transform :
    RasterTransformError;

import raster.transform_into :
    transformInto;

import raster.view :
    RasterView;


/++
    Failure category for tryTransformAllocated().

    The default state is deliberately a failure.
+/
enum RasterAllocatedTransformError : ubyte
{
    none,

    invalidSourcePlane,

    sizeOverflow,

    allocationFailed,

    backingConstructionFailed,

    writableDestinationUnavailable,

    transformFailed,

    internalFailure
}


/// Example inspecting the default allocating-transform error state.
@safe unittest
{
    import raster;

    assert(
        RasterAllocatedTransformError.init
        == RasterAllocatedTransformError.none
    );
}


/++
    Result carrier for one allocating transform.

    On success this object retains an independently owned one-plane RasterLease.
    Calling lease() returns another O(1) retained owner copy.

    The eventual v0.2 Raster!T owner can replace this transitional payload
    without changing transformInto(), which remains the semantic execution
    primitive.
+/
struct RasterAllocatedTransformResult(T)
{
    static assert(
        isRasterSampleType!T,
        "Allocating transform requires a valid raster sample type."
    );

private:
    RasterAllocatedTransformError error_ =
        RasterAllocatedTransformError.internalFailure;

    RasterTransformError transformError_ =
        RasterTransformError.none;

    RasterLease!T lease_;


public:
    /++
        Whether allocation, retained construction and transform all succeeded.
    +/
    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_ == RasterAllocatedTransformError.none;
    }


    /++
        High-level failure category.
    +/
    @property
    RasterAllocatedTransformError error() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_;
    }


    /++
        Underlying transformInto() failure when error == transformFailed.

        Returns RasterTransformError.none for all other states.
    +/
    @property
    RasterTransformError transformError() const
    @safe
    pure
    nothrow
    @nogc
    {
        return transformError_;
    }


    /++
        Returns an O(1) retained copy of the successful output owner.

        Failure returns RasterLease!T.init.
    +/
    RasterLease!T lease()
    @safe
    {
        if (!ok)
            return RasterLease!T.init;

        return lease_;
    }
}


/// Example inspecting the deliberately failing default result.
@safe unittest
{
    import raster;

    RasterAllocatedTransformResult!ubyte result;

    assert(!result.ok);

    assert(
        result.error
        == RasterAllocatedTransformError.internalFailure
    );

    assert(
        result.transformError
        == RasterTransformError.none
    );

    assert(result.lease().view().planeCount == 0);
}


/++
    Allocates a new compact one-plane raster and applies one compile-time
    same-type point transform into it.

    Allocation is explicit in both the function name and result type.

    The selected source plane is the semantic input. The successful output:

    - has the same sample type T;
    - has width/height equal to source;
    - has resident origin (0,0);
    - contains exactly one logical plane;
    - uses newly owned compact row-major storage;
    - is writable through the ordinary retained writable-certification path;
    - does not alias source storage.

    Matching zero-area source geometry succeeds without pixel allocation. A
    metadata-only retained one-plane owner is produced and transform is not
    invoked.

    The operation is deliberately a convenience/materialization layer:

        validate selected source plane
            -> allocate compact retained destination
            -> obtain writable destination view
            -> transformInto!transform(...)

    It contains no second transform kernel.

    transformInto() remains the performance-oriented primitive when callers
    already own or want to reuse destination storage.

    The transform alias must satisfy the same compile-time contract as
    transformInto():

        @safe pure nothrow @nogc T -> T

    Allocation and retained-owner construction are fallible. Error-level runtime
    allocation failure inside the existing SafeRefCounted owner remains governed
    by the backing layer's existing contract.
+/
RasterAllocatedTransformResult!T tryTransformAllocated(alias transform, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex
)
@safe
{
    RasterAllocatedTransformResult!T result;

    if (
        sourcePlaneIndex
        >= source.planeCount
    )
    {
        result.error_ =
            RasterAllocatedTransformError.invalidSourcePlane;

        return result;
    }

    auto allocated =
        allocateCompactRaster!T(
            source.width,
            source.height
        );

    final switch (allocated.error)
    {
        case CompactAllocationError.none:
            break;

        case CompactAllocationError.sizeOverflow:
            result.error_ =
                RasterAllocatedTransformError.sizeOverflow;
            return result;

        case CompactAllocationError.allocationFailed:
            result.error_ =
                RasterAllocatedTransformError.allocationFailed;
            return result;

        case CompactAllocationError.backingConstructionFailed:
            result.error_ =
                RasterAllocatedTransformError.backingConstructionFailed;
            return result;

        case CompactAllocationError.internalFailure:
            result.error_ =
                RasterAllocatedTransformError.internalFailure;
            return result;
    }

    bool writableOk;

    scope auto destination =
        allocated.lease.tryWritableView(
            writableOk
        );

    if (!writableOk)
    {
        result.error_ =
            RasterAllocatedTransformError.writableDestinationUnavailable;

        return result;
    }

    RasterTransformError transformError;

    if (
        !source.transformInto!transform(
            sourcePlaneIndex,
            destination,
            0,
            transformError
        )
    )
    {
        result.error_ =
            RasterAllocatedTransformError.transformFailed;

        result.transformError_ =
            transformError;

        return result;
    }

    result.error_ =
        RasterAllocatedTransformError.none;

    result.lease_ =
        move(allocated.lease);

    return result;
}


/// Example using the allocating convenience through UFCS.
@safe unittest
{
    import raster;

    alias plusOne =
        (float value)
        @safe pure nothrow @nogc
        => value + 1.0f;

    RasterView!float source;

    const result =
        source.tryTransformAllocated!plusOne(
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == RasterAllocatedTransformError.invalidSourcePlane
    );
}


version (unittest)
{

import raster.descriptor :
    PlaneDescriptor;

import raster.view :
    makeRasterViewAssumeValidated;


@safe
pure
nothrow
@nogc
private
ubyte incrementByte(
    ubyte value
)
{
    return cast(ubyte)(value + 1);
}


@safe
pure
nothrow
@nogc
private
float addTen(
    float value
)
{
    return value + 10.0f;
}


/*
 * Compact result preserves semantic values while normalizing resident origin
 * and materializing independent writable storage.
 */
@system
unittest
{
    float[8] sourceStorage =
        [1, 99, 2, 99, 3, 99, 4, 99];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr + 6,
            -4,
            -2
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            descriptors[],
            Region2D(
                0,
                0,
                2,
                2
            )
        );

    auto result =
        source.tryTransformAllocated!addTen(
            0
        );

    assert(result.ok);
    assert(result.error == RasterAllocatedTransformError.none);

    auto outputLease =
        result.lease();

    scope auto output =
        outputLease.view();

    assert(output.planeCount == 1);
    assert(output.region == Region2D(0, 0, 2, 2));

    float value;

    assert(output.trySample(0, 0, 0, value));
    assert(value == 14.0f);

    assert(output.trySample(0, 1, 0, value));
    assert(value == 13.0f);

    assert(output.trySample(0, 0, 1, value));
    assert(value == 12.0f);

    assert(output.trySample(0, 1, 1, value));
    assert(value == 11.0f);

    /*
     * Result storage is independently writable.
     */
    bool writableOk;

    scope auto writable =
        outputLease.tryWritableView(
            writableOk
        );

    assert(writableOk);

    assert(
        writable.trySetSample(
            0,
            0,
            0,
            123.0f
        )
    );

    assert(sourceStorage[6] == 4.0f);
}


/*
 * Zero-area input creates a real retained one-plane empty result without pixel
 * allocation or transform invocation.
 */
@system
unittest
{
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            null,
            0,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(
                0,
                0,
                0,
                3
            )
        );

    auto result =
        source.tryTransformAllocated!incrementByte(
            0
        );

    assert(result.ok);

    auto outputLease =
        result.lease();

    scope auto output =
        outputLease.view();

    assert(output.planeCount == 1);
    assert(output.width == 0);
    assert(output.height == 3);
    assert(output.empty);

    bool writableOk;

    scope auto writable =
        outputLease.tryWritableView(
            writableOk
        );

    assert(writableOk);
    assert(writable.planeCount == 1);
    assert(writable.empty);
}


/*
 * Invalid source plane fails before allocating a result owner.
 */
@safe
unittest
{
    RasterView!ubyte source;

    auto result =
        source.tryTransformAllocated!incrementByte(
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == RasterAllocatedTransformError.invalidSourcePlane
    );

    assert(result.lease().view().planeCount == 0);
}

} // version (unittest)
