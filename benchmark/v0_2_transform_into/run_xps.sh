#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="feat/v0.2-m2-transform-into"
CPU="${1:-0}"
OUT="${2:-/tmp/raster-v0.2-transform-into-$(date +%Y%m%d-%H%M%S)}"

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
} > "$OUT/environment.txt"

snapshot_freq()
{
    local tag="$1"
    {
        echo "tag=$tag"
        date -u +%Y-%m-%dT%H:%M:%SZ

        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
            [[ -d "$cpu/cpufreq" ]] || continue

            id="${cpu##*cpu}"
            gov="$(cat "$cpu/cpufreq/scaling_governor 2>/dev/null || true)"
            cur="$(cat "$cpu/cpufreq/scaling_cur_freq 2>/dev/null || true)"
            min="$(cat "$cpu/cpufreq/scaling_min_freq 2>/dev/null || true)"
            max="$(cat "$cpu/cpufreq/scaling_max_freq 2>/dev/null || true)"

            printf 'cpu=%s governor=%s cur_khz=%s min_khz=%s max_khz=%s\n' \
                "$id" "$gov" "$cur" "$min" "$max"
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

    dub build         --root="$ROOT/benchmark/v0_2_transform_into"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp "$ROOT/benchmark/v0_2_transform_into/raster-v0-2-transform-into-benchmark"         "$tmp/$label"

    sha256sum "$tmp/$label" > "$dir/binary.sha256"
    "$compiler" --version > "$dir/compiler.txt" 2>&1

    for process in 0 1 2 3 4 5; do
        taskset -c "$CPU" "$tmp/$label"             > "$dir/run-$process.txt"

        test "$(grep -c '^transform_into_benchmark ' "$dir/run-$process.txt")" -eq 2
        test "$(grep -c '^transform_into_ratio ' "$dir/run-$process.txt")" -eq 1
    done

    python3 - "$dir" <<'PY'
from pathlib import Path
import statistics
import sys

root = Path(sys.argv[1])

legacy = []
current = []
ratios = []
legacy_hashes = set()
current_hashes = set()

for path in sorted(root.glob("run-*.txt")):
    for line in path.read_text().splitlines():
        if line.startswith("transform_into_benchmark "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            value = float(fields["ns_per_pixel"])
            if fields["api"] == "legacy":
                legacy.append(value)
                legacy_hashes.add(fields["checksum"])
            elif fields["api"] == "transformInto":
                current.append(value)
                current_hashes.add(fields["checksum"])
        elif line.startswith("transform_into_ratio "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            ratios.append(float(fields["legacy_over_new"]))

if len(legacy) != 6 or len(current) != 6 or len(ratios) != 6:
    raise SystemExit(
        f"expected 6 values per series, got "
        f"legacy={len(legacy)} current={len(current)} ratios={len(ratios)}"
    )

if len(legacy_hashes) != 1 or legacy_hashes != current_hashes:
    raise SystemExit(
        f"checksum mismatch legacy={legacy_hashes} current={current_hashes}"
    )

with (root / "summary.txt").open("w") as out:
    out.write(
        f"legacy_n=6 median_ns_per_pixel={statistics.median(legacy):.6f} "
        f"min={min(legacy):.6f} max={max(legacy):.6f}\n"
    )
    out.write(
        f"transformInto_n=6 median_ns_per_pixel={statistics.median(current):.6f} "
        f"min={min(current):.6f} max={max(current):.6f}\n"
    )
    out.write(
        f"legacy_over_new_n=6 median={statistics.median(ratios):.6f} "
        f"min={min(ratios):.6f} max={max(ratios):.6f}\n"
    )
    out.write(
        f"checksum={next(iter(legacy_hashes))}\n"
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
