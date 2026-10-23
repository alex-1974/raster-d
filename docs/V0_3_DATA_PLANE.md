# v0.3 Data-Plane API — Initial Slice

This document records the first implementation increment for issue #261.

`withContiguousPlane` performs all layout validation before entering a
synchronous callback and supplies a scoped D slice for the selected plane.
The slice cannot be retained as part of the API contract and the callback must
not start work that outlives the `RasterView` or `WritableRasterView` borrow.

The initial increment intentionally accepts only a flat contiguous plane. It
does not yet define public semantics for:

- interleaved or padded rows;
- negative row/sample strides;
- source/destination alias analysis;
- mixed source and destination sample types;
- asynchronous or parallel callbacks.

Those cases need a separate public contract. In particular, exposing a scoped
slice for a non-contiguous plane would silently discard stride semantics and
would therefore be incorrect.

Example:

```d
import raster;

scope const RasterView!ubyte source = ...;
auto ok = source.withContiguousPlane(0,
    (scope const(ubyte)[] samples, size_t width, size_t height)
    {
        // Validation is complete; this loop performs no per-sample checks.
        foreach (i, sample; samples)
            /* consume sample */;
    });
```

The writable overload has the same lifetime boundary and grants write access,
but does not imply uniqueness, non-aliasing, or thread exclusivity.

## Affine plane windows

`withPlane` is the strided extension. Its callback receives a scoped
`RasterPlaneWindow!T` or `WritableRasterPlaneWindow!T`. The window reports the
logical dimensions and signed row/sample strides and provides `load`/`store`
without forming a public raw pointer. This preserves planar, interleaved,
padded and negative-stride layouts.

Coordinates passed to `load` and `store` must be inside the reported logical
dimensions. They are intentionally unchecked in the hot loop; the enclosing
view and plane geometry have already been validated before the callback runs.

## Multi-plane kernels

`withPlanesInto` combines several source and destination windows and supports
different source and destination sample types. Window arrays are supplied by
the caller, so validation and callback entry are allocation-free. All planes
must have the same logical width and height. Read-only source planes may alias
one another. Destination/destination and source/destination byte-envelope
intersections are rejected before the callback. The check is conservative:
an intersecting envelope is rejected even if individual reachable samples
might be disjoint.
