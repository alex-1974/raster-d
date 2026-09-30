/++
    Public generic raster point-transform operation.

    M2.2 exposes only semantic point transformation.

    Physical affine-relation classification and the defensive exact overlap
    fallback remain implementation details of this module.
+/
module raster.transform;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective,
    classifySameTypeAffine2DByteOverlap;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


/++
    Semantic failure category for one raster-plane point transform.
+/
enum RasterTransformError : ubyte
{
    none,

    invalidSourcePlane,

    invalidDestinationPlane,

    shapeMismatch,

    nonInjectiveDestination,

    sourceDestinationOverlap
}


/++
    Invokes one caller-supplied point transform under the operation's required
    compile-time attribute contract.

    A transform alias that is not usable as:

        @safe pure nothrow @nogc T -> T

    fails to instantiate this helper and therefore fails at compile time.
+/
private
T invokePointTransform(alias transform, T)(
    T value
)
@safe
pure
nothrow
@nogc
{
    return transform(value);
}


/++
    Exact allocation-free fallback for same-type source/destination sample-byte
    overlap.

    The normal relation path uses the checked-wide affine classifier.

    This fallback is reached only if that defensive classifier reports
    arithmetic failure. The operands already originate from validated raster
    views, so their reachable sample pointers are valid. The fallback enumerates
    the finite reachable sample sets before any destination write.

    Destination injectivity has already been established.

    For equal-sized T samples, two byte intervals overlap exactly when the
    absolute difference between sample starts is less than T.sizeof.
+/
private
bool sameTypeSampleBytesOverlapFallback(T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStrideElements,
    ptrdiff_t sourceSampleStrideElements,

    scope T* destinationBase,
    ptrdiff_t destinationRowStrideElements,
    ptrdiff_t destinationSampleStrideElements,

    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);
    assert(width != 0);
    assert(height != 0);

    auto sourceRow =
        sourceBase;

    foreach (sourceY; 0 .. height)
    {
        auto sourceSample =
            sourceRow;

        foreach (sourceX; 0 .. width)
        {
            const sourceAddress =
                cast(size_t) sourceSample;

            auto destinationRow =
                destinationBase;

            foreach (destinationY; 0 .. height)
            {
                auto destinationSample =
                    destinationRow;

                foreach (destinationX; 0 .. width)
                {
                    const destinationAddress =
                        cast(size_t) destinationSample;

                    const distance =
                        sourceAddress <= destinationAddress
                        ? destinationAddress - sourceAddress
                        : sourceAddress - destinationAddress;

                    if (distance < T.sizeof)
                        return true;

                    if (destinationX + 1 < width)
                    {
                        destinationSample +=
                            destinationSampleStrideElements;
                    }
                }

                if (destinationY + 1 < height)
                {
                    destinationRow +=
                        destinationRowStrideElements;
                }
            }

            if (sourceX + 1 < width)
            {
                sourceSample +=
                    sourceSampleStrideElements;
            }
        }

        if (sourceY + 1 < height)
        {
            sourceRow +=
                sourceRowStrideElements;
        }
    }

    return false;
}


/++
    Applies one compile-time same-type point transform from a selected source
    plane into a selected writable destination plane.

    The transform alias must be callable as:

        @safe pure nothrow @nogc T -> T

    This requirement is checked by template instantiation.

    Structural semantics:

    - source and destination plane indices must be valid;
    - logical source/destination shapes must match;
    - a matching empty shape succeeds without invoking transform;
    - the writable destination mapping must be injective;
    - reachable source/destination sample bytes must be physically disjoint;
    - every structural failure occurs before the first destination write.

    Every validated resident affine layout is semantically supported.

    Raster-d performs no implicit numeric conversion, clamping, saturation,
    NaN normalization, signed-zero normalization, FMA selection or image-domain
    interpretation. Each successful destination sample receives exactly the T
    value returned by transform for the corresponding logical source sample.

    The operation allocates nothing and retains no operand.
