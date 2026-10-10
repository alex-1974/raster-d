#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
HARNESS_BASE="2003a84e0d970c2fc7c19124e9002adb3d59f040"
CPU="${1:-0}"
OUT="${2:-/tmp/raster-v0.2-neighbourhood-family-$(date +%Y%m%d-%H%M%S)}"

git -C "$ROOT" merge-base --is-ancestor "$HARNESS_BASE" HEAD
test ! -e "$OUT"
mkdir -p "$OUT"

{
    echo "head=$(git -C "$ROOT" rev-parse HEAD)"
    echo "branch=$(git -C "$ROOT" branch --show-current)"
    echo "harness_base=$HARNESS_BASE"
    echo "cpu=$CPU"
    echo "dub_build=release"
    echo "dflags=-preview=dip1000"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    uname -a
    lscpu
    dub --version
    dmd --version
    ldc2 --version
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

    dub build         --root="$ROOT/benchmark/v0_2_neighbourhood_family"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp         "$ROOT/benchmark/v0_2_neighbourhood_family/raster-v0-2-neighbourhood-family-benchmark"         "$tmp/$label"

    sha256sum "$tmp/$label" > "$dir/binary.sha256"
    "$compiler" --version > "$dir/compiler.txt" 2>&1

    for process in 0 1 2 3 4 5; do
        snapshot_freq "$label-pre-$process"

        taskset -c "$CPU" "$tmp/$label"             > "$dir/run-$process.txt"

        test "$(grep -c '^neighbourhood_benchmark ' "$dir/run-$process.txt")" -eq 5
        test "$(grep -c '^neighbourhood_ratio ' "$dir/run-$process.txt")" -eq 4

        snapshot_freq "$label-post-$process"
    done

    python3 - "$dir" <<'PY'
from pathlib import Path
import statistics
import sys

root = Path(sys.argv[1])

paths = {}
ratios = {}
checksums = {}

for file in sorted(root.glob("run-*.txt")):
    for line in file.read_text().splitlines():
        if line.startswith("neighbourhood_benchmark "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            key = (fields["operation"], fields["path"])
            paths.setdefault(key, []).append(float(fields["ns_per_sample"]))
            checksums.setdefault(key, set()).add(fields["checksum"])

        elif line.startswith("neighbourhood_ratio "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            ratios.setdefault(fields["comparison"], []).append(
                float(fields["value"])
            )

expected = {
    ("3x3", "public_generic"),
    ("3x3", "public_legacy"),
    ("3x3", "hot_executor"),
    ("5x3", "public_canonical"),
    ("5x3", "public_strided"),
}

if set(paths) != expected:
    raise SystemExit(f"unexpected path set: {sorted(paths)}")

for key, values in paths.items():
    if len(values) != 6:
        raise SystemExit(f"{key}: expected 6 values, got {len(values)}")

    if len(checksums[key]) != 1:
        raise SystemExit(f"{key}: unstable checksum {checksums[key]}")

three = {
    next(iter(checksums[key]))
    for key in [
        ("3x3", "public_generic"),
        ("3x3", "public_legacy"),
        ("3x3", "hot_executor"),
    ]
}

if len(three) != 1:
    raise SystemExit(f"3x3 checksum mismatch: {three}")

five = {
    next(iter(checksums[key]))
    for key in [
        ("5x3", "public_canonical"),
        ("5x3", "public_strided"),
    ]
}

if len(five) != 1:
    raise SystemExit(f"5x3 checksum mismatch: {five}")

for name, values in ratios.items():
    if len(values) != 6:
        raise SystemExit(f"{name}: expected 6 ratios, got {len(values)}")

with (root / "summary.txt").open("w") as out:
    for key in sorted(paths):
        values = paths[key]
        out.write(
            f"operation={key[0]} path={key[1]} n=6 "
            f"median_ns_per_sample={statistics.median(values):.6f} "
            f"min={min(values):.6f} max={max(values):.6f} "
            f"checksum={next(iter(checksums[key]))}\n"
        )

    for name in sorted(ratios):
        values = ratios[name]
        out.write(
            f"comparison={name} n=6 "
            f"median={statistics.median(values):.6f} "
            f"min={min(values):.6f} max={max(values):.6f}\n"
        )
PY
done

snapshot_freq after

(
    cd "$OUT"
    find . -type f ! -name SHA256SUMS -print0         | sort -z         | xargs -0 sha256sum
) > "$OUT/SHA256SUMS"

ARCHIVE="$OUT.tar.gz"
tar -C "$(dirname "$OUT")" -czf "$ARCHIVE" "$(basename "$OUT")"

echo
echo "=== DMD ==="
cat "$OUT/dmd/summary.txt"

echo
echo "=== LDC ==="
cat "$OUT/ldc/summary.txt"

echo
echo "=== ARCHIVE ==="
sha256sum "$ARCHIVE"
echo "archive=$ARCHIVE"
