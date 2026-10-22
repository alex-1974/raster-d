/++
    Generic, caller-buffered numeric interval histograms.

    Unlike histogram256, which counts every ubyte value exactly, this module
    groups values of any supported numeric RasterView sample type into an
    explicitly selected range and number of bins.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
+/
module raster.histogram_into;

import raster.sample : isNumericRasterSample;
import raster.view : RasterView;


/++
    Error categories for a generic interval histogram.

    The error enum defaults to none, while RasterHistogramResult.init is
    deliberately unsuccessful.
+/
enum RasterHistogramError : ubyte
{
    none,
    invalidPlane,
    emptyBins,
    invalidRange,
    countOverflow
}

/// Example distinguishing an invalid range from an invalid plane.
@safe unittest
{
    import raster;
    assert(RasterHistogramError.invalidRange != RasterHistogramError.invalidPlane);
}


/++
    Result of counting a single numeric raster plane into caller-owned bins.

    The histogram bins are not retained in this result: the caller owns the
    destination slice supplied to histogramInto. On success, belowRange and
    aboveRange count values outside the closed requested range; nanCount
    counts floating-point NaNs (zero for integer inputs). Infinite floating
    samples belong to the corresponding out-of-range category.

    On error, all three result counters AND the entire caller-supplied bins
    slice are zero. The default .init state is an invalid-plane failure.
+/
struct RasterHistogramResult
{
    /// Samples strictly below the lower bound, including -Infinity.
    ulong belowRange;

    /// Samples strictly above the upper bound, including +Infinity.
    ulong aboveRange;

    /// NaN samples, for floating-point sources only.
    ulong nanCount;

private:
    RasterHistogramError error_ = RasterHistogramError.invalidPlane;

public:
    /++ The operation's result or error category. +/
    @property
    RasterHistogramError error() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_;
    }

    /// Example reading a default failed result.
    @safe unittest
    {
        import raster;
        RasterHistogramResult result;
        assert(result.error == RasterHistogramError.invalidPlane);
    }

    /++ Whether all counts were produced successfully. +/
    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_ == RasterHistogramError.none;
    }

    /// Example verifying the default result cannot be mistaken for success.
    @safe unittest
    {
        import raster;
        RasterHistogramResult result;
        assert(!result.ok);
        assert(result.belowRange == 0);
        assert(result.aboveRange == 0);
        assert(result.nanCount == 0);
    }
}

/// Example checking the failing default result and zero counts.
@safe unittest
{
    import raster;
    RasterHistogramResult result;
    assert(!result.ok);
    assert(result.error == RasterHistogramError.invalidPlane);
    assert(result.belowRange == 0);
    assert(result.aboveRange == 0);
    assert(result.nanCount == 0);
}


/++
    Counts numeric samples into N equally spaced value intervals.

    The requested domain is the CLOSED interval [lower, upper], with lower
    strictly less than upper. For N = bins.length > 0, every in-range sample
    v is assigned to:

        min(N - 1, floor((v - lower) * N / (upper - lower)))

    Thus each interior bin is left-inclusive and right-exclusive, and the
    final bin also includes upper. Values below lower, above upper and NaNs
    are counted separately in the returned result, never silently dropped.
    Both range endpoints must be finite for float/double. Floating bin
    placement uses double arithmetic, with a scaled calculation when the
    range's direct double difference would overflow. Float/double boundaries
    may round near an interval edge; integer placement is always exact.

    Integral arithmetic does not convert to floating point. The common case
    uses checked-width ulong multiplication. For large 64-bit ranges where
    the product would overflow, an exact quotient/remainder fallback preserves
    bin assignment across the full long/ulong domain.

    Supported samples: byte, ubyte, short, ushort, int, uint, long, ulong,
    float and double (the existing isNumericRasterSample contract).

    Destination ownership:
    - bins is a caller-owned, writable slice. All entries are OVERWRITTEN;
      previous counts are never accumulated.
    - No heap allocation, hidden raster materialization, retained view or
      worker thread is created.
    - Any error zeros the complete bins slice and all result counters. On
      success even a valid empty plane returns all zero counts.
    - Count overflow is detected before traversal by validating that logical
      width * height is representable in ulong. All counters start at zero,
      so no individual counter can then exceed this total.

    Plane and layout semantics match the rest of raster-d: planeIndex is a
    logical plane; source may be a validated ROI and use any validated signed
    row/sample strides, planar or interleaved storage.

    For tiled datasets, only combine histograms with IDENTICAL range endpoints,
    bin count and sample type. Addition is componentwise and must be checked
    for ulong overflow by the consumer.

    Params:
        source = Borrowed validated numeric raster view.
        planeIndex = Zero-based logical plane index.
        lower = Inclusive lower numeric bound.
        upper = Inclusive upper numeric bound, included in the last bin.
        bins = Writable caller-owned output counts; length defines N.

    Returns:
        Explicit success/error and counts below/above range and NaNs.
        Bin counts are returned through the caller-owned bins slice.
