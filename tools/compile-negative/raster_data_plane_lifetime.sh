#!/usr/bin/env bash
set -euo pipefail

compiler="${1:-${DC:-dmd}}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/raster-d-data-plane-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/negative.d" <<'D'
module raster_data_plane_negative_escape;

import raster;

RasterPlaneWindow!ubyte escaped;

@safe
void escape(scope ref const RasterView!ubyte view)
{
    withPlane(view, 0,
        (scope ref const(RasterPlaneWindow!ubyte) window)
            @safe nothrow @nogc
            {
                escaped = window;
            });
}
D

if "$compiler" -c -o- -I"$root/source" "$tmp/negative.d" >/dev/null 2>&1; then
    echo "ERROR: data-plane window escaped its scoped callback" >&2
    exit 1
fi

echo "data-plane lifetime negative probe: PASS"
