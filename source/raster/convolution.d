/++
    Generic fixed-kernel floating raster convolution.

    Spatial execution is delegated to applyNeighbourhoodInto so convolution
    does not introduce a second neighbourhood traversal engine.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.convolution;

import raster.neighbourhood_into :
    RasterNeighbourhoodError,
    applyNeighbourhoodInto;

import raster.region :
    Region2D;

import raster.sample :
    isExactConvertible;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


/++
    Compile-time fixed convolution kernel.

    Shape provides fixed neighbourhood geometry.

    Coefficient is float or double.

    Coefficients are template values in row-major neighbourhood order and their
    count must equal Shape.sampleCount.

    The type stores no runtime fields. Coefficients are manifest compile-time
    data, allowing fixed-kernel code generation and specialization.

    No normalization, scale factor, colour/radiometric meaning or border policy
    is implied.
+/
struct FixedConvolutionKernel(
    alias Shape,
    Coefficient,
    Coefficients...
)
if (
    is(Coefficient == float)
    || is(Coefficient == double)
)
{
    static assert(
        Coefficients.length
        == Shape.sampleCount,
        "Convolution coefficient count must equal Shape.sampleCount."
    );

    alias shape =
        Shape;

    alias coefficientType =
        Coefficient;

    enum Coefficient[Shape.sampleCount] coefficients =
        [Coefficients];
}


/++
    Whether one source/coefficient/accumulator combination is supported by the
    initial convolution family.

    Source/output sample type is T.

    T, coefficient type and Accumulator are limited to float/double.

    Source and coefficient values must both be exactly representable in
    Accumulator before multiplication.

    The final Accumulator -> T conversion is:
    - identity when Accumulator == T;
    - one documented double -> float narrowing when T == float and
      Accumulator == double.

    Integer convolution is deliberately excluded until overflow and final
    conversion policy are separately specified.
+/
private
template isSupportedConvolution(
    T,
    Coefficient,
    Accumulator
)
{
    enum isSupportedConvolution =
        (
            is(T == float)
            || is(T == double)
        )
        && (
            is(Coefficient == float)
            || is(Coefficient == double)
        )
        && (
            is(Accumulator == float)
            || is(Accumulator == double)
        )
        && isExactConvertible!(
            T,
            Accumulator
        )
        && isExactConvertible!(
            Coefficient,
            Accumulator
        )
        && (
            is(Accumulator == T)
            || (
                is(T == float)
                && is(Accumulator == double)
            )
        );
}


/++
    Evaluates one fixed convolution neighbourhood.

    Terms are visited in row-major coefficient order.

    For each term:

        sample      -> exact cast to Accumulator
        coefficient -> exact cast to Accumulator
        product      = sample * coefficient
        total        = total + product

    total starts at +0 in Accumulator.

    Floating NaN and infinity participate through ordinary D/IEEE arithmetic.

    The public contract fixes term order and Accumulator type. It does not add a
    separate promise forbidding compiler-permitted floating contraction.

    The final result is cast once to T. When T=float and Accumulator=double this
    is one explicit binary64 -> binary32 rounding boundary.
+/
private
T evaluateFixedConvolution(
    alias Kernel,
    Accumulator,
    T
)(
    ref const(T)[Kernel.shape.sampleCount] values
)
@safe
pure
nothrow
@nogc
if (
    isSupportedConvolution!(
        T,
        Kernel.coefficientType,
        Accumulator
    )
)
{
    Accumulator total =
        cast(Accumulator) 0;

    foreach (index; 0 .. Kernel.shape.sampleCount)
    {
        const sample =
            cast(Accumulator)
                values[index];

        const coefficient =
            cast(Accumulator)
                Kernel.coefficients[index];

        const product =
            sample * coefficient;

        total =
            total + product;
    }

    return cast(T) total;
}


/++
    Applies one compile-time fixed convolution kernel into caller-owned
    destination storage.

    Kernel is one FixedConvolutionKernel instantiation.

    Accumulator is explicit.

    Source/output T is limited to float/double in the initial production family.

    Spatial semantics are exactly applyNeighbourhoodInto using Kernel.shape:

    - sourceOutputRegion is resident-relative;
    - complete resident halo is required;
    - matching empty output succeeds;
    - destination shape must match output region;
    - destination must be injective;
    - exact required-source/destination overlap is rejected before writes;
    - every validated signed-affine layout remains supported;
    - no hidden allocation or scheduling occurs.

    Border semantics are currently the valid/resident-halo policy of
    applyNeighbourhoodInto. The generic border policy model is separate and does
    not silently synthesize edge samples here.

    Returns the same RasterNeighbourhoodError structural failure model used by
    the underlying spatial primitive.
+/
bool convolveInto(
    alias Kernel,
    Accumulator,
    T
)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterNeighbourhoodError error
)
@safe
nothrow
@nogc
if (
    isSupportedConvolution!(
        T,
        Kernel.coefficientType,
        Accumulator
    )
)
{
    alias convolutionKernel =
        evaluateFixedConvolution!(
            Kernel,
            Accumulator,
            T
        );

    return source.applyNeighbourhoodInto!(
        Kernel.shape,
        convolutionKernel
    )(
        sourcePlaneIndex,
        sourceOutputRegion,
        destination,
        destinationPlaneIndex,
        error
    );
}


