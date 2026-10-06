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

import raster.internal.extrema :
    ExtremaMode,
    ExtremaStatus,
    executeExtrema;

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
    Common failure category for min, max and minMax reductions.

    NaN is not a failure. A non-empty floating input containing NaN succeeds
    with a NaN extrema result according to the M3.1 contract.
+/
enum RasterExtremaError : ubyte
{
    none,

    invalidPlane,

    emptyInput
}


/++
    Result carrier for one min or max reduction.

    The default state is deliberately unsuccessful.

    value is meaningful only when ok is true.
+/
struct RasterExtremaResult(T)
if (isSupportedExtremaSample!T)
{
private:
    RasterExtremaError error_ =
        RasterExtremaError.invalidPlane;

    T value_ =
        T.init;

public:

    @property
    RasterExtremaError error() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_;
    }


    @property
    T value() const
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
            == RasterExtremaError.none;
    }
}


/++
    Result carrier for one one-pass minMax reduction.

    minimum and maximum are meaningful only when ok is true.
+/
struct RasterMinMaxResult(T)
if (isSupportedExtremaSample!T)
{
private:
    RasterExtremaError error_ =
        RasterExtremaError.invalidPlane;

    T minimum_ =
        T.init;

    T maximum_ =
        T.init;

public:

    @property
    RasterExtremaError error() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_;
    }


    @property
    T minimum() const
    @safe
    pure
    nothrow
    @nogc
    {
        return minimum_;
    }


    @property
    T maximum() const
    @safe
    pure
    nothrow
    @nogc
    {
        return maximum_;
    }


    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_
            == RasterExtremaError.none;
    }
}


private
template isSupportedExtremaSample(T)
{
    enum isSupportedExtremaSample =
        is(T == byte)
        || is(T == ubyte)
        || is(T == short)
        || is(T == ushort)
        || is(T == int)
        || is(T == uint)
        || is(T == long)
        || is(T == ulong)
        || is(T == float)
        || is(T == double);
}


private
RasterExtremaError publicExtremaError(
    ExtremaStatus status
)
@safe
pure
nothrow
@nogc
{
    final switch (status)
    {
        case ExtremaStatus.none:
            return RasterExtremaError.none;

        case ExtremaStatus.invalidPlane:
            return RasterExtremaError.invalidPlane;

        case ExtremaStatus.emptyInput:
            return RasterExtremaError.emptyInput;
    }
}


private
RasterExtremaResult!T extremaResult(T)(
    ExtremaStatus status,
    T value
)
@safe
pure
nothrow
@nogc
if (isSupportedExtremaSample!T)
{
    RasterExtremaResult!T result;

    result.error_ =
        publicExtremaError(status);

    if (status == ExtremaStatus.none)
    {
        result.value_ =
            value;
    }

    return result;
}


private
RasterMinMaxResult!T minMaxResult(T)(
    ExtremaStatus status,
    T minimum,
    T maximum
)
@safe
pure
nothrow
@nogc
if (isSupportedExtremaSample!T)
{
    RasterMinMaxResult!T result;

    result.error_ =
        publicExtremaError(status);

    if (status == ExtremaStatus.none)
    {
        result.minimum_ =
            minimum;

        result.maximum_ =
            maximum;
    }

    return result;
}


/++
    Returns the minimum sample of one selected logical raster plane.

    Supported sample types are:

        byte, ubyte, short, ushort, int, uint, long, ulong, float, double

    real and non-numeric representation-only Raster sample types are rejected at
    compile time.

    A valid empty selected plane fails with RasterExtremaError.emptyInput.

    Floating semantics:

    - if any logical sample is NaN, the operation succeeds with a NaN value;
    - infinities participate as ordinary ordered floating values;
    - when both signed zeros occur, the minimum is -0 independent of encounter
      order.

    All validated resident signed affine layouts are semantically equivalent.
    The operation allocates nothing and retains no source.
+/
RasterExtremaResult!T min(T)(
    scope RasterView!T source,
    size_t planeIndex
)
@safe
nothrow
@nogc
if (isSupportedExtremaSample!T)
{
    const execution =
        executeExtrema!(
            ExtremaMode.minimum,
            T
        )(
            source,
            planeIndex
        );

    return extremaResult(
        execution.status,
        execution.minimum
    );
}


/++
    Returns the maximum sample of one selected logical raster plane.

    Supported sample types and failure semantics match min().

    Floating semantics:

    - if any logical sample is NaN, the operation succeeds with a NaN value;
    - infinities participate as ordinary ordered floating values;
    - when both signed zeros occur, the maximum is +0 independent of encounter
      order.

    All validated resident signed affine layouts are semantically equivalent.
    The operation allocates nothing and retains no source.
+/
RasterExtremaResult!T max(T)(
    scope RasterView!T source,
    size_t planeIndex
)
@safe
nothrow
@nogc
if (isSupportedExtremaSample!T)
{
    const execution =
        executeExtrema!(
            ExtremaMode.maximum,
            T
        )(
            source,
            planeIndex
        );

    return extremaResult(
        execution.status,
        execution.maximum
    );
}


