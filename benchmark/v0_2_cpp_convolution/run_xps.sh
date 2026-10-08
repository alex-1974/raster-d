#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
HARNESS_BASE="cd16397fe3639352d48268a879089fa85b7a3fb5"
CPU="${1:-0}"
OUT="${2:-/tmp/raster-v0.2-cpp-convolution-$(date +%Y%m%d-%H%M%S)}"

git -C "$ROOT" merge-base --is-ancestor "$HARNESS_BASE" HEAD
test ! -e "$OUT"
mkdir -p "$OUT"

{
  echo "head=$(git -C "$ROOT" rev-parse HEAD)"
  echo "branch=$(git -C "$ROOT" branch --show-current)"
  echo "harness_base=$HARNESS_BASE"
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
      printf 'cpu=%s governor=%s cur_khz=%s min_khz=%s max_khz=%s\n' "$id" "$gov" "$cur" "$min" "$max"
    done
  } > "$OUT/frequency-$tag.txt"
}

snapshot_freq before
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for compiler in dmd ldc2; do
  label="$compiler"
  [[ "$compiler" == "ldc2" ]] && label="ldc"
  dir="$OUT/$label"
  mkdir -p "$dir"

  dub build --root="$ROOT/benchmark/v0_2_cpp_convolution" --compiler="$compiler" --build=release --force > "$dir/build.txt" 2>&1
  cp "$ROOT/benchmark/v0_2_cpp_convolution/raster-v0-2-cpp-convolution" "$tmp/$label"
  sha256sum "$tmp/$label" > "$dir/binary.sha256"
  "$compiler" --version > "$dir/compiler.txt" 2>&1
  objdump -d -C "$tmp/$label" > "$dir/disassembly.txt"

  for process in 0 1 2 3 4 5; do
    snapshot_freq "$label-pre-$process"
    taskset -c "$CPU" "$tmp/$label" > "$dir/run-$process.txt"
    test "$(grep -c '^cpp_gate_d ' "$dir/run-$process.txt")" -eq 2
    test "$(grep -c '^cpp_gate_d_ratio ' "$dir/run-$process.txt")" -eq 1
    snapshot_freq "$label-post-$process"
  done
done

cpp_dir="$OUT/cpp"
mkdir -p "$cpp_dir"

g++ -O3 -std=c++20 -fno-fast-math -ffp-contract=off   "$ROOT/benchmark/v0_2_cpp_convolution/cpp/reference.cpp"   -o "$tmp/cpp-reference" > "$cpp_dir/build.txt" 2>&1

sha256sum "$tmp/cpp-reference" > "$cpp_dir/binary.sha256"
g++ --version > "$cpp_dir/compiler.txt" 2>&1
objdump -d -C "$tmp/cpp-reference" > "$cpp_dir/disassembly.txt"

for process in 0 1 2 3 4 5; do
  snapshot_freq "cpp-pre-$process"
  taskset -c "$CPU" "$tmp/cpp-reference" > "$cpp_dir/run-$process.txt"
  test "$(grep -c '^cpp_gate_cpp ' "$cpp_dir/run-$process.txt")" -eq 1
  snapshot_freq "cpp-post-$process"
done

python3 - "$OUT" <<'PY'
from pathlib import Path
import statistics, sys
root=Path(sys.argv[1])
series={"dmd_public":[],"dmd_direct":[],"ldc_public":[],"ldc_direct":[],"cpp":[]}
checksums={k:set() for k in series}

for compiler in ("dmd","ldc"):
    for path in sorted((root/compiler).glob("run-*.txt")):
        for line in path.read_text().splitlines():
            if not line.startswith("cpp_gate_d "):
                continue
            fields=dict(item.split("=",1) for item in line.split()[1:])
            key=f"{compiler}_{'public' if fields['path']=='public_convolution' else 'direct'}"
            series[key].append(float(fields["ns_per_pixel"]))
            checksums[key].add(fields["checksum"])

for path in sorted((root/"cpp").glob("run-*.txt")):
    for line in path.read_text().splitlines():
        if line.startswith("cpp_gate_cpp "):
            fields=dict(item.split("=",1) for item in line.split()[1:])
            series["cpp"].append(float(fields["ns_per_pixel"]))
            checksums["cpp"].add(fields["checksum"])

for key, values in series.items():
    if len(values)!=6: raise SystemExit(f"{key}: expected 6 values, got {len(values)}")
    if len(checksums[key])!=1: raise SystemExit(f"{key}: unstable checksum {checksums[key]}")

all_checksums={next(iter(v)) for v in checksums.values()}
if len(all_checksums)!=1: raise SystemExit(f"checksum mismatch: {checksums}")

with (root/"summary.txt").open("w") as out:
    for key,values in series.items():
        out.write(f"{key}_n=6 median_ns_per_pixel={statistics.median(values):.6f} min={min(values):.6f} max={max(values):.6f} checksum={next(iter(checksums[key]))}\n")
    cpp=statistics.median(series["cpp"])
    for compiler in ("dmd","ldc"):
        public=statistics.median(series[f"{compiler}_public"])
        direct=statistics.median(series[f"{compiler}_direct"])
        out.write(f"{compiler}_public_over_direct={public/direct:.6f}\n")
        out.write(f"{compiler}_direct_over_cpp={direct/cpp:.6f}\n")
        out.write(f"{compiler}_public_over_cpp={public/cpp:.6f}\n")
PY

snapshot_freq after

(
  cd "$OUT"
  find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum
) > "$OUT/SHA256SUMS"

ARCHIVE="$OUT.tar.gz"
tar -C "$(dirname "$OUT")" -czf "$ARCHIVE" "$(basename "$OUT")"

cat "$OUT/summary.txt"
echo
echo "=== ARCHIVE ==="
sha256sum "$ARCHIVE"
echo "archive=$ARCHIVE"
