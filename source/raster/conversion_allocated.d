/++
    v0.2 allocating raster conversion convenience API.

    The caller-controlled convertRasterInto() operation remains the fundamental
    destination-oriented primitive. This module adds explicit allocation and
    materializes one selected source plane into a newly owned compact one-plane
    RasterLease!To.

    RasterLease is the retained owner used by the v0.2 public contract.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.conversion_allocated;

import std.algorithm.mutation :
    move;

import raster.backing :
    RasterLease;

import raster.conversion :
    RasterConversionError,
    convertRasterInto;

import raster.conversion_policy :
    RasterConversionPolicy;

import raster.internal.compact_allocation :
    CompactAllocationError,
    allocateCompactRaster;

import raster.internal.conversion_policy :
    isUniversallyExactRasterConversion;

import raster.view :
    RasterView;


/++
    Failure category for allocating raster conversion.

    The default state is deliberately a failure.
+/
enum RasterAllocatedConversionError : ubyte
{
    none,

    invalidSourcePlane,

    sizeOverflow,

    allocationFailed,

    backingConstructionFailed,

    writableDestinationUnavailable,

    conversionFailed,

    internalFailure
}

/// Example inspecting the allocating-conversion error categories.
@safe unittest
{
    import raster;
    assert(RasterAllocatedConversionError.init == RasterAllocatedConversionError.none);
    assert(RasterAllocatedConversionError.invalidSourcePlane != RasterAllocatedConversionError.none);
}



/++
    Result carrier for one allocating conversion.

    On success lease() returns an O(1) retained copy of a newly owned compact
    one-plane RasterLease!To.

    conversionError is meaningful only when error == conversionFailed.
+/
struct RasterAllocatedConversionResult(To)
{
private:
    RasterAllocatedConversionError error_ =
        RasterAllocatedConversionError.internalFailure;

    RasterConversionError conversionError_ =
        RasterConversionError.none;

    RasterLease!To lease_;


public:

    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_
            == RasterAllocatedConversionError.none;
    }


    @property
    RasterAllocatedConversionError error() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_;
    }


    @property
    RasterConversionError conversionError() const
    @safe
    pure
    nothrow
    @nogc
    {
        return conversionError_;
    }


    RasterLease!To lease()
    @safe
    {
        if (!ok)
            return RasterLease!To.init;

        return lease_;
    }
}

/// Example inspecting the deliberately failing default conversion result.
@safe unittest
{
    import raster;
    RasterAllocatedConversionResult!float result;
    assert(!result.ok);
    assert(result.error == RasterAllocatedConversionError.internalFailure);
    assert(result.conversionError == RasterConversionError.none);
    assert(result.lease().view().empty);
}



/++
    Allocates one compact one-plane To raster and converts one selected source
    plane into it.

    The conversion semantic is exactly convertRasterInto!(To, Policy).

    Policy defaults to RasterConversionPolicy.exact, the only policy promoted
    by M3.5.

    Successful output:

    - sample type To;
    - width/height equal to source;
    - resident origin (0,0);
    - exactly one logical plane;
    - compact sample stride 1 / row stride width;
    - independently owned writable storage;
    - no alias with source storage.

    A matching zero-area source creates a retained metadata-only one-plane
    result without pixel allocation.

    Failure sequence:

    1. invalid source plane;
    2. destination size/allocation/backing construction;
    3. writable destination capability;
    4. convertRasterInto structural failure.

    The function contains no conversion loop. All sample semantics are delegated
    to convertRasterInto().

    The destination-oriented API remains preferable when callers already own or
    wish to reuse destination storage.
