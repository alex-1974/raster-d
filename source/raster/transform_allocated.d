/++
    v0.2 allocating point-transform convenience API.

    The caller-controlled transformInto() operation remains the fundamental
    performance-oriented primitive. This module adds an explicit allocating
    convenience that materializes one selected source plane into a newly owned
    compact one-plane RasterLease.

    The retained owner type for v0.2 is RasterLease. No second
    storage/lifetime architecture is introduced.

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

import raster.result :
    RasterResult;


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

    The result deliberately reuses RasterLease rather than introducing a
    second ownership type. transformInto() remains the semantic execution
    primitive.
+/
struct RasterAllocatedTransformFailure
{
    RasterAllocatedTransformError error;
    RasterTransformError transformError;
}

alias RasterAllocatedTransformResult(T) =
    RasterResult!(RasterLease!T, RasterAllocatedTransformFailure);


/// Example inspecting the deliberately failing default result.
@safe unittest
{
    import raster;

    RasterAllocatedTransformResult!ubyte result;

    assert(result.isEmpty);
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

    Allocation and retained-owner construction are fallible. Error-level
    failure while creating the retained owner remains governed by the backing
    layer's allocation contract.
+/
RasterAllocatedTransformResult!T tryTransformAllocated(alias transform, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex
)
@safe
{
    alias R = RasterAllocatedTransformResult!T;

    auto failure(RasterAllocatedTransformError error,
        RasterTransformError transformError = RasterTransformError.none)
    {
        return R.failure(RasterAllocatedTransformFailure(error, transformError));
    }

    if (
        sourcePlaneIndex
        >= source.planeCount
    )
    {
        return failure(RasterAllocatedTransformError.invalidSourcePlane);
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
            return failure(RasterAllocatedTransformError.sizeOverflow);

        case CompactAllocationError.allocationFailed:
            return failure(RasterAllocatedTransformError.allocationFailed);

        case CompactAllocationError.backingConstructionFailed:
            return failure(RasterAllocatedTransformError.backingConstructionFailed);

        case CompactAllocationError.internalFailure:
            return failure(RasterAllocatedTransformError.internalFailure);
    }

    bool writableOk;

    scope auto destination =
        allocated.lease.tryWritableView(
            writableOk
        );

    if (!writableOk)
    {
        return failure(RasterAllocatedTransformError.writableDestinationUnavailable);
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
        return failure(RasterAllocatedTransformError.transformFailed, transformError);
    }

    return R.success(move(allocated.lease));
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

    assert(result.hasError);

    assert(
        result.error().error
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

    assert(result.hasValue);

    auto outputLease =
        result.takeValue();

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

    assert(result.hasValue);

    auto outputLease =
        result.takeValue();

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

    assert(result.hasError);

    assert(
        result.error().error
        == RasterAllocatedTransformError.invalidSourcePlane
    );
}

} // version (unittest)
