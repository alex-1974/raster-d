#!/usr/bin/env bash

compiler="${1:-${DC:-dmd}}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1
    pwd
)"

tmp_dir="${TMPDIR:-/tmp}/raster-d-raster-import-public-$$"

mkdir -p "$tmp_dir"

failures=0


if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required"
    exit 1
fi


# Compile external/public-surface probes with the same package import paths
# that a real DUB consumer sees.  This matters once the public umbrella module
# re-exports operations whose implementation depends on internal Mir modules.
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


if [ "${#import_args[@]}" -eq 0 ]; then
    echo "ERROR: dub describe produced no import paths"
    exit 1
fi


cat > "$tmp_dir/positive_safe.d" <<'D'
module raster_import_public_positive_safe;

import raster :
    OwnedByteResource,
    OwnedRasterImportError,
    OwnedRasterImportResult,
    OwnedRasterResourceDisposition,
    PlaneByteLayout,
    RasterLease,
    Region2D,
    tryImportOwnedRaster;


@safe
OwnedRasterImportResult importFromSafeCode(
    ref OwnedByteResource resource,
    ref RasterLease!ubyte lease
)
{
    PlaneByteLayout[1] planes =
    [
        PlaneByteLayout(
            0,
            4,
            1
        )
    ];


    auto result =
        tryImportOwnedRaster!ubyte(
            resource,
            planes[],
            Region2D(
                0,
                0,
                4,
                1
            ),
            lease
        );


    if (result.ok)
    {
        assert(
            result.error
            == OwnedRasterImportError.none
        );

        assert(
            result.resourceDisposition
            == OwnedRasterResourceDisposition.transferredToLease
        );
    }


    return result;
}
D


cat > "$tmp_dir/internal_surface.d" <<'D'
module raster_import_public_negative_internal_surface;


/*
 * MUST FAIL:
 *
 * Package-internal import mechanics must not be exported by raster.
 */
import raster :
    SingleResourceRasterImportError,
    SingleResourceRasterImportResult,
    importSingleOwnedResource;
D


cat > "$tmp_dir/result_constructor.d" <<'D'
module raster_import_public_negative_result_constructor;

import raster :
    OwnedRasterImportError,
    OwnedRasterImportResult,
    OwnedRasterResourceDisposition;


/*
 * MUST FAIL:
 *
 * Public callers may not fabricate an arbitrary successful ownership result
 * through the module-private constructor.
 */
void invalidResultConstruction()
{
    auto result =
        OwnedRasterImportResult(
            OwnedRasterImportError.none,
            size_t.max,
            OwnedRasterResourceDisposition.transferredToLease
        );
}
D


cat > "$tmp_dir/result_mutation.d" <<'D'
module raster_import_public_negative_result_mutation;

import raster :
    OwnedRasterImportError,
    OwnedRasterImportResult;


/*
 * MUST FAIL:
 *
 * Public callers may inspect but may not fabricate error/disposition states.
 */
void invalidResultMutation()
{
    OwnedRasterImportResult result;

    result.error_ =
        OwnedRasterImportError.none;
}
D


compile_probe()
{
    name="$1"
    expectation="$2"

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
        compiled=yes
    else
        compiled=no
    fi


    if [ "$expectation" = "pass" ]; then
        if [ "$compiled" = "yes" ]; then
            echo "PASS expected-compile: $name"
        else
            echo "FAIL expected-compile: $name"
            sed -n '1,160p' "$log_file"
            failures=$((failures + 1))
        fi
    else
        if [ "$compiled" = "no" ]; then
            echo "PASS expected-rejection: $name"
            echo "  compiler diagnostic:"
            sed -n '1,120p' "$log_file" | sed 's/^/    /'
        else
            echo "FAIL expected-rejection: $name compiled successfully"
            failures=$((failures + 1))
        fi
    fi
}


echo "compiler=$compiler"

compile_probe positive_safe pass
compile_probe internal_surface reject
compile_probe result_constructor reject
compile_probe result_mutation reject

echo "FAILURES=$failures"

rm -rf "$tmp_dir"

if [ "$failures" -eq 0 ]; then
    true
else
    false
fi
