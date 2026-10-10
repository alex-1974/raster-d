#!/usr/bin/env bash
set -uo pipefail

compiler="${1:-dmd}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1 &&
    pwd
)"

tmp_dir="$(
    mktemp -d "${TMPDIR:-/tmp}/raster-d-neighbourhood-into-api-XXXXXX"
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
                sed -n '1,180p' "$log"
                failures=$((failures + 1))
            fi
        fi
    }

    cat > "$tmp_dir/positive_5x3.d" <<'D'
module neighbourhood_into_positive_5x3;

import raster :
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    applyNeighbourhoodInto;

alias Shape = NeighbourhoodShape!(5, 3, 2, 1);

@safe
pure
nothrow
@nogc
ubyte center(ref const(ubyte)[15] values)
{
    return values[7];
}

@safe
void probe(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.applyNeighbourhoodInto!(
            Shape,
            center
        )(
            0,
            Region2D(2, 1, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/positive_3x3.d" <<'D'
module neighbourhood_into_positive_3x3;

import raster :
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    applyNeighbourhoodInto;

alias Shape = NeighbourhoodShape!(3, 3, 1, 1);

@safe
pure
nothrow
@nogc
float center(ref const(float)[9] values)
{
    return values[4];
}

@safe
void probe(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.applyNeighbourhoodInto!(
            Shape,
            center
        )(
            0,
            Region2D(1, 1, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_wrong_carrier.d" <<'D'
module neighbourhood_into_negative_wrong_carrier;

import raster :
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    applyNeighbourhoodInto;

alias Shape = NeighbourhoodShape!(5, 3, 2, 1);

@safe
pure
nothrow
@nogc
ubyte wrong(ref const(ubyte)[9] values)
{
    return values[4];
}

@safe
void probe(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.applyNeighbourhoodInto!(
            Shape,
            wrong
        )(
            0,
            Region2D(2, 1, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_impure.d" <<'D'
module neighbourhood_into_negative_impure;

import raster :
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    applyNeighbourhoodInto;

alias Shape = NeighbourhoodShape!(5, 3, 2, 1);

ubyte state;

@safe
nothrow
@nogc
ubyte impure(ref const(ubyte)[15] values)
{
    state = values[7];
    return values[7];
}

@safe
void probe(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.applyNeighbourhoodInto!(
            Shape,
            impure
        )(
            0,
            Region2D(2, 1, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_throwing.d" <<'D'
module neighbourhood_into_negative_throwing;

import raster :
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    applyNeighbourhoodInto;

alias Shape = NeighbourhoodShape!(5, 3, 2, 1);

@safe
pure
ubyte throwing(ref const(ubyte)[15] values)
{
    if (values[7] == 0)
        throw new Exception("zero");

    return values[7];
}

@safe
void probe(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.applyNeighbourhoodInto!(
            Shape,
            throwing
        )(
            0,
            Region2D(2, 1, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_allocating.d" <<'D'
module neighbourhood_into_negative_allocating;

import raster :
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    applyNeighbourhoodInto;

alias Shape = NeighbourhoodShape!(5, 3, 2, 1);

@safe
pure
nothrow
ubyte allocating(ref const(ubyte)[15] values)
{
    auto memory = new ubyte[1];
    memory[0] = values[7];
    return memory[0];
}

@safe
void probe(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.applyNeighbourhoodInto!(
            Shape,
            allocating
        )(
            0,
            Region2D(2, 1, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_system.d" <<'D'
module neighbourhood_into_negative_system;

import raster :
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    applyNeighbourhoodInto;

alias Shape = NeighbourhoodShape!(5, 3, 2, 1);

@system
pure
nothrow
@nogc
ubyte systemKernel(ref const(ubyte)[15] values)
{
    return values[7];
}

@safe
void probe(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.applyNeighbourhoodInto!(
            Shape,
            systemKernel
        )(
            0,
            Region2D(2, 1, 1, 1),
            destination,
            0,
            error
        );
}
D

    compile_probe positive_5x3 pass
    compile_probe positive_3x3 pass

    compile_probe negative_wrong_carrier reject
    compile_probe negative_impure reject
    compile_probe negative_throwing reject
    compile_probe negative_allocating reject
    compile_probe negative_system reject

    echo "FAILURES=$failures"
    [ "$failures" -eq 0 ]
}

main "$@"
status=$?
cleanup
[ "$status" -eq 0 ]
