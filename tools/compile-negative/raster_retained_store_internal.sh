#!/usr/bin/env bash

compiler="${1:-${DC:-dmd}}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1
    pwd
)"

tmp_dir="${TMPDIR:-/tmp}/raster-d-retained-store-internal-$$"

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
module raster_retained_store_negative_root_export;

/*
 * MUST FAIL:
 *
 * Retained-store control-plane types must not be re-exported by raster.
 */
import raster :
    RetainedRasterStore,
    RetainedStoreInsertResult;
D


cat > "$tmp_dir/direct_internal.d" <<'D'
module raster_retained_store_negative_direct_internal;

import raster.internal.retained_store :
    RetainedRasterStore;


struct Key
{
    size_t id;
}


size_t hashKey(
    ref const Key key
)
{
    return key.id;
}


bool sameKey(
    ref const Key lhs,
    ref const Key rhs
)
{
    return lhs == rhs;
}


/*
 * MUST FAIL:
 *
 * External code may name the internal module but package(raster) must prevent
 * use of its retained-store type.
 */
void useInternalStore()
{
    alias Store =
        RetainedRasterStore!(
            ubyte,
            Key,
            4,
            hashKey,
            sameKey
        );

    auto store =
        Store(1024);

    assert(store.entryCount == 0);
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