+/
RasterHistogramResult histogramInto(T)(
    scope RasterView!T source,
    size_t planeIndex,
    T lower,
    T upper,
    scope ulong[] bins
)
@safe
nothrow
@nogc
if (isNumericRasterSample!T)
{
    RasterHistogramResult result;
    bins[] = 0;

    if (planeIndex >= source.planeCount)
        return result;

    if (bins.length == 0)
    {
        result.error_ = RasterHistogramError.emptyBins;
        return result;
    }

    if (!(lower < upper))
    {
        result.error_ = RasterHistogramError.invalidRange;
        return result;
    }

    static if (is(T == float) || is(T == double))
    {
        // Also reject NaN, +Infinity and -Infinity as histogram bounds.
        if (
            !(lower >= -T.max && lower <= T.max)
            || !(upper >= -T.max && upper <= T.max)
        )
        {
            result.error_ = RasterHistogramError.invalidRange;
            return result;
        }
    }

    // Bounds count the selected logical samples, never the physical span.
    if (
        source.height != 0
        && cast(ulong) source.width > ulong.max / source.height
    )
    {
        result.error_ = RasterHistogramError.countOverflow;
        return result;
    }

    executeIntervalHistogram(
        source, planeIndex, lower, upper, bins, result
    );

    result.error_ = RasterHistogramError.none;
    return result;
}

/// Example calculating a signed elevation histogram using the public importer.
@system unittest
{
    import core.stdc.stdlib : malloc;
    import raster;

    void* memory = malloc(4 * short.sizeof);
    assert(memory !is null);
    (cast(short*) memory)[0 .. 4] = [-100, 0, 50, 100];

    OwnedByteResource owner;
    assert(tryAdoptMallocResource(memory, 4 * short.sizeof, owner));

    const PlaneByteLayout[1] layout = [
        PlaneByteLayout(0, 2 * short.sizeof, short.sizeof)
    ];

    RasterLease!short lease;
    assert(tryImportOwnedRaster!short(
        owner, layout[], Region2D(0, 0, 2, 2), lease
    ).ok);

    scope auto view = lease.view();
    ulong[4] counts;
    const result = view.histogramInto(0, cast(short) -100, cast(short) 100, counts[]);
    assert(result.ok);
    assert(counts == [1UL, 0UL, 1UL, 2UL]);
    assert(result.belowRange == 0 && result.aboveRange == 0);
}


// Integer multiplication/division without overflow or floating rounding.
// Offsets and span are unsigned differences of ordered signed/unsigned
// values, so they correctly cover even [long.min, long.max] and [0, ulong.max].
private
size_t exactIntegralBin(
    ulong offset,
    ulong span,
    size_t binCount
)
@safe
pure
nothrow
@nogc
{
    assert(offset < span && span > 0 && binCount > 0);

    const multiplier = cast(ulong) binCount;

    if (offset <= ulong.max / multiplier)
        return cast(size_t) ((offset * multiplier) / span);

    // Fractional binary multiply: quotient + remainder/span equals
    // offset/span multiplied by each processed prefix of binCount.
    // Remainder additions/subtractions never overflow ulong.
    ulong remainder = 0;
    ulong quotient = 0;
    size_t bit = 1;

    while (bit <= binCount / 2)
        bit <<= 1;

    while (bit != 0)
    {
        quotient <<= 1;

        if (remainder >= span - remainder)
        {
            remainder -= span - remainder;
            ++quotient;
        }
        else
        {
            remainder += remainder;
        }

        if ((binCount & bit) != 0)
        {
            if (remainder >= span - offset)
            {
                remainder -= span - offset;
                ++quotient;
            }
            else
            {
                remainder += offset;
            }
        }

        bit >>= 1;
    }

    assert(quotient < multiplier);
    return cast(size_t) quotient;
}


