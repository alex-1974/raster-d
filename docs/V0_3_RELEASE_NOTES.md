# raster-d v0.3.0 release notes — candidate

**Status:** NOT PUBLISHED. This is release-preparation documentation; do not
advertise `raster-d@0.3.0` as a DUB dependency until the `v0.3.0` tag,
GitHub Release and registry availability are independently verified.

## Why this minor version

v0.3.0 makes generic numeric histogram operations available as a versioned
dependency for consumers such as `imagery-d`. This is a new public API family
and therefore the next **minor** release rather than a v0.2.x bugfix.

The library remains image-domain agnostic. It counts generic raster plane
values; RGB and other image-specific interpretation remain the responsibility
of `imagery-d`.

## New operations

- `histogram256(source, planeIndex)` returns a fixed `ulong[256]` exact
  frequency result for one `RasterView!ubyte` plane.
- `histogramInto(source, planeIndex, lower, upper, bins[])` counts values
  in configurable equal-width bins for all ten admitted numeric raster
  sample types. The caller supplies the output buffer; there is no hidden
  heap allocation. Results also expose below-range, above-range and NaN
  counts.
- Both operations support checked logical planes, zero-copy ROIs, signed
  strides, planar/interleaved storage, valid empty inputs, and composable
  disjoint-window results.
- Full 64-bit integer ranges are assigned exactly without a floating
  conversion. Floating range boundaries must be finite; near-edge
  floating bin placement is subject to double-rounding behaviour.

See [the v0.3 candidate API contract](API_0_3.md),
[exact 8-bit guide](how-to/histogram256.md), and
[numeric interval guide](how-to/histogram-intervals.md).

## Compatibility

All 66 frozen v0.2 root exports remain available through `import raster;`.
Six histogram root exports are added. No v0.2-compatible operation is
deliberately removed or renamed.

v0.3 is a pre-1.0 minor release; once published, its own public source
contract will be frozen for that release.

## Integration with imagery-d

The currently published imagery-d consumer uses `raster-d ~>0.2.0`.
After v0.3.0 publication, a **separate imagery-d PR** must update its
DUB dependency to `~>0.3.0`, update any pinned source baseline used by
its CI, and test the image-specific histogram and ROI consumer against
the actual released raster package. Nothing is automatically merged into
`imagery-d` by publishing this library.

## Qualification and publication

This draft does not establish a feature/API freeze, full release-gate PASS,
signed tag, GitHub Release, stable Pages deployment, DUB registry availability
or fresh published-artifact consumer. See issue #254 and
[v0.3 release-gate checklist](V0_3_RELEASE_GATE.md).

The published v0.2.0 is unchanged. Its previous retrospective documentation
qualification gap is preserved in [issue #198](https://github.com/alex-1974/raster-d/issues/198).
