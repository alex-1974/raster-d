#!/usr/bin/env bash
set -euo pipefail

compiler="${1:-${DC:-dmd}}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/raster-d-copy-conversion-XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
command -v jq >/dev/null
(cd "$repo_root" && dub describe --compiler="$compiler") > "$tmp_dir/describe.json"
import_args=()
while IFS= read -r path; do
    import_args+=("-I$path")
done < <(jq -r '.packages[] | .path as $base | (.importPaths // [])[] |
    if startswith("/") then . else ($base + "/" + .) end' "$tmp_dir/describe.json")

compile_probe()
{
    (cd "$repo_root" && "$compiler" -c -preview=dip1000 "${import_args[@]}" \
        -of="$tmp_dir/$1.o" "$tmp_dir/$1.d") > "$tmp_dir/$1.log" 2>&1
}

# A working external import distinguishes visibility rejection from a broken
# dependency/toolchain setup. Compile only: no undefined-symbol link failure.
cat > "$tmp_dir/public_control.d" <<'D'
module external_public_control;
import raster;
D
if ! compile_probe public_control; then
    cat "$tmp_dir/public_control.log"
    exit 1
fi
echo 'PASS public import control'

for symbol in readApprovedRow writeApprovedRow executeApprovedRows; do
    for surface in raster raster.internal.copy_dispatch raster.internal.conversion_dispatch; do
        cat > "$tmp_dir/rejection.d" <<D
module external_copy_conversion_rejection;
import $surface : $symbol;
alias leaked = $symbol;
D
        if compile_probe rejection; then
            echo "FAIL internal symbol accessible: $surface : $symbol"
            exit 1
        fi
        # Both DMD and LDC must reject the intended symbol for visibility/name
        # lookup, rather than an unrelated syntax, dependency or link failure.
        if ! grep -E "($symbol.*(not visible|not found)|not visible.*$symbol|not found.*$symbol)" \
            "$tmp_dir/rejection.log" >/dev/null; then
            cat "$tmp_dir/rejection.log"
            exit 1
        fi
        echo "PASS visibility rejection: $surface : $symbol"
    done
done
