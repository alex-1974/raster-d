#!/usr/bin/env bash

set -euo pipefail

ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

REPO="$(
    cd "$ROOT/../.." &&
    pwd
)"

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <ldc-compiler>" >&2
    echo "example: $0 ldc2" >&2
    exit 2
fi

COMPILER="$1"

if ! command -v "$COMPILER" >/dev/null 2>&1; then
    echo "compiler not found: $COMPILER" >&2
    exit 2
fi

COMPILER_VERSION="$("$COMPILER" --version 2>&1)"

case "$COMPILER_VERSION" in
    *"LDC - the LLVM D compiler"*)
        ;;
    *)
        echo "E4 structural replay requires LDC/LLVM" >&2
        exit 2
        ;;
esac

hash_file()
{
    file="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return
    fi

    python3 - "$file" <<'PY'
from hashlib import sha256
from pathlib import Path
import sys

h = sha256()

with Path(sys.argv[1]).open("rb") as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b""):
        h.update(chunk)

print(h.hexdigest())
PY
}

echo '=== E4 EXECUTION SPECIALIZATION — REPLAY ==='
echo "compiler=$COMPILER"
printf '%s\n' "$COMPILER_VERSION"
echo

echo '=== HISTORICAL SOURCE INTEGRITY ==='

while read -r expected relative
do
    file="$ROOT/$relative"

    if [ ! -f "$file" ]; then
        echo "$relative: MISSING" >&2
        exit 1
    fi

    actual="$(hash_file "$file")"

    if [ "$actual" != "$expected" ]; then
        echo "$relative: HASH FAIL" >&2
        echo "expected=$expected" >&2
        echo "actual  =$actual" >&2
        exit 1
    fi

    echo "$relative: PASS"
done < "$ROOT/SHA256SUMS"

RUN="$(
    mktemp -d \
        "${TMPDIR:-/tmp}/raster-d-e4-replay.XXXXXX"
)"

trap 'rm -rf "$RUN"' EXIT


bridge_historical_source()
{
    source="$1"
    target="$2"

    mkdir -p "$(dirname "$target")"

    python3 - "$source" "$target" <<'PY_BRIDGE'
from pathlib import Path
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])

text = source.read_text()

if "imagery.raster" not in text:
    raise SystemExit(
        f"historical replay bridge source contains no old namespace: {source}"
    )

translated = text.replace(
    "imagery.raster",
    "raster",
)

if "imagery.raster" in translated:
    raise SystemExit(
        f"historical replay bridge incomplete: {source}"
    )

target.write_text(translated)
PY_BRIDGE
}


POLICY_SOURCE="$RUN/historical/policy_codegen/policy_probe.d"
LANE4_SOURCE="$RUN/historical/fixed_lane4/lane_probe.d"
BASELINE_SOURCE="$RUN/historical/noalias/current_baseline.d"
INITIAL_SOURCE="$RUN/historical/initial_codegen/codegen_probe.d"
MIR_SOURCE="$RUN/historical/noalias/mir_probe.d"

bridge_historical_source \
    "$ROOT/original/policy_codegen/policy_probe.d" \
    "$POLICY_SOURCE"

bridge_historical_source \
    "$ROOT/original/fixed_lane4/lane_probe.d" \
    "$LANE4_SOURCE"

bridge_historical_source \
    "$ROOT/original/noalias/current_baseline.d" \
    "$BASELINE_SOURCE"

bridge_historical_source \
    "$ROOT/original/initial_codegen/codegen_probe.d" \
    "$INITIAL_SOURCE"

bridge_historical_source \
    "$ROOT/original/noalias/mir_probe.d" \
    "$MIR_SOURCE"


(
    cd "$REPO"
    git status --porcelain=v1 --untracked-files=all
) > "$RUN/status.before"

(
    cd "$REPO"
    dub describe --compiler="$COMPILER"
) > "$RUN/dub-describe.json"

python3 - \
    "$RUN/dub-describe.json" \
    "$RUN/import-paths.txt" <<'PY'
import json
import os
import sys

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

paths = []

