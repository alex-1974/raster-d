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
- `withPlanesInto`;
- `withPlanesIntoParallel`;
- `ParallelRowsResult`;
- `parallelRows`.

## Contract

The synchronous data-plane callbacks are `@safe`, `nothrow`, and `@nogc`.
The opt-in parallel callback is `@safe` and `nothrow`; worker creation is
intentionally outside the `@nogc` contract. Window values
and slices are scoped to the callback and do not expose raw pointers.

`withPlane` supports validated signed row/sample strides, including planar,
interleaved, padded and negative-stride layouts. `load` and `store` assume
coordinates are inside the validated logical extent; they intentionally omit
per-sample bounds checks in the hot loop.

`withPlanesInto` supports different source and destination sample types. The
caller supplies window workspace, so the API performs no allocation. Source
planes may alias each other. Source/destination and destination/destination
byte-envelope intersections are rejected before the callback.

`withPlanesIntoParallel` applies the same validation and passes each callback
a disjoint half-open row range. It creates only invocation-local workers,
joins every started worker before returning, and may leave partial writes on a
failed callback. It does not install a persistent executor or global pool.

## Evidence

- external DMD/LDC consumer tests cover contiguous, negative-stride,
  interleaved and `ubyte -> float` three-plane execution;
- compile-negative DMD/LDC probes reject window escape;
- `benchmark/v0_3_data_plane` compares checked accessors with the public
  multi-plane path.
