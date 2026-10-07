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
import raster;

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

void main()
{
    enum size_t sourceWidth = 7;
    enum size_t sourceHeight = 5;

    float[sourceWidth * sourceHeight] sourceStorage;
    foreach (y; 0 .. sourceHeight)
        foreach (x; 0 .. sourceWidth)
            sourceStorage[y * sourceWidth + x] = cast(float)(y * 100 + x);

    float[3 * 3] destination3;
    float[3 * 3] destination5;

    const PlaneByteLayout[1] sourceLayout =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(sourceWidth * float.sizeof),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    const PlaneByteLayout[1] destinationLayout =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(3 * float.sizeof),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    OwnedByteResource sourceResource;
    OwnedByteResource destination3Resource;
    OwnedByteResource destination5Resource;

    assert(tryAdoptMallocResource(null, 0, sourceResource) == false);

    // Use caller-owned static storage through validated descriptors.
    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, sourceWidth, 1)];

    const PlaneDescriptor[1] destination3Descriptors =
        [PlaneDescriptor(destination3.ptr, 3, 1)];

    const PlaneDescriptor[1] destination5Descriptors =
        [PlaneDescriptor(destination5.ptr, 3, 1)];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(0, 0, sourceWidth, sourceHeight)
        );

    import raster.resource : ResourceAccess, ResourceEntry;
    import raster.validation :
        BackingValidationResult,
        WritableBackingCertificationResult;
    import raster.writable_view : tryMakeWritableRasterView;

    const ResourceEntry[1] resources3 =
    [
        ResourceEntry(
            destination3.ptr,
            destination3.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const ResourceEntry[1] resources5 =
    [
        ResourceEntry(
            destination5.ptr,
            destination5.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    BackingValidationResult validation3;
    WritableBackingCertificationResult certification3;

    scope auto writable3 =
        tryMakeWritableRasterView!float(
            resources3[],
            destination3Descriptors[],
            Region2D(0, 0, 3, 3),
            validation3,
            certification3
        );

    if (!validation3.ok || !certification3.ok)
        assert(0);

    RasterNeighbourhood3x3Error error3;

    if (!tryApplyRasterNeighbourhood3x3!center3(
        source,
        0,
        Region2D(1, 1, 3, 3),
        writable3,
        0,
        error3
    ))
        assert(0);

    foreach (y; 0 .. 3)
        foreach (x; 0 .. 3)
            if (destination3[y * 3 + x] != sourceStorage[(y + 1) * sourceWidth + (x + 1)])
                assert(0);

    BackingValidationResult validation5;
    WritableBackingCertificationResult certification5;

    scope auto writable5 =
        tryMakeWritableRasterView!float(
            resources5[],
            destination5Descriptors[],
            Region2D(0, 0, 3, 3),
            validation5,
            certification5
        );

    if (!validation5.ok || !certification5.ok)
        assert(0);

    alias Shape5x3 = NeighbourhoodShape!(5, 3, 2, 1);
    RasterNeighbourhoodError error5;

    if (!source.applyNeighbourhoodInto!(Shape5x3, center5x3)(
        0,
        Region2D(2, 1, 3, 3),
        writable5,
        0,
        error5
    ))
        assert(0);

    foreach (y; 0 .. 3)
        foreach (x; 0 .. 3)
            if (destination5[y * 3 + x] != sourceStorage[(y + 1) * sourceWidth + (x + 2)])
                assert(0);
}
EOF

for compiler in dmd ldc2; do
    dub run         --root="$TMP"         --compiler="$compiler"         --build=release         --force
done
