/++
    Public exact raster conversion operations.

    This module exposes semantic conversion behavior only.

    Execution layouts, Mir adapters, contiguous targets, physical-range
    classifiers and checked-wide relation machinery remain internal.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-05
+/
module raster.conversion;

import raster.internal.conversion_dispatch :
    ExactUbyteToFloatRasterError,
    convertUbyteToFloatRasterPlane;

import raster.internal.conversion_policy :
    isUniversallyExactRasterConversion;

import raster.internal.exact_conversion :
    ExactRasterConversionError,
    convertExactRasterPlane;

import raster.conversion_policy :
    RasterConversionPolicy;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


/++
    Semantic failure category for `tryConvertUbyteToFloatPlane`.

    `.none` means that no semantic request failure occurred.

    Execution coverage and arithmetic-carrier limitations are not public
    failures.
+/
enum UbyteToFloatConversionError : ubyte
{
    none,

    invalidSourcePlane,

    invalidDestinationPlane,

    shapeMismatch,

    nonInjectiveDestination,

    sourceDestinationOverlap
}

/// Example using the exact-conversion error category.
@safe unittest
{
    import raster;
    assert(UbyteToFloatConversionError.init == UbyteToFloatConversionError.none);
}



static assert(
    UbyteToFloatConversionError.init
    == UbyteToFloatConversionError.none
);


static assert(
    isUniversallyExactRasterConversion!(
        ubyte,
        float
    )
);


/++
    Semantic failure category for generic destination-oriented raster
    conversion.

    The exact policy has no per-sample numerical failure. Therefore every false
    result is a structural/request failure detected before the first
    destination write.
+/
enum RasterConversionError : ubyte
{
    none,

    invalidSourcePlane,

    invalidDestinationPlane,

    shapeMismatch,

    nonInjectiveDestination,

    sourceDestinationOverlap
}


/++
    Converts one selected logical source plane into an equally shaped writable
    destination plane under one explicit conversion policy.

    The first v0.2 production policy is RasterConversionPolicy.exact.

    Ordinary form:

        convertRasterInto!(
            float,
            RasterConversionPolicy.exact
        )(
            source,
            sourcePlaneIndex,
            destination,
            destinationPlaneIndex,
            error
        );

    UFCS form:

        source.convertRasterInto!(
            float,
            RasterConversionPolicy.exact
        )(
            sourcePlaneIndex,
            destination,
            destinationPlaneIndex,
            error
        );

    Because exact is currently the only promoted policy it is also the template
    default:

        source.convertRasterInto!float(...);

    Exact-policy type legality is compile-time. Unsupported From -> To pairs do
    not instantiate this API.

    Structural semantics:

    - source and destination plane indices must be valid;
    - shapes must match;
    - matching empty shapes succeed as a no-op;
    - destination mapping must be injective;
    - actual source/destination sample-byte overlap is rejected;
    - every structural failure is resolved before the first destination write;
    - every validated resident signed affine layout is semantically supported;
    - source self-aliasing is permitted;
    - no allocation, ownership transfer or scheduling occurs.

    On entry error is reset to RasterConversionError.none. On false, destination
    content is unchanged and error identifies the structural failure.
+/
bool convertRasterInto(
    To,
    RasterConversionPolicy Policy = RasterConversionPolicy.exact,
    From
)(
    scope RasterView!From source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!To destination,
    size_t destinationPlaneIndex,

    out RasterConversionError error
)
@safe
nothrow
@nogc
if (
    Policy == RasterConversionPolicy.exact
    && isUniversallyExactRasterConversion!(
        From,
        To
    )
)
{
    error =
        RasterConversionError.none;

    final switch (
        convertExactRasterPlane!(
            From,
            To
        )(
            source,
            sourcePlaneIndex,
            destination,
            destinationPlaneIndex
        )
    )
    {
        case ExactRasterConversionError.none:
            return true;

        case ExactRasterConversionError.invalidSourcePlane:
            error =
                RasterConversionError.invalidSourcePlane;
            return false;

        case ExactRasterConversionError.invalidDestinationPlane:
            error =
                RasterConversionError.invalidDestinationPlane;
            return false;

        case ExactRasterConversionError.shapeMismatch:
            error =
                RasterConversionError.shapeMismatch;
            return false;

        case ExactRasterConversionError.nonInjectiveDestination:
            error =
                RasterConversionError.nonInjectiveDestination;
            return false;

        case ExactRasterConversionError.sourceDestinationOverlap:
            error =
                RasterConversionError.sourceDestinationOverlap;
            return false;
    }
}