/// Example using a fixed centered 3 x 3 identity convolution.
@safe unittest
{
    import raster;

    alias Shape =
        NeighbourhoodShape!(
            3,
            3,
            1,
            1
        );

    alias Kernel =
        FixedConvolutionKernel!(
            Shape,
            float,
            0.0f, 0.0f, 0.0f,
            0.0f, 1.0f, 0.0f,
            0.0f, 0.0f, 0.0f
        );

    RasterView!float source;
    WritableRasterView!float destination;

    RasterNeighbourhoodError error;

    assert(
        !source.convolveInto!(
            Kernel,
            float
        )(
            0,
            Region2D(1, 1, 1, 1),
            destination,
            0,
            error
        )
    );

    assert(
        error
        == RasterNeighbourhoodError.invalidSourcePlane
    );
}


version (unittest)
{

import raster.descriptor :
    PlaneDescriptor;

import raster.neighbourhood_shape :
    NeighbourhoodShape;

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
WritableRasterView!T makeWritableConvolutionTestView(T)(
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


alias Shape3x3 =
    NeighbourhoodShape!(
        3,
        3,
        1,
        1
    );

alias Identity3x3 =
    FixedConvolutionKernel!(
        Shape3x3,
        float,
        0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f
    );


static assert(Identity3x3.tupleof.length == 0);
static assert(Identity3x3.shape.sampleCount == 9);
static assert(Identity3x3.coefficients[4] == 1.0f);


/*
 * Centered 3 x 3 fixed convolution delegates through the qualified
 * neighbourhood specialization and preserves identity exactly.
 */
unittest
{
    float[25] sourceStorage;

    foreach (i; 0 .. sourceStorage.length)
        sourceStorage[i] = cast(float)(i + 1);

    float[9] destinationStorage;

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
            Region2D(0, 0, 5, 5)
        );

    scope auto destination =
        makeWritableConvolutionTestView!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 3, 3)
        );

    RasterNeighbourhoodError error;

    assert(
        source.convolveInto!(
            Identity3x3,
            float
        )(
            0,
            Region2D(1, 1, 3, 3),
            destination,
            0,
            error
        )
    );

    assert(error == RasterNeighbourhoodError.none);

    foreach (y; 0 .. 3)
    {
        foreach (x; 0 .. 3)
        {
            assert(
                destinationStorage[y * 3 + x]
                == sourceStorage[(y + 1) * 5 + x + 1]
            );
        }
    }
}


alias Shape5x3 =
    NeighbourhoodShape!(
        5,
        3,
        2,
        1
    );

alias Weighted5x3 =
    FixedConvolutionKernel!(
        Shape5x3,
        double,
        1.0,  2.0,  3.0,  4.0,  5.0,
        6.0,  7.0,  8.0,  9.0, 10.0,
       11.0, 12.0, 13.0, 14.0, 15.0
    );


/*
 * Generic 5 x 3 convolution uses explicit double accumulation and one final
 * float narrowing.
 */
unittest
{
    float[15] sourceStorage;

    foreach (i; 0 .. sourceStorage.length)
        sourceStorage[i] = cast(float)(i + 1);

    float[1] destinationStorage;

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
            1,
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
            Region2D(0, 0, 5, 3)
        );

    scope auto destination =
        makeWritableConvolutionTestView!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 1, 1)
        );

    RasterNeighbourhoodError error;

    assert(
        source.convolveInto!(
            Weighted5x3,
            double
        )(
            0,
            Region2D(2, 1, 1, 1),
            destination,
            0,
            error
        )
    );

    double expected = 0.0;

    foreach (index; 0 .. 15)
    {
        expected +=
            cast(double) sourceStorage[index]
            * Weighted5x3.coefficients[index];
    }

    assert(error == RasterNeighbourhoodError.none);
    assert(destinationStorage[0] == cast(float) expected);
}


/*
 * NaN and infinity participate through ordinary floating arithmetic.
 */
unittest
{
    alias Shape1x1 =
        NeighbourhoodShape!(
            1,
            1,
            0,
            0
        );

    alias Scale2 =
        FixedConvolutionKernel!(
            Shape1x1,
            double,
            2.0
        );

    double[2] sourceStorage =
        [double.infinity, double.nan];

    double[2] destinationStorage;

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
        makeRasterViewAssumeValidated!double(
            sourceDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto destination =
        makeWritableConvolutionTestView!double(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    RasterNeighbourhoodError error;

    assert(
        source.convolveInto!(
            Scale2,
            double
        )(
            0,
            Region2D(0, 0, 2, 1),
            destination,
            0,
            error
        )
    );

    assert(error == RasterNeighbourhoodError.none);
    assert(destinationStorage[0] == double.infinity);
    assert(destinationStorage[1] != destinationStorage[1]);
}


/*
 * Kernel/source/accumulator support matrix.
 */
static assert(
    isSupportedConvolution!(
        float,
        float,
        float
    )
);

static assert(
    isSupportedConvolution!(
        float,
        float,
        double
    )
);

static assert(
    isSupportedConvolution!(
        float,
        double,
        double
    )
);

static assert(
    isSupportedConvolution!(
        double,
        float,
        double
    )
);

static assert(
    isSupportedConvolution!(
        double,
        double,
        double
    )
);

static assert(
    !isSupportedConvolution!(
        double,
        double,
        float
    )
);

static assert(
    !isSupportedConvolution!(
        int,
        float,
        double
    )
);

} // version (unittest)