+/
RasterAllocatedConversionResult!To tryConvertAllocated(
    To,
    RasterConversionPolicy Policy = RasterConversionPolicy.exact,
    From
)(
    scope RasterView!From source,
    size_t sourcePlaneIndex
)
@safe
if (
    Policy == RasterConversionPolicy.exact
    && isUniversallyExactRasterConversion!(
        From,
        To
    )
)
{
    RasterAllocatedConversionResult!To result;

    if (
        sourcePlaneIndex
        >= source.planeCount
    )
    {
        result.error_ =
            RasterAllocatedConversionError.invalidSourcePlane;

        return result;
    }

    auto allocated =
        allocateCompactRaster!To(
            source.width,
            source.height
        );

    final switch (allocated.error)
    {
        case CompactAllocationError.none:
            break;

        case CompactAllocationError.sizeOverflow:
            result.error_ =
                RasterAllocatedConversionError.sizeOverflow;
            return result;

        case CompactAllocationError.allocationFailed:
            result.error_ =
                RasterAllocatedConversionError.allocationFailed;
            return result;

        case CompactAllocationError.backingConstructionFailed:
            result.error_ =
                RasterAllocatedConversionError.backingConstructionFailed;
            return result;

        case CompactAllocationError.internalFailure:
            result.error_ =
                RasterAllocatedConversionError.internalFailure;
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
            RasterAllocatedConversionError
                .writableDestinationUnavailable;

        return result;
    }

    RasterConversionError conversionError;

    if (
        !source.convertRasterInto!(
            To,
            Policy
        )(
            sourcePlaneIndex,
            destination,
            0,
            conversionError
        )
    )
    {
        result.error_ =
            RasterAllocatedConversionError.conversionFailed;

        result.conversionError_ =
            conversionError;

        return result;
    }

    result.error_ =
        RasterAllocatedConversionError.none;

    result.lease_ =
        move(allocated.lease);

    return result;
}


/// Example using allocating exact conversion through UFCS.
@safe unittest
{
    import raster;

    RasterView!ubyte source;

    const result =
        source.tryConvertAllocated!float(
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == RasterAllocatedConversionError.invalidSourcePlane
    );
}


version (unittest)
{

import raster.descriptor :
    PlaneDescriptor;

import raster.region :
    Region2D;

import raster.view :
    makeRasterViewAssumeValidated;


/*
 * Signed-stride source converts into independent compact output.
 */
@system
unittest
{
    ushort[8] storage =
        [1, 99, 2, 99, 3, 99, 4, 99];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr + 6,
            -4,
            -2
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ushort(
            descriptors[],
            Region2D(0, 0, 2, 2)
        );

    auto result =
        source.tryConvertAllocated!int(
            0
        );

    assert(result.ok);

    auto outputLease =
        result.lease();

    scope auto output =
        outputLease.view();

    assert(output.planeCount == 1);
    assert(output.region == Region2D(0, 0, 2, 2));

    int value;

    assert(output.trySample(0, 0, 0, value));
    assert(value == 4);

    assert(output.trySample(0, 1, 0, value));
    assert(value == 3);

    assert(output.trySample(0, 0, 1, value));
    assert(value == 2);

    assert(output.trySample(0, 1, 1, value));
    assert(value == 1);

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
            123
        )
    );

    assert(storage[6] == 4);
}


/*
 * Existing ubyte -> float exact semantics flow through convertRasterInto.
 */
@system
unittest
{
    ubyte[4] storage =
        [0, 17, 128, 255];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            4,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(0, 0, 4, 1)
        );

    auto result =
        source.tryConvertAllocated!float(
            0
        );

    assert(result.ok);

    auto outputLease =
        result.lease();

    scope auto output =
        outputLease.view();

    float value;

    assert(output.trySample(0, 0, 0, value));
    assert(value == 0.0f);

    assert(output.trySample(0, 1, 0, value));
    assert(value == 17.0f);

    assert(output.trySample(0, 2, 0, value));
    assert(value == 128.0f);

    assert(output.trySample(0, 3, 0, value));
    assert(value == 255.0f);
}


/*
 * Zero-area input creates a real retained one-plane empty result without pixel
 * allocation.
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
        makeRasterViewAssumeValidated!short(
            descriptors[],
            Region2D(
                0,
                0,
                0,
                3
            )
        );

    auto result =
        source.tryConvertAllocated!double(
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
    assert(writable.empty);
}


/*
 * Invalid source plane fails before allocation.
 */
@safe
unittest
{
    RasterView!ubyte source;

    auto result =
        source.tryConvertAllocated!float(
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == RasterAllocatedConversionError.invalidSourcePlane
    );

    assert(result.lease().view().planeCount == 0);
}


/*
 * Explicit policy spelling matches the default exact semantic.
 */
@system
unittest
{
    byte[2] storage =
        [-1, 7];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            2,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!byte(
            descriptors[],
            Region2D(0, 0, 2, 1)
        );

    auto result =
        source.tryConvertAllocated!(
            short,
            RasterConversionPolicy.exact
        )(
            0
        );

    assert(result.ok);

    auto lease =
        result.lease();

    scope auto output =
        lease.view();

    short value;

    assert(output.trySample(0, 0, 0, value));
    assert(value == -1);

    assert(output.trySample(0, 1, 0, value));
    assert(value == 7);
}

} // version (unittest)
