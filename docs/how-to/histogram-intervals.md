# Numeric interval histograms

**Availability:** Unreleased feature-branch candidate for
[raster-d issue #251](https://github.com/alex-1974/raster-d/issues/251).
It is not part of the immutable v0.2.0 release.

Use `histogramInto` to group samples of a numeric raster plane into a
caller-defined number of equally spaced bins. Unlike
[`histogram256`](histogram256.md), this works with `byte`, `ubyte`,
`short`, `ushort`, `int`, `uint`, `long`, `ulong`,
`float` and `double`.

## Elevation example

Assume `elevation` is a borrowed, validated `RasterView!short`
covering the resident elevation samples.

~~~d
import raster;

ulong[100] counts;

// Heights -500..4500, 100 equally spaced intervals.
// This call overwrites all 100 caller-owned counters.
const result = elevation.histogramInto(
    0, cast(short) -500, cast(short) 4500, counts[]
);

if (result.ok)
{
    // counts[0..100] contain exact sample frequencies per interval.
    // Samples outside the requested range have separate counts.
    ulong low = result.belowRange;
    ulong high = result.aboveRange;
}
~~~

No heap allocation, channel interpretation, mask or NoData inference occurs.

## Exact interval definition

The numerical domain is **[lower, upper]**, including both endpoints,
with `lower < upper` and a nonempty destination slice.

For `N = counts.length`, an in-range value `v` goes to:

`min(N - 1, floor((v - lower) * N / (upper - lower)))`.

All but the final interval are left-inclusive, right-exclusive; the
final interval **also includes `upper`**. This deliberately supports
a highest integral sample equal to `long.max` or `ulong.max`,
which could not be represented as an exclusive upper bound of its type.

For example, interval `[0, 10]` with 5 bins has:

| Bin | Integer values |
| --- | --- |
| 0 | 0, 1 |
| 1 | 2, 3 |
| 2 | 4, 5 |
| 3 | 6, 7 |
| 4 | 8, 9, **10** |

`byte` through `ulong` and `long` use exact integer mapping, even at
64-bit limits: **no double conversion or rounding for integer types**.
Floating types use double arithmetic, including a scaled computation for
ranges whose direct double width would overflow. A sample very close to
a bin boundary may map differently from exact real arithmetic due to
floating rounding.

For floating rasters, both requested bounds must be finite. Samples at
`-Infinity` count as `belowRange`, at `+Infinity` as
`aboveRange`, and all NaNs as `nanCount`. These categories do not
reduce the bin counts.

## Failures, empty rasters and buffers

The `RasterHistogramResult` contains `ok`, `error`,
`belowRange`, `aboveRange` and `nanCount`; the actual bins remain
in the caller-owned slice.

Possible errors: `invalidPlane`, `emptyBins`, `invalidRange`, and
`countOverflow`. `RasterHistogramResult.init` is a failure.
A valid empty raster succeeds with zero counts.

The complete destination is **overwritten**, not incremented. On any
error its bins and all three result counters are set to zero, so a
partial or stale histogram cannot be mistaken for success.

## ROIs and tiled data

An existing view can produce a zero-copy ROI through `tryRoi`.
Each non-overlapping tile can use the same bounds and destination length.
The full-raster counts then equal the checked componentwise sum of the
per-tile results, including the three out-of-range/NaN categories.

The caller must check `ulong` overflow when aggregating results across
tiles. The histogram function itself validates that the selected logical
area fits in `ulong` before accessing any sample. There is no
separate merge operation and no implicit parallel scheduling.

The histogram operation works with all validated plane layouts, including
planar/interleaved, row padding and negative strides.

## Scope and ownership

`histogram256` remains the optimal fixed-domain special case for exact
8-bit frequency counting. `histogramInto` handles configurable equal-width
intervals for the broader numeric family. It does not implement sparse exact
label maps, logarithmic binning, weights, validity masks or image-specific
metadata. Such semantics require specific consumers and separate contracts.
