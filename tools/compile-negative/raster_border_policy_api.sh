#!/usr/bin/env bash
set -uo pipefail

compiler="${1:-dmd}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1 &&
    pwd
)"

tmp_dir="$(
    mktemp -d "${TMPDIR:-/tmp}/raster-d-border-policy-api-XXXXXX"
)"

cleanup()
{
    rm -rf "$tmp_dir"
}

trap cleanup RETURN

main()
{
    if ! command -v jq >/dev/null 2>&1; then
        echo 'FAIL: jq is required'
        return 1
    fi

    if ! (
        cd "$repo_root" &&
        dub describe --compiler="$compiler"
    ) >"$tmp_dir/describe.json"
    then
        echo 'FAIL: dub describe failed'
        return 1
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

    failures=0

    compile_probe()
    {
        local name="$1"
        local expectation="$2"
        local source="$tmp_dir/$name.d"
        local log="$tmp_dir/$name.log"
        local object="$tmp_dir/$name.o"

        if "$compiler"             -c             -preview=dip1000             "${import_args[@]}"             -of="$object"             "$source"             >"$log" 2>&1
        then
            if [ "$expectation" = pass ]; then
                echo "PASS expected-compile: $name"
            else
                echo "FAIL expected-rejection: $name"
                sed -n '1,120p' "$log"
                failures=$((failures + 1))
            fi
        else
            if [ "$expectation" = reject ]; then
                echo "PASS expected-rejection: $name"
            else
                echo "FAIL expected-compile: $name"
                sed -n '1,160p' "$log"
                failures=$((failures + 1))
            fi
        fi
    }

    cat > "$tmp_dir/positive.d" <<'D'
module raster_border_policy_positive;

import raster :
    RasterBorderKind,
    RasterClampBorder,
    RasterConstantBorder,
    RasterMirrorBorder,
    RasterValidBorder,
    RasterWrapBorder;

static assert(RasterValidBorder.kind == RasterBorderKind.valid);
static assert(RasterClampBorder.kind == RasterBorderKind.clamp);
static assert(RasterMirrorBorder.kind == RasterBorderKind.mirror);
static assert(RasterWrapBorder.kind == RasterBorderKind.wrap);

static assert(RasterValidBorder.tupleof.length == 0);
static assert(RasterClampBorder.tupleof.length == 0);
static assert(RasterMirrorBorder.tupleof.length == 0);
static assert(RasterWrapBorder.tupleof.length == 0);

RasterConstantBorder!ubyte makeConstant()
{
    return RasterConstantBorder!ubyte(17);
}
D

    cat > "$tmp_dir/positive_pod.d" <<'D'
module raster_border_policy_positive_pod;

import raster : RasterConstantBorder;

struct Pixel
{
    ushort a;
    ushort b;
}

RasterConstantBorder!Pixel makeConstant()
{
    return RasterConstantBorder!Pixel(Pixel(1, 2));
}
D

    cat > "$tmp_dir/negative_pointer.d" <<'D'
module raster_border_policy_negative_pointer;

import raster : RasterConstantBorder;

alias Invalid = RasterConstantBorder!(ubyte*);
Invalid value;
D

    cat > "$tmp_dir/negative_dynamic_array.d" <<'D'
module raster_border_policy_negative_dynamic_array;

import raster : RasterConstantBorder;

alias Invalid = RasterConstantBorder!(ubyte[]);
Invalid value;
D

    cat > "$tmp_dir/negative_qualified.d" <<'D'
module raster_border_policy_negative_qualified;

import raster : RasterConstantBorder;

alias Invalid = RasterConstantBorder!(const ubyte);
Invalid value;
D

    compile_probe positive pass
    compile_probe positive_pod pass

    compile_probe negative_pointer reject
    compile_probe negative_dynamic_array reject
    compile_probe negative_qualified reject

    echo "FAILURES=$failures"
    [ "$failures" -eq 0 ]
}

main "$@"
status=$?
cleanup
[ "$status" -eq 0 ]
