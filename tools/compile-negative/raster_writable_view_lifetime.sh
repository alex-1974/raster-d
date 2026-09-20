#!/usr/bin/env bash

compiler="${1:-dmd}"


repo_root="$(
    cd "$(dirname "$0")/../.." >/dev/null 2>&1
    pwd
)"

tmp_dir="$(
    mktemp -d \
        "/tmp/imagery-d-raster-writable-view-XXXXXX"
)"

cleanup()
{
    rm -rf "$tmp_dir"
}

trap cleanup EXIT

failures=0


if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required"
    exit 1
fi


# Compile external/public-surface probes with the same package import paths
# that a real DUB consumer sees.  This matters once the public umbrella module
# re-exports operations whose implementation depends on internal Mir modules.
if ! (
    cd "$repo_root" &&
    dub describe --compiler="$compiler"
) >"$tmp_dir/describe.json"
then
    echo "ERROR: dub describe failed"
    exit 1
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
    echo "ERROR: dub describe produced no import paths"
    exit 1
fi


compile_probe()
{
    name="$1"
    expectation="$2"

    source="$tmp_dir/$name.d"
    object="$tmp_dir/$name.o"
    stderr="$tmp_dir/$name.stderr"

    if "$compiler" \
        -preview=dip1000 \
        "${import_args[@]}" \
        -c "$source" \
        -of="$object" \
        2>"$stderr"
    then
        actual="pass"
    else
        actual="reject"
    fi

    if [ "$actual" = "$expectation" ]; then
        echo "PASS expected-$expectation: $name"

        # Expected rejections are diagnostic evidence too.
        # Show the first few lines so a false-positive rejection caused by
        # some unrelated module error remains visible.
        if [ "$expectation" = "reject" ] &&
           [ -s "$stderr" ]
        then
            echo '  compiler diagnostic:'
            sed 's/^/    /' "$stderr" | head -12
        fi
    else
        echo "FAIL expected-$expectation: $name"
        failures=$((failures + 1))

        if [ -s "$stderr" ]; then
            echo '  compiler diagnostic:'
            sed 's/^/    /' "$stderr" | head -50
        fi
    fi
}


compiler_supports_named_arguments()
{
    cat > "$tmp_dir/named_argument_capability.d" <<'D'
module raster_writable_named_argument_capability;

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


cat > "$tmp_dir/positive.d" <<'D'
module imagery.raster.writable_view_positive;

import imagery.raster.descriptor :
    PlaneDescriptor;

import imagery.raster.region :
    Region2D;

import imagery.raster.resource :
    ResourceEntry;

import imagery.raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import imagery.raster.writable_view :
    tryMakeWritableRasterView;


/*
 * MUST PASS.
 *
 * This models the future retained-backing use:
 *
 * - resource metadata already exists and is borrowed;
 * - descriptor metadata already exists and is borrowed;
 * - the writable capability is consumed only inside those borrows.
 *
 * No local raw-pointer metadata table is manufactured here.
 */
@safe
bool exerciseWritableView(
    scope const(ResourceEntry)[] resources,
    scope const(PlaneDescriptor)[] descriptors
)
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto view =
        tryMakeWritableRasterView!ubyte(
            resources,
            descriptors,
            Region2D(
                0,
                0,
                4,
                1
            ),
            validation,
            certification
        );

    if (
        !validation.ok
        || !certification.ok
    )
    {
        return false;
    }


    if (
        !view.trySetSample(
            0,
            2,
            0,
            55
        )
    )
    {
        return false;
    }


    bool roiSuccess;

    auto roi =
        view.tryRoi(
            Region2D(
                1,
                0,
                2,
                1
            ),
            roiSuccess
        );

    if (!roiSuccess)
    {
        return false;
    }


    ubyte value;

    return
        roi.trySample(
            0,
            1,
            0,
            value
        );
}
D


cat > "$tmp_dir/local_escape.d" <<'D'
module imagery.raster.writable_view_negative_local_escape;

import imagery.raster.descriptor :
    PlaneDescriptor;

import imagery.raster.region :
    Region2D;

import imagery.raster.resource :
    ResourceEntry;

import imagery.raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import imagery.raster.writable_view :
    WritableRasterView,
    tryMakeWritableRasterView;


/*
 * MUST FAIL.
 *
 * Metadata is only scope-borrowed by this function.
 * Returning the resulting WritableRasterView would extend that borrow.
 */
@safe
WritableRasterView!ubyte escapeScopeBorrow(
    scope const(ResourceEntry)[] resources,
    scope const(PlaneDescriptor)[] descriptors
)
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    return tryMakeWritableRasterView!ubyte(
        resources,
        descriptors,
        Region2D(
            0,
            0,
            4,
            1
        ),
        validation,
        certification
    );
}
D