private
size_t floatingBin(T)(
    T value,
    T lower,
    T upper,
    size_t binCount
)
@safe
pure
nothrow
@nogc
if (is(T == float) || is(T == double))
{
    const x = cast(double) value;
    const lo = cast(double) lower;
    const hi = cast(double) upper;
    const span = hi - lo;

    double fraction;
    if (span <= double.max)
        fraction = (x - lo) / span;
    else
        fraction = (x * 0.5 - lo * 0.5) / (hi * 0.5 - lo * 0.5);

    const scaled = fraction * cast(double) binCount;

    // Inexact arithmetic may round an interior sample onto the top edge.
    if (scaled >= cast(double) binCount)
        return binCount - 1;
    if (scaled <= 0)
        return 0;
    return cast(size_t) scaled;
}


/++
    Trusted traversal of validated signed-stride RasterView storage.
    Only the borrow-validation boundary forms pointers; the public API
    cannot construct an unchecked view. No pointer to storage escapes.
+/
private
void executeIntervalHistogram(T)(
    scope RasterView!T source,
    size_t planeIndex,
    T lower,
    T upper,
    scope ulong[] bins,
    ref RasterHistogramResult result
)
@trusted
nothrow
@nogc
if (isNumericRasterSample!T)
{
    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;

    const valid = source.tryExecutionPlaneStrides(
        planeIndex, rowStride, sampleStride
    );
    assert(valid);

    if (source.empty)
        return;

    const(T)* row = source.executionRegionBase(planeIndex);
    assert(row !is null);

    static if (!(is(T == float) || is(T == double)))
        const span = cast(ulong) upper - cast(ulong) lower;

    foreach (y; 0 .. source.height)
    {
        const(T)* sample = row;

        foreach (x; 0 .. source.width)
        {
            const value = *sample;

            static if (is(T == float) || is(T == double))
            {
                if (value != value)
                {
                    ++result.nanCount;
                }
                else if (value < lower)
                {
                    ++result.belowRange;
                }
                else if (value > upper)
                {
                    ++result.aboveRange;
                }
                else
                {
                    const index = value == upper
                        ? bins.length - 1
                        : floatingBin(value, lower, upper, bins.length);
                    ++bins[index];
                }
            }
            else
            {
                if (value < lower)
                {
                    ++result.belowRange;
                }
                else if (value > upper)
                {
                    ++result.aboveRange;
                }
                else
                {
                    const offset = cast(ulong) value - cast(ulong) lower;
                    const index = value == upper
                        ? bins.length - 1
                        : exactIntegralBin(offset, span, bins.length);
                    ++bins[index];
                }
            }

            if (x + 1 < source.width)
                sample += sampleStride;
        }

        if (y + 1 < source.height)
            row += rowStride;
    }
}