for package in data.get("packages", []):
    base = package.get("path", "")
    candidates = package.get("importPaths")

    if candidates is None:
        candidates = package.get("sourcePaths", [])

    for path in candidates:
        if not os.path.isabs(path):
            path = os.path.join(base, path)

        path = os.path.normpath(path)

        if path not in paths:
            paths.append(path)

with open(sys.argv[2], "w", encoding="utf-8") as f:
    for path in paths:
        f.write(path + "\n")
PY

IMPORT_ARGS=("-I$REPO/source")

while IFS= read -r path
do
    [ -n "$path" ] || continue
    IMPORT_ARGS+=("-I$path")
done < "$RUN/import-paths.txt"

compile_ir()
{
    name="$1"
    source="$2"

    echo "compile $name"

    (
        cd "$RUN"

        "$COMPILER" \
            -O3 \
            -release \
            -preview=dip1000 \
            -output-ll \
            -c \
            "${IMPORT_ARGS[@]}" \
            "$source" \
            "-of=$RUN/$name.ll"
    )
}

compile_ir \
    pointer \
    "$ROOT/original/noalias/pointer_probe.d"

compile_ir \
    policy \
    "$POLICY_SOURCE"

compile_ir \
    lane4 \
    "$LANE4_SOURCE"

compile_ir \
    current_baseline \
    "$BASELINE_SOURCE"

compile_ir \
    initial_codegen \
    "$INITIAL_SOURCE"

echo
echo '=== STRUCTURAL LLVM IR CONTRACT ==='

python3 - \
    "$RUN/pointer.ll" \
    "$RUN/policy.ll" \
    "$RUN/lane4.ll" \
    "$RUN/current_baseline.ll" \
    "$RUN/initial_codegen.ll" <<'PY'
from pathlib import Path
import sys


def read(path):
    return Path(path).read_text(encoding="utf-8")


def function(text, name):
    lines = text.splitlines()

    for index, line in enumerate(lines):
        if line.startswith("define ") and f"@{name}(" in line:
            body = [line]

            for next_line in lines[index + 1:]:
                body.append(next_line)

                if next_line == "}":
                    break
            else:
                raise SystemExit(
                    f"{name}: unterminated LLVM function"
                )

            return line, "\n".join(body)

    raise SystemExit(
        f"{name}: LLVM function not found"
    )


pointer = read(sys.argv[1])
policy = read(sys.argv[2])
lane4 = read(sys.argv[3])
baseline = read(sys.argv[4])
initial = read(sys.argv[5])


unknown_sig, unknown_body = function(
    pointer,
    "e43CopyPointerUnknown",
)

restrict_sig, restrict_body = function(
    pointer,
    "e43CopyPointerRestrict",
)

if " noalias " in unknown_sig:
    raise SystemExit(
        "pointer unknown-alias unexpectedly has noalias"
    )

if restrict_sig.count(" noalias ") < 2:
    raise SystemExit(
        "pointer restrict lost parameter noalias"
    )

if "@llvm.memcpy" not in restrict_body:
    raise SystemExit(
        "pointer restrict no longer lowers to llvm.memcpy"
    )

print("pointer restrict/noalias/memcpy: PASS")


copy_unknown_sig, _ = function(
    policy,
    "copy_unknown_alias",
)

copy_restrict_sig, copy_restrict_body = function(
    policy,
    "copy_restrict",
)

_, strict_body = function(
    policy,
    "sum_f32_f64_strict",
)

_, fast_body = function(
    policy,
    "sum_f32_f64_fastmath",
)

if " noalias " in copy_unknown_sig:
    raise SystemExit(
        "policy unknown-alias unexpectedly has noalias"
    )

if copy_restrict_sig.count(" noalias ") < 2:
    raise SystemExit(
        "policy restrict lost parameter noalias"
    )

if "@llvm.memcpy" not in copy_restrict_body:
    raise SystemExit(
        "policy restrict no longer lowers to llvm.memcpy"
    )

if "fadd fast" in strict_body:
    raise SystemExit(
        "strict floating reduction acquired fast-math"
    )

if "fadd fast" not in fast_body:
    raise SystemExit(
        "fast-math probe lost fast floating operations"
    )

