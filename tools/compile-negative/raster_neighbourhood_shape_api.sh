#!/usr/bin/env bash
set -uo pipefail

compiler="${1:-dmd}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1 &&
    pwd
)"

tmp_dir="$(
    mktemp -d "${TMPDIR:-/tmp}/raster-d-neighbourhood-shape-api-XXXXXX"
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

    cat > "$tmp_dir/positive_3x3.d" <<'D'
module neighbourhood_shape_positive_3x3;

import raster : NeighbourhoodShape;

alias Shape = NeighbourhoodShape!(3, 3, 1, 1);

static assert(Shape.sampleCount == 9);
static assert(Shape.left == 1);
static assert(Shape.right == 1);
static assert(Shape.top == 1);
static assert(Shape.bottom == 1);
static assert(Shape.tupleof.length == 0);
D

    cat > "$tmp_dir/positive_asymmetric.d" <<'D'
module neighbourhood_shape_positive_asymmetric;

import raster : NeighbourhoodShape;

alias Shape = NeighbourhoodShape!(5, 3, 1, 2);

static assert(Shape.sampleCount == 15);
static assert(Shape.left == 1);
static assert(Shape.right == 3);
static assert(Shape.top == 2);
static assert(Shape.bottom == 0);
D

    cat > "$tmp_dir/negative_zero_width.d" <<'D'
module neighbourhood_shape_negative_zero_width;

import raster : NeighbourhoodShape;

alias Shape = NeighbourhoodShape!(0, 3, 0, 1);
enum forceInstantiation = Shape.sampleCount;
D

    cat > "$tmp_dir/negative_zero_height.d" <<'D'
module neighbourhood_shape_negative_zero_height;

import raster : NeighbourhoodShape;

alias Shape = NeighbourhoodShape!(3, 0, 1, 0);
enum forceInstantiation = Shape.sampleCount;
D

    cat > "$tmp_dir/negative_anchor_x.d" <<'D'
module neighbourhood_shape_negative_anchor_x;

import raster : NeighbourhoodShape;

alias Shape = NeighbourhoodShape!(3, 3, 3, 1);
enum forceInstantiation = Shape.sampleCount;
D

    cat > "$tmp_dir/negative_anchor_y.d" <<'D'
module neighbourhood_shape_negative_anchor_y;

import raster : NeighbourhoodShape;

alias Shape = NeighbourhoodShape!(3, 3, 1, 3);
enum forceInstantiation = Shape.sampleCount;
D

    cat > "$tmp_dir/negative_overflow.d" <<'D'
module neighbourhood_shape_negative_overflow;

import raster : NeighbourhoodShape;

alias Shape = NeighbourhoodShape!(size_t.max, 2, 0, 0);
enum forceInstantiation = Shape.sampleCount;
D

    compile_probe positive_3x3 pass
    compile_probe positive_asymmetric pass

    compile_probe negative_zero_width reject
    compile_probe negative_zero_height reject
    compile_probe negative_anchor_x reject
    compile_probe negative_anchor_y reject
    compile_probe negative_overflow reject

    echo "FAILURES=$failures"
    [ "$failures" -eq 0 ]
}

main "$@"
status=$?
cleanup
[ "$status" -eq 0 ]