/// Example compiling the default exact-policy UFCS surface.
@safe unittest
{
    import raster;

    RasterView!ubyte source;
    WritableRasterView!float destination;
    RasterConversionError error;

    assert(
        !source.convertRasterInto!float(
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterConversionError.invalidSourcePlane
    );
}


/++
    Converts one logical `ubyte` source plane to one equally shaped writable
    `float` destination plane.

    Every successful destination sample is exactly:

        cast(float) sourceSample

    All 256 ubyte values are exactly representable in IEEE binary32, so this
    operation has no rounding, clamping, overflow, NaN or infinity policy.

    A matching empty source/destination shape succeeds as a no-op.

    The destination mapping must be injective.

    Source self-aliasing is permitted. Source and destination may share retained
    backing storage when their actually reachable sample bytes are disjoint.

    Actual source/destination sample-byte overlap is rejected before the first
    destination write.

    Returns true on success and false on a semantic request failure.

    `error` is reset to `UbyteToFloatConversionError.none` on entry. On false it
    identifies exactly one of:

    - invalid source plane;
    - invalid destination plane;
    - shape mismatch;
    - non-injective destination mapping;
    - actual source/destination sample-byte overlap.

    Every validated resident layout is semantically supported.

    The operation is allocation-free and retains neither operand.
+/
bool tryConvertUbyteToFloatPlane(
    scope RasterView!ubyte source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!float destination,
    size_t destinationPlaneIndex,

    out UbyteToFloatConversionError error
)
@safe
nothrow
@nogc
{
    error =
        UbyteToFloatConversionError.none;

    final switch (
        convertUbyteToFloatRasterPlane(
            source,
            sourcePlaneIndex,
            destination,
            destinationPlaneIndex
        )
    )
    {
        case ExactUbyteToFloatRasterError.none:
            return true;

        case ExactUbyteToFloatRasterError.invalidSourcePlane:
            error =
                UbyteToFloatConversionError.invalidSourcePlane;
            return false;

        case ExactUbyteToFloatRasterError.invalidDestinationPlane:
            error =
                UbyteToFloatConversionError.invalidDestinationPlane;
            return false;

        case ExactUbyteToFloatRasterError.shapeMismatch:
            error =
                UbyteToFloatConversionError.shapeMismatch;
            return false;

        case ExactUbyteToFloatRasterError.nonInjectiveDestination:
            error =
                UbyteToFloatConversionError.nonInjectiveDestination;
            return false;

        case ExactUbyteToFloatRasterError.sourceDestinationOverlap:
            error =
                UbyteToFloatConversionError.sourceDestinationOverlap;
            return false;
    }
}

/// Example reporting an invalid source plane before conversion.
@safe unittest
{
    import raster;
    RasterView!ubyte source;
    WritableRasterView!float destination;
    UbyteToFloatConversionError error;
    assert(!tryConvertUbyteToFloatPlane(source, 0, destination, 0, error));
    assert(error == UbyteToFloatConversionError.invalidSourcePlane);
}



version (unittest)
{

import raster.descriptor :
    PlaneDescriptor;

import raster.region :
    Region2D;

import raster.resource :
    ResourceAccess,
    ResourceEntry;

import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import raster.view :
    makeRasterViewAssumeValidated;

import raster.writable_view :
    tryMakeWritableRasterView;


private
WritableRasterView!float makeWritableFloatTestView(
    return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,
    Region2D region
)
@safe
nothrow
@nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto result =
        tryMakeWritableRasterView!float(
            resources,
            descriptors,
            region,
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    return result;
}


/*
 * Contiguous public path converts the complete ubyte domain exactly.
 */
unittest
{
    ubyte[256] sourceStorage;
    float[256] destinationStorage;

    foreach (i; 0 .. sourceStorage.length)
    {
        sourceStorage[i] =
            cast(ubyte) i;
    }

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            256,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            256,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 256, 1)
        );

    scope auto destination =
        makeWritableFloatTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 256, 1)
        );

    UbyteToFloatConversionError error;

    assert(
        tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == UbyteToFloatConversionError.none);

    foreach (i; 0 .. sourceStorage.length)
    {
        assert(
            destinationStorage[i]
            == cast(float) sourceStorage[i]
        );
    }
}