print("strict-vs-fastmath policy: PASS")


_, lane4_body = function(
    lane4,
    "sum_fixed_lane4",
)

if "fadd" not in lane4_body:
    raise SystemExit(
        "fixed lane4 contains no floating additions"
    )

if "fadd fast" in lane4_body:
    raise SystemExit(
        "fixed lane4 unexpectedly acquired fast-math"
    )

print("fixed-lane4 semantic codegen: PASS")


function(
    baseline,
    "e43CurrentScalarCopy",
)

for symbol in (
    "d_imagery_copy_u8_mir",
    "d_imagery_copy_u8_raw",
    "d_imagery_sum_u8_u64_mir",
    "d_imagery_sum_u8_u64_raw",
    "d_imagery_sum_f32_f64_mir",
    "d_imagery_sum_f32_f64_raw",
):
    function(initial, symbol)

print("baseline and initial probe symbols: PASS")
PY


expected_negative()
{
    name="$1"
    source="$2"
    symbol="$3"

    out="$RUN/$name.out"
    err="$RUN/$name.err"
    ir="$RUN/$name.ll"

    echo
    echo "=== TOOLCHAIN CHANGE DETECTOR: $name ==="

    if (
        cd "$RUN"

        "$COMPILER" \
            -O3 \
            -release \
            -preview=dip1000 \
            -output-ll \
            -c \
            "${IMPORT_ARGS[@]}" \
            "$source" \
            "-of=$ir" \
            >"$out" \
            2>"$err"
    )
    then
        echo "$name: REVIEW REQUIRED" >&2
        echo "historically invalid @restrict shape now compiles" >&2
        exit 1
    fi

    if ! grep -Fq \
        "Attribute 'noalias' applied to incompatible type!" \
        "$err"
    then
        echo "$name: REVIEW REQUIRED" >&2
        echo "expected noalias verifier diagnostic changed" >&2
        cat "$err" >&2
        exit 1
    fi

    if ! grep -Fq \
        "$symbol" \
        "$err"
    then
        echo "$name: REVIEW REQUIRED" >&2
        echo "expected symbol missing from verifier diagnostic" >&2
        cat "$err" >&2
        exit 1
    fi

    if ! grep -Fq \
        "LLVM ERROR: Broken module found" \
        "$err"
    then
        echo "$name: REVIEW REQUIRED" >&2
        echo "expected LLVM verifier failure changed" >&2
        cat "$err" >&2
        exit 1
    fi

    echo "$name: expected historical failure reproduced: PASS"
}

expected_negative \
    slice_restrict \
    "$ROOT/original/noalias/slice_probe.d" \
    "e43CopySliceRestrict"

expected_negative \
    mir_restrict \
    "$MIR_SOURCE" \
    "e43CopyMirRestrict"


echo
echo '=== REASSOC HISTORICAL PROBE ==='

if (
    cd "$RUN"

    "$COMPILER" \
        -c \
        "$ROOT/original/fixed_lane4/reassoc_warning.d" \
        "-of=$RUN/reassoc.o" \
        >"$RUN/reassoc.out" \
        2>"$RUN/reassoc.err"
)
then
    echo 'reassoc source compiles: PASS'
else
    echo 'reassoc source no longer compiles: REVIEW REQUIRED' >&2
    cat "$RUN/reassoc.err" >&2
    exit 1
fi

if [ -s "$RUN/reassoc.err" ]; then
    echo 'reassoc compiler diagnostics:'
    cat "$RUN/reassoc.err"
else
    echo 'reassoc compiler diagnostics: <empty>'
fi

echo 'historical warning text is intentionally not a live gate'


(
    cd "$REPO"
    git status --porcelain=v1 --untracked-files=all
) > "$RUN/status.after"

if ! cmp -s \
    "$RUN/status.before" \
    "$RUN/status.after"
then
    echo 'repository state changed during replay' >&2
    diff -u \
        "$RUN/status.before" \
        "$RUN/status.after" \
        || true
    exit 1
fi

echo
echo '=== RESULT ==='
echo 'E4 execution-specialization replay: PASS'
