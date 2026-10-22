# Exact 8-bit raster histograms

**Availability:** Unreleased `develop` API, proposed in
[raster-d issue #251](https://github.com/alex-1974/raster-d/issues/251).
This function is **not** part of the published v0.2.0 contract.

`histogram256` counts exact values in one numeric `ubyte` raster plane.
It is independent of image formats, RGB, colour spaces, alpha and NoData.
A result has 256 `ulong` bins, indexed 0 through 255.

## Using an existing raster view

~~~d
import raster;

// source is an already validated, lifetime-bound RasterView!ubyte.
RasterHistogram256Result counts = histogram256(source, planeIndex);

if (counts.ok)
{
    ulong zeroValues = counts.bins[0];
    ulong maximumValues = counts.bins[255];
}
else
{
    // counts.error says invalidPlane or countOverflow.
}
~~~

`source.histogram256(planeIndex)` is the equivalent UFCS call. This
operation does not allocate heap storage or retain the source. It operates
on the *logical* samples of the selected plane regardless of physical
row/sample stride, including planar and interleaved representations.

## Working with a subregion

Form a checked ROI view using the existing `tryRoi` operation:

~~~d
bool ok;
scope auto roi = source.tryRoi(Region2D(12, 8, 128, 64), ok);
if (ok)
{
    auto h = roi.histogram256(planeIndex);
    assert(h.ok); // assuming the selected plane is valid
}
~~~

ROI coordinates are relative to `source`, not global dataset coordinates.
Do not let the borrowed ROI outlive the retained storage.

A valid empty selected plane produces a successful all-zero histogram. An
invalid plane selection fails, even if the source view is empty.

## Counting a streamed or tiled dataset

Each resident window can be counted independently. All windows use the same
exact integer bins, so no normalization or floating arithmetic is needed.

~~~d
ulong[256] totals;

foreach (window; residentWindows)
{
    // Each window is a validated RasterView!ubyte covering a disjoint region.
    const h = window.histogram256(planeIndex);
    if (!h.ok)
    {
        // Handle the error; do not publish partially accumulated totals.
        break;
    }

    foreach (i; 0 .. 256)
    {
        if (h.bins[i] > ulong.max - totals[i])
        {
            // Count overflow: reject the aggregation.
            break;
        }
        totals[i] += h.bins[i];
    }
}
~~~

The loop is an illustration of checked componentwise addition, **not** an
atomic failure-safe whole-dataset aggregator. A consumer requiring atomic
publication accumulates into private working storage and publishes only when
all windows and additions succeeded.

For disjoint windows covering a complete raster, the sum of each bin equals
the corresponding whole-raster bin. The library does not currently provide
a separate histogram-merge API.

## Explicit limitations

This first slice intentionally supports only `RasterView!ubyte`.
It has no configurable numerical intervals, masks, per-sample weights,
floating-point NaN/Inf rules, NoData inference or image-channel semantics.
Those features require separate consumer justification and contracts.