cat > "$tmp_dir/global_escape.d" <<'D'
module imagery.raster.writable_view_negative_global_escape;

import imagery.raster.descriptor :
    PlaneDescriptor;

import imagery.raster.region :
    Region2D;

import imagery.raster.resource :
    ResourceEntry;

import imagery.raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import imagery.raster.writable_view :
    WritableRasterView,
    tryMakeWritableRasterView;


WritableRasterView!ubyte escaped;


/*
 * MUST FAIL.
 *
 * A capability tied to scope-borrowed retained metadata must not escape into
 * global storage.
 */
@safe
void storeScopeBorrowGlobally(
    scope const(ResourceEntry)[] resources,
    scope const(PlaneDescriptor)[] descriptors
)
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto view =
        tryMakeWritableRasterView!ubyte(
            resources,
            descriptors,
            Region2D(
                0,
                0,
                4,
                1
            ),
            validation,
            certification
        );

    escaped =
        view;
}
D


cat > "$tmp_dir/const_roi.d" <<'D'
module imagery.raster.writable_view_negative_const_roi;

import imagery.raster.descriptor :
    PlaneDescriptor;

import imagery.raster.region :
    Region2D;

import imagery.raster.resource :
    ResourceEntry;

import imagery.raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;

import imagery.raster.writable_view :
    tryMakeWritableRasterView;


/*
 * MUST FAIL.
 *
 * The backing borrows themselves are valid for this function.
 * Rejection must arise because writable child creation requires a mutable
 * WritableRasterView receiver.
 */
@safe
bool writableChildFromConstParent(
    scope const(ResourceEntry)[] resources,
    scope const(PlaneDescriptor)[] descriptors
)
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    const parent =
        tryMakeWritableRasterView!ubyte(
            resources,
            descriptors,
            Region2D(
                0,
                0,
                4,
                1
            ),
            validation,
            certification
        );

    bool success;

    auto child =
        parent.tryRoi(
            Region2D(
                0,
                0,
                2,
                1
            ),
            success
        );

    return success && !child.empty;
}
D


cat > "$tmp_dir/raw_constructor_surface.d" <<'D'
module imagery.raster.writable_view_negative_raw_constructor_surface;

/*
 * MUST FAIL.
 *
 * Even another module inside imagery.raster must not manufacture writable
 * capability directly from PlaneDescriptor[] + Region2D.
 */
import imagery.raster.writable_view :
    makeWritableRasterViewAssumeCertified;

alias escapedRawConstructor =
    makeWritableRasterViewAssumeCertified;
D


cat > "$tmp_dir/external_surface.d" <<'D'
module raster_writable_view_public_external_surface;

import imagery.raster :
    WritableRasterView;


/*
 * MUST PASS.
 *
 * E5.4g.1 deliberately exposes the semantic writable-view type through the
 * public raster package.
 *
 * Default construction is safe and inert; raw certification remains hidden.
 */
@safe
bool inspectPublicWritableView(
    scope ref WritableRasterView!ubyte view
)
{
    return
        view.planeCount == 0
        || !view.empty;
}
D


cat > "$tmp_dir/external_factory_surface.d" <<'D'
module raster_writable_view_negative_external_factory_surface;

/*
 * MUST FAIL.
 *
 * Publishing WritableRasterView does not publish its raw certification
 * boundary.
 */
import imagery.raster.writable_view :
    tryMakeWritableRasterView;

alias escapedWritableFactory =
    tryMakeWritableRasterView;
D


cat > "$tmp_dir/external_execution_surface.d" <<'D'
module raster_writable_view_negative_external_execution_surface;

import imagery.raster :
    WritableRasterView;


/*
 * MUST FAIL.
 *
 * The public semantic writable view must not expose mutable execution pointers.
 */
@safe
void consumeInternalExecutionBase(
    scope ref WritableRasterView!ubyte view
)
{
    auto base =
        view.executionRegionBase(0);

    cast(void) base;
}
D


cat > "$tmp_dir/execution_traits_positive.d" <<'D'
module imagery.raster.writable_view_execution_traits_positive;

import imagery.raster.internal.execution_layout :
    PlaneExecutionTraits;

import imagery.raster.writable_view :
    WritableRasterView;


/*
 * MUST PASS.
 *
 * Execution-layout metadata remains readable through a const writable view.
 */
@safe
bool queryWritableExecutionTraits(
    scope ref const(WritableRasterView!ubyte) view
)
{
    PlaneExecutionTraits traits;

    return view.tryPlaneExecutionTraits(
        0,
        traits
    );
}
D


cat > "$tmp_dir/execution_base_positive.d" <<'D'
module imagery.raster.writable_view_execution_base_positive;

