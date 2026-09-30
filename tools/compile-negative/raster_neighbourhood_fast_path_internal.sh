#!/usr/bin/env bash

compiler="${1:-${DC:-dmd}}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1
    pwd
)"

tmp_dir="${TMPDIR:-/tmp}/raster-d-neighbourhood-fast-path-internal-$$"

mkdir -p "$tmp_dir"

failures=0

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required"
    false
fi

if ! (
    cd "$repo_root" &&
    dub describe --compiler="$compiler"
) >"$tmp_dir/describe.json"
then
    echo "ERROR: dub describe failed"
    false
fi

import_args=()

while IFS= read -r path
do
    if [ -n "$path" ]; then
        import_args+=("-I$path")
    fi
done < <(
    jq -r '
        .packages[]
        | .path as $base
        | (.importPaths // [])[]
        | if startswith("/")
          then .
          else ($base + "/" + .)
          end
    ' "$tmp_dir/describe.json"
)

cat > "$tmp_dir/root_export.d" <<'D'
module raster_neighbourhood_fast_path_negative_root_export;

import raster :
    executeApprovedNeighbourhood3x3,
    useLdc2111NegativeFloatNeighbourhoodRowBoundary;
D

cat > "$tmp_dir/direct_dispatch.d" <<'D'
module raster_neighbourhood_fast_path_negative_direct_dispatch;

import raster.internal.neighbourhood_dispatch :
    executeApprovedNeighbourhood3x3;

@safe
pure
nothrow
@nogc
float center(ref const(float)[9] n)
{
    return n[4];
}

void invalidExternalUse()
{
    float[9] source;
    float[1] destination;

    executeApprovedNeighbourhood3x3!center(
        source.ptr,
        3,
        1,
        1,
        1,
        1,
        destination.ptr,
        1
    );
}
D

cat > "$tmp_dir/direct_capability.d" <<'D'
module raster_neighbourhood_fast_path_negative_direct_capability;

import raster.internal.compiler_capabilities :
    useLdc2111NegativeFloatNeighbourhoodRowBoundary;

enum bool leaked =
    useLdc2111NegativeFloatNeighbourhoodRowBoundary;
D

compile_rejection()
{
    name="$1"

    source_file="$tmp_dir/$name.d"
    object_file="$tmp_dir/$name.o"
    log_file="$tmp_dir/$name.log"

    if (
        cd "$repo_root" &&
        "$compiler" \
            -c \
            -preview=dip1000 \
            -unittest \
            "${import_args[@]}" \
            -of="$object_file" \
            "$source_file"
    ) >"$log_file" 2>&1
    then
        echo "FAIL expected-rejection: $name compiled successfully"
        failures=$((failures + 1))
    else
        echo "PASS expected-rejection: $name"
        echo "  compiler diagnostic:"
        sed -n '1,120p' "$log_file" | sed 's/^/    /'
    fi
}

echo "compiler=$compiler"

compile_rejection root_export
compile_rejection direct_dispatch
compile_rejection direct_capability

echo "FAILURES=$failures"

rm -rf "$tmp_dir"

if [ "$failures" -eq 0 ]; then
    true
else
    false
fi