/++
    Returns both minimum and maximum of one selected logical raster plane.

    minMax performs one logical pass.

    Its minimum and maximum are semantically identical to separate min() and
    max() calls over the same logical samples, including NaN propagation,
    infinities and signed-zero tie handling.

    Empty input fails with RasterExtremaError.emptyInput.

    All validated resident signed affine layouts are semantically equivalent.
    The operation allocates nothing and retains no source.
+/
RasterMinMaxResult!T minMax(T)(
    scope RasterView!T source,
    size_t planeIndex
)
@safe
nothrow
@nogc
if (isSupportedExtremaSample!T)
{
    const execution =
        executeExtrema!(
            ExtremaMode.minMax,
            T
        )(
            source,
            planeIndex
        );

    return minMaxResult(
        execution.status,
        execution.minimum,
        execution.maximum
    );
}


/// Example compiling ordinary and UFCS extrema forms.
@safe unittest
{
    import raster;

    RasterView!float source;

    const ordinary =
        min(
            source,
            0
        );

    const ufcs =
        source.max(
            0
        );

    const pair =
        source.minMax(
            0
        );

    assert(!ordinary.ok);
    assert(!ufcs.ok);
    assert(!pair.ok);

    assert(
        ordinary.error
        == RasterExtremaError.invalidPlane
    );

    assert(ufcs.error == ordinary.error);
    assert(pair.error == ordinary.error);
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




/*
 * Integer extrema and one-pass minMax agree.
 */
unittest
{
    int[6] storage =
        [7, -2, 9, 4, -8, 5];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            3,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!int(
            descriptors[],
            Region2D(0, 0, 3, 2)
        );

    const minimum =
        source.min(0);

    const maximum =
        source.max(0);

    const pair =
        source.minMax(0);

    assert(minimum.ok);
    assert(maximum.ok);
    assert(pair.ok);

    assert(minimum.value == -8);
    assert(maximum.value == 9);
    assert(pair.minimum == minimum.value);
    assert(pair.maximum == maximum.value);
}


/*
 * Signed row/sample strides do not alter logical extrema.
 */
unittest
{
    short[8] storage =
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
        makeRasterViewAssumeValidated!short(
            descriptors[],
            Region2D(0, 0, 2, 2)
        );

    const pair =
        source.minMax(0);

    assert(pair.ok);
    assert(pair.minimum == -3);
    assert(pair.maximum == 8);
}


/*
 * Empty is an explicit failure distinct from invalid plane.
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
        source.minMax(0);

    const invalidResult =
        source.minMax(1);

    assert(!emptyResult.ok);
    assert(!invalidResult.ok);

    assert(
        emptyResult.error
        == RasterExtremaError.emptyInput
    );

    assert(
        invalidResult.error
        == RasterExtremaError.invalidPlane
    );
}


/*
 * Any NaN produces successful NaN extrema and is not interpreted as missing
 * data.
 */
unittest
{
    double[4] storage =
        [4.0, -2.0, double.nan, 9.0];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            4,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!double(
            descriptors[],
            Region2D(0, 0, 4, 1)
        );

    const minimum =
        source.min(0);

    const maximum =
        source.max(0);

    const pair =
        source.minMax(0);

    assert(minimum.ok);
    assert(maximum.ok);
    assert(pair.ok);

    assert(minimum.value != minimum.value);
    assert(maximum.value != maximum.value);
    assert(pair.minimum != pair.minimum);
    assert(pair.maximum != pair.maximum);
}


/*
 * Signed zero is order independent for separate and combined extrema.
 */
unittest
{
    import std.math : signbit;

    float[2] storage =
        [+0.0f, -0.0f];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            2,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            descriptors[],
            Region2D(0, 0, 2, 1)
        );

    const minimum =
        source.min(0);

    const maximum =
        source.max(0);

    const pair =
        source.minMax(0);

    assert(minimum.ok);
    assert(maximum.ok);
    assert(pair.ok);

    assert(signbit(minimum.value));
    assert(!signbit(maximum.value));

    assert(signbit(pair.minimum));
    assert(!signbit(pair.maximum));
}


/*
 * Infinities remain ordinary ordered values.
 */
unittest
{
    double[3] storage =
        [
            -double.infinity,
            3.0,
            double.infinity
        ];

    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(
            storage.ptr,
            3,
            1
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!double(
            descriptors[],
            Region2D(0, 0, 3, 1)
        );

    const pair =
        source.minMax(0);

    assert(pair.ok);
    assert(pair.minimum == -double.infinity);
    assert(pair.maximum == double.infinity);
}


/*
 * Public sample constraints are explicit compile contracts.
 *
 * Probe the instantiated function symbol rather than calling through
 * RasterView!T.init. The latter introduces a temporary-scope/lifetime question
 * that is unrelated to whether the public template itself is legal for T.
 */
static assert(
    __traits(
        compiles,
        &min!ubyte
    )
);

static assert(
    __traits(
        compiles,
        &max!long
    )
);

static assert(
    __traits(
        compiles,
        &minMax!float
    )
);

static assert(
    __traits(
        compiles,
        &minMax!double
    )
);

static assert(
    !__traits(
        compiles,
        &min!real
    )
);

private
struct ExtremaPairSample
{
    int x;
    int y;
}

static assert(
    !__traits(
        compiles,
        &minMax!ExtremaPairSample
    )
);


} // version (unittest)
