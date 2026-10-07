#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
HARNESS_BASE="f4df7e4cc436e9e061962e125c20fdba2c337173"
CPU="${1:-0}"
OUT="${2:-/tmp/raster-v0.2-reduction-codegen-$(date +%Y%m%d-%H%M%S)}"
git -C "$ROOT" merge-base --is-ancestor "$HARNESS_BASE" HEAD
test ! -e "$OUT"; mkdir -p "$OUT"
{
 echo "head=$(git -C "$ROOT" rev-parse HEAD)"
 echo "branch=$(git -C "$ROOT" branch --show-current)"
 echo "harness_base=$HARNESS_BASE"
 echo "cpu=$CPU"; echo "dub_build=release"; echo "dflags=-preview=dip1000"
 echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
 uname -a; lscpu; dub --version; dmd --version; ldc2 --version
} > "$OUT/environment.txt"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
for compiler in dmd ldc2; do
 label="$compiler"; [[ "$compiler" == "ldc2" ]] && label="ldc"
 dir="$OUT/$label"; mkdir -p "$dir"
 dub build --root="$ROOT/benchmark/v0_2_reduction_codegen" --compiler="$compiler" --build=release --force > "$dir/build.txt" 2>&1
 cp "$ROOT/benchmark/v0_2_reduction_codegen/raster-v0-2-reduction-codegen" "$tmp/$label"
 sha256sum "$tmp/$label" > "$dir/binary.sha256"
 "$compiler" --version > "$dir/compiler.txt" 2>&1
 objdump -d -C "$tmp/$label" > "$dir/disassembly.txt" 2>&1 || true
 for process in 0 1 2 3 4 5; do
   taskset -c "$CPU" "$tmp/$label" > "$dir/run-$process.txt"
   test "$(grep -c '^reduction_codegen ' "$dir/run-$process.txt")" -eq 13
 done
 python3 - "$dir" <<'PY'
from pathlib import Path
import statistics, sys
root=Path(sys.argv[1]); values={}; checks={}
for f in sorted(root.glob("run-*.txt")):
    for line in f.read_text().splitlines():
        if not line.startswith("reduction_codegen "): continue
        d=dict(x.split("=",1) for x in line.split()[1:])
        k=(d["operation"],d["path"])
        values.setdefault(k,[]).append(float(d["ns_per_sample"]))
        checks.setdefault(k,set()).add(d["checksum"])
if len(values)!=13: raise SystemExit(f"expected 13 paths, got {len(values)}")
with (root/"summary.txt").open("w") as out:
    for k in sorted(values):
        v=values[k]
        if len(v)!=6 or len(checks[k])!=1: raise SystemExit(f"unstable {k}")
        out.write(f"operation={k[0]} path={k[1]} n=6 median_ns_per_sample={statistics.median(v):.6f} min={min(v):.6f} max={max(v):.6f} checksum={next(iter(checks[k]))}\n")
PY
done
(cd "$OUT"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum) > "$OUT/SHA256SUMS"
ARCHIVE="$OUT.tar.gz"; tar -C "$(dirname "$OUT")" -czf "$ARCHIVE" "$(basename "$OUT")"
echo "=== DMD ==="; cat "$OUT/dmd/summary.txt"
echo "=== LDC ==="; cat "$OUT/ldc/summary.txt"
echo "=== ARCHIVE ==="; sha256sum "$ARCHIVE"; echo "archive=$ARCHIVE"
