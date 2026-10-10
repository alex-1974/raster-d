#!/usr/bin/env bash
set -uo pipefail

compiler="${1:-dmd}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1 &&
    pwd
)"

tmp_dir="$(
    mktemp -d "${TMPDIR:-/tmp}/raster-d-convolution-api-XXXXXX"
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
                sed -n '1,140p' "$log"
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

    cat > "$tmp_dir/positive_float.d" <<'D'
module raster_convolution_positive_float;

import raster :
    FixedConvolutionKernel,
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    convolveInto;

alias Shape = NeighbourhoodShape!(3, 3, 1, 1);

alias Kernel =
    FixedConvolutionKernel!(
        Shape,
        float,
        0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f
    );

@safe
void probe(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.convolveInto!(
            Kernel,
            float
        )(
            0,
            Region2D(1, 1, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/positive_double_accumulator.d" <<'D'
module raster_convolution_positive_double_accumulator;

import raster :
    FixedConvolutionKernel,
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    convolveInto;

alias Shape = NeighbourhoodShape!(1, 1, 0, 0);

alias Kernel =
    FixedConvolutionKernel!(
        Shape,
        double,
        0.5
    );

@safe
void probe(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.convolveInto!(
            Kernel,
            double
        )(
            0,
            Region2D(0, 0, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_integer_source.d" <<'D'
module raster_convolution_negative_integer_source;

import raster :
    FixedConvolutionKernel,
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    convolveInto;

alias Shape = NeighbourhoodShape!(1, 1, 0, 0);
alias Kernel = FixedConvolutionKernel!(Shape, float, 1.0f);

@safe
void probe(
    scope RasterView!int source,
    scope ref WritableRasterView!int destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.convolveInto!(
            Kernel,
            float
        )(
            0,
            Region2D(0, 0, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_narrow_accumulator.d" <<'D'
module raster_convolution_negative_narrow_accumulator;

import raster :
    FixedConvolutionKernel,
    NeighbourhoodShape,
    RasterNeighbourhoodError,
    RasterView,
    Region2D,
    WritableRasterView,
    convolveInto;

alias Shape = NeighbourhoodShape!(1, 1, 0, 0);
alias Kernel = FixedConvolutionKernel!(Shape, double, 1.0);

@safe
void probe(
    scope RasterView!double source,
    scope ref WritableRasterView!double destination
)
{
    RasterNeighbourhoodError error;

    cast(void)
        source.convolveInto!(
            Kernel,
            float
        )(
            0,
            Region2D(0, 0, 1, 1),
            destination,
            0,
            error
        );
}
D

    cat > "$tmp_dir/negative_coefficient_count.d" <<'D'
module raster_convolution_negative_coefficient_count;

import raster :
    FixedConvolutionKernel,
    NeighbourhoodShape;

alias Shape = NeighbourhoodShape!(3, 3, 1, 1);

alias InvalidKernel =
    FixedConvolutionKernel!(
        Shape,
        float,
        1.0f
    );

enum forceInstantiation =
    InvalidKernel.shape.sampleCount;
D

    compile_probe positive_float pass
    compile_probe positive_double_accumulator pass

    compile_probe negative_integer_source reject
    compile_probe negative_narrow_accumulator reject
    compile_probe negative_coefficient_count reject

    echo "FAILURES=$failures"
    [ "$failures" -eq 0 ]
}

main "$@"
status=$?
cleanup
[ "$status" -eq 0 ]
