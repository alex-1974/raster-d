/++
    v0.2 two-input destination-oriented elementwise transform API.

    This module provides the generic same-type zip primitive intended to back
    arithmetic wrappers, pairwise min/max, mask combination and consumer-defined
    elementwise kernels.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.zip_transform_into;

import raster.internal.affine_relation :
    affine2DMappingIsInjective;

import raster.internal.same_type_overlap :
    validatedSameTypePlaneRegionsOverlap;

import raster.internal.zip_transform_dispatch :
    executeApprovedCanonicalZipTransform;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


/++
    Semantic failure category for one same-type zip transform.
+/
enum RasterZipTransformError : ubyte
{
    none,

    invalidLeftPlane,

    invalidRightPlane,

    invalidDestinationPlane,

    shapeMismatch,

    nonInjectiveDestination,

    leftDestinationOverlap,

    rightDestinationOverlap
}


/// Example using the zip-transform error category.
@safe unittest
{
    import raster;

    assert(
        RasterZipTransformError.init
        == RasterZipTransformError.none
    );
}


/++
    Invokes one caller-supplied zip transform under the operation's required
    compile-time attribute and type contract.

    A transform alias that cannot be used as:

        @safe pure nothrow @nogc T, T -> T

    fails to instantiate.
+/
private
T invokeZipTransform(alias transform, T)(
    T left,
    T right
)
@safe
pure
nothrow
@nogc
{
    return transform(left, right);
}


/++
    Applies one compile-time same-type two-input elementwise transform into a
    selected writable destination plane.

    Canonical UFCS form:

        left.zipTransformInto!transform(
            leftPlaneIndex,
            right,
            rightPlaneIndex,
            destination,
            destinationPlaneIndex,
            error
        );

    The transform alias must be usable as:

        @safe pure nothrow @nogc T, T -> T

    Structural semantics:

    - all three plane indices must be valid;
    - left, right and destination logical width/height must match;
    - matching empty shapes succeed without invoking transform;
    - non-empty destination mapping must be injective;
    - left/destination reachable sample bytes must be physically disjoint;
    - right/destination reachable sample bytes must be physically disjoint;
    - left/right physical overlap is allowed because both inputs are read-only;
    - every structural/alias failure occurs before the first destination write.

    Every already-validated signed affine resident layout is supported.

    The operation is coordinate-wise in each view's relative semantic
    coordinates. Resident Region2D origins do not need to be equal.

    Raster-d performs no implicit conversion, clamping, saturation, numeric
    policy, image-domain interpretation or scheduling.

    The function allocates nothing and retains no operand.
+/
bool zipTransformInto(alias transform, T)(
    scope RasterView!T left,
    size_t leftPlaneIndex,

    scope RasterView!T right,
    size_t rightPlaneIndex,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterZipTransformError error
)
@safe
nothrow
@nogc
{
    error =
        RasterZipTransformError.none;


    ptrdiff_t leftRowStrideElements;
    ptrdiff_t leftSampleStrideElements;

    if (
        !left.tryExecutionPlaneStrides(
            leftPlaneIndex,
            leftRowStrideElements,
            leftSampleStrideElements
        )
    )
    {
        error =
            RasterZipTransformError.invalidLeftPlane;

        return false;
    }


    ptrdiff_t rightRowStrideElements;
    ptrdiff_t rightSampleStrideElements;

    if (
        !right.tryExecutionPlaneStrides(
            rightPlaneIndex,
            rightRowStrideElements,
            rightSampleStrideElements
        )
    )
    {
        error =
            RasterZipTransformError.invalidRightPlane;

        return false;
    }


    ptrdiff_t destinationRowStrideElements;
    ptrdiff_t destinationSampleStrideElements;

    if (
        !destination.tryExecutionPlaneStrides(
            destinationPlaneIndex,
            destinationRowStrideElements,
            destinationSampleStrideElements
        )
    )
    {
        error =
            RasterZipTransformError.invalidDestinationPlane;

        return false;
    }


    if (
        left.width != right.width
        || left.height != right.height
        || left.width != destination.width
        || left.height != destination.height
    )
    {
        error =
            RasterZipTransformError.shapeMismatch;

        return false;
    }


    if (left.empty)
        return true;


    if (
        !affine2DMappingIsInjective(
            destination.width,
            destination.height,
            destinationRowStrideElements,
            destinationSampleStrideElements
        )
    )
    {
        error =
            RasterZipTransformError.nonInjectiveDestination;

        return false;
    }


    const leftBase =
        left.executionRegionBase(
            leftPlaneIndex
        );

    const rightBase =
        right.executionRegionBase(
            rightPlaneIndex
        );

    auto destinationBase =
        destination.executionRegionBase(
            destinationPlaneIndex
        );

    assert(leftBase !is null);
    assert(rightBase !is null);
    assert(destinationBase !is null);


    if (
        validatedSameTypePlaneRegionsOverlap(
            leftBase,
            leftRowStrideElements,
            leftSampleStrideElements,

            destinationBase,
            destinationRowStrideElements,
            destinationSampleStrideElements,

            left.width,
            left.height
        )
    )
    {
        error =
            RasterZipTransformError.leftDestinationOverlap;

        return false;
    }


    if (
        validatedSameTypePlaneRegionsOverlap(
            rightBase,
            rightRowStrideElements,
            rightSampleStrideElements,

            destinationBase,
            destinationRowStrideElements,
            destinationSampleStrideElements,

            left.width,
            left.height
        )
    )
    {
        error =
            RasterZipTransformError.rightDestinationOverlap;

        return false;
    }


    if (
        executeApprovedCanonicalZipTransform!transform(
            leftBase,
            leftRowStrideElements,
            leftSampleStrideElements,

            rightBase,
            rightRowStrideElements,
            rightSampleStrideElements,

            left.width,
            left.height,

            destinationBase,
            destinationRowStrideElements,
            destinationSampleStrideElements
        )
    )
    {
        return true;
    }


    foreach (y; 0 .. left.height)
    {
        foreach (x; 0 .. left.width)
        {
            T leftValue;
            T rightValue;

            const leftReadOk =
                left.trySample(
                    leftPlaneIndex,
                    x,
                    y,
                    leftValue
                );

            const rightReadOk =
                right.trySample(
                    rightPlaneIndex,
                    x,
                    y,
                    rightValue
                );

            assert(leftReadOk);
            assert(rightReadOk);


            const transformed =
                invokeZipTransform!transform(
                    leftValue,
                    rightValue
                );


            const writeOk =
                destination.trySetSample(
                    destinationPlaneIndex,
                    x,
                    y,
                    transformed
                );

            assert(writeOk);
        }
    }


    return true;
}


