/++
    Public raster reduction operations.

    This module exposes semantic operations only. Execution-layout
    classification, Mir adaptation, fixed-lane reduction graphs and kernel
    dispatch remain package-internal.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-05
+/
module raster.reduction;

import raster.internal.reduction_dispatch :
    tryStrictFloatToDoubleSum;

import raster.internal.strict_sum :
    StrictSumStatus,
    executeStrictSum;

import raster.view :
    RasterView;


/++
    Failure category for the v0.2 generic strict sum family.
+/
enum RasterSumError : ubyte
{
    none,

    invalidPlane,

    accumulatorOverflow
}


/++
    Result carrier for one generic strict raster sum.

    The default state is deliberately unsuccessful.

    value is meaningful only when ok is true. Failed results expose the additive
    identity in value so no partial accumulation escapes as if it were complete.
+/
struct RasterSumResult(Accumulator)
if (isSupportedSumAccumulator!Accumulator)
{
private:
    RasterSumError error_ =
        RasterSumError.invalidPlane;

    Accumulator value_ =
        cast(Accumulator) 0;

public:

    @property
    RasterSumError error() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_;
    }


    @property
    Accumulator value() const
    @safe
    pure
    nothrow
    @nogc
    {
        return value_;
    }


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_
            == RasterSumError.none;
    }
}


/++
    Whether T is one explicitly supported integer sum sample/accumulator type.
