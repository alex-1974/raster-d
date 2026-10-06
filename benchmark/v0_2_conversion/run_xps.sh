#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
HARNESS_BASE="af7f3e0875812d00e11452b0349e7510d0de9c23"
CPU="${1:-0}"
OUT="${2:-/tmp/raster-v0.2-conversion-$(date +%Y%m%d-%H%M%S)}"

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

    dub build         --root="$ROOT/benchmark/v0_2_conversion"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp         "$ROOT/benchmark/v0_2_conversion/raster-v0-2-conversion-benchmark"         "$tmp/$label"

    sha256sum "$tmp/$label" > "$dir/binary.sha256"
    "$compiler" --version > "$dir/compiler.txt" 2>&1

    for process in 0 1 2 3 4 5; do
        snapshot_freq "$label-pre-$process"
        taskset -c "$CPU" "$tmp/$label" > "$dir/run-$process.txt"

        test "$(grep -c '^conversion_benchmark ' "$dir/run-$process.txt")" -eq 5
        test "$(grep -c '^conversion_allocated ' "$dir/run-$process.txt")" -eq 2
        test "$(grep -c '^conversion_ratio ' "$dir/run-$process.txt")" -eq 3

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
allocated = {}

for file in sorted(root.glob("run-*.txt")):
    for line in file.read_text().splitlines():
        if line.startswith("conversion_benchmark "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            key = (fields["pair"], fields["path"])
            paths.setdefault(key, []).append(float(fields["ns_per_sample"]))
            checksums.setdefault(key, set()).add(fields["checksum"])
        elif line.startswith("conversion_allocated "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            key = fields["path"]
            allocated.setdefault(key, []).append(float(fields["ns_per_sample"]))
            if int(fields["successes"]) <= 0:
                raise SystemExit(f"{file}: zero allocated successes for {key}")
        elif line.startswith("conversion_ratio "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            pair = fields["pair"]
            for key, value in fields.items():
                if key in ("compiler", "pair"):
                    continue
                ratios.setdefault((pair, key), []).append(float(value))

expected = {
    ("ubyte_to_float", "public_generic"),
    ("ubyte_to_float", "public_specialized"),
    ("ubyte_to_float", "semantic_engine"),
    ("ushort_to_float", "public_generic"),
    ("ushort_to_float", "semantic_engine"),
}

if set(paths) != expected:
    raise SystemExit(f"unexpected path set: {sorted(paths)}")

if set(allocated) != {"public_allocated", "explicit_allocate_convert"}:
    raise SystemExit(f"unexpected allocated set: {sorted(allocated)}")

for key, values in paths.items():
    if len(values) != 6:
        raise SystemExit(f"{key}: expected 6 values, got {len(values)}")
    if len(checksums[key]) != 1:
        raise SystemExit(f"{key}: unstable checksum {checksums[key]}")

for pair in ("ubyte_to_float", "ushort_to_float"):
    pair_checksums = {
        next(iter(value))
        for key, value in checksums.items()
        if key[0] == pair
    }
    if len(pair_checksums) != 1:
        raise SystemExit(f"{pair}: checksum mismatch {pair_checksums}")

for key, values in allocated.items():
    if len(values) != 6:
        raise SystemExit(f"{key}: expected 6 values, got {len(values)}")

with (root / "summary.txt").open("w") as out:
    for key in sorted(paths):
        values = paths[key]
        out.write(
            f"pair={key[0]} path={key[1]} n=6 "
            f"median_ns_per_sample={statistics.median(values):.6f} "
            f"min={min(values):.6f} max={max(values):.6f} "
            f"checksum={next(iter(checksums[key]))}\n"
        )

    for key in sorted(allocated):
        values = allocated[key]
        out.write(
            f"pair=allocated_ushort_to_float path={key} n=6 "
            f"median_ns_per_sample={statistics.median(values):.6f} "
            f"min={min(values):.6f} max={max(values):.6f}\n"
        )

    for key in sorted(ratios):
        values = ratios[key]
        out.write(
            f"pair={key[0]} ratio={key[1]} n=6 "
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
