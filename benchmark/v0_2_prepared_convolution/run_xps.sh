#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
BRANCH="research/v0.2-m4-prepared-convolution"
CPU="${1:-0}"
OUT="${2:-/tmp/raster-v0.2-prepared-convolution-$(date +%Y%m%d-%H%M%S)}"

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

    dub build         --root="$ROOT/benchmark/v0_2_prepared_convolution"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp         "$ROOT/benchmark/v0_2_prepared_convolution/raster-v0-2-prepared-convolution-benchmark"         "$tmp/$label"

    sha256sum "$tmp/$label" > "$dir/binary.sha256"
    "$compiler" --version > "$dir/compiler.txt" 2>&1

    for process in 0 1 2 3 4 5; do
        snapshot_freq "$label-pre-$process"

        taskset -c "$CPU" "$tmp/$label"             > "$dir/run-$process.txt"

        test "$(grep -c '^prepared_convolution ' "$dir/run-$process.txt")" -eq 3
        test "$(grep -c '^prepared_convolution_ratio ' "$dir/run-$process.txt")" -eq 1

        snapshot_freq "$label-post-$process"
    done

    python3 - "$dir" <<'PY'
from pathlib import Path
import math
import statistics
import sys

root = Path(sys.argv[1])

one_shot = []
prepared = []
prep = []
ratios = []
break_even = []
checksums = {"one_shot": set(), "prepared": set()}

for path in sorted(root.glob("run-*.txt")):
    for line in path.read_text().splitlines():
        if line.startswith("prepared_convolution "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            mode = fields["mode"]

            if mode in ("one_shot", "prepared"):
                value = float(fields["ns_per_pixel"])
                if mode == "one_shot":
                    one_shot.append(value)
                else:
                    prepared.append(value)
                checksums[mode].add(fields["checksum"])

            elif mode == "prepare":
                prep.append(float(fields["ns_per_prepare"]))

        elif line.startswith("prepared_convolution_ratio "):
            fields = dict(item.split("=", 1) for item in line.split()[1:])
            ratios.append(float(fields["one_shot_over_prepared"]))

            value = float(fields["break_even_reuse"])
            break_even.append(value)

if not all(len(v) == 6 for v in (one_shot, prepared, prep, ratios, break_even)):
    raise SystemExit(
        "expected six process values: "
        f"one_shot={len(one_shot)} prepared={len(prepared)} "
        f"prep={len(prep)} ratios={len(ratios)} break_even={len(break_even)}"
    )

if len(checksums["one_shot"]) != 1 or checksums["one_shot"] != checksums["prepared"]:
    raise SystemExit(f"checksum mismatch: {checksums}")

finite_break_even = [v for v in break_even if math.isfinite(v)]

with (root / "summary.txt").open("w") as out:
    out.write(
        f"one_shot_n=6 median_ns_per_pixel={statistics.median(one_shot):.6f} "
        f"min={min(one_shot):.6f} max={max(one_shot):.6f}\n"
    )
    out.write(
        f"prepared_n=6 median_ns_per_pixel={statistics.median(prepared):.6f} "
        f"min={min(prepared):.6f} max={max(prepared):.6f}\n"
    )
    out.write(
        f"prepare_n=6 median_ns_per_prepare={statistics.median(prep):.6f} "
        f"min={min(prep):.6f} max={max(prep):.6f}\n"
    )
    out.write(
        f"one_shot_over_prepared_n=6 median={statistics.median(ratios):.6f} "
        f"min={min(ratios):.6f} max={max(ratios):.6f}\n"
    )

    if finite_break_even:
        out.write(
            f"break_even_reuse_finite_n={len(finite_break_even)} "
            f"median={statistics.median(finite_break_even):.9f} "
            f"min={min(finite_break_even):.9f} "
            f"max={max(finite_break_even):.9f}\n"
        )
    else:
        out.write("break_even_reuse_finite_n=0\n")

    out.write(
        f"checksum={next(iter(checksums['one_shot']))}\n"
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