+/
private
template isSupportedSumInteger(T)
{
    enum isSupportedSumInteger =
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
    Whether T is one explicitly supported floating sum sample/accumulator type.

    real is deliberately excluded because it is not one portable precision.
+/
private
template isSupportedSumFloating(T)
{
    enum isSupportedSumFloating =
        is(T == float)
        || is(T == double);
}


private
template isSupportedSumAccumulator(T)
{
    enum isSupportedSumAccumulator =
        isSupportedSumInteger!T
        || isSupportedSumFloating!T;
}


private
template isSignedSumInteger(T)
{
    enum isSignedSumInteger =
        is(T == byte)
        || is(T == short)
        || is(T == int)
        || is(T == long);
}


/++
    Whether every possible Sample value is exactly representable in
    Accumulator and both belong to the same numeric family.

    Integer rules:
    - signed -> signed: accumulator width must be at least sample width;
    - signed -> unsigned: rejected because negative Sample values exist;
    - unsigned -> unsigned: accumulator width must be at least sample width;
    - unsigned -> signed: accumulator must be strictly wider.

    Floating rules:
    - float -> float;
    - float -> double;
    - double -> double.

    Integer/floating cross-family accumulation is deliberately excluded.
+/
private
template isSupportedRasterSumPair(
    Sample,
    Accumulator
)
{
    static if (
        isSupportedSumInteger!Sample
        && isSupportedSumInteger!Accumulator
    )
    {
        static if (isSignedSumInteger!Sample)
        {
            enum isSupportedRasterSumPair =
                isSignedSumInteger!Accumulator
                && Sample.sizeof
                    <= Accumulator.sizeof;
        }
        else static if (isSignedSumInteger!Accumulator)
        {
            enum isSupportedRasterSumPair =
                Sample.sizeof
                < Accumulator.sizeof;
        }
        else
        {
            enum isSupportedRasterSumPair =
                Sample.sizeof
                <= Accumulator.sizeof;
        }
    }
    else static if (
        isSupportedSumFloating!Sample
        && isSupportedSumFloating!Accumulator
    )
    {
        enum isSupportedRasterSumPair =
            (is(Sample == float)
                && (
                    is(Accumulator == float)
                    || is(Accumulator == double)
                ))
            || (
                is(Sample == double)
                && is(Accumulator == double)
            );
    }
    else
    {
        enum isSupportedRasterSumPair =
            false;
    }
}


private
RasterSumResult!Accumulator successfulSumResult(Accumulator)(
    Accumulator value
)
@safe
pure
nothrow
@nogc
if (isSupportedSumAccumulator!Accumulator)
{
    RasterSumResult!Accumulator result;

    result.error_ =
        RasterSumError.none;

    result.value_ =
        value;

    return result;
}


private
RasterSumResult!Accumulator failedSumResult(Accumulator)(
    RasterSumError error
)
@safe
pure
nothrow
@nogc
if (isSupportedSumAccumulator!Accumulator)
{
    RasterSumResult!Accumulator result;

    result.error_ =
        error;

    return result;
}


/++
    Strictly sums one selected logical raster plane into an explicitly selected
    accumulator type.

    Call forms:

        auto result = sum!double(source, planeIndex);
        auto result = source.sum!double(planeIndex);

    Accumulator selection is mandatory. There is no implicit default widening.

    Legal Sample -> Accumulator pairs require every possible Sample value to be
    exactly representable in Accumulator.

    Integer samples and accumulators:

    - signed -> signed when Accumulator is at least as wide;
    - unsigned -> unsigned when Accumulator is at least as wide;
    - unsigned -> signed only when Accumulator is strictly wider;
    - signed -> unsigned is rejected.

    Floating samples and accumulators:

    - float -> float;
    - float -> double;
    - double -> double.

    Integer/floating cross-family accumulation and real are rejected.

    Numerical semantics:

    - logical traversal is strict row-major order;
    - integer addition is checked before commit and fails on accumulator
      overflow;
    - floating addition uses ordinary D/IEEE arithmetic in Accumulator;
    - NaN and infinity participate normally;
    - valid empty input succeeds with the additive identity;
    - invalid plane selection fails;
    - failure never exposes a partial sum as the result value.

    Physical layout does not change logical order. All validated resident signed
    affine layouts are semantically supported.

    The operation allocates nothing, retains no source, and performs no hidden
    parallel/tree reassociation.

    The float -> double specialization reuses the already-qualified v0.1 strict
    engine so the generic API does not regress that established path.
+/
RasterSumResult!Accumulator sum(
    Accumulator,
    Sample
)(
    scope RasterView!Sample source,
    size_t planeIndex
)
@safe
nothrow
@nogc
if (
    isSupportedRasterSumPair!(
        Sample,
        Accumulator
    )
)
{
    static if (
        is(Sample == float)
        && is(Accumulator == double)
    )
    {
        double value;

        if (
            !tryStrictFloatToDoubleSum(
                source,
                planeIndex,
                value
            )
        )
        {
            return failedSumResult!Accumulator(
                RasterSumError.invalidPlane
            );
        }

        return successfulSumResult!Accumulator(
            value
        );
    }
    else
    {
        const execution =
            executeStrictSum!(
                Sample,
                Accumulator
            )(
                source,
                planeIndex
            );

        final switch (execution.status)
        {
            case StrictSumStatus.invalidPlane:
                return failedSumResult!Accumulator(
                    RasterSumError.invalidPlane
                );

            case StrictSumStatus.none:
                return successfulSumResult!Accumulator(
                    execution.value
                );

            case StrictSumStatus.accumulatorOverflow:
                return failedSumResult!Accumulator(
                    RasterSumError.accumulatorOverflow
                );
        }
    }
}


/// Example compiling ordinary and UFCS generic strict sum forms.
@safe unittest
{
    import raster;

    RasterView!float source;

    const ordinary =
        sum!double(
            source,
            0
        );

    const ufcs =
        source.sum!double(
            0
        );

    assert(!ordinary.ok);
    assert(!ufcs.ok);

    assert(
        ordinary.error
        == RasterSumError.invalidPlane
    );

    assert(ufcs.error == ordinary.error);
}

/++
    Sums one logical `float` plane into a `double` result using the strict
    row-major reduction semantic.

    All validated resident layouts are semantically supported. A valid empty
    plane succeeds with `sum == 0.0`.

    Returns false only when `planeIndex` does not select a logical source
    plane. On failure `sum` is reset to `0.0`.

    The operation is allocation-free and does not retain `source`.
+/
bool trySumFloatToDouble(
    scope RasterView!float source,
    size_t planeIndex,
    out double sum
)
@safe
nothrow
@nogc
{
    return tryStrictFloatToDoubleSum(
        source,
        planeIndex,
        sum
    );
}

/// Example observing failure and output reset for an invalid plane.
@safe unittest
{
    import raster;
    RasterView!float source;
    double sum = 42.0;
    assert(!trySumFloatToDouble(source, 0, sum));
    assert(sum == 0.0);
}


version (unittest)
{
import raster.descriptor : PlaneDescriptor;
import raster.region : Region2D;
import raster.view : makeRasterViewAssumeValidated;

unittest
{
    float[6] storage = [1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr, 3, 2)
    ];

    scope auto source = makeRasterViewAssumeValidated!float(
        descriptors[],
        Region2D(0, 0, 2, 2)
    );

    double sum = -1.0;
    assert(trySumFloatToDouble(source, 0, sum));
    assert(sum == 14.0);
}

unittest
{
    float[1] storage = [42.0f];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr, 1, 1)
    ];

    scope auto source = makeRasterViewAssumeValidated!float(
        descriptors[],
        Region2D(0, 0, 0, 1)
    );

    double sum = -1.0;
    assert(trySumFloatToDouble(source, 0, sum));
    assert(sum == 0.0);
}