version (unittest)
{
    import raster.descriptor : PlaneDescriptor;
    import raster.region : Region2D;
    import raster.view : makeRasterViewAssumeValidated;
    import std.meta : AliasSeq;

    // All 10 public numeric sample types instantiate and count correctly.
    unittest
    {
        static foreach (Sample; AliasSeq!(
            byte, ubyte, short, ushort, int, uint, long, ulong, float, double
        ))
        {
            Sample[4] values = [
                cast(Sample) 0,
                cast(Sample) 2,
                cast(Sample) 4,
                cast(Sample) 10
            ];
            const PlaneDescriptor[1] planes = [
                PlaneDescriptor(values.ptr, 4, 1)
            ];

            scope auto source = makeRasterViewAssumeValidated!Sample(
                planes[], Region2D(0, 0, 4, 1)
            );
            ulong[5] bins;
            const result = source.histogramInto(
                0, cast(Sample) 0, cast(Sample) 10, bins[]
            );
            assert(result.ok);
            assert(bins == [1UL, 1UL, 1UL, 0UL, 1UL]);
            assert(result.belowRange == 0);
            assert(result.aboveRange == 0);
            assert(result.nanCount == 0);
        }
    }

    // Signed values, range endpoints and both out-of-range categories.
    unittest
    {
        short[8] values = [-100, -10, -5, 0, 5, 10, 100, 300];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(values.ptr, 8, 1)
        ];
        scope auto source = makeRasterViewAssumeValidated!short(
            planes[], Region2D(0, 0, 8, 1)
        );
        ulong[4] bins;
        const result = source.histogramInto(
            0, cast(short) -10, cast(short) 10, bins[]
        );
        assert(result.ok);
        assert(bins == [1UL, 1UL, 1UL, 2UL]);
        assert(result.belowRange == 1);
        assert(result.aboveRange == 2);
        assert(result.nanCount == 0);
    }

    // Wide integral domains must never round through double or overflow.
    unittest
    {
        ulong[5] values = [
            0, 1, ulong.max / 2, ulong.max - 1, ulong.max
        ];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(values.ptr, 5, 1)
        ];
        scope auto source = makeRasterViewAssumeValidated!ulong(
            planes[], Region2D(0, 0, 5, 1)
        );
        ulong[4] bins;
        const result = source.histogramInto(
            0, 0UL, ulong.max, bins[]
        );
        assert(result.ok);
        assert(bins == [2UL, 1UL, 0UL, 2UL]);
    }

    unittest
    {
        long[4] values = [long.min, -1, 0, long.max];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(values.ptr, 4, 1)
        ];
        scope auto source = makeRasterViewAssumeValidated!long(
            planes[], Region2D(0, 0, 4, 1)
        );
        ulong[4] bins;
        const result = source.histogramInto(
            0, long.min, long.max, bins[]
        );
        assert(result.ok);
        assert(bins == [1UL, 1UL, 1UL, 1UL]);
    }

    // Test the fallback's exact boundaries against an independent tiny oracle.
    unittest
    {
        const span = ulong.max;
        foreach (n; 2 .. 18)
        {
            foreach (offset; [
                0UL, 1UL, ulong.max / 4, ulong.max / 2,
                ulong.max - 2, ulong.max - 1
            ])
            {
                const expected = cast(size_t)(
                    cast(double) offset * cast(double) n
                    / cast(double) span
                );
                const calculated = exactIntegralBin(
                    offset, span, n
                );

                // Floating oracle is used only for coarse interior points;
                // the integer result always stays within valid range.
                assert(calculated < n);
                if (
                    offset == 0 || offset == 1
                    || offset == ulong.max - 2 || offset == ulong.max - 1
                )
                    continue;
                assert(calculated == expected || calculated + 1 == expected
                    || expected + 1 == calculated);
            }
        }

        // Exact mathematical boundary: floor((2^64 - 2) * 3 / (2^64 - 1)) = 2.
        assert(exactIntegralBin(ulong.max - 1, ulong.max, 3) == 2);
        assert(exactIntegralBin(ulong.max / 2, ulong.max, 2) == 0);
    }

    // Signed negative strides and ROI decomposition with same bin policy.
    unittest
    {
        int[8] values = [0, 99, 2, 99, 4, 99, 6, 99];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(values.ptr + 6, -4, -2)
        ];
        scope auto source = makeRasterViewAssumeValidated!int(
            planes[], Region2D(0, 0, 2, 2)
        );

        ulong[4] whole;
        const all = source.histogramInto(0, 0, 6, whole[]);
        assert(all.ok);
        assert(whole == [1UL, 1UL, 1UL, 1UL]);

        bool ok;
        scope auto left = source.tryRoi(Region2D(0, 0, 1, 2), ok);
        assert(ok);
        scope auto right = source.tryRoi(Region2D(1, 0, 1, 2), ok);
        assert(ok);

        ulong[4] a;
        ulong[4] b;
        assert(left.histogramInto(0, 0, 6, a[]).ok);
        assert(right.histogramInto(0, 0, 6, b[]).ok);
        foreach (i; 0 .. 4)
            assert(whole[i] == a[i] + b[i]);
    }

    // Three-plane planar and interleaved implementations agree.
    unittest
    {
        ubyte[6] planar = [0, 2, 10, 20, 40, 60];
        ubyte[6] interleaved = [0, 10, 40, 2, 20, 60];
        const PlaneDescriptor[3] p = [
            PlaneDescriptor(planar.ptr, 2, 1),
            PlaneDescriptor(planar.ptr + 2, 2, 1),
            PlaneDescriptor(planar.ptr + 4, 2, 1)
        ];
        const PlaneDescriptor[3] i = [
            PlaneDescriptor(interleaved.ptr, 6, 3),
            PlaneDescriptor(interleaved.ptr + 1, 6, 3),
            PlaneDescriptor(interleaved.ptr + 2, 6, 3)
        ];
        scope auto a = makeRasterViewAssumeValidated!ubyte(
            p[], Region2D(0, 0, 2, 1)
        );
        scope auto b = makeRasterViewAssumeValidated!ubyte(
            i[], Region2D(0, 0, 2, 1)
        );
        foreach (plane; 0 .. 3)
        {
            ulong[4] aa;
            ulong[4] bb;
            assert(a.histogramInto(plane, cast(ubyte) 0,
                cast(ubyte) 60, aa[]).ok);
            assert(b.histogramInto(plane, cast(ubyte) 0,
                cast(ubyte) 60, bb[]).ok);
            assert(aa == bb);
        }
    }

    // Floating NaN, infinities, range boundaries, and extreme finite range.
    unittest
    {
        static foreach (Sample; AliasSeq!(float, double))
        {
            Sample[8] values = [
                -Sample.infinity, cast(Sample) -10,
                cast(Sample) -5, cast(Sample) 0,
                cast(Sample) 5, cast(Sample) 10,
                Sample.infinity, Sample.nan
            ];
            const PlaneDescriptor[1] planes = [
                PlaneDescriptor(values.ptr, 8, 1)
            ];
            scope auto source = makeRasterViewAssumeValidated!Sample(
                planes[], Region2D(0, 0, 8, 1)
            );
            ulong[4] bins;
            const result = source.histogramInto(
                0, cast(Sample) -10, cast(Sample) 10, bins[]
            );
            assert(result.ok);
            assert(bins == [1UL, 1UL, 1UL, 2UL]);
            assert(result.belowRange == 1);
            assert(result.aboveRange == 1);
            assert(result.nanCount == 1);
        }
    }

    unittest
    {
        double[3] values = [-double.max, 0.0, double.max];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(values.ptr, 3, 1)
        ];
        scope auto source = makeRasterViewAssumeValidated!double(
            planes[], Region2D(0, 0, 3, 1)
        );
        ulong[2] bins;
        const result = source.histogramInto(
            0, -double.max, double.max, bins[]
        );
        assert(result.ok);
        assert(bins == [1UL, 2UL]);
    }

    // Input errors zero all destination counts, including stale ones.
    unittest
    {
        ubyte[2] values = [2, 3];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(values.ptr, 2, 1)
        ];
        scope auto source = makeRasterViewAssumeValidated!ubyte(
            planes[], Region2D(0, 0, 2, 1)
        );

        ulong[2] counts = [77, 88];
        auto r = source.histogramInto(
            7, cast(ubyte) 0, cast(ubyte) 10, counts[]
        );
        assert(!r.ok && r.error == RasterHistogramError.invalidPlane);
        assert(counts == [0UL, 0UL]);

        counts[] = 9;
        r = source.histogramInto(0, cast(ubyte) 10,
            cast(ubyte) 10, counts[]);
        assert(!r.ok && r.error == RasterHistogramError.invalidRange);
        assert(counts == [0UL, 0UL]);

        r = source.histogramInto(0, cast(ubyte) 0,
            cast(ubyte) 10, counts[0 .. 0]);
        assert(!r.ok && r.error == RasterHistogramError.emptyBins);

        ulong[2] missing = [1, 2];
        // NaN and infinite bounds are invalid even for a valid plane.
        float[1] floatData;
        const PlaneDescriptor[1] fp = [
            PlaneDescriptor(floatData.ptr, 1, 1)
        ];
        scope auto floats = makeRasterViewAssumeValidated!float(
            fp[], Region2D(0, 0, 1, 1)
        );
        auto invalid = floats.histogramInto(
            0, float.nan, 10.0f, missing[]
        );
        assert(invalid.error == RasterHistogramError.invalidRange);
        assert(missing == [0UL, 0UL]);

        invalid = floats.histogramInto(
            0, -float.infinity, 10.0f, missing[]
        );
        assert(invalid.error == RasterHistogramError.invalidRange);
    }

    // Valid empty views never dereference their descriptor.
    unittest
    {
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(null, ptrdiff_t.min, ptrdiff_t.min)
        ];
        scope auto source = makeRasterViewAssumeValidated!int(
            planes[], Region2D(size_t.max, size_t.max, 0, 3)
        );

        ulong[3] bins = [9, 9, 9];
        const result = source.histogramInto(0, -1, 10, bins[]);
        assert(result.ok);
        assert(bins == [0UL, 0UL, 0UL]);
    }

    // Logical sample count overflow is rejected before pointer formation.
    static if (size_t.sizeof == 8)
    unittest
    {
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(null, 1, 1)
        ];
        // Synthetic non-dereference fixture: the area check precedes access.
        scope auto source = makeRasterViewAssumeValidated!ulong(
            planes[], Region2D(0, 0, size_t.max, 2)
        );
        ulong[2] bins = [4, 5];
        const result = source.histogramInto(0, 0UL, 10UL, bins[]);
        assert(!result.ok);
        assert(result.error == RasterHistogramError.countOverflow);
        assert(bins == [0UL, 0UL]);
    }
} // version (unittest)