import imagery.raster.writable_view :
    WritableRasterView;


/*
 * MUST PASS.
 *
 * A mutable scope-borrowed writable view may locally consume the mutable
 * execution-region base.
 */
@safe
bool consumeWritableExecutionBase(
    scope ref WritableRasterView!ubyte view
)
{
    scope auto base =
        view.executionRegionBase(0);

    return
        base is null
        || base !is null;
}
D


cat > "$tmp_dir/execution_base_const.d" <<'D'
module imagery.raster.writable_view_execution_base_negative_const;

import imagery.raster.writable_view :
    WritableRasterView;


/*
 * MUST FAIL.
 *
 * Const writable-view metadata must not recover a mutable execution pointer.
 */
@safe
void mutableBaseFromConst(
    scope ref const(WritableRasterView!ubyte) view
)
{
    auto base =
        view.executionRegionBase(0);

    cast(void) base;
}
D


cat > "$tmp_dir/execution_base_return.d" <<'D'
module imagery.raster.writable_view_execution_base_negative_return;

import imagery.raster.writable_view :
    WritableRasterView;


/*
 * MUST FAIL.
 *
 * Mutable execution pointer remains lifetime-bound to the scope view.
 */
@safe
ubyte* escapeExecutionBase(
    scope ref WritableRasterView!ubyte view
)
{
    return view.executionRegionBase(0);
}
D


cat > "$tmp_dir/execution_base_global.d" <<'D'
module imagery.raster.writable_view_execution_base_negative_global;

import imagery.raster.writable_view :
    WritableRasterView;


ubyte* escaped;


/*
 * MUST FAIL.
 *
 * Mutable execution pointer may not enter global storage.
 */
@safe
void storeExecutionBaseGlobally(
    scope ref WritableRasterView!ubyte view
)
{
    escaped =
        view.executionRegionBase(0);
}
D


cat > "$tmp_dir/external_lease_surface.d" <<'D'
module raster_writable_view_public_external_lease_surface;

import imagery.raster :
    RasterLease,
    WritableRasterView;


/*
 * MUST PASS.
 *
 * E5.4g.1 exposes the lease-bound semantic writable borrow.
 *
 * The borrow remains lifetime-related to the mutable lease and carries no
 * uniqueness/noalias guarantee.
 */
@safe
bool externalWritableBorrow(
    ref RasterLease!ubyte lease
)
{
    bool success;

    scope WritableRasterView!ubyte view =
        lease.tryWritableView(
            success
        );

    return
        !success
        || view.planeCount != 0;
}
D



cat > "$tmp_dir/external_named_arguments.d" <<'D'
module raster_writable_view_public_named_arguments;

import imagery.raster :
    RasterLease,
    Region2D,
    WritableRasterView;


/*
 * MUST PASS.
 *
 * Public D parameter names may be used as named arguments and therefore belong
 * to the stabilized source-compatibility surface.
 *
 * This probe deliberately locks the E5.4g.1 names:
 *
 * RasterLease.tryWritableView:
 *     success
 *
 * WritableRasterView.tryRoi:
 *     relative, success
 *
 * WritableRasterView.trySample:
 *     band, x, y, value
 *
 * WritableRasterView.trySetSample:
 *     band, x, y, value
 */
@safe
bool exercisePublicNamedArguments(
    ref RasterLease!ubyte lease
)
{
    bool borrowSuccess;

    scope WritableRasterView!ubyte view =
        lease.tryWritableView(
            success: borrowSuccess
        );

    if (!borrowSuccess)
        return true;


    bool roiSuccess;

    scope WritableRasterView!ubyte roi =
        view.tryRoi(
            relative: Region2D.init,
            success: roiSuccess
        );

    ubyte value;

    cast(void) roi.trySample(
        band: 0,
        x: 0,
        y: 0,
        value: value
    );

    cast(void) roi.trySetSample(
        band: 0,
        x: 0,
        y: 0,
        value: ubyte.init
    );

    return roiSuccess || !roiSuccess;
}
D


compile_probe positive pass

compile_probe execution_traits_positive pass
compile_probe execution_base_positive pass
compile_probe execution_base_const reject
compile_probe execution_base_return reject
compile_probe execution_base_global reject

compile_probe local_escape reject
compile_probe global_escape reject
compile_probe const_roi reject
compile_probe raw_constructor_surface reject
compile_probe external_surface pass
compile_probe external_factory_surface reject
compile_probe external_execution_surface reject
compile_probe external_lease_surface pass

if compiler_supports_named_arguments; then
    compile_probe external_named_arguments pass
else
    echo 'SKIP expected-pass: external_named_arguments (compiler syntax unsupported)'
fi

echo "FAILURES=$failures"

[ "$failures" -eq 0 ]
