/++
    Internal generic extrema execution.

    The implementation preserves logical row-major semantics across every
    validated signed affine raster layout.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.internal.extrema;

import std.math : signbit;

import raster.view :
    RasterView;


/++
    Compile-time extrema operation mode.

    One implementation family serves min, max and one-pass minMax without
    forcing the single-extrema operations to perform the other comparison.
+/
package(raster)
enum ExtremaMode : ubyte
{
    minimum,
    maximum,
    minMax
}


/++
    Internal extrema execution status.

    The default state is deliberately invalid-plane failure.
+/
package(raster)
enum ExtremaStatus : ubyte
{
    invalidPlane,
    emptyInput,
    none
}


/++
    Internal extrema execution result.

    minimum/maximum are meaningful only when status == none.
+/
package(raster)
struct ExtremaExecutionResult(T)
{
    ExtremaStatus status =
        ExtremaStatus.invalidPlane;

    T minimum =
        T.init;

    T maximum =
        T.init;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return status
            == ExtremaStatus.none;
    }
}


private
template isExtremaFloating(T)
{
    enum isExtremaFloating =
        is(T == float)
        || is(T == double);
}


private
bool isNegativeZero(T)(
    T value
)
@safe
pure
nothrow
@nogc
if (isExtremaFloating!T)
{
    return value == cast(T) 0
        && signbit(value);
}


/++
    Updates a minimum candidate according to M3.1 semantics.

    NaN is handled by the outer execution loop before this helper.

    Equal signed zero values use -0 for minimum independent of encounter order.
+/
private
void updateMinimum(T)(
    ref T current,
    T value
)
@safe
pure
nothrow
@nogc
{
    if (value < current)
    {
        current =
            value;

        return;
    }

    static if (isExtremaFloating!T)
    {
        if (
            value == current
            && value == cast(T) 0
            && isNegativeZero(value)
        )
        {
            current =
                value;
        }
    }
}


/++
    Updates a maximum candidate according to M3.1 semantics.

    NaN is handled by the outer execution loop before this helper.

    Equal signed zero values use +0 for maximum independent of encounter order.
+/
private
void updateMaximum(T)(
    ref T current,
    T value
)
@safe
pure
nothrow
@nogc
{
    if (value > current)
    {
        current =
            value;

        return;
    }

    static if (isExtremaFloating!T)
    {
        if (
            value == current
            && value == cast(T) 0
            && !isNegativeZero(value)
        )
        {
            current =
                value;
        }
    }
}


/++
    Executes min, max or minMax in logical row-major order.

    The caller selects Mode at compile time.

    For floating T, any NaN sample produces a successful NaN extrema result.
    The exact NaN payload/sign is not part of the public contract.

    Empty input is distinct from invalid-plane failure.

    Safety:
    RasterView validation has already proven every reachable sample address.
