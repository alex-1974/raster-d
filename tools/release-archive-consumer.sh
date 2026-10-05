#!/usr/bin/env bash
set -euo pipefail

compiler="${1:-${DC:-dmd}}"
repo_root="$(
    cd "$(dirname "$0")/.." >/dev/null 2>&1
    pwd
)"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/raster-release-consumer-XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT

package_dir="$tmp_dir/raster-d"
consumer_dir="$tmp_dir/consumer"

mkdir -p "$package_dir" "$consumer_dir/source"

git -C "$repo_root" archive --format=tar HEAD \
    | tar -xf - -C "$package_dir"

test ! -e "$package_dir/.git"
test -f "$package_dir/dub.sdl"
test -f "$package_dir/source/raster/package.d"

cat >"$consumer_dir/dub.sdl" <<DUB
name "raster-d-release-consumer"
description "External archive consumer smoke for raster-d"
authors "raster-d release gate"
license "MIT"
targetType "executable"
dflags "-preview=dip1000"
dependency "raster-d" path="$package_dir"
DUB

cat >"$consumer_dir/source/app.d" <<'D'
module app;

import core.stdc.stdlib : malloc;
import raster;

static assert(isRasterSampleType!ubyte);
static assert(isRasterSampleType!float);
static assert(!isRasterSampleType!(ubyte*));

private float plusOne(float value)
@safe pure nothrow @nogc
{
    return value + 1.0f;
}

void main()
@system
{
    void* sourceMemory = malloc(4);
    void* targetMemory = malloc(4 * float.sizeof);

    assert(sourceMemory !is null);
    assert(targetMemory !is null);

    auto sourceSamples =
        (cast(ubyte*) sourceMemory)[0 .. 4];

    sourceSamples[] =
        [1, 2, 3, 4];

    OwnedByteResource sourceResource;
    OwnedByteResource targetResource;

    assert(tryAdoptMallocResource(sourceMemory, 4, sourceResource));
    assert(tryAdoptMallocResource(targetMemory, 4 * float.sizeof, targetResource));

    const PlaneByteLayout[1] sourceLayout =
    [
        PlaneByteLayout(0, 2, 1)
    ];

    const PlaneByteLayout[1] targetLayout =
    [
        PlaneByteLayout(0, 2 * float.sizeof, float.sizeof)
    ];

    RasterLease!ubyte sourceLease;
    RasterLease!float targetLease;

    assert(
        tryImportOwnedRaster!ubyte(
            sourceResource,
            sourceLayout[],
            Region2D(0, 0, 2, 2),
            sourceLease
        ).ok
    );

    assert(
        tryImportOwnedRaster!float(
            targetResource,
            targetLayout[],
            Region2D(0, 0, 2, 2),
            targetLease
        ).ok
    );

    scope auto source =
        sourceLease.view();

    bool writableSuccess;

    scope auto destination =
        targetLease.tryWritableView(writableSuccess);

    assert(writableSuccess);

    UbyteToFloatConversionError conversionError;

    assert(
        tryConvertUbyteToFloatPlane(
            source,
            0,
            destination,
            0,
            conversionError
        )
    );

    float value;

    assert(destination.trySample(0, 1, 1, value));
    assert(value == 4.0f);

    RasterTransformError transformError;

    assert(
        tryTransformRasterPlane!plusOne(
            targetLease.view(),
            0,
            destination,
            0,
            transformError
        )
    );

    assert(destination.trySample(0, 1, 1, value));
    assert(value == 5.0f);

    double sum;

    assert(
        trySumFloatToDouble(
            targetLease.view(),
            0,
            sum
        )
    );

    assert(sum == 14.0);
}
D

(
    cd "$consumer_dir"

    dub build \
        --compiler="$compiler" \
        --build=release \
        --force

    dub run \
        --compiler="$compiler" \
        --build=release \
        --force
)

echo "PASS: external git-archive consumer with $compiler"
