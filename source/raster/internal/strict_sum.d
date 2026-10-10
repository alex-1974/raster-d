/++
    Internal strict generic sum execution.

    This module owns the common row-major execution loop used by the v0.2
    generic sum family for combinations that are not routed through an already
    qualified specialized implementation.

    It deliberately does not define public sample/accumulator legality. Public
    reduction constraints remain in raster.reduction.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.internal.strict_sum;

import raster.view :
    RasterView;


/++
    Internal strict-sum status.

    The default is deliberately failure.
+/
package(raster)
enum StrictSumStatus : ubyte
{
    invalidPlane,
    none,
    accumulatorOverflow
}


/++
    Internal strict-sum result.
+/
package(raster)
struct StrictSumExecutionResult(Accumulator)
{
    StrictSumStatus status =
        StrictSumStatus.invalidPlane;

    Accumulator value =
        cast(Accumulator) 0;


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return status
            == StrictSumStatus.none;
    }
}


private
template isSupportedIntegralAccumulator(T)
{
    enum isSupportedIntegralAccumulator =
        is(T == byte)
        || is(T == ubyte)
        || is(T == short)
        || is(T == ushort)
        || is(T == int)
        || is(T == uint)
        || is(T == long)
        || is(T == ulong);
}


/++
    Checked accumulator addition.

    The caller has already proven that value itself is representable in
    Accumulator.

    The potentially overflowing addition is evaluated only after the
    representability predicate has succeeded.
+/
private
bool tryAddChecked(Accumulator)(
    Accumulator total,
    Accumulator value,
    out Accumulator result
)
@safe
pure
nothrow
@nogc
if (isSupportedIntegralAccumulator!Accumulator)
{
    result =
        cast(Accumulator) 0;

    static if (
        is(Accumulator == ubyte)
        || is(Accumulator == ushort)
        || is(Accumulator == uint)
        || is(Accumulator == ulong)
    )
    {
        if (
            value
            > Accumulator.max - total
        )
        {
            return false;
        }
    }
    else
    {
        if (
            value > 0
            && total
                > Accumulator.max - value
        )
        {
            return false;
        }

        if (
            value < 0
            && total
                < Accumulator.min - value
        )
        {
            return false;
        }
    }

    result =
        cast(Accumulator)(
            total + value
        );

    return true;
}


/++
    Executes one strict logical row-major sum.

    Plane index validation occurs before any pointer formation.

    Empty input returns the additive identity.

    Integer accumulation is checked before each committed addition.
    Floating accumulation performs one Accumulator addition per logical sample
    in exact row-major order.

    Safety:
    - RasterView construction already validated all reachable sample addresses;
    - executionRegionBase() forms the first reachable pointer;
    - signed row/sample strides are retained exactly;
    - pointer advancement occurs only while another logical coordinate exists.