+/
bool tryTransformRasterPlane(alias transform, T)(
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
    error =
        RasterTransformError.none;


    ptrdiff_t sourceRowStrideElements;
    ptrdiff_t sourceSampleStrideElements;

    if (
        !source.tryExecutionPlaneStrides(
            sourcePlaneIndex,
            sourceRowStrideElements,
            sourceSampleStrideElements
        )
    )
    {
        error =
            RasterTransformError.invalidSourcePlane;

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
            RasterTransformError.invalidDestinationPlane;

        return false;
    }


    if (
        source.width != destination.width
        || source.height != destination.height
    )
    {
        error =
            RasterTransformError.shapeMismatch;

        return false;
    }


    if (source.empty)
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
            RasterTransformError.nonInjectiveDestination;

        return false;
    }


    const sourceBase =
        source.executionRegionBase(
            sourcePlaneIndex
        );

    auto destinationBase =
        destination.executionRegionBase(
            destinationPlaneIndex
        );

    assert(sourceBase !is null);
    assert(destinationBase !is null);


    final switch (
        classifySameTypeAffine2DByteOverlap(
            source.width,
            source.height,

            cast(size_t) sourceBase,
            sourceRowStrideElements,
            sourceSampleStrideElements,

            cast(size_t) destinationBase,
            destinationRowStrideElements,
            destinationSampleStrideElements,

            T.sizeof
        )
    )
    {
        case AffineByteOverlapRelation.overlap:
            error =
                RasterTransformError.sourceDestinationOverlap;

            return false;

        case AffineByteOverlapRelation.disjoint:
            break;

        case AffineByteOverlapRelation.arithmeticFailure:
            if (
                sameTypeSampleBytesOverlapFallback(
                    sourceBase,
                    sourceRowStrideElements,
                    sourceSampleStrideElements,

                    destinationBase,
                    destinationRowStrideElements,
                    destinationSampleStrideElements,

                    source.width,
                    source.height
                )
            )
            {
                error =
                    RasterTransformError.sourceDestinationOverlap;

                return false;
            }

            break;
    }


    foreach (y; 0 .. source.height)
    {
        foreach (x; 0 .. source.width)
        {
            T value;

            const readOk =
                source.trySample(
                    sourcePlaneIndex,
                    x,
                    y,
                    value
                );

            assert(readOk);


            const transformed =
                invokePointTransform!transform(
                    value
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
WritableRasterView!T makeWritableTransformTestView(T)(
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
ubyte incrementByte(ubyte value)
{
    return cast(ubyte)(value + 1);
}


@safe
pure
nothrow
@nogc
private
float addTen(float value)
{
    return value + 10.0f;
}


private
struct PairSample
{
    ushort a;
    ushort b;
}


@safe
pure
nothrow
@nogc
private
PairSample swapPair(PairSample value)
{
    return PairSample(
        value.b,
        value.a
    );
}


/*
 * Contiguous float source/destination.
 */
unittest
{
    float[6] sourceStorage =
        [1, 2, 3, 4, 5, 6];

    float[6] destinationStorage;

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
            3,
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
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    scope auto destination =
        makeWritableTransformTestView!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    RasterTransformError error;

    assert(
        tryTransformRasterPlane!addTen(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterTransformError.none);

    assert(
        destinationStorage
        == [11, 12, 13, 14, 15, 16]
    );
}


/*
 * Padded rows preserve destination padding.
 */
unittest
{
    ubyte[10] sourceStorage =
        [1, 2, 3, 90, 91, 4, 5, 6, 92, 93];

    ubyte[12] destinationStorage =
        [0, 0, 0, 80, 81, 82, 0, 0, 0, 83, 84, 85];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            5,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr,
            6,
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
            Region2D(0, 0, 3, 2)
        );

    scope auto destination =
        makeWritableTransformTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 3, 2)
        );

    RasterTransformError error;

    assert(
        tryTransformRasterPlane!incrementByte(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        destinationStorage
        == [2, 3, 4, 80, 81, 82, 5, 6, 7, 83, 84, 85]
    );
}


/*
 * Arbitrary signed row/sample strides remain supported.
 */
unittest
{
    ubyte[8] sourceStorage =
        [1, 99, 2, 99, 3, 99, 4, 99];

    ubyte[8] destinationStorage =
        [0, 77, 0, 77, 0, 77, 0, 77];

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

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    scope auto destination =
        makeWritableTransformTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 2)
        );

    RasterTransformError error;

    assert(
        tryTransformRasterPlane!incrementByte(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(destinationStorage[6] == 5);
    assert(destinationStorage[4] == 4);
    assert(destinationStorage[2] == 3);
    assert(destinationStorage[0] == 2);

    assert(destinationStorage[1] == 77);
    assert(destinationStorage[3] == 77);
    assert(destinationStorage[5] == 77);
    assert(destinationStorage[7] == 77);
}


/*
 * POD samples are supported without numeric interpretation.
 */
unittest
{
    PairSample[2] sourceStorage =
    [
        PairSample(1, 2),
        PairSample(3, 4)
    ];

    PairSample[2] destinationStorage;

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
        makeRasterViewAssumeValidated!PairSample(
            sourceDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto destination =
        makeWritableTransformTestView!PairSample(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    RasterTransformError error;

    assert(
        tryTransformRasterPlane!swapPair(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        destinationStorage[0]
        == PairSample(2, 1)
    );

    assert(
        destinationStorage[1]
        == PairSample(4, 3)
    );
}


/*
 * Non-injective destination is rejected before writing.
 */
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
        makeWritableTransformTestView!ubyte(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    RasterTransformError error;

    assert(
        !tryTransformRasterPlane!incrementByte(
            source,
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


/*
 * Exact in-place overlap is rejected before writing.
 */
unittest
{
    ubyte[3] storage =
        [1, 2, 3];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            3,
            1
        )
    ];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            descriptors[],
            Region2D(0, 0, 3, 1)
        );

    scope auto destination =
        makeWritableTransformTestView!ubyte(
            resources[],
            descriptors[],
            Region2D(0, 0, 3, 1)
        );

    RasterTransformError error;

    assert(
        !tryTransformRasterPlane!incrementByte(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterTransformError.sourceDestinationOverlap
    );

    assert(storage == [1, 2, 3]);
}


/*
 * Shifted overlap is rejected before writing.
 */
unittest
{
    ubyte[4] storage =
        [1, 2, 3, 4];

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            3,
            1
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            storage.ptr + 1,
            3,
            1
        )
    ];

    const ResourceEntry[1] resources =
    [
        ResourceEntry(
            storage.ptr,
            storage.sizeof,
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
        makeWritableTransformTestView!ubyte(
            resources[],
            destinationDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    RasterTransformError error;

    assert(
        !tryTransformRasterPlane!incrementByte(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterTransformError.sourceDestinationOverlap
    );

    assert(storage == [1, 2, 3, 4]);
}


/*
 * Invalid plane indices and shape mismatch fail before writing.
 */
unittest
{
    ubyte[2] sourceStorage =
        [1, 2];

    ubyte[3] destinationStorage =
        [8, 8, 8];

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
            3,
            1
        )
    ];

    const ResourceEntry[1] resources =
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
            Region2D(0, 0, 2, 1)
        );

    scope auto destination =
        makeWritableTransformTestView!ubyte(
            resources[],
            destinationDescriptors[],
            Region2D(0, 0, 3, 1)
        );

    RasterTransformError error;

    assert(
        !tryTransformRasterPlane!incrementByte(
            source,
            1,
            destination,
            0,
            error
        )
    );

    assert(error == RasterTransformError.invalidSourcePlane);

    assert(
        !tryTransformRasterPlane!incrementByte(
            source,
            0,
            destination,
            1,
            error
        )
    );

    assert(error == RasterTransformError.invalidDestinationPlane);

    assert(
        !tryTransformRasterPlane!incrementByte(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterTransformError.shapeMismatch);

    assert(destinationStorage == [8, 8, 8]);
}


/*
 * Matching empty planes succeed without invoking the transform.
 *
 * The transform deliberately asserts if called.
 */
@safe
pure
nothrow
@nogc
private
ubyte mustNotRun(ubyte)
{
    assert(0);
}


unittest
{
    ubyte[1] sourceStorage =
        [5];

    ubyte[1] destinationStorage =
        [9];

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

    const ResourceEntry[1] resources =
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
            Region2D(0, 0, 0, 1)
        );

    scope auto destination =
        makeWritableTransformTestView!ubyte(
            resources[],
            destinationDescriptors[],
            Region2D(0, 0, 0, 1)
        );

    RasterTransformError error;

    assert(
        tryTransformRasterPlane!mustNotRun(
            source,
            0,
            destination,
            0,
            error
        )
    );

    assert(error == RasterTransformError.none);
    assert(destinationStorage[0] == 9);
}


/*
 * The exact fallback itself handles overlap and disjoint same-type samples
 * without allocation. It is separately tested because reaching the defensive
 * classifier arithmetic-failure branch through fully validated metadata is not
 * expected during ordinary operation.
 */
unittest
{
    ubyte[4] source =
        [1, 2, 3, 4];

    ubyte[4] destination;

    assert(
        !sameTypeSampleBytesOverlapFallback(
            source.ptr,
            4,
            1,

            destination.ptr,
            4,
            1,

            4,
            1
        )
    );

    assert(
        sameTypeSampleBytesOverlapFallback(
            source.ptr,
            4,
            1,

            source.ptr + 1,
            4,
            1,

            3,
            1
        )
    );
}

} // version (unittest)
