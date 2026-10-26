# raster-d v0.5.3 release notes

`raster-d` v0.5.3 extends bounded, synchronous data-plane execution to
multiple independently backed source views. It remains generic: RGB, mask,
histogram and colour semantics belong to consumers such as imagery-d.

## Public API

- `withViewsParallelPhases` for source-only multi-view analysis;
- `withViewsIntoParallelPhases` for multi-view analysis followed by a
  destination transform;
- independent view and plane validation with common logical extents;
- callback-scoped grouped affine windows with the existing bounded phase
  barriers, stable worker indices and alias checks.

The source-view collection is homogeneous by sample type. This keeps the
public callback strongly typed and allocation-free while supporting RGB data
plus a separately backed byte mask.

## Qualification

- DMD and LDC unit tests pass, including DIP1000 probes;
- all PR #272 release gates pass;
- the release benchmark covers the imagery-shaped RGB plus separate-mask
  workload with worker-local 65,536-bin histograms and deterministic
  reduction before the three-channel float transform.
