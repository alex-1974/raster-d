# Public data-plane benchmark

This is an external-consumer-style benchmark for the interleaved RGB workload
from raster-d issue #261. It compares checked sample access, affine windows,
callback-scoped row accessors, and callback-scoped strided rows whose data and
sample stride are hoisted once per row.

Build and run separately with DMD and LDC:

```sh
dub build --root=benchmark/v0_3_data_plane --compiler=dmd --build=release
./benchmark/v0_3_data_plane/raster-v0-3-data-plane-benchmark

dub build --root=benchmark/v0_3_data_plane --compiler=ldc2 --build=release
./benchmark/v0_3_data_plane/raster-v0-3-data-plane-benchmark
```

The benchmark uses 256x256 RGB source and destination planes, three interleaved
channels, three warmups and seven measured samples. The direct strided-row
callback is `@trusted` only at the pointer-arithmetic boundary; validation and
the callback lifetime remain enforced by raster-d.