/// Example reporting an invalid left plane through UFCS.
@safe unittest
{
    import raster;

    alias add =
        (float left, float right)
        @safe pure nothrow @nogc
        => left + right;

    RasterView!float left;
    RasterView!float right;
    WritableRasterView!float destination;

    RasterZipTransformError error;

    assert(
        !left.zipTransformInto!add(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterZipTransformError.invalidLeftPlane
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


private
WritableRasterView!T makeWritableZipTransformTestView(T)(
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


@safe
pure
nothrow
@nogc
private
float addFloat(
    float left,
    float right
)
{
    return left + right;
}


@safe
pure
nothrow
@nogc
private
ubyte addByte(
    ubyte left,
    ubyte right
)
{
    return cast(ubyte)(
        left + right
    );
}


@safe
pure
nothrow
@nogc
private
ubyte mustNotRun(
    ubyte left,
    ubyte right
)
{
    assert(0);
}


/*
 * Ordinary-call and UFCS forms are equivalent on contiguous storage.
 */
@system
unittest
{
    float[6] leftStorage =
        [1, 2, 3, 4, 5, 6];

    float[6] rightStorage =
        [10, 20, 30, 40, 50, 60];

    float[6] ordinaryStorage;
    float[6] ufcsStorage;

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(
            leftStorage.ptr,
            3,
            1
        )
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(
            rightStorage.ptr,
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

    scope auto left =
        makeRasterViewAssumeValidated!float(
            leftDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    scope auto right =
        makeRasterViewAssumeValidated!float(
            rightDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    scope auto ordinaryDestination =
        makeWritableZipTransformTestView!float(
            ordinaryResources[],
            ordinaryDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    scope auto ufcsDestination =
        makeWritableZipTransformTestView!float(
            ufcsResources[],
            ufcsDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    RasterZipTransformError ordinaryError;
    RasterZipTransformError ufcsError;

    assert(
        zipTransformInto!addFloat(
            left,
            0,
            right,
            0,
            ordinaryDestination,
            0,
            ordinaryError
        )
    );

    assert(
        left.zipTransformInto!addFloat(
            0,
            right,
            0,
            ufcsDestination,
            0,
            ufcsError
        )
    );

    assert(
        ordinaryError
        == RasterZipTransformError.none
    );

    assert(
        ufcsError
        == RasterZipTransformError.none
    );

    assert(
        ordinaryStorage
        == ufcsStorage
    );

    assert(
        ordinaryStorage
        == [11, 22, 33, 44, 55, 66]
    );
}


/*
 * Arbitrary validated signed row/sample strides remain semantic.
 */
@system
unittest
{
    ubyte[8] leftStorage =
        [1, 99, 2, 99, 3, 99, 4, 99];

    ubyte[8] rightStorage =
        [10, 88, 20, 88, 30, 88, 40, 88];

    ubyte[8] destinationStorage =
        [0, 77, 0, 77, 0, 77, 0, 77];

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(
            leftStorage.ptr + 6,
            -4,
            -2
        )
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(
            rightStorage.ptr,
            4,
            2
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr + 6,
            -4,
            -2
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

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            leftDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            rightDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableZipTransformTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterZipTransformError error;

    assert(
        left.zipTransformInto!addByte(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    /*
     * left relative matrix:
     *   4 3
     *   2 1
     *
     * right relative matrix:
     *   10 20
     *   30 40
     */
    assert(destinationStorage[6] == 14);
    assert(destinationStorage[4] == 23);
    assert(destinationStorage[2] == 32);
    assert(destinationStorage[0] == 41);

    assert(destinationStorage[1] == 77);
    assert(destinationStorage[3] == 77);
    assert(destinationStorage[5] == 77);
    assert(destinationStorage[7] == 77);
}


/*
 * The two read-only inputs may physically alias each other.
 */
@system
unittest
{
    ubyte[4] sourceStorage =
        [1, 2, 3, 4];

    ubyte[4] destinationStorage;

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
            destinationStorage.sizeof,
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
        makeWritableZipTransformTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterZipTransformError error;

    assert(
        source.zipTransformInto!addByte(
            0,
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        destinationStorage
        == [2, 4, 6, 8]
    );
}


/*
 * Left/destination overlap is rejected before the first write.
 */
@system
unittest
{
    ubyte[4] sharedStorage =
        [1, 2, 3, 4];

    ubyte[4] rightStorage =
        [10, 20, 30, 40];

    const PlaneDescriptor[1] sharedDescriptors =
    [
        PlaneDescriptor(
            sharedStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(
            rightStorage.ptr,
            2,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            sharedStorage.ptr,
            sharedStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            sharedDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            rightDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableZipTransformTestView!ubyte(
            destinationResources[],
            sharedDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    const before =
        sharedStorage;

    RasterZipTransformError error;

    assert(
        !left.zipTransformInto!addByte(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterZipTransformError.leftDestinationOverlap
    );

    assert(sharedStorage == before);
}


/*
 * Right/destination overlap is rejected before the first write.
 */
@system
unittest
{
    ubyte[4] leftStorage =
        [1, 2, 3, 4];

    ubyte[4] sharedStorage =
        [10, 20, 30, 40];

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(
            leftStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] sharedDescriptors =
    [
        PlaneDescriptor(
            sharedStorage.ptr,
            2,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            sharedStorage.ptr,
            sharedStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            leftDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            sharedDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableZipTransformTestView!ubyte(
            destinationResources[],
            sharedDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    const before =
        sharedStorage;

    RasterZipTransformError error;

    assert(
        !left.zipTransformInto!addByte(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterZipTransformError.rightDestinationOverlap
    );

    assert(sharedStorage == before);
}


/*
 * Shape mismatch is rejected before writing.
 */
@system
unittest
{
    ubyte[4] leftStorage =
        [1, 2, 3, 4];

    ubyte[3] rightStorage =
        [10, 20, 30];

    ubyte[4] destinationStorage =
        [44, 44, 44, 44];

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(
            leftStorage.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(
            rightStorage.ptr,
            3,
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
            destinationStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            leftDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            rightDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    scope auto destination =
        makeWritableZipTransformTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterZipTransformError error;

    assert(
        !left.zipTransformInto!addByte(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterZipTransformError.shapeMismatch
    );

    assert(
        destinationStorage
        == [44, 44, 44, 44]
    );
}


/*
 * Non-injective destination is rejected before writing.
 */
@system
unittest
{
    ubyte[3] leftStorage =
        [1, 2, 3];

    ubyte[3] rightStorage =
        [10, 20, 30];

    ubyte[1] destinationStorage =
        [44];

    const PlaneDescriptor[1] leftDescriptors =
    [
        PlaneDescriptor(
            leftStorage.ptr,
            3,
            1
        )
    ];

    const PlaneDescriptor[1] rightDescriptors =
    [
        PlaneDescriptor(
            rightStorage.ptr,
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

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            leftDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            rightDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    scope auto destination =
        makeWritableZipTransformTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    RasterZipTransformError error;

    assert(
        !left.zipTransformInto!addByte(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterZipTransformError.nonInjectiveDestination
    );

    assert(destinationStorage[0] == 44);
}


/*
 * Matching empty shapes succeed without invoking the callable.
 */
@system
unittest
{
    const PlaneDescriptor[1] emptyDescriptors =
    [
        PlaneDescriptor(
            null,
            0,
            1
        )
    ];

    ResourceEntry[] resources;

    scope auto left =
        makeRasterViewAssumeValidated!ubyte(
            emptyDescriptors[],
            Region2D(0, 0, 0, 3)
        );

    scope auto right =
        makeRasterViewAssumeValidated!ubyte(
            emptyDescriptors[],
            Region2D(0, 0, 0, 3)
        );

    scope auto destination =
        makeWritableZipTransformTestView!ubyte(
            resources,
            emptyDescriptors[],
            Region2D(0, 0, 0, 3)
        );

    RasterZipTransformError error;

    assert(
        left.zipTransformInto!mustNotRun(
            0,
            right,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterZipTransformError.none
    );
}

} // version (unittest)