/*
 * Invalid source plane is reported semantically.
 */
unittest
{
    RasterView!ubyte source;
    WritableRasterView!float destination;

    UbyteToFloatConversionError error;

    assert(
        !tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == UbyteToFloatConversionError.invalidSourcePlane
    );
}


/*
 * Invalid destination plane is distinct from invalid source.
 */
unittest
{
    ubyte[1] sourceStorage = [9];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            1,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    WritableRasterView!float destination;

    UbyteToFloatConversionError error;

    assert(
        !tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == UbyteToFloatConversionError.invalidDestinationPlane
    );
}


/*
 * Shape mismatch fails before the first destination write.
 */
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    float[4] destinationStorage =
        [91.0f, 92.0f, 93.0f, 94.0f];

    const expected =
        destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            2,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableFloatTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 2)
        );

    UbyteToFloatConversionError error;

    assert(
        !tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == UbyteToFloatConversionError.shapeMismatch
    );

    assert(destinationStorage == expected);
}


/*
 * Non-injective destination fails before writing.
 */
unittest
{
    ubyte[2] sourceStorage =
        [5, 6];

    float[1] destinationStorage =
        [71.0f];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            0,
            0
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto destination =
        makeWritableFloatTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    UbyteToFloatConversionError error;

    assert(
        !tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == UbyteToFloatConversionError.nonInjectiveDestination
    );

    assert(destinationStorage[0] == 71.0f);
}


/*
 * Actual source/destination byte overlap is rejected before writing.
 */
unittest
{
    union Storage
    {
        ubyte[16] bytes;
        float[4] floats;
    }

    Storage storage;

    storage.bytes[3] = 77;

    const expected =
        storage.bytes;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.bytes.ptr + 3,
            0,
            0
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            storage.floats.ptr,
            0,
            0
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            storage.bytes.ptr,
            storage.bytes.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    scope auto destination =
        makeWritableFloatTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    UbyteToFloatConversionError error;

    assert(
        !tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == UbyteToFloatConversionError.sourceDestinationOverlap
    );

    assert(storage.bytes == expected);
}


/*
 * Matching empty shapes succeed as a no-op.
 */
unittest
{
    ubyte[1] sourceStorage = [7];
    float[1] destinationStorage = [33.0f];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            1,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            1,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 0, 1)
        );

    scope auto destination =
        makeWritableFloatTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 0, 1)
        );

    UbyteToFloatConversionError error =
        UbyteToFloatConversionError.shapeMismatch;

    assert(
        tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == UbyteToFloatConversionError.none);
    assert(destinationStorage[0] == 33.0f);
}


/*
 * Shared retained backing is permitted when reachable source bytes and
 * destination float sample bytes are disjoint.
 */
unittest
{
    union Storage
    {
        ubyte[32] bytes;
        float[8] floats;
    }

    Storage storage;

    storage.bytes[16 .. 20] =
        [10, 20, 30, 40];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.bytes.ptr + 16,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            storage.floats.ptr,
            2,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            storage.bytes.ptr,
            storage.bytes.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableFloatTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    UbyteToFloatConversionError error;

    assert(
        tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == UbyteToFloatConversionError.none);

    assert(storage.floats[0] == 10.0f);
    assert(storage.floats[1] == 20.0f);
    assert(storage.floats[2] == 30.0f);
    assert(storage.floats[3] == 40.0f);

    assert(
        storage.bytes[16 .. 20]
        == [10, 20, 30, 40]
    );
}


/*
 * Valid negative destination strides are supported through the affine path.
 */
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    float[4] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr + 3,
            -2,
            -1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableFloatTestView(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    UbyteToFloatConversionError error;

    assert(
        tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == UbyteToFloatConversionError.none);

    assert(
        destinationStorage
        == [4.0f, 3.0f, 2.0f, 1.0f]
    );
}



private
WritableRasterView!To makeWritableConversionTestView(To)(
    return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,
    Region2D region
)
@safe
nothrow
@nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto result =
        tryMakeWritableRasterView!To(
            resources,
            descriptors,
            region,
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    return result;
}


