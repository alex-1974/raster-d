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

PROBE="$ROOT/original/production_equivalence.d"

RELATION="$REPO/source/raster/internal/affine_relation.d"


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

if [ ! -f "$RELATION" ]; then
    echo "production relation module missing: $RELATION" >&2
    exit 1
fi


hash_file()
{
    file="$1"

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" |
        awk '{print $1}'
        return
    fi

    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" |
        awk '{print $1}'
        return
    fi

    python3 - "$file" <<'PY'
from hashlib import sha256
from pathlib import Path
import sys

digest = sha256()

with Path(sys.argv[1]).open("rb") as stream:
    for chunk in iter(
        lambda: stream.read(1024 * 1024),
        b""
    ):
        digest.update(chunk)

print(digest.hexdigest())
PY
}


echo '=== E5.4f.5c.2 PRODUCTION RELATION EQUIVALENCE ==='
echo "compiler=$COMPILER"

if git -C "$REPO" rev-parse HEAD >/dev/null 2>&1; then
    echo "HEAD=$(git -C "$REPO" rev-parse HEAD)"
fi

echo "productionRelationSha256=$(hash_file "$RELATION")"

"$COMPILER" --version


echo
echo '=== PROBE INTEGRITY ==='

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
        "${TMPDIR:-/tmp}/raster-d-e5_4f_5c2-prod-eq.XXXXXX"
)"

cleanup()
{
    rm -rf "$RUN"
}

trap cleanup EXIT


REPLAY_PROBE="$RUN/production_equivalence.d"

python3 - "$PROBE" "$REPLAY_PROBE" <<'PY_BRIDGE'
from pathlib import Path
import sys

source = Path(sys.argv[1])
target = Path(sys.argv[2])

text = source.read_text()

if text.count("imagery.raster") != 2:
    raise SystemExit(
        "historical production-equivalence probe has unexpected namespace shape"
    )

translated = text.replace(
    "imagery.raster",
    "raster",
)

if "imagery.raster" in translated:
    raise SystemExit(
        "historical production-equivalence replay bridge incomplete"
    )

target.write_text(translated)
PY_BRIDGE


EXE="$RUN/production_equivalence"
OUT="$RUN/production_equivalence.out"
ERR="$RUN/production_equivalence.err"
EXPECTED="$RUN/production_equivalence.expected"


cat > "$EXPECTED" <<'EOF_EXPECTED'
injectivityCases=4225
overlapCases=550000
expectedOverlapCases=234041
expectedDisjointCases=315959
production affine relation equivalence: PASS
EOF_EXPECTED


echo
echo '=== BUILD ==='

"$COMPILER" \
    -preview=dip1000 \
    "-I$REPO/source" \
    "$REPLAY_PROBE" \
    "$RELATION" \
    "-of=$EXE"

echo 'build: PASS'


echo
echo '=== EXECUTE ==='

"$EXE" \
    > "$OUT" \
    2> "$ERR"

if [ -s "$ERR" ]; then
    echo 'unexpected stderr: FAIL' >&2
    cat "$ERR" >&2
    exit 1
fi

if ! cmp -s "$EXPECTED" "$OUT"; then
    echo 'deterministic output mismatch: FAIL' >&2
    diff -u "$EXPECTED" "$OUT" || true
    exit 1
fi

cat "$OUT"


echo
echo '=== RESULT ==='
echo 'production affine relation equivalence replay: PASS'
