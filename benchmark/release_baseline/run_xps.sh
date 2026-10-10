#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
FEATURE_FREEZE="658f4fd48a2141b4434996e2ed9e1044bf0d5ad3"
FEATURE_TAG="freeze/feature-0.2.0"
CPU="${2:-0}"
OUT="${1:-/tmp/raster-release-0.2-baseline-$(date +%Y%m%d-%H%M%S)}"

test ! -e "$OUT"
mkdir -p "$OUT"

if ! git -C "$ROOT" merge-base --is-ancestor "$FEATURE_FREEZE" HEAD; then
    echo "STOP: release branch no longer descends from feature-freeze baseline" >&2
    exit 1
fi

if ! git -C "$ROOT" show-ref --verify --quiet "refs/tags/$FEATURE_TAG"; then
    echo "STOP: required feature-freeze tag is missing: $FEATURE_TAG" >&2
    exit 1
fi

tag_commit="$(git -C "$ROOT" rev-list -n 1 "$FEATURE_TAG")"

if [[ "$tag_commit" != "$FEATURE_FREEZE" ]]; then
    echo "STOP: feature-freeze tag points at $tag_commit, expected $FEATURE_FREEZE" >&2
    exit 1
fi

mapfile -t source_changes < <(
    git -C "$ROOT" diff --name-only "$FEATURE_FREEZE"..HEAD -- source/raster
)

if (("${#source_changes[@]}" != 0)); then
    echo "STOP: production source changed after the v0.2 feature freeze" >&2
    printf '  %s\n' "${source_changes[@]}" >&2
    exit 1
fi

source_tree_matches_feature_freeze=yes

snapshot_freq()
{
    local tag="$1"
    {
        echo "tag=$tag"
        date -u +%Y-%m-%dT%H:%M:%SZ
        for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
            [[ -d "$cpu/cpufreq" ]] || continue
            id="${cpu##*cpu}"
            gov="$(cat "$cpu/cpufreq/scaling_governor" 2>/dev/null || true)"
            cur="$(cat "$cpu/cpufreq/scaling_cur_freq" 2>/dev/null || true)"
            min="$(cat "$cpu/cpufreq/scaling_min_freq" 2>/dev/null || true)"
            max="$(cat "$cpu/cpufreq/scaling_max_freq" 2>/dev/null || true)"
            printf 'cpu=%s governor=%s cur_khz=%s min_khz=%s max_khz=%s\n'                 "$id" "$gov" "$cur" "$min" "$max"
        done
        for path in /sys/class/thermal/thermal_zone*/temp; do
            [[ -r "$path" ]] || continue
            printf '%s=' "$path"
            cat "$path"
        done
    } > "$OUT/frequency-thermal-$tag.txt"
}

{
    echo "benchmark_head=$(git -C "$ROOT" rev-parse HEAD)"
    echo "feature_freeze=$FEATURE_FREEZE"
    echo "feature_tag=$FEATURE_TAG"
    echo "branch=$(git -C "$ROOT" branch --show-current)"
    echo "source_tree_matches_feature_freeze=$source_tree_matches_feature_freeze"
    printf 'source_change_from_feature_freeze=%s\n' "${source_changes[@]:-none}"
    echo "cpu=$CPU"
    echo "shell_affinity=$(taskset -pc $$ 2>&1 || true)"
    echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    uname -a
    lscpu
    dub --version
    dmd --version
    ldc2 --version
} > "$OUT/environment.txt"

snapshot_freq before

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for compiler in dmd ldc2; do
    label="$compiler"
    [[ "$compiler" == "ldc2" ]] && label="ldc"

    dir="$OUT/$label"
    mkdir -p "$dir"

    dub build         --root="$ROOT/benchmark/release_baseline"         --compiler="$compiler"         --build=release         --force         > "$dir/build.txt" 2>&1

    cp "$ROOT/benchmark/release_baseline/raster-release-baseline"         "$tmp/$label"

    sha256sum "$tmp/$label" > "$dir/binary.sha256"
    "$compiler" --version > "$dir/compiler.txt" 2>&1

    for process in 0 1 2 3 4 5; do
        snapshot_freq "$label-pre-$process"

        taskset -c "$CPU" "$tmp/$label"             > "$dir/run-$process.txt"

        test "$(grep -c '^release_benchmark ' "$dir/run-$process.txt")" -eq 9

        snapshot_freq "$label-post-$process"
    done

    python3 - "$dir" <<'PY'
from pathlib import Path
import statistics
import sys

root=Path(sys.argv[1])
rows={}
checksums={}

for path in sorted(root.glob("run-*.txt")):
    for line in path.read_text().splitlines():
        if not line.startswith("release_benchmark "):
            continue
        fields=dict(item.split("=",1) for item in line.split()[1:])
        key=fields["workload"]
        rows.setdefault(key,[]).append(float(fields["ns_per_pixel"]))
        checksums.setdefault(key,set()).add(fields["checksum"])

if len(rows) != 9:
    raise SystemExit(f"expected 9 workloads, got {len(rows)}")

for key,values in rows.items():
    if len(values) != 6:
        raise SystemExit(f"{key}: expected 6 runs, got {len(values)}")
    if len(checksums[key]) != 1:
        raise SystemExit(f"{key}: checksum mismatch across processes")

with (root/"summary.txt").open("w") as out:
    for key in sorted(rows):
        values=rows[key]
        out.write(
            f"workload={key} n={len(values)} "
            f"median_ns_per_pixel={statistics.median(values):.6f} "
            f"min={min(values):.6f} max={max(values):.6f} "
            f"checksum={next(iter(checksums[key]))}\n"
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
echo "=== DMD SUMMARY ==="
cat "$OUT/dmd/summary.txt"
echo
echo "=== LDC SUMMARY ==="
cat "$OUT/ldc/summary.txt"
echo
echo "=== ARCHIVE ==="
sha256sum "$ARCHIVE"
echo "archive=$ARCHIVE"
echo "manifest=$OUT/SHA256SUMS"
