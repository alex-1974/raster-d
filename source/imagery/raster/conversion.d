/++
    Public exact raster conversion operations.

    This module exposes semantic conversion behavior only.

    Execution layouts, Mir adapters, contiguous targets, physical-range
    classifiers and checked-wide relation machinery remain internal.
+/
module imagery.raster.conversion;

import imagery.raster.internal.conversion_dispatch :
    ExactUbyteToFloatRasterError,
    convertUbyteToFloatRasterPlane;

import imagery.raster.view :
    RasterView;

import imagery.raster.writable_view :
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


static assert(
    UbyteToFloatConversionError.init
    == UbyteToFloatConversionError.none
);


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


version (unittest)
{

import imagery.raster.descriptor :
    PlaneDescriptor;

import imagery.raster.region :
    Region2D;

import imagery.raster.resource :
    ResourceAccess,
    ResourceEntry;

import imagery.raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import imagery.raster.view :
    makeRasterViewAssumeValidated;

import imagery.raster.writable_view :
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

} // version (unittest)
