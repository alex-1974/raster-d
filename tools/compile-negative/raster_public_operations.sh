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
    tryFillRasterPlane,
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

    const fillOk =
        tryFillRasterPlane(
            byteDestination,
            0,
            cast(ubyte) 23
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
        && (fillOk || byteDestination.planeCount == 0)
        && (fillOk || byteDestination.planeCount == 0)
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

    const fillOk =
        tryFillRasterPlane(
            destination: byteDestination,
            planeIndex: 0,
            value: cast(ubyte) 23
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
    DependencyMargins,
    ContextDeficit,
    ExpandedDependency,
    RequestMaterializationPlan,
    RequestMaterializationError,
    UbyteToFloatConversionResult,
    tryFillRasterPlaneScalar,
    convertUbyteToFloatRasterPlane,
    copySameTypeRasterPlane,
    tryMakeWritableRasterView,
    tryMaterializeRequest,
    tryStrictFloatToDoubleSum;
D

    cat > "$tmp_dir/internal_dependency_surface.d" <<'D'
module raster_public_operations_negative_internal_dependency_surface;

import raster.internal.dependency :
    ContextDeficit,
    DependencyMargins,
    ExpandedDependency,
    tryExpandDependency;

void invalidExternalDependencyUse()
{
    ExpandedDependency result;

    const ok =
        tryExpandDependency(
            Region2D.init,
            Region2D.init,
            DependencyMargins.init,
            result
        );

    ContextDeficit deficit = result.contextDeficit;

    if (ok && deficit.left != 0)
    {
        assert(0);
    }
}

import raster.region : Region2D;
D


    cat > "$tmp_dir/internal_materialization_plan_surface.d" <<'D'
module raster_public_operations_negative_internal_materialization_plan_surface;

import raster.internal.materialization_plan :
    RequestMaterializationPlan,
    tryPlanRequestMaterialization;

import raster.internal.dependency :
    DependencyMargins;

import raster.region :
    Region2D;

void invalidExternalMaterializationPlanUse()
{
    RequestMaterializationPlan plan;

    const ok =
        tryPlanRequestMaterialization(
            Region2D.init,
            Region2D.init,
            DependencyMargins.init,
            plan
        );

    if (ok && plan.residentInput.width != 0)
    {
        assert(0);
    }
}
D


    cat > "$tmp_dir/internal_materialization_surface.d" <<'D'
module raster_public_operations_negative_internal_materialization_surface;

import raster.internal.materialization :
    RequestMaterializationError,
    tryMaterializeRequest;

import raster.internal.materialization_plan :
    RequestMaterializationPlan;

import raster.writable_view :
    WritableRasterView;

import raster.region :
    Region2D;

struct ExternalSource
{
    bool materializeInto(
        Region2D logicalRegion,
        scope WritableRasterView!ubyte destination
    )
    {
        return true;
    }
}

void invalidExternalMaterializationUse()
{
    RequestMaterializationPlan plan;
    WritableRasterView!ubyte destination;
    ExternalSource source;
    RequestMaterializationError error;

    const ok =
        tryMaterializeRequest(
            plan,
            source,
            destination,
            error
        );

    if (ok)
    {
        assert(0);
    }
}
D


    cat > "$tmp_dir/internal_fill_surface.d" <<'D'
module raster_public_operations_negative_internal_fill_surface;

import raster.internal.fill_dispatch :
    tryFillRasterPlaneScalar;

import raster.writable_view :
    WritableRasterView;

void invalidExternalFillDispatchUse()
{
    WritableRasterView!ubyte destination;

    const ok =
        tryFillRasterPlaneScalar(
            destination,
            0,
            cast(ubyte) 7
        );

    if (ok)
    {
        assert(0);
    }
}
D

    cat > "$tmp_dir/point_transform_surface.d" <<'D'
module raster_public_operations_point_transform_positive;

import raster :
    RasterLease,
    RasterTransformError,
    tryTransformRasterPlane;

@safe
pure
nothrow
@nogc
ubyte increment(ubyte value)
{
    return cast(ubyte)(value + 1);
}

@safe
bool exercisePointTransform(
    ref RasterLease!ubyte sourceLease,
    ref RasterLease!ubyte destinationLease
)
{
    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    RasterTransformError error;

    const ok =
        tryTransformRasterPlane!increment(
            sourceLease.view(),
            0,
            destination,
            0,
            error
        );

    return
        !writableOk
        || ok
        || error != RasterTransformError.none;
}
D


    cat > "$tmp_dir/point_transform_named_arguments.d" <<'D'
module raster_public_operations_point_transform_named_arguments;

import raster :
    RasterLease,
    RasterTransformError,
    tryTransformRasterPlane;

@safe
pure
nothrow
@nogc
ubyte increment(ubyte value)
{
    return cast(ubyte)(value + 1);
}

@safe
bool exercisePointTransformNamed(
    ref RasterLease!ubyte sourceLease,
    ref RasterLease!ubyte destinationLease
)
{
    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            success: writableOk
        );

    RasterTransformError error;

    const ok =
        tryTransformRasterPlane!increment(
            source: sourceLease.view(),
            sourcePlaneIndex: 0,
            destination: destination,
            destinationPlaneIndex: 0,
            error: error
        );

    return
        !writableOk
        || ok
        || error != RasterTransformError.none;
}
D


    cat > "$tmp_dir/point_transform_impure.d" <<'D'
module raster_public_operations_point_transform_negative_impure;

import raster :
    RasterLease,
    RasterTransformError,
    tryTransformRasterPlane;

ubyte state;

@safe
nothrow
@nogc
ubyte impureTransform(ubyte value)
{
    state = value;
    return value;
}

@safe
void invalidUse(
    ref RasterLease!ubyte sourceLease,
    ref RasterLease!ubyte destinationLease
)
{
    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    RasterTransformError error;

    tryTransformRasterPlane!impureTransform(
        sourceLease.view(),
        0,
        destination,
        0,
        error
    );
}
D


    cat > "$tmp_dir/point_transform_throwing.d" <<'D'
module raster_public_operations_point_transform_negative_throwing;

import raster :
    RasterLease,
    RasterTransformError,
    tryTransformRasterPlane;

@safe
pure
ubyte throwingTransform(ubyte value)
{
    if (value == 0)
        throw new Exception("zero");

    return value;
}

@safe
void invalidUse(
    ref RasterLease!ubyte sourceLease,
    ref RasterLease!ubyte destinationLease
)
{
    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    RasterTransformError error;

    tryTransformRasterPlane!throwingTransform(
        sourceLease.view(),
        0,
        destination,
        0,
        error
    );
}
D


    cat > "$tmp_dir/point_transform_allocating.d" <<'D'
module raster_public_operations_point_transform_negative_allocating;

import raster :
    RasterLease,
    RasterTransformError,
    tryTransformRasterPlane;

@safe
pure
nothrow
ubyte allocatingTransform(ubyte value)
{
    auto storage = new ubyte[1];
    storage[0] = value;
    return storage[0];
}

@safe
void invalidUse(
    ref RasterLease!ubyte sourceLease,
    ref RasterLease!ubyte destinationLease
)
{
    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    RasterTransformError error;

    tryTransformRasterPlane!allocatingTransform(
        sourceLease.view(),
        0,
        destination,
        0,
        error
    );
}
D


    cat > "$tmp_dir/point_transform_system.d" <<'D'
module raster_public_operations_point_transform_negative_system;

import raster :
    RasterLease,
    RasterTransformError,
    tryTransformRasterPlane;

@system
pure
nothrow
@nogc
ubyte systemTransform(ubyte value)
{
    return value;
}

@safe
void invalidUse(
    ref RasterLease!ubyte sourceLease,
    ref RasterLease!ubyte destinationLease
)
{
    bool writableOk;

    scope auto destination =
        destinationLease.tryWritableView(
            writableOk
        );

    RasterTransformError error;

    tryTransformRasterPlane!systemTransform(
        sourceLease.view(),
        0,
        destination,
        0,
        error
    );
}
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
    compile_probe point_transform_surface pass

    if compiler_supports_named_arguments; then
        compile_probe named_arguments pass
        compile_probe point_transform_named_arguments pass
    else
        echo 'SKIP named_arguments: compiler does not support D named-argument syntax'
        echo 'SKIP point_transform_named_arguments: compiler does not support D named-argument syntax'
    fi

    compile_probe point_transform_impure reject
    compile_probe point_transform_throwing reject
    compile_probe point_transform_allocating reject
    compile_probe point_transform_system reject

    compile_probe internal_umbrella_surface reject
    compile_probe internal_dependency_surface reject
    compile_probe internal_materialization_plan_surface reject
    compile_probe internal_materialization_surface reject
    compile_probe internal_fill_surface reject
    compile_probe writable_escape reject
    compile_probe writable_global reject

    echo "FAILURES=$failures"

    [ "$failures" -eq 0 ]
}

main "$@"
status=$?
cleanup
[ "$status" -eq 0 ]
