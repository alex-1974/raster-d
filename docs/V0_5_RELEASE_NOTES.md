# raster-d v0.5.0 release notes

`raster-d` v0.5.0 adds the callback-scoped strided row contract requested by
imagery-d issue #261.

## New public API

`RasterPlaneRow!T` and `WritableRasterPlaneRow!T` are now exported through
`import raster`. Each row exposes:

- `length`, the validated logical row width;
- `data`, a callback-scoped pointer to the first sample;
- `sampleStride`, the signed element stride between logical samples.

This supports planar, interleaved, padded and negative-row-stride layouts.
Validation and alias checks still happen before the synchronous multi-plane
callback. The borrowed pointer must not escape the callback.

## Performance evidence

The external RGB benchmark uses three interleaved `ubyte` source channels and
three interleaved `float` destination channels at 256x256, with three warmups
and seven measured samples. On the development x86-64 host:

| Compiler | Existing row path | Hoisted strided-row path |
|---|---:|---:|
| DMD | 3.78 ns/pixel | 1.79 ns/pixel |
| LDC | 0.76 ns/pixel | 0.84 ns/pixel |

CPU frequency was not locked. DMD final-binary inspection found no per-sample
`load`, `store` or `data` symbols in the hot path. The pointer-arithmetic
consumer boundary is explicitly `@trusted`; the raster-d validation and
callback lifetime contract remain unchanged.
