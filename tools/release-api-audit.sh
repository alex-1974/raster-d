#!/usr/bin/env bash
set -euo pipefail

compiler="\${1:-\${DC:-dmd}}"
repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1
    pwd
)"
tmp_dir="$(mktemp -d "\${TMPDIR:-/tmp}/raster-api-freeze-XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required" >&2
    exit 1
fi

(
    cd "$repo_root"
    dub describe --compiler="$compiler"
) >"$tmp_dir/describe.json"

import_args=()
while IFS= read -r path; do
    [[ -n "$path" ]] && import_args+=("-I$path")
done < <(
    jq -r '
      .packages[]
      | .path as $base
      | (.importPaths // [])[]
      | if startswith("/") then . else ($base + "/" + .) end
    ' "$tmp_dir/describe.json"
)

failures=0

compile_probe()
{
    local name="$1"
    local expectation="$2"
    local source="$tmp_dir/$name.d"
    local object="$tmp_dir/$name.o"
    local log="$tmp_dir/$name.log"

    if (
        cd "$repo_root"
        "$compiler" -c -preview=dip1000 "\${import_args[@]}" \
            -of="$object" "$source"
    ) >"$log" 2>&1; then
        actual=pass
    else
        actual=reject
    fi

    if [[ "$actual" == "$expectation" ]]; then
        echo "PASS expected-$expectation: $name"
        if [[ "$expectation" == reject ]]; then
            sed -n '1,20p' "$log" | sed 's/^/  /'
        fi
    else
        echo "FAIL expected-$expectation: $name"
        sed -n '1,120p' "$log"
        failures=$((failures + 1))
    fi
}

cat >"$tmp_dir/resource_surface.d" <<'D'
module external_resource_surface;
import raster.resource : ResourceEntry, ResourceAccess, ReleaseFn;
ResourceEntry escaped;
D

cat >"$tmp_dir/validation_surface.d" <<'D'
module external_validation_surface;
import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult,
    validateRasterBackingLayout;
D

cat >"$tmp_dir/construction_surface.d" <<'D'
module external_construction_surface;
import raster.construction : constructRetainedRaster;
D

cat >"$tmp_dir/import_transaction_surface.d" <<'D'
module external_import_transaction_surface;
import raster.import_single_resource :
    SingleResourceRasterImportError,
    SingleResourceRasterImportResult,
    importSingleOwnedResource;
D

cat >"$tmp_dir/internal_execution_surface.d" <<'D'
module external_internal_execution_surface;
import raster.internal.execution_layout :
    PlaneExecutionLayout2D,
    PlaneExecutionTraits,
    classifyPlaneExecutionLayout;
D

cat >"$tmp_dir/raw_read_view_factory.d" <<'D'
module external_raw_read_view_factory;
import raster.view : makeRasterViewAssumeValidated;
alias escaped = makeRasterViewAssumeValidated;
D

cat >"$tmp_dir/raw_writable_view_factory.d" <<'D'
module external_raw_writable_view_factory;
import raster.writable_view : tryMakeWritableRasterView;
alias escaped = tryMakeWritableRasterView;
D

cat >"$tmp_dir/raw_backing_type.d" <<'D'
module external_raw_backing_type;
import raster.backing : RasterBacking;
RasterBacking escaped;
D

cat >"$tmp_dir/invalid_sample_view.d" <<'D'
module external_invalid_sample_view;
import raster : RasterView;
RasterView!(ubyte*) invalid;
D

cat >"$tmp_dir/invalid_sample_lease.d" <<'D'
module external_invalid_sample_lease;
import raster : RasterLease;
RasterLease!(const ubyte) invalid;
D

cat >"$tmp_dir/copy_owned_resource.d" <<'D'
module external_copy_owned_resource;
import raster : OwnedByteResource;
void invalid(OwnedByteResource resource)
{
    auto copy = resource;
}
D

cat >"$tmp_dir/result_constructor.d" <<'D'
module external_result_constructor;
import raster :
    OwnedRasterImportError,
    OwnedRasterImportResult,
    OwnedRasterResourceDisposition;
void invalid()
{
    auto result = OwnedRasterImportResult(
        OwnedRasterImportError.none,
        size_t.max,
        OwnedRasterResourceDisposition.transferredToLease
    );
}
D

cat >"$tmp_dir/positive_root_surface.d" <<'D'
module external_positive_root_surface;
import raster;

static assert(is(Region2D));
static assert(is(PlaneDescriptor));
static assert(is(PlaneByteLayout));
static assert(is(OwnedByteResource));
static assert(is(OwnedRasterImportResult));
static assert(is(RasterLease!ubyte));
static assert(is(RasterView!ubyte));
static assert(is(WritableRasterView!ubyte));
D

compile_probe positive_root_surface pass
compile_probe resource_surface reject
compile_probe validation_surface reject
compile_probe construction_surface reject
compile_probe import_transaction_surface reject
compile_probe internal_execution_surface reject
compile_probe raw_read_view_factory reject
compile_probe raw_writable_view_factory reject
compile_probe raw_backing_type reject
compile_probe invalid_sample_view reject
compile_probe invalid_sample_lease reject
compile_probe copy_owned_resource reject
compile_probe result_constructor reject

echo "FAILURES=$failures"
[[ "$failures" -eq 0 ]]
