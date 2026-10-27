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
output includes the serial strided-row path, the opt-in parallel row path and
both two-phase scoped operations (four local workers, minimum chunk 32),
including setup and execution cost. The imagery-shaped case uses an RGB source
and a separately backed mask view. Selected pixels use a documented 16-bit
integer luma domain (`77*r + 150*g + 29*b`, scaled to 0..65535), worker-local
65,536-entry `ulong` histograms, deterministic reduction, and a 75th-percentile
nearest-rank threshold. The serial and parallel complete workloads are reported
separately and their destination checksums are compared on every sample.

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
allocation, phase thread startup, reduction, and host scheduling are part of
thread startup and host scheduling are part of this API's measured cost.

## Issue #274 acceptance measurements

The focused acceptance run used five process-level samples, four workers,
minimum chunk 32, Release builds, and included the complete serial and
parallel imagery-shaped operation. Values below are local to the recorded
host and are nanoseconds per pixel; P95 is the largest of the five samples.

| Compiler | Size | Serial median / P95 | Parallel median / P95 |
|---|---:|---:|---:|
| DMD | 1024x768 | 24.804 / 25.795 | 8.637 / 9.216 |
| DMD | 1920x1080 | 24.149 / 24.553 | 8.181 / 8.610 |
| LDC | 1024x768 | 15.686 / 20.875 | 13.483 / 15.633 |
| LDC | 1920x1080 | 13.870 / 18.894 | 13.617 / 14.018 |

Reproduce the focused matrix from the repository root:

```sh
for compiler in dmd ldc2; do
    for version in default raster_benchmark_1080p; do
        versions=""
        test "$version" = default || versions="--d-version=$version"
        dub build --root=benchmark/v0_3_data_plane --compiler="$compiler" --build=release $versions
        for run in 1 2 3 4 5; do
            ./benchmark/v0_3_data_plane/raster-v0-3-data-plane-benchmark
        done
    done
done
```

Every run also performs the independent histogram fixture and the direct
element-wise serial/parallel output comparison before reporting timings.
