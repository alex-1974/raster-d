#!/usr/bin/env bash
set -uo pipefail

compiler="${1:-dmd}"

repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1 &&
    pwd
)"

tmp_dir="$(
    mktemp -d "${TMPDIR:-/tmp}/raster-d-raster-public-operations-XXXXXX"
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

        if "$compiler" \
            -c \
            -preview=dip1000 \
            "${import_args[@]}" \
            -of="$object" \
            "$source" \
            >"$log" 2>&1
        then
            if [ "$expectation" = 'pass' ]; then
                echo "PASS expected-compile: $name"
            else
                echo "FAIL expected-rejection: $name"
                sed -n '1,80p' "$log"
                failures=$((failures + 1))
            fi
        else
            if [ "$expectation" = 'reject' ]; then
                echo "PASS expected-rejection: $name"
                echo '  compiler diagnostic:'
                sed -n '1,80p' "$log" | sed 's/^/    /'
            else
                echo "FAIL expected-compile: $name"
                sed -n '1,120p' "$log"
                failures=$((failures + 1))
            fi
        fi
    }


    compiler_supports_named_arguments()
    {
        cat > "$tmp_dir/named_argument_capability.d" <<'D'
module raster_named_argument_capability;

private int combine(
    int left,
    int right
)
{
    return left + right;
}

enum namedArgumentCapability =
    combine(
        left: 1,
        right: 2
    );
D

        "$compiler" \
            -c \
            -of="$tmp_dir/named_argument_capability.o" \
            "$tmp_dir/named_argument_capability.d" \
            >"$tmp_dir/named_argument_capability.log" 2>&1
    }

    cat > "$tmp_dir/public_surface.d" <<'D'
module raster_public_operations_positive;

import raster :
    RasterCopyError,
    RasterLease,
    RasterView,
    UbyteToFloatConversionError,
    WritableRasterView,
    tryConvertUbyteToFloatPlane,
    tryCopyRasterPlane,
    trySumFloatToDouble;

@safe
bool exercisePublicRasterOperations(
    ref RasterLease!ubyte byteLease,
    ref RasterLease!float floatLease,
    scope RasterView!float floatSource
)
{
    bool byteWritableOk;

    scope WritableRasterView!ubyte byteDestination =
        byteLease.tryWritableView(
            byteWritableOk
        );

    bool floatWritableOk;

    scope WritableRasterView!float floatDestination =
        floatLease.tryWritableView(
            floatWritableOk
        );

    double sum;

    const sumOk =
        trySumFloatToDouble(
            floatSource,
            0,
            sum
        );

    RasterCopyError copyError;

    const copyOk =
        tryCopyRasterPlane(
            byteLease.view(),
            0,
            byteDestination,
            0,
            copyError
        );

    UbyteToFloatConversionError conversionError;

    const conversionOk =
        tryConvertUbyteToFloatPlane(
            byteLease.view(),
            0,
            floatDestination,
            0,
            conversionError
        );

    return
        (!byteWritableOk || byteDestination.planeCount != 0)
        && (!floatWritableOk || floatDestination.planeCount != 0)
        && (sumOk || sum == 0.0)
        && (copyOk || copyError != RasterCopyError.none)
        && (
            conversionOk
            || conversionError != UbyteToFloatConversionError.none
        );
}
D


    cat > "$tmp_dir/named_arguments.d" <<'D'
module raster_public_operations_named_arguments;

import raster :
    RasterCopyError,
    RasterLease,
    RasterView,
    UbyteToFloatConversionError,
    WritableRasterView,
    tryConvertUbyteToFloatPlane,
    tryCopyRasterPlane,
    trySumFloatToDouble;

@safe
bool exercisePublicRasterNamedArguments(
    ref RasterLease!ubyte byteLease,
    ref RasterLease!float floatLease,
    scope RasterView!float floatSource
)
{
    bool byteWritableOk;

    scope WritableRasterView!ubyte byteDestination =
        byteLease.tryWritableView(
            success: byteWritableOk
        );

    bool floatWritableOk;

    scope WritableRasterView!float floatDestination =
        floatLease.tryWritableView(
            success: floatWritableOk
        );

    double sum;

    const sumOk =
        trySumFloatToDouble(
            source: floatSource,
            planeIndex: 0,
            sum: sum
        );

    RasterCopyError copyError;

    const copyOk =
        tryCopyRasterPlane(
            source: byteLease.view(),
            sourcePlaneIndex: 0,
            destination: byteDestination,
            destinationPlaneIndex: 0,
            error: copyError
        );

    UbyteToFloatConversionError conversionError;

    const conversionOk =
        tryConvertUbyteToFloatPlane(
            source: byteLease.view(),
            sourcePlaneIndex: 0,
            destination: floatDestination,
            destinationPlaneIndex: 0,
            error: conversionError
        );

    return
        (!byteWritableOk || byteDestination.planeCount != 0)
        && (!floatWritableOk || floatDestination.planeCount != 0)
        && (sumOk || sum == 0.0)
        && (copyOk || copyError != RasterCopyError.none)
        && (
            conversionOk
            || conversionError != UbyteToFloatConversionError.none
        );
}
D

    cat > "$tmp_dir/internal_umbrella_surface.d" <<'D'
module raster_public_operations_negative_internal_umbrella_surface;

import raster :
    AffineByteOverlapRelation,
    ExactUbyteToFloatRasterError,
    FloatToDoubleSumResult,
    MirUniversalPlane,
    PlaneExecutionTraits,
    RasterTargetPlane,
    SameTypeRasterCopyError,
    SumReductionSemantics,
    UbyteToFloatConversionResult,
    convertUbyteToFloatRasterPlane,
    copySameTypeRasterPlane,
    tryMakeWritableRasterView,
    tryStrictFloatToDoubleSum;
D

    cat > "$tmp_dir/writable_escape.d" <<'D'
module raster_public_operations_negative_writable_escape;

import raster :
    RasterLease,
    WritableRasterView;

@safe
WritableRasterView!ubyte invalidEscape()
{
    RasterLease!ubyte lease;

    bool success;

    scope auto view =
        lease.tryWritableView(
            success
        );

    return view;
}
D

    cat > "$tmp_dir/writable_global.d" <<'D'
module raster_public_operations_negative_writable_global;

import raster :
    RasterLease,
    WritableRasterView;

WritableRasterView!ubyte escaped;

@safe
void invalidGlobal(
    ref RasterLease!ubyte lease
)
{
    bool success;

    scope auto view =
        lease.tryWritableView(
            success
        );

    escaped = view;
}
D

    compile_probe public_surface pass

    if compiler_supports_named_arguments; then
        compile_probe named_arguments pass
    else
        echo 'SKIP named_arguments: compiler does not support D named-argument syntax'
    fi

    compile_probe internal_umbrella_surface reject
    compile_probe writable_escape reject
    compile_probe writable_global reject

    echo "FAILURES=$failures"

    [ "$failures" -eq 0 ]
}

main "$@"
status=$?
cleanup
[ "$status" -eq 0 ]