+/
package(raster)
ExtremaExecutionResult!T executeExtrema(
    ExtremaMode Mode,
    T
)(
    scope RasterView!T source,
    size_t planeIndex
)
@trusted
nothrow
@nogc
{
    ExtremaExecutionResult!T result;

    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;

    if (
        !source.tryExecutionPlaneStrides(
            planeIndex,
            rowStride,
            sampleStride
        )
    )
    {
        return result;
    }

    if (source.empty)
    {
        result.status =
            ExtremaStatus.emptyInput;

        return result;
    }

    const(T)* row =
        source.executionRegionBase(
            planeIndex
        );

    assert(row !is null);

    T minimum =
        *row;

    T maximum =
        *row;

    static if (isExtremaFloating!T)
    {
        if (minimum != minimum)
        {
            result.status =
                ExtremaStatus.none;

            result.minimum =
                minimum;

            result.maximum =
                minimum;

            return result;
        }
    }

    bool first =
        true;

    foreach (y; 0 .. source.height)
    {
        const(T)* sample =
            row;

        foreach (x; 0 .. source.width)
        {
            if (first)
            {
                first =
                    false;
            }
            else
            {
                const value =
                    *sample;

                static if (isExtremaFloating!T)
                {
                    if (value != value)
                    {
                        result.status =
                            ExtremaStatus.none;

                        result.minimum =
                            value;

                        result.maximum =
                            value;

                        return result;
                    }
                }

                static if (
                    Mode == ExtremaMode.minimum
                    || Mode == ExtremaMode.minMax
                )
                {
                    updateMinimum(
                        minimum,
                        value
                    );
                }

                static if (
                    Mode == ExtremaMode.maximum
                    || Mode == ExtremaMode.minMax
                )
                {
                    updateMaximum(
                        maximum,
                        value
                    );
                }
            }

            if (x + 1 < source.width)
            {
                sample +=
                    sampleStride;
            }
        }

        if (y + 1 < source.height)
        {
            row +=
                rowStride;
        }
    }

    result.status =
        ExtremaStatus.none;

    result.minimum =
        minimum;

    result.maximum =
        maximum;

    return result;
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
 * Signed strides preserve logical extrema.
 */
unittest
{
    int[8] storage =
        [1, 99, 8, 99, -3, 99, 4, 99];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr + 6,
            -4,
            -2
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!int(
            descriptors[],
            Region2D(0, 0, 2, 2)
        );

    const result =
        executeExtrema!(
            ExtremaMode.minMax,
            int
        )(
            source,
            0
        );

    assert(result.ok);
    assert(result.minimum == -3);
    assert(result.maximum == 8);
}


/*
 * min and max modes share execution without calculating the other comparison.
 */
unittest
{
    ubyte[4] storage =
        [7, 2, 9, 3];

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

    const minResult =
        executeExtrema!(
            ExtremaMode.minimum,
            ubyte
        )(
            source,
            0
        );

    const maxResult =
        executeExtrema!(
            ExtremaMode.maximum,
            ubyte
        )(
            source,
            0
        );

    assert(minResult.ok);
    assert(maxResult.ok);

    assert(minResult.minimum == 2);
    assert(maxResult.maximum == 9);
}


/*
 * Any NaN propagates as a successful extrema value.
 */
unittest
{
    float[4] storage =
        [4.0f, -2.0f, float.nan, 9.0f];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            4,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            descriptors[],
            Region2D(0, 0, 4, 1)
        );

    const result =
        executeExtrema!(
            ExtremaMode.minMax,
            float
        )(
            source,
            0
        );

    assert(result.ok);
    assert(result.minimum != result.minimum);
    assert(result.maximum != result.maximum);
}


/*
 * Signed zero extrema are encounter-order independent.
 */
unittest
{
    float[2] firstOrder =
        [-0.0f, +0.0f];

    float[2] secondOrder =
        [+0.0f, -0.0f];

    const PlaneDescriptor[1] firstDescriptors =
    [
        PlaneDescriptor(
            firstOrder.ptr,
            2,
            1
        )
    ];

    const PlaneDescriptor[1] secondDescriptors =
    [
        PlaneDescriptor(
            secondOrder.ptr,
            2,
            1
        )
    ];

    scope auto first =
        makeRasterViewAssumeValidated!float(
            firstDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    scope auto second =
        makeRasterViewAssumeValidated!float(
            secondDescriptors[],
            Region2D(0, 0, 2, 1)
        );

    const a =
        executeExtrema!(
            ExtremaMode.minMax,
            float
        )(
            first,
            0
        );

    const b =
        executeExtrema!(
            ExtremaMode.minMax,
            float
        )(
            second,
            0
        );

    assert(a.ok);
    assert(b.ok);

    assert(signbit(a.minimum));
    assert(signbit(b.minimum));

    assert(!signbit(a.maximum));
    assert(!signbit(b.maximum));
}


/*
 * Empty and invalid-plane states remain distinct.
 */
unittest
{
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            null,
            ptrdiff_t.min,
            ptrdiff_t.min
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!double(
            descriptors[],
            Region2D(
                size_t.max,
                size_t.max,
                0,
                3
            )
        );

    const emptyResult =
        executeExtrema!(
            ExtremaMode.minimum,
            double
        )(
            source,
            0
        );

    const invalidResult =
        executeExtrema!(
            ExtremaMode.minimum,
            double
        )(
            source,
            1
        );

    assert(
        emptyResult.status
        == ExtremaStatus.emptyInput
    );

    assert(
        invalidResult.status
        == ExtremaStatus.invalidPlane
    );
}

} // version (unittest)
