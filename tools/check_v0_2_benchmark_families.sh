#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/benchmark/v0_2_families/families.tsv"

if [[ ! -f "$MANIFEST" ]]; then
    echo "ERROR: missing $MANIFEST" >&2
    exit 1
fi

expected_header=$'family\tpublic_surface\tcurrent_harness\tevidence_scope\tstatus'
actual_header="$(head -n 1 "$MANIFEST")"

if [[ "$actual_header" != "$expected_header" ]]; then
    echo "ERROR: unexpected benchmark-family manifest header" >&2
    exit 1
fi

required=(
    reduction
    unary-transform
    fill-copy
    binary-transform-arithmetic
    conversion
    neighbourhood
)

for family in "${required[@]}"; do
    count="$(awk -F '\t' -v family="$family" 'NR > 1 && $1 == family { n++ } END { print n + 0 }' "$MANIFEST")"
    if [[ "$count" != "1" ]]; then
        echo "ERROR: expected exactly one row for family '$family', found $count" >&2
        exit 1
    fi
done

awk -F '\t' '
    NR == 1 { next }
    NF != 5 {
        printf "ERROR: line %d has %d fields, expected 5\n", NR, NF > "/dev/stderr"
        failed = 1
        next
    }
    $5 != "qualified" &&
    $5 != "partial" &&
    $5 != "gap" &&
    $5 != "not-applicable" {
        printf "ERROR: line %d has invalid status %s\n", NR, $5 > "/dev/stderr"
        failed = 1
    }
    END { exit failed ? 1 : 0 }
' "$MANIFEST"

echo "v0.2 benchmark-family manifest OK"
