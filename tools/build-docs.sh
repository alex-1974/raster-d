#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${SOURCE_ROOT:-$root}"
tool_root="${TOOL_ROOT:-$root}"
verify_contracts="${VERIFY_CONTRACTS:-0}"
inventory_only="${INVENTORY_ONLY:-1}"
output_root="${OUTPUT_ROOT:-$source_root}"

source_root="$(cd "$source_root" && pwd)"
tool_root="$(cd "$tool_root" && pwd)"
mkdir -p "$output_root"
output_root="$(cd "$output_root" && pwd)"

ddox_version="0.16.24"
compiler="${DC:-dmd}"
work_dir="$output_root/build/ddox"
site_dir="$work_dir/site"
json_file="$work_dir/docs.json"
dummy_file="$work_dir/__dummy.html"

rm -rf "$work_dir"
mkdir -p "$site_dir"

mapfile -t public_sources < <(
    cd "$source_root"
    find source/raster -type f -name '*.d' ! -path '*/internal/*' -print | sort
)

if (("${#public_sources[@]}" == 0)); then
    echo "error: no public raster-d source modules found under $source_root" >&2
    exit 1
fi

echo "Generating DDox input for ${#public_sources[@]} non-internal raster modules..."

if [[ "$verify_contracts" == "1" ]]; then
    python3 "$tool_root/tools/verify-public-module-ddoc.py" "$source_root"
    (
        cd "$source_root"
        python3 "$tool_root/tools/verify-internal-ddoc.py"
    )
fi

(
    cd "$source_root"
    "$compiler" -preview=dip1000 -o- -wi         -Xf"$json_file" -Df"$dummy_file" -Isource "${public_sources[@]}"
)
rm -f "$dummy_file"

python3 "$tool_root/tools/filter-internal-ddox-json.py"     "$json_file"     "$source_root"

dub run "ddox@$ddox_version" --     filter --min-protection=Public --only-documented "$json_file"

dub run "ddox@$ddox_version" --     generate-html --navigation-type=ModuleTree "$json_file" "$site_dir"

ddox_dir="$(dub list "ddox@$ddox_version" | sed -nE "s|^[[:space:]]*ddox[[:space:]]+$ddox_version:[[:space:]]+(.*)$|\1|p" | head -n 1)"
if [[ -z "$ddox_dir" || ! -d "$ddox_dir/public" ]]; then
    echo "error: cannot locate DDox public assets" >&2
    exit 1
fi

cp -au "$ddox_dir/public/." "$site_dir/"

test -f "$site_dir/raster.html" || {
    echo "error: missing generated raster package page" >&2
    exit 1
}

if grep -Rqi 'raster\.internal' "$site_dir" --include='*.html'; then
    echo "error: internal raster modules leaked into public documentation" >&2
    exit 1
fi

if [[ "$inventory_only" == "1" ]]; then
    python3 "$tool_root/tools/verify-public-api-examples.py"         "$site_dir"         --source-root "$source_root"         --inventory-only
elif [[ "$verify_contracts" == "1" ]]; then
    python3 "$tool_root/tools/verify-public-api-examples.py"         "$site_dir"         "$tool_root/docs/public-api-example-audit.md"         --source-root "$source_root"         --require-complete
fi

echo "PASS: public-only raster DDox documentation generated"
echo "Documentation generated: $site_dir/index.html"
