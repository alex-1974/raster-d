# raster-d v0.3 public data-plane inventory

This inventory covers the public data-plane addition prepared from issue #261.
It is additive to the frozen v0.2 surface and must not be used to reinterpret
the immutable v0.2 API checkpoint.

## Root exports

`source/raster/package.d` exports:

- `RasterPlaneWindow!T`;
- `WritableRasterPlaneWindow!T`;
- `withContiguousPlane`;
- `withPlane`;
- `withPlanesInto`.

## Contract

All callbacks are synchronous, `@safe`, `nothrow`, and `@nogc`. Window values
and slices are scoped to the callback and do not expose raw pointers.

`withPlane` supports validated signed row/sample strides, including planar,
interleaved, padded and negative-stride layouts. `load` and `store` assume
coordinates are inside the validated logical extent; they intentionally omit
per-sample bounds checks in the hot loop.

`withPlanesInto` supports different source and destination sample types. The
caller supplies window workspace, so the API performs no allocation. Source
planes may alias each other. Source/destination and destination/destination
byte-envelope intersections are rejected before the callback.

## Evidence

- external DMD/LDC consumer tests cover contiguous, negative-stride,
  interleaved and `ubyte -> float` three-plane execution;
- compile-negative DMD/LDC probes reject window escape;
- `benchmark/v0_3_data_plane` compares checked accessors with the public
  multi-plane path.
