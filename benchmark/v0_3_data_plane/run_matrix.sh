#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"

runs=${RUNS:-5}
if ! [[ "$runs" =~ ^[1-9][0-9]*$ ]]; then
    echo "RUNS must be a positive integer" >&2
    exit 2
fi

for compiler in dmd ldc2; do
    for size_version in default raster_benchmark_1080p; do
        for worker_version in raster_benchmark_workers_1 raster_benchmark_workers_2 raster_benchmark_workers_4 raster_benchmark_workers_8; do
            for chunk_version in default raster_benchmark_chunk_8 raster_benchmark_chunk_32 raster_benchmark_chunk_64 raster_benchmark_chunk_128; do
                versions=""
                [[ "$size_version" != default ]] && versions+=" --d-version=$size_version"
                [[ "$worker_version" != raster_benchmark_workers_4 ]] && versions+=" --d-version=$worker_version"
                [[ "$chunk_version" != default ]] && versions+=" --d-version=$chunk_version"
                dub build --root=benchmark/v0_3_data_plane --compiler="$compiler" --build=release $versions >/dev/null
                values=()
                for _ in $(seq 1 "$runs"); do
                    value=$(./benchmark/v0_3_data_plane/raster-v0-3-data-plane-benchmark \
                        | sed -n 's/.*parallel_row_ns_per_pixel=\([0-9.]*\).*/\1/p')
                    values+=("$value")
                done
                sorted=$(printf '%s\n' "${values[@]}" | sort -n)
                median=$(printf '%s\n' "$sorted" | awk -v n="$runs" 'NR == int((n + 1) / 2) { print; exit }')
                p95=$(printf '%s\n' "$sorted" | awk -v n="$runs" 'NR >= int(0.95 * n + 0.999999) { print; exit }')
                printf '%s %s %s %s median=%s p95=%s samples=' "$compiler" "$size_version" "$worker_version" "$chunk_version" "$median" "$p95"
                printf '%s,' "${values[@]}" | sed 's/,$/\n/'
            done
        done
    done
done
