/++
    v0.2 destination-oriented point transform API.

    This module promotes the already-qualified same-type compile-time point
    transform into the v0.2 naming/UFCS family without introducing a second
    execution engine.

    The existing tryTransformRasterPlane() API remains the v0.1 compatibility
    surface and authoritative semantic implementation.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.transform_into;

import raster.transform :
    RasterTransformError,
    tryTransformRasterPlane;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


/++
    Applies one compile-time same-type point transform from a selected source
    plane into a selected writable destination plane.

    This is the v0.2 destination-oriented spelling of the existing qualified
    point-transform semantic.

    The transform alias must be usable as:

        @safe pure nothrow @nogc T -> T

    source is deliberately the first runtime argument so the same free
    function supports ordinary-call and UFCS forms.

    Structural, aliasing, layout, empty-input and failure semantics are exactly
    those of tryTransformRasterPlane():

    - source and destination plane indices must be valid;
    - source and destination logical shapes must match;
    - matching empty shapes succeed without invoking transform;
    - destination mapping must be injective;
    - actual source/destination sample-byte overlap is rejected before writing;
    - every validated signed affine resident layout is supported;
    - structural failure occurs before the first destination write.

    The function allocates no storage, retains neither operand, performs no
    implicit conversion and adds no scheduling or execution-policy surface.

    The additional source/destination plane indices are a compatibility bridge
    while RasterPlaneView/WritableRasterPlaneView are not yet production types.
    A later plane-view overload may remove that plumbing without changing this
    semantic engine.
+/
bool transformInto(alias transform, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterTransformError error
)
@safe
nothrow
@nogc
{
    return tryTransformRasterPlane!transform(
        source,
        sourcePlaneIndex,
        destination,
        destinationPlaneIndex,
        error
    );
}


/// Example using the v0.2 transform name through UFCS.
@safe unittest
{
    import raster;

    alias plusOne =
        (float value)
        @safe pure nothrow @nogc
        => value + 1.0f;

    RasterView!float source;
    WritableRasterView!float destination;
    RasterTransformError error;

    assert(
        !source.transformInto!plusOne(
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterTransformError.invalidSourcePlane
    );
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


private
WritableRasterView!T makeWritableTransformIntoTestView(T)(
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
        tryMakeWritableRasterView!T(
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
 * Ordinary-call and UFCS forms are semantically identical on a contiguous
 * representative layout.
 */
@system
unittest
{
    float[6] sourceStorage =
        [1, 2, 3, 4, 5, 6];

    float[6] ordinaryStorage;
    float[6] ufcsStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            3,
            1
        )
    ];

    const PlaneDescriptor[1] ordinaryDescriptors =
    [
        PlaneDescriptor(
            ordinaryStorage.ptr,
            3,
            1
        )
    ];

    const PlaneDescriptor[1] ufcsDescriptors =
    [
        PlaneDescriptor(
            ufcsStorage.ptr,
            3,
            1
        )
    ];

    const ResourceEntry[1] ordinaryResources =
    [
        ResourceEntry(
            ordinaryStorage.ptr,
            ordinaryStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const ResourceEntry[1] ufcsResources =
    [
        ResourceEntry(
            ufcsStorage.ptr,
            ufcsStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    scope auto ordinaryDestination =
        makeWritableTransformIntoTestView!float(
            ordinaryResources[],
            ordinaryDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    scope auto ufcsDestination =
        makeWritableTransformIntoTestView!float(
            ufcsResources[],
            ufcsDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    RasterTransformError ordinaryError;
    RasterTransformError ufcsError;

    assert(
        transformInto!addTen(
            source,
            0,
            ordinaryDestination,
            0,
            ordinaryError
        )
    );

    assert(
        source.transformInto!addTen(
            0,
            ufcsDestination,
            0,
            ufcsError
        )
    );

    assert(ordinaryError == RasterTransformError.none);
    assert(ufcsError == RasterTransformError.none);

    assert(
        ordinaryStorage
        == ufcsStorage
    );

    assert(
        ordinaryStorage
        == [11, 12, 13, 14, 15, 16]
    );
}


/*
 * The v0.2 wrapper and v0.1 compatibility call are layout-equivalent for
 * signed sample/row strides.
 */
@system
unittest
{
    ubyte[8] sourceStorage =
        [1, 99, 2, 99, 3, 99, 4, 99];

    ubyte[8] newApiStorage =
        [0, 77, 0, 77, 0, 77, 0, 77];

    ubyte[8] legacyStorage =
        [0, 77, 0, 77, 0, 77, 0, 77];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr + 6,
            -4,
            -2
        )
    ];

    const PlaneDescriptor[1] newApiDescriptors =
    [
        PlaneDescriptor(
            newApiStorage.ptr + 6,
            -4,
            -2
        )
    ];

    const PlaneDescriptor[1] legacyDescriptors =
    [
        PlaneDescriptor(
            legacyStorage.ptr + 6,
            -4,
            -2
        )
    ];

    const ResourceEntry[1] newApiResources =
    [
        ResourceEntry(
            newApiStorage.ptr,
            newApiStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const ResourceEntry[1] legacyResources =
    [
        ResourceEntry(
            legacyStorage.ptr,
            legacyStorage.sizeof,
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

    scope auto newApiDestination =
        makeWritableTransformIntoTestView!ubyte(
            newApiResources[],
            newApiDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto legacyDestination =
        makeWritableTransformIntoTestView!ubyte(
            legacyResources[],
            legacyDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterTransformError newApiError;
    RasterTransformError legacyError;

    assert(
        transformInto!incrementByte(
            source,
            0,
            newApiDestination,
            0,
            newApiError
        )
    );

    assert(
        tryTransformRasterPlane!incrementByte(
            source,
            0,
            legacyDestination,
            0,
            legacyError
        )
    );

    assert(newApiError == legacyError);
    assert(newApiStorage == legacyStorage);

    assert(newApiStorage[6] == 5);
    assert(newApiStorage[4] == 4);
    assert(newApiStorage[2] == 3);
    assert(newApiStorage[0] == 2);

    assert(newApiStorage[1] == 77);
    assert(newApiStorage[3] == 77);
    assert(newApiStorage[5] == 77);
    assert(newApiStorage[7] == 77);
}


/*
 * Failure behavior is exactly inherited and remains pre-write.
 */
@system
unittest
{
    ubyte[3] sourceStorage =
        [1, 2, 3];

    ubyte[1] destinationStorage =
        [44];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            3,
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
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    scope auto destination =
        makeWritableTransformIntoTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    RasterTransformError error;

    assert(
        !source.transformInto!incrementByte(
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterTransformError.nonInjectiveDestination
    );

    assert(destinationStorage[0] == 44);
}

} // version (unittest)
