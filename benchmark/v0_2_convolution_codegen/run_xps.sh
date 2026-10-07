#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
HARNESS_BASE="0b73ef27aba7e5c5eaa7da25ccb5e7d675ed07c6"
CPU="${1:-0}"
OUT="${2:-/tmp/raster-v0.2-convolution-codegen-$(date +%Y%m%d-%H%M%S)}"

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

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for compiler in dmd ldc2; do
    label="$compiler"
    [[ "$compiler" == "ldc2" ]] && label="ldc"
    dir="$OUT/$label"
    mkdir -p "$dir"

    dub build         --root="$ROOT/benchmark/v0_2_convolution_codegen"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp         "$ROOT/benchmark/v0_2_convolution_codegen/raster-v0-2-convolution-codegen"         "$tmp/$label"

    sha256sum "$tmp/$label" > "$dir/binary.sha256"
    "$compiler" --version > "$dir/compiler.txt" 2>&1
    objdump -d -C "$tmp/$label" > "$dir/disassembly.txt" 2>&1 || true

    for process in 0 1 2 3 4 5; do
        taskset -c "$CPU" "$tmp/$label" > "$dir/run-$process.txt"
        test "$(grep -c '^convolution_codegen ' "$dir/run-$process.txt")" -eq 5
        test "$(grep -c '^convolution_codegen_ratio ' "$dir/run-$process.txt")" -eq 1
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
        if line.startswith("convolution_codegen "):
            f = dict(item.split("=", 1) for item in line.split()[1:])
            paths.setdefault(f["path"], []).append(float(f["ns_per_pixel"]))
            checksums.setdefault(f["path"], set()).add(f["checksum"])
        elif line.startswith("convolution_codegen_ratio "):
            f = dict(item.split("=", 1) for item in line.split()[1:])
            for key, value in f.items():
                if key != "compiler":
                    ratios.setdefault(key, []).append(float(value))

expected = {
    "public_convolution",
    "public_neighbourhood_loop",
    "hot_neighbourhood_loop",
    "hot_neighbourhood_unrolled",
    "direct_unrolled",
}

if set(paths) != expected:
    raise SystemExit(f"unexpected paths: {sorted(paths)}")

for key, values in paths.items():
    if len(values) != 6:
        raise SystemExit(f"{key}: expected six process values")
    if len(checksums[key]) != 1:
        raise SystemExit(f"{key}: unstable checksum")

if len({next(iter(v)) for v in checksums.values()}) != 1:
    raise SystemExit("semantic checksum mismatch")

with (root / "summary.txt").open("w") as out:
    for key in sorted(paths):
        values = paths[key]
        out.write(
            f"path={key} n=6 median_ns_per_pixel={statistics.median(values):.6f} "
            f"min={min(values):.6f} max={max(values):.6f} "
            f"checksum={next(iter(checksums[key]))}\n"
        )

    for key in sorted(ratios):
        values = ratios[key]
        out.write(
            f"ratio={key} n=6 median={statistics.median(values):.6f} "
            f"min={min(values):.6f} max={max(values):.6f}\n"
        )
PY
done

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
