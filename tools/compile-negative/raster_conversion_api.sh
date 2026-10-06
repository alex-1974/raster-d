#!/usr/bin/env bash
set -uo pipefail

compiler="${1:-dmd}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1 &&
    pwd
)"

tmp_dir="$(
    mktemp -d "${TMPDIR:-/tmp}/raster-d-convert-into-api-XXXXXX"
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

    if [ "${#import_args[@]}" -eq 0 ]; then
        echo 'FAIL: dub describe produced no import paths'
        return 1
    fi

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
                echo '  compiler diagnostic:'
                sed -n '1,100p' "$log" | sed 's/^/    /'
            else
                echo "FAIL expected-compile: $name"
                sed -n '1,160p' "$log"
                failures=$((failures + 1))
            fi
        fi
    }

    cat > "$tmp_dir/positive_default.d" <<'D'
module raster_convert_into_positive_default;

import raster :
    RasterConversionError,
    RasterView,
    WritableRasterView,
    convertRasterInto;

@safe
void probe(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!float destination
)
{
    RasterConversionError error;

    cast(void)
        source.convertRasterInto!float(
            0,
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/positive_explicit_policy.d" <<'D'
module raster_convert_into_positive_explicit_policy;

import raster :
    RasterConversionError,
    RasterConversionPolicy,
    RasterView,
    WritableRasterView,
    convertRasterInto;

@safe
void probe(
    scope RasterView!ushort source,
    scope ref WritableRasterView!int destination
)
{
    RasterConversionError error;

    cast(void)
        source.convertRasterInto!(
            int,
            RasterConversionPolicy.exact
        )(
            0,
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_int_float.d" <<'D'
module raster_convert_into_negative_int_float;

import raster :
    RasterConversionError,
    RasterView,
    WritableRasterView,
    convertRasterInto;

@safe
void probe(
    scope RasterView!int source,
    scope ref WritableRasterView!float destination
)
{
    RasterConversionError error;

    cast(void)
        source.convertRasterInto!float(
            0,
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_long_double.d" <<'D'
module raster_convert_into_negative_long_double;

import raster :
    RasterConversionError,
    RasterView,
    WritableRasterView,
    convertRasterInto;

@safe
void probe(
    scope RasterView!long source,
    scope ref WritableRasterView!double destination
)
{
    RasterConversionError error;

    cast(void)
        source.convertRasterInto!double(
            0,
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_double_float.d" <<'D'
module raster_convert_into_negative_double_float;

import raster :
    RasterConversionError,
    RasterView,
    WritableRasterView,
    convertRasterInto;

@safe
void probe(
    scope RasterView!double source,
    scope ref WritableRasterView!float destination
)
{
    RasterConversionError error;

    cast(void)
        source.convertRasterInto!float(
            0,
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_float_int.d" <<'D'
module raster_convert_into_negative_float_int;

import raster :
    RasterConversionError,
    RasterView,
    WritableRasterView,
    convertRasterInto;

@safe
void probe(
    scope RasterView!float source,
    scope ref WritableRasterView!int destination
)
{
    RasterConversionError error;

    cast(void)
        source.convertRasterInto!int(
            0,
            destination,
            0,
            error
        );
}
D

    compile_probe positive_default pass
    compile_probe positive_explicit_policy pass

    compile_probe negative_int_float reject
    compile_probe negative_long_double reject
    compile_probe negative_double_float reject
    compile_probe negative_float_int reject

    echo "FAILURES=$failures"
    [ "$failures" -eq 0 ]
}

main "$@"
status=$?
cleanup
[ "$status" -eq 0 ]