/*
 * Generic default exact policy reuses the qualified ubyte -> float semantic.
 */
unittest
{
    ubyte[4] sourceStorage =
        [0, 17, 128, 255];

    float[4] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            4,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            4,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 4, 1)
        );

    scope auto destination =
        makeWritableConversionTestView!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 4, 1)
        );

    RasterConversionError error;

    assert(
        source.convertRasterInto!float(
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterConversionError.none);

    assert(
        destinationStorage
        == [0.0f, 17.0f, 128.0f, 255.0f]
    );
}


/*
 * Explicit exact policy and integer widening work over signed affine layouts.
 */
unittest
{
    ushort[8] sourceStorage =
        [1, 99, 2, 99, 3, 99, 4, 99];

    int[4] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr + 6,
            -4,
            -2
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr + 3,
            -2,
            -1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * int.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ushort(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableConversionTestView!int(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterConversionError error;

    assert(
        source.convertRasterInto!(
            int,
            RasterConversionPolicy.exact
        )(
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterConversionError.none);
    assert(destinationStorage == [4, 3, 2, 1]);
}


/*
 * float -> double preserves finite values, infinities and NaN-ness exactly
 * under the promoted policy.
 */
unittest
{
    float[4] sourceStorage =
        [
            -0.0f,
            1.5f,
            float.infinity,
            float.nan
        ];

    double[4] destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            4,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            4,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * double.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(0, 0, 4, 1)
        );

    scope auto destination =
        makeWritableConversionTestView!double(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 4, 1)
        );

    RasterConversionError error;

    assert(
        source.convertRasterInto!double(
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterConversionError.none);
    assert(destinationStorage[0] == 0.0);
    assert(destinationStorage[1] == 1.5);
    assert(destinationStorage[2] == double.infinity);
    assert(destinationStorage[3] != destinationStorage[3]);
}


/*
 * Shape failure leaves the destination unchanged.
 */
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    float[4] destinationStorage =
        [11.0f, 12.0f, 13.0f, 14.0f];

    const expected =
        destinationStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            2,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableConversionTestView!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 2)
        );

    RasterConversionError error;

    assert(
        !source.convertRasterInto!float(
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterConversionError.shapeMismatch);
    assert(destinationStorage == expected);
}


/*
 * Actual byte overlap is rejected before writing for a generic different-size
 * exact pair, not only for the historical ubyte -> float specialization.
 */
unittest
{
    union Storage
    {
        ubyte[32] bytes;
        uint[8] words;
    }

    Storage storage;
    storage.bytes[3] = 77;

    const expected =
        storage.bytes;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.bytes.ptr + 3,
            0,
            0
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            storage.words.ptr,
            0,
            0
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            storage.bytes.ptr,
            storage.bytes.length,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    scope auto destination =
        makeWritableConversionTestView!uint(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    RasterConversionError error;

    assert(
        !source.convertRasterInto!uint(
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterConversionError.sourceDestinationOverlap
    );

    assert(storage.bytes == expected);
}


/*
 * Matching empty shapes succeed without touching destination storage.
 */
unittest
{
    short[1] sourceStorage = [7];
    double[1] destinationStorage = [33.0];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            1,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            1,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * double.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!short(
            sourceDescriptors[],
            Region2D(0, 0, 0, 1)
        );

    scope auto destination =
        makeWritableConversionTestView!double(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 0, 1)
        );

    RasterConversionError error =
        RasterConversionError.shapeMismatch;

    assert(
        source.convertRasterInto!double(
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterConversionError.none);
    assert(destinationStorage[0] == 33.0);
}


/*
 * Public compile constraints: accepted and rejected type pairs are semantic
 * compatibility surface.
 */
static assert(
    isUniversallyExactRasterConversion!(
        ubyte,
        float
    )
);

static assert(
    isUniversallyExactRasterConversion!(
        ushort,
        int
    )
);

static assert(
    isUniversallyExactRasterConversion!(
        float,
        double
    )
);

static assert(
    !isUniversallyExactRasterConversion!(
        int,
        float
    )
);

static assert(
    !isUniversallyExactRasterConversion!(
        long,
        double
    )
);

static assert(
    !isUniversallyExactRasterConversion!(
        double,
        float
    )
);

static assert(
    !isUniversallyExactRasterConversion!(
        float,
        int
    )
);

} // version (unittest)
