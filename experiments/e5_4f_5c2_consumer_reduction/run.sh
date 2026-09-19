#!/usr/bin/env bash

set -eu

ROOT="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
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


echo '=== E5.4f.5c.2 CONSUMER REDUCTION — ORIGINAL REPLAY ==='
echo "compiler=$COMPILER"
"$COMPILER" --version
echo

echo '=== SOURCE INTEGRITY ==='

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
        "${TMPDIR:-/tmp}/imagery-d-e5_4f_5c2-replay.XXXXXX"
)"

trap 'rm -rf "$RUN"' EXIT

EXE="$RUN/consumer_reduction"
OUT="$RUN/consumer_reduction.out"
ERR="$RUN/consumer_reduction.err"
EXPECTED="$RUN/consumer_reduction.expected"

cat > "$EXPECTED" <<'EOF_EXPECTED'
sameTypeCases=972405
sameTypeOverlapCases=307920
maxSameTypeCandidates=2
ubyteToFloatCases=194481
ubyteToFloatOverlapCases=56385
ubyteToFloatCandidateCount=4
consumer-specific displacement reduction: PASS
EOF_EXPECTED


echo
echo '=== BUILD ==='

"$COMPILER" \
    -preview=dip1000 \
    "$ROOT/original/consumer_reduction.d" \
    "-of=$EXE"

echo 'build: PASS'


echo
echo '=== EXECUTE ==='

"$EXE" >"$OUT" 2>"$ERR"

if [ -s "$ERR" ]; then
    echo 'unexpected stderr: FAIL' >&2
    cat "$ERR" >&2
    exit 1
fi

if ! cmp -s "$EXPECTED" "$OUT"; then
    echo 'output mismatch: FAIL' >&2
    diff -u "$EXPECTED" "$OUT" || true
    exit 1
fi

cat "$OUT"

echo
echo '=== RESULT ==='
echo 'E5.4f.5c.2 consumer reduction replay: PASS'
