#!/usr/bin/env bash

compiler="${1:-${DC:-dmd}}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1
    pwd
)"

tmp_dir="${TMPDIR:-/tmp}/raster-d-block-resolution-internal-$$"

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
module raster_block_resolution_negative_root_export;

import raster :
    RetainedBlockDescriptor,
    DependencyBlockResolveError,
    DependencyBlockResolveStats,
    tryResolveDependencyBlocks;
D

cat > "$tmp_dir/direct_internal.d" <<'D'
module raster_block_resolution_negative_direct_internal;

import raster.internal.block_resolution :
    RetainedBlockDescriptor;

struct Key
{
    size_t id;
}

void useInternalDescriptor()
{
    auto descriptor =
        RetainedBlockDescriptor!Key(
            Key(1),
            typeof(RetainedBlockDescriptor!Key.init.logicalRegion)(
                0,
                0,
                1,
                1
            )
        );

    assert(descriptor.key.id == 1);
}
D

compile_rejection()
{
    name="$1"

    source_file="$tmp_dir/$name.d"
    object_file="$tmp_dir/$name.o"
    log_file="$tmp_dir/$name.log"

    if (
        cd "$repo_root" &&
        "$compiler"             -c             -preview=dip1000             -unittest             "${import_args[@]}"             -of="$object_file"             "$source_file"
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
compile_rejection direct_internal

echo "FAILURES=$failures"

rm -rf "$tmp_dir"

if [ "$failures" -eq 0 ]; then
    true
else
    false
fi