+/
package(raster)
StrictSumExecutionResult!Accumulator executeStrictSum(
    Sample,
    Accumulator
)(
    scope RasterView!Sample source,
    size_t planeIndex
)
@trusted
nothrow
@nogc
{
    StrictSumExecutionResult!Accumulator result;

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

    result.status =
        StrictSumStatus.none;

    if (source.empty)
        return result;

    const(Sample)* row =
        source.executionRegionBase(
            planeIndex
        );

    assert(row !is null);

    Accumulator total =
        cast(Accumulator) 0;

    foreach (y; 0 .. source.height)
    {
        const(Sample)* sample =
            row;

        foreach (x; 0 .. source.width)
        {
            const value =
                cast(Accumulator) *sample;

            static if (
                isSupportedIntegralAccumulator!Accumulator
            )
            {
                Accumulator next;

                static if (is(Accumulator == ulong))
                {
                    // Inline checked addition for the qualified ulong hot path.
                    // Never evaluate the addition after detecting overflow.
                    if (value > ulong.max - total)
                    {
                        result.status =
                            StrictSumStatus.accumulatorOverflow;

                        result.value =
                            cast(Accumulator) 0;

                        return result;
                    }

                    total += value;
                }
                else
                {
                    if (
                        !tryAddChecked(
                            total,
                            value,
                            next
                        )
                    )
                    {
                        result.status =
                            StrictSumStatus.accumulatorOverflow;

                        result.value =
                            cast(Accumulator) 0;

                        return result;
                    }

                    total =
                        next;
                }
            }
            else
            {
                total +=
                    value;
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

    result.value =
        total;

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
 * Universal signed-stride traversal remains logical row-major.
 */
unittest
{
    int[8] storage =
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
        makeRasterViewAssumeValidated!int(
            descriptors[],
            Region2D(0, 0, 2, 2)
        );

    const result =
        executeStrictSum!(
            int,
            long
        )(
            source,
            0
        );

    assert(result.ok);
    assert(result.value == 10);
}


/*
 * Positive signed overflow fails before evaluating the overflowing addition.
 */
unittest
{
    long[2] storage =
        [long.max, 1];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            2,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!long(
            descriptors[],
            Region2D(0, 0, 2, 1)
        );

    const result =
        executeStrictSum!(
            long,
            long
        )(
            source,
            0
        );

    assert(!result.ok);
    assert(
        result.status
        == StrictSumStatus.accumulatorOverflow
    );
    assert(result.value == 0);
}


/*
 * Negative signed overflow is detected as well.
 */
unittest
{
    long[2] storage =
        [long.min, -1];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            2,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!long(
            descriptors[],
            Region2D(0, 0, 2, 1)
        );

    const result =
        executeStrictSum!(
            long,
            long
        )(
            source,
            0
        );

    assert(!result.ok);
    assert(
        result.status
        == StrictSumStatus.accumulatorOverflow
    );
}


/*
 * Unsigned overflow is checked rather than wrapped.
 */
unittest
{
    ulong[2] storage =
        [ulong.max, 1];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            2,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ulong(
            descriptors[],
            Region2D(0, 0, 2, 1)
        );

    const result =
        executeStrictSum!(
            ulong,
            ulong
        )(
            source,
            0
        );

    assert(!result.ok);
    assert(
        result.status
        == StrictSumStatus.accumulatorOverflow
    );
}


/*
 * Floating cancellation proves strict encounter order.
 */
unittest
{
    float[4] storage =
    [
        1.0e20f,
        1.0f,
        -1.0e20f,
        1.0f
    ];

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
        executeStrictSum!(
            float,
            float
        )(
            source,
            0
        );

    assert(result.ok);
    assert(result.value == 1.0f);
}


/*
 * Empty input returns the additive identity before pointer formation.
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
                7
            )
        );

    const result =
        executeStrictSum!(
            double,
            double
        )(
            source,
            0
        );

    assert(result.ok);
    assert(result.value == 0.0);
}

/*
 * Inline ulong path accepts the exact upper boundary and rejects the
 * first subsequent addition without committing wrapped output.
 */
unittest
{
    ulong[3] storage = [ulong.max - 2, 1, 1];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr, 3, 1)
    ];
    scope auto source = makeRasterViewAssumeValidated!ulong(
        descriptors[], Region2D(0, 0, 3, 1)
    );
    const result = executeStrictSum!(ulong, ulong)(source, 0);
    assert(result.ok);
    assert(result.value == ulong.max);
}

unittest
{
    ulong[3] storage = [ulong.max - 2, 2, 1];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr, 3, 1)
    ];
    scope auto source = makeRasterViewAssumeValidated!ulong(
        descriptors[], Region2D(0, 0, 3, 1)
    );
    const result = executeStrictSum!(ulong, ulong)(source, 0);
    assert(!result.ok);
    assert(result.status == StrictSumStatus.accumulatorOverflow);
    assert(result.value == 0);
}

/*
 * Signed row and sample strides retain the same logical iteration.
 */
unittest
{
    ulong[8] storage = [1, 99, 2, 99, 3, 99, 4, 99];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr + 6, -4, -2)
    ];
    scope auto source = makeRasterViewAssumeValidated!ulong(
        descriptors[], Region2D(0, 0, 2, 2)
    );
    const result = executeStrictSum!(ulong, ulong)(source, 0);
    assert(result.ok);
    assert(result.value == 10);
}

} // version (unittest)
