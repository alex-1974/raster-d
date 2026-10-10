#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="feat/v0.2-m3-generic-sum"
CPU="${1:-0}"
OUT="${2:-/tmp/raster-v0.2-sum-$(date +%Y%m%d-%H%M%S)}"

test "$(git -C "$ROOT" branch --show-current)" = "$BRANCH"
test ! -e "$OUT"
mkdir -p "$OUT"

{
    echo "head=$(git -C "$ROOT" rev-parse HEAD)"
    echo "branch=$(git -C "$ROOT" branch --show-current)"
    echo "cpu=$CPU"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    uname -a
    lscpu
    dub --version
    dmd --version
    ldc2 --version
    g++ --version
} > "$OUT/environment.txt"

snapshot_freq()
{
    local tag="$1"

    {
        echo "tag=$tag"
        date -u +%Y-%m-%dT%H:%M:%SZ

        for cpu_path in /sys/devices/system/cpu/cpu[0-9]*; do
            [[ -d "$cpu_path/cpufreq" ]] || continue

            id="${cpu_path##*cpu}"
            gov="$(cat "$cpu_path/cpufreq/scaling_governor" 2>/dev/null || true)"
            cur="$(cat "$cpu_path/cpufreq/scaling_cur_freq" 2>/dev/null || true)"
            min="$(cat "$cpu_path/cpufreq/scaling_min_freq" 2>/dev/null || true)"
            max="$(cat "$cpu_path/cpufreq/scaling_max_freq" 2>/dev/null || true)"

            printf 'cpu=%s governor=%s cur_khz=%s min_khz=%s max_khz=%s\n'                 "$id" "$gov" "$cur" "$min" "$max"
        done

        for path in /sys/class/thermal/thermal_zone*/temp; do
            [[ -r "$path" ]] || continue
            printf '%s=' "$path"
            cat "$path"
        done
    } > "$OUT/frequency-thermal-$tag.txt"
}

snapshot_freq before

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for compiler in dmd ldc2; do
    label="$compiler"
    [[ "$compiler" == "ldc2" ]] && label="ldc"

    dir="$OUT/$label"
    mkdir -p "$dir"

    dub build         --root="$ROOT/benchmark/v0_2_sum"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp         "$ROOT/benchmark/v0_2_sum/raster-v0-2-sum-benchmark"         "$tmp/$label"

    sha256sum "$tmp/$label" > "$dir/binary.sha256"
    "$compiler" --version > "$dir/compiler.txt" 2>&1

    for process in 0 1 2 3 4 5; do
        snapshot_freq "$label-pre-$process"

        taskset -c "$CPU" "$tmp/$label"             > "$dir/run-$process.txt"

        test "$(grep -c '^sum_benchmark ' "$dir/run-$process.txt")" -eq 2
        test "$(grep -c '^sum_ratio ' "$dir/run-$process.txt")" -eq 1

        snapshot_freq "$label-post-$process"
    done
done

cpp_dir="$OUT/cpp"
mkdir -p "$cpp_dir"

g++     -O3     -std=c++20     -fno-fast-math     -ffp-contract=off     -fno-tree-vectorize     -fno-tree-slp-vectorize     "$ROOT/benchmark/v0_2_sum/cpp/reference.cpp"     -o "$tmp/cpp-reference"     > "$cpp_dir/build.txt" 2>&1

sha256sum "$tmp/cpp-reference" > "$cpp_dir/binary.sha256"
g++ --version > "$cpp_dir/compiler.txt" 2>&1

for process in 0 1 2 3 4 5; do
    snapshot_freq "cpp-pre-$process"

    taskset -c "$CPU" "$tmp/cpp-reference"         > "$cpp_dir/run-$process.txt"

    test "$(grep -c '^sum_cpp_benchmark ' "$cpp_dir/run-$process.txt")" -eq 1

    snapshot_freq "cpp-post-$process"
done

python3 - "$OUT" <<'PY'
from pathlib import Path
import statistics
import sys

root = Path(sys.argv[1])

series = {
    "dmd_legacy": [],
    "dmd_generic": [],
    "ldc_legacy": [],
    "ldc_generic": [],
    "cpp": [],
}

result_bits = set()
d_checksums = {}

for compiler in ("dmd", "ldc"):
    checksums = {"legacy": set(), "generic": set()}

    for path in sorted((root / compiler).glob("run-*.txt")):
        for line in path.read_text().splitlines():
            if not line.startswith("sum_benchmark "):
                continue

            fields = dict(item.split("=", 1) for item in line.split()[1:])
            api = fields["api"]
            series[f"{compiler}_{api}"].append(
                float(fields["ns_per_sample"])
            )
            result_bits.add(fields["result_bits"])
            checksums[api].add(fields["checksum"])

    if any(len(values) != 1 for values in checksums.values()):
        raise SystemExit(f"{compiler}: unstable timed checksum: {checksums}")

    if checksums["legacy"] != checksums["generic"]:
        raise SystemExit(
            f"{compiler}: legacy/generic checksum mismatch: {checksums}"
        )

    d_checksums[compiler] = next(iter(checksums["legacy"]))

for path in sorted((root / "cpp").glob("run-*.txt")):
    for line in path.read_text().splitlines():
        if not line.startswith("sum_cpp_benchmark "):
            continue

        fields = dict(item.split("=", 1) for item in line.split()[1:])
        series["cpp"].append(float(fields["ns_per_sample"]))
        result_bits.add(fields["result_bits"])

if len(result_bits) != 1:
    raise SystemExit(f"result-bit mismatch across D/C++: {result_bits}")

for name, values in series.items():
    if len(values) != 6:
        raise SystemExit(
            f"expected 6 values for {name}, got {len(values)}"
        )

with (root / "summary.txt").open("w") as out:
    for name, values in series.items():
        out.write(
            f"{name}_n=6 "
            f"median_ns_per_sample={statistics.median(values):.6f} "
            f"min={min(values):.6f} "
            f"max={max(values):.6f}\n"
        )

    out.write(f"result_bits={next(iter(result_bits))}\n")
    out.write(f"dmd_checksum={d_checksums['dmd']}\n")
    out.write(f"ldc_checksum={d_checksums['ldc']}\n")

    for compiler in ("dmd", "ldc"):
        generic = statistics.median(series[f"{compiler}_generic"])
        cpp = statistics.median(series["cpp"])
        legacy = statistics.median(series[f"{compiler}_legacy"])

        out.write(
            f"{compiler}_legacy_over_generic={legacy / generic:.6f}\n"
        )
        out.write(
            f"{compiler}_generic_over_cpp={generic / cpp:.6f}\n"
        )
PY

snapshot_freq after

(
    cd "$OUT"
    find . -type f ! -name SHA256SUMS -print0         | sort -z         | xargs -0 sha256sum
) > "$OUT/SHA256SUMS"

ARCHIVE="$OUT.tar.gz"
tar -C "$(dirname "$OUT")" -czf "$ARCHIVE" "$(basename "$OUT")"

echo
cat "$OUT/summary.txt"

echo
echo "=== ARCHIVE ==="
sha256sum "$ARCHIVE"
echo "archive=$ARCHIVE"
