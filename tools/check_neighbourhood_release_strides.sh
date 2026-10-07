#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/dub.sdl" <<'EOF'
name "raster-neighbourhood-release-stride-probe"
targetType "executable"
sourcePaths "."
dflags "-preview=dip1000"
dependency "raster-d" path="REPO_PATH"
EOF

sed -i "s|REPO_PATH|$ROOT|" "$TMP/dub.sdl"

cat > "$TMP/app.d" <<'EOF'
module raster.neighbourhood_release_stride_probe;

import core.stdc.stdlib : malloc;

import raster;


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private float center3(ref const(float)[9] n)
@safe pure nothrow @nogc
{
    return n[4];
}


private float center5x3(ref const(float)[15] n)
@safe pure nothrow @nogc
{
    return n[7];
}


private bool makeFloatLease(
    size_t width,
    size_t height,
    bool initialize,
    ref RasterLease!float lease
)
@system
{
    if (
        width == 0
        || height == 0
        || width > size_t.max / height
    )
        return false;

    const count = width * height;

    if (count > size_t.max / float.sizeof)
        return false;

    void* memory = malloc(count * float.sizeof);

    if (memory is null)
        return false;

    auto data = (cast(float*) memory)[0 .. count];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. width)
        {
            data[y * width + x] =
                initialize
                ? cast(float)(y * 100 + x)
                : -9999.0f;
        }
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            count * float.sizeof,
            resource
        )
    )
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(width * float.sizeof),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    return tryImportOwnedRaster!float(
        resource,
        layouts[],
        Region2D(0, 0, width, height),
        lease
    ).ok;
}


void main()
@system
{
    enum size_t sourceWidth = 7;
    enum size_t sourceHeight = 5;
    enum size_t outputWidth = 3;
    enum size_t outputHeight = 3;

    RasterLease!float sourceLease;
    RasterLease!float destination3Lease;
    RasterLease!float destination5Lease;

    require(
        makeFloatLease(
            sourceWidth,
            sourceHeight,
            true,
            sourceLease
        ),
        "source construction failed"
    );

    require(
        makeFloatLease(
            outputWidth,
            outputHeight,
            false,
            destination3Lease
        )
        && makeFloatLease(
            outputWidth,
            outputHeight,
            false,
            destination5Lease
        ),
        "destination construction failed"
    );

    scope auto source = sourceLease.view();

    bool writable3Ok;
    scope auto destination3 =
        destination3Lease.tryWritableView(writable3Ok);

    require(writable3Ok, "3x3 writable destination unavailable");

    RasterNeighbourhood3x3Error error3;

    require(
        tryApplyRasterNeighbourhood3x3!center3(
            source,
            0,
            Region2D(1, 1, outputWidth, outputHeight),
            destination3,
            0,
            error3
        ),
        "fixed 3x3 release operation failed"
    );

    require(
        error3 == RasterNeighbourhood3x3Error.none,
        "fixed 3x3 release operation returned error"
    );

    auto result3 = destination3Lease.view();

    foreach (y; 0 .. outputHeight)
    {
        foreach (x; 0 .. outputWidth)
        {
            float actual;
            float expected;

            require(
                result3.trySample(0, x, y, actual)
                && source.trySample(0, x + 1, y + 1, expected),
                "fixed 3x3 release result read failed"
            );

            require(
                actual == expected,
                "fixed 3x3 release result mismatch"
            );
        }
    }

    bool writable5Ok;
    scope auto destination5 =
        destination5Lease.tryWritableView(writable5Ok);

    require(writable5Ok, "5x3 writable destination unavailable");

    alias Shape5x3 =
        NeighbourhoodShape!(5, 3, 2, 1);

    RasterNeighbourhoodError error5;

    require(
        source.applyNeighbourhoodInto!(
            Shape5x3,
            center5x3
        )(
            0,
            Region2D(2, 1, outputWidth, outputHeight),
            destination5,
            0,
            error5
        ),
        "generic 5x3 release operation failed"
    );

    require(
        error5 == RasterNeighbourhoodError.none,
        "generic 5x3 release operation returned error"
    );

    auto result5 = destination5Lease.view();

    foreach (y; 0 .. outputHeight)
    {
        foreach (x; 0 .. outputWidth)
        {
            float actual;
            float expected;

            require(
                result5.trySample(0, x, y, actual)
                && source.trySample(0, x + 2, y + 1, expected),
                "generic 5x3 release result read failed"
            );

            require(
                actual == expected,
                "generic 5x3 release result mismatch"
            );
        }
    }
}
EOF

for compiler in dmd ldc2; do
    dub run         --root="$TMP"         --compiler="$compiler"         --build=release         --force
done
