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
                serial_values=()
                parallel_values=()
                for _ in $(seq 1 "$runs"); do
                    read -r serial parallel < <(./benchmark/v0_3_data_plane/raster-v0-3-data-plane-benchmark \
                        | sed -n 's/.*imagery_serial_ns_per_pixel=\([0-9.]*\).*imagery_two_phase_ns_per_pixel=\([0-9.]*\).*/\1 \2/p')
                    serial_values+=("$serial")
                    parallel_values+=("$parallel")
                done
                serial_sorted=$(printf '%s\n' "${serial_values[@]}" | sort -n)
                parallel_sorted=$(printf '%s\n' "${parallel_values[@]}" | sort -n)
                serial_median=$(printf '%s\n' "$serial_sorted" | awk -v n="$runs" 'NR == int((n + 1) / 2) { print; exit }')
                parallel_median=$(printf '%s\n' "$parallel_sorted" | awk -v n="$runs" 'NR == int((n + 1) / 2) { print; exit }')
                printf '%s %s %s %s serial_median=%s parallel_median=%s serial_samples=' "$compiler" "$size_version" "$worker_version" "$chunk_version" "$serial_median" "$parallel_median"
                printf '%s,' "${serial_values[@]}" | sed 's/,$/ parallel_samples=/'
                printf '%s,' "${parallel_values[@]}" | sed 's/,$/\n/'
            done
        done
    done
done
