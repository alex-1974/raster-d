#!/usr/bin/env bash

compiler="${1:-${DC:-dmd}}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1
    pwd
)"

tmp_dir="${TMPDIR:-/tmp}/raster-d-residency-internal-$$"

mkdir -p "$tmp_dir"

failures=0


if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required"
    exit 1
fi


if ! (
    cd "$repo_root" &&
    dub describe --compiler="$compiler"
) >"$tmp_dir/describe.json"
then
    echo "ERROR: dub describe failed"
    exit 1
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
module raster_residency_negative_root_export;

/*
 * MUST FAIL:
 *
 * Residency accounting is package-internal and must not be re-exported by the
 * public raster umbrella module.
 */
import raster :
    ResidencyBudget;
D


cat > "$tmp_dir/direct_internal.d" <<'D'
module raster_residency_negative_direct_internal;

import raster.internal.residency :
    ResidencyBudget;


/*
 * MUST FAIL:
 *
 * External code may name the internal module but package(raster) must prevent
 * use of its residency-accounting type.
 */
void useInternalResidency()
{
    auto budget =
        ResidencyBudget(64);

    assert(budget.tryAdmit(32));
}
D


cat > "$tmp_dir/lease_cost.d" <<'D'
module raster_residency_negative_lease_cost;

import raster :
    RasterLease;


/*
 * MUST FAIL:
 *
 * Physical-resource byte accounting is an internal control-plane query.
 */
void inspectLeaseCost(
    ref RasterLease!ubyte lease
)
{
    size_t bytes;

    auto ok =
        lease.tryPhysicalResourceBytes(
            bytes
        );

    assert(ok || bytes == 0);
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
compile_rejection lease_cost

echo "FAILURES=$failures"

rm -rf "$tmp_dir"

if [ "$failures" -eq 0 ]; then
    true
else
    false
fi
