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
    echo "usage: $0 <d-compiler>" >&2
    echo "example: $0 dmd" >&2
    echo "example: $0 ldc2" >&2
    exit 2
fi

COMPILER="$1"

if ! command -v "$COMPILER" >/dev/null 2>&1; then
    echo "compiler not found: $COMPILER" >&2
    exit 2
fi

COMPILER_VERSION="$("$COMPILER" --version 2>&1)"

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

echo '=== E5.3 CONVERSION OPTIMIZATION — REPLAY ==='
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
        "${TMPDIR:-/tmp}/raster-d-e5_3-replay.XXXXXX"
)"

trap 'rm -rf "$RUN"' EXIT

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


echo
echo '=== PRODUCTION SEMANTICS ==='

EXE="$RUN/scalar-conversion-unittest"

(
    cd "$RUN"

    "$COMPILER" \
        -unittest \
        -main \
        -preview=dip1000 \
        "${IMPORT_ARGS[@]}" \
        "$REPO/source/raster/internal/scalar_conversion.d" \
        "-of=$EXE"
)

"$EXE" \
    >"$RUN/semantic.out" \
    2>"$RUN/semantic.err"

if [ -s "$RUN/semantic.err" ]; then
    if ! awk '
        NF {
            seen = 1

            if ($0 !~ /^[0-9]+ modules? passed unittests$/)
                bad = 1
        }

        END {
            exit !(seen && !bad)
        }
    ' "$RUN/semantic.err"
    then
        echo 'unexpected semantic-test stderr' >&2
        cat "$RUN/semantic.err" >&2
        exit 1
    fi

    echo 'semantic-test stderr contains only unittest summary: PASS'
    cat "$RUN/semantic.err"
fi

echo 'production scalar-conversion semantics: PASS'


case "$COMPILER_VERSION" in
    *"LDC - the LLVM D compiler"*)
        ;;
    *)
        echo
        echo 'LDC/LLVM structural replay: SKIPPED'
        echo 'compiler-neutral semantic replay completed'
        echo

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

        echo '=== RESULT ==='
        echo 'E5.3 conversion replay: PASS'
        exit 0
        ;;
esac


echo
echo '=== LDC/LLVM STRUCTURAL REPLAY ==='

(
    cd "$RUN"

    "$COMPILER" \
        -O3 \
        -release \
        -preview=dip1000 \
        -output-ll \
        -c \
        "${IMPORT_ARGS[@]}" \
        "$ROOT/original/alias_codegen/alias_probe.d" \
        "-of=$RUN/alias.ll"
)

(
    cd "$RUN"

    "$COMPILER" \
        -O3 \
        -release \
        -preview=dip1000 \
        -output-ll \
        -c \
        "${IMPORT_ARGS[@]}" \
        "$REPO/source/raster/internal/scalar_conversion.d" \
        "-of=$RUN/production.ll"
)

python3 - \
    "$RUN/alias.ll" \
    "$RUN/production.ll" <<'PY'
from pathlib import Path
import re
import sys


def read(path):
    return Path(path).read_text(encoding="utf-8")


def function_exact(text, name):
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


def function_containing(text, fragment):
    lines = text.splitlines()

    for index, line in enumerate(lines):
        if (
            line.startswith("define ")
            and fragment in line
        ):
            body = [line]

            for next_line in lines[index + 1:]:
                body.append(next_line)

                if next_line == "}":
                    break
            else:
                raise SystemExit(
                    f"{fragment}: unterminated LLVM function"
                )

            return line, "\n".join(body)

    raise SystemExit(
        f"{fragment}: LLVM function not found"
    )


alias = read(sys.argv[1])
production = read(sys.argv[2])

unknown_sig, unknown_body = function_exact(
    alias,
    "rawConvertUnknown",
)

restrict_sig, restrict_body = function_exact(
    alias,
    "rawConvertRestrict",
)

if " noalias " in unknown_sig:
    raise SystemExit(
        "raw unknown-alias unexpectedly has noalias"
    )

if "vector.memcheck" not in unknown_body:
    raise SystemExit(
        "raw unknown-alias lost runtime vector memcheck; review required"
    )

if restrict_sig.count(" noalias ") < 2:
    raise SystemExit(
        "raw restrict lost parameter noalias"
    )

if "vector.memcheck" in restrict_body:
    raise SystemExit(
        "raw restrict unexpectedly gained vector memcheck"
    )

vector_convert = re.compile(
    r"uitofp <[0-9]+ x i8> .* to <[0-9]+ x float>"
)

if not vector_convert.search(unknown_body):
    raise SystemExit(
        "raw unknown-alias is no longer vectorized as expected"
    )

if not vector_convert.search(restrict_body):
    raise SystemExit(
        "raw restrict is no longer vectorized as expected"
    )

print("alias/noalias structural contrast: PASS")


_, production_body = function_containing(
    production,
    "scalarConvertUbyteToFloatContiguous1D",
)

if "vector.memcheck" not in production_body:
    raise SystemExit(
        "production conversion lost runtime alias versioning; review required"
    )

if not vector_convert.search(production_body):
    raise SystemExit(
        "production ubyte-to-float loop is no longer vectorized"
    )

if not re.search(
    r"store <[0-9]+ x float>",
    production_body,
):
    raise SystemExit(
        "production conversion has no vector float store"
    )

print("production auto-vectorization/runtime alias versioning: PASS")
PY


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
echo 'E5.3 conversion replay: PASS'
