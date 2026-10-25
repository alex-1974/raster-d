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

The benchmark uses 1024x768 RGB source and destination planes by default, or
1920x1080 when built with `-version=raster_benchmark_1080p`. Both cases use
three interleaved channels, three warmups and seven measured samples. The
output includes the serial strided-row path and the opt-in parallel row path
(four local workers, minimum chunk 32), including setup and execution cost.

```sh
dub build --root=benchmark/v0_3_data_plane --compiler=dmd --build=release
./benchmark/v0_3_data_plane/raster-v0-3-data-plane-benchmark

dub build --root=benchmark/v0_3_data_plane --compiler=dmd --build=release \
    --d-version=raster_benchmark_1080p
./benchmark/v0_3_data_plane/raster-v0-3-data-plane-benchmark
```

The direct strided-row callback is `@trusted` only at the pointer-arithmetic
boundary; validation and callback lifetime remain enforced by raster-d.

For a repeatable worker/chunk matrix, run:

```sh
RUNS=5 ./benchmark/v0_3_data_plane/run_matrix.sh > matrix-results.txt
```

The script records five process-level samples for DMD and LDC, both supported
resolutions, four worker limits and four chunk sizes. Use the recorded samples
to calculate median and P95; process-level repetition is intentional because
thread startup and host scheduling are part of this API's measured cost.
