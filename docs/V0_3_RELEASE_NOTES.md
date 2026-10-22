# raster-d v0.3.0 release notes

**Source qualification:** v0.3.0 passed the required release gates and its public
API is frozen at `freeze/api-0.3.0`. These release notes describe the
qualified source, not an assertion that a package has already appeared in the
registry. Confirm the [GitHub Release](https://github.com/alex-1974/raster-d/releases)
and [DUB listing](https://code.dlang.org/packages/raster-d) before adopting
the new dependency.

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

See [the v0.3 frozen API contract](API_0_3.md),
[exact 8-bit guide](how-to/histogram256.md), and
[numeric interval guide](how-to/histogram-intervals.md).

## Compatibility

All 66 frozen v0.2 root exports remain available through `import raster;`.
Six histogram root exports are added. No v0.2-compatible operation is
deliberately removed or renamed.

v0.3 is a pre-1.0 minor release; its public source contract was frozen
at `freeze/api-0.3.0`. The older v0.2.0 source contract remains immutable.

## Integration with imagery-d

The currently published imagery-d consumer uses `raster-d ~>0.2.0`.
Once `raster-d@0.3.0` is available through DUB, a **separate imagery-d
PR** must update the dependency to `~>0.3.0`, update the pinned source
baseline used by CI, and test the image-specific histogram and ROI consumer
against the actual package. Publishing raster-d does not automatically
update `imagery-d`.

## Qualification and publication

Release source qualification is recorded in [issue #254](https://github.com/alex-1974/raster-d/issues/254)
and the [v0.3 release-gate record](V0_3_RELEASE_GATE.md). Exact-head
GitHub workflows passed: 15/15 Release Gate, 8/8 Compiler Floor, 3/3
Release Documentation, 2/2 Archive Consumer and API documentation build.
Public DDox rendered 111/111 Examples. A representative x86-64 LDC 1.42.0
release-mode smoke checked correct counts and observed 776.6 MiB/s median
for `histogram256` and 219.4 MiB/s for `histogramInto`. These figures
are not claims of C++ performance parity. Signed annotated feature/API
freeze tags exist. Actual release publication, Pages promotion, DUB
availability and a fresh published consumer are separate post-tag checks.

The published v0.2.0 is unchanged. Its previous retrospective documentation
qualification gap is preserved in [issue #198](https://github.com/alex-1974/raster-d/issues/198).