unittest
{
    float[1] storage = [7.0f];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr, 1, 1)
    ];

    scope auto source = makeRasterViewAssumeValidated!float(
        descriptors[],
        Region2D(0, 0, 1, 1)
    );

    double sum = 123.0;
    assert(!trySumFloatToDouble(source, 1, sum));
    assert(sum == 0.0);
}



/*
 * Generic float -> double must be exactly equivalent to the frozen v0.1
 * strict operation, including cancellation order.
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

    double legacy;
    assert(
        trySumFloatToDouble(
            source,
            0,
            legacy
        )
    );

    const generic =
        source.sum!double(
            0
        );

    assert(generic.ok);
    assert(generic.value == legacy);
    assert(generic.value == 1.0);
}


/*
 * Widened unsigned integer accumulation succeeds exactly.
 */
unittest
{
    uint[4] storage =
        [uint.max, 1, 2, 3];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            4,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!uint(
            descriptors[],
            Region2D(0, 0, 4, 1)
        );

    const result =
        source.sum!ulong(
            0
        );

    assert(result.ok);
    assert(
        result.value
        == cast(ulong) uint.max + 6UL
    );
}


/*
 * Widened signed integer accumulation succeeds exactly across signed strides.
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
        source.sum!long(
            0
        );

    assert(result.ok);
    assert(result.value == 10);
}


/*
 * Same-width integer accumulation is legal but runtime overflow is explicit.
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
        source.sum!long(
            0
        );

    assert(!result.ok);

    assert(
        result.error
        == RasterSumError.accumulatorOverflow
    );

    assert(result.value == 0);
}


/*
 * Floating NaN participates as ordinary strict IEEE arithmetic.
 */
unittest
{
    float[3] storage =
        [1.0f, float.nan, 2.0f];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            3,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            descriptors[],
            Region2D(0, 0, 3, 1)
        );

    const result =
        source.sum!double(
            0
        );

    assert(result.ok);
    assert(result.value != result.value);
}


/*
 * Empty generic sum succeeds with the additive identity.
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
        makeRasterViewAssumeValidated!ushort(
            descriptors[],
            Region2D(
                size_t.max,
                size_t.max,
                0,
                5
            )
        );

    const result =
        source.sum!ulong(
            0
        );

    assert(result.ok);
    assert(result.value == 0);
}


/*
 * Invalid plane is explicit and does not masquerade as a successful zero sum.
 */
unittest
{
    uint[1] storage = [7];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            1,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!uint(
            descriptors[],
            Region2D(0, 0, 1, 1)
        );

    const result =
        source.sum!ulong(
            1
        );

    assert(!result.ok);

    assert(
        result.error
        == RasterSumError.invalidPlane
    );
}


/*
 * Public compile-contract matrix.
 *
 * Use typeof(expression) rather than a statement block. __traits(compiles,
 * { ... }) checks the block as a maximally inferred anonymous function and can
 * accidentally impose pure on a callable that does not claim it. The contract
 * here is template instantiability, not an unstated purity promise.
 */
static assert(
    __traits(
        compiles,
        typeof(
            RasterView!ubyte.init.sum!ushort(0)
        )
    )
);

static assert(
    __traits(
        compiles,
        typeof(
            RasterView!uint.init.sum!ulong(0)
        )
    )
);

static assert(
    __traits(
        compiles,
        typeof(
            RasterView!ushort.init.sum!int(0)
        )
    )
);

static assert(
    __traits(
        compiles,
        typeof(
            RasterView!int.init.sum!long(0)
        )
    )
);

static assert(
    __traits(
        compiles,
        typeof(
            RasterView!float.init.sum!float(0)
        )
    )
);

static assert(
    __traits(
        compiles,
        typeof(
            RasterView!float.init.sum!double(0)
        )
    )
);

static assert(
    __traits(
        compiles,
        typeof(
            RasterView!double.init.sum!double(0)
        )
    )
);

static assert(
    !__traits(
        compiles,
        typeof(
            RasterView!long.init.sum!ulong(0)
        )
    )
);

static assert(
    !__traits(
        compiles,
        typeof(
            RasterView!ulong.init.sum!long(0)
        )
    )
);

static assert(
    !__traits(
        compiles,
        typeof(
            RasterView!double.init.sum!float(0)
        )
    )
);

static assert(
    !__traits(
        compiles,
        typeof(
            RasterView!int.init.sum!double(0)
        )
    )
);

static assert(
    !__traits(
        compiles,
        typeof(
            RasterView!real.init.sum!real(0)
        )
    )
);


} // version (unittest)
