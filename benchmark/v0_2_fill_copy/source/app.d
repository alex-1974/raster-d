module raster.benchmark_fill_copy;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;
import raster.internal.fill_dispatch :
    tryFillRasterPlaneScalar;
import raster.internal.copy_dispatch :
    SameTypeRasterCopyError,
    copySameTypeRasterPlane;

private enum size_t warmups = 6;
private enum size_t samples = 18;
private enum ubyte paddingCanary = 0xD7;
private enum ubyte fillValue = 0xAD;

private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}

private bool makeLease(
    size_t width,
    size_t height,
    size_t rowPadding,
    int seed,
    bool destination,
    ref RasterLease!ubyte lease,
    out ubyte* base,
    out size_t rowElements
)
@system
{
    rowElements = width + rowPadding;

    if (
        width == 0
        || height == 0
        || rowElements < width
        || rowElements > size_t.max / height
    )
        return false;

    const physicalElements = rowElements * height;
    void* memory = malloc(physicalElements);

    if (memory is null)
        return false;

    base = cast(ubyte*) memory;
    auto bytes = base[0 .. physicalElements];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            if (x >= width)
                bytes[y * rowElements + x] = paddingCanary;
            else if (destination)
                bytes[y * rowElements + x] = 0;
            else
                bytes[y * rowElements + x] =
                    cast(ubyte)((y * 131 + x * 17 + seed) & 0xff);
        }
    }

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(memory, physicalElements, resource))
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t) rowElements,
            1
        )
    ];

    const imported = tryImportOwnedRaster!ubyte(
        resource,
        layouts[],
        Region2D(0, 0, width, height),
        lease
    );

    return imported.ok;
}

private ulong checksum(
    scope const(ubyte)* base,
    size_t width,
    size_t height,
    size_t rowElements
)
@trusted nothrow @nogc
{
    ulong hash = 1469598103934665603UL;

    foreach (y; 0 .. height)
    {
        const row = base + y * rowElements;

        foreach (x; 0 .. width)
        {
            hash ^= row[x];
            hash *= 1099511628211UL;
        }
    }

    return hash;
}

private bool paddingIsIntact(
    scope const(ubyte)* base,
    size_t width,
    size_t height,
    size_t rowElements
)
@trusted nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const row = base + y * rowElements;

        foreach (x; width .. rowElements)
        {
            if (row[x] != paddingCanary)
                return false;
        }
    }

    return true;
}

private long median(long[samples] values)
{
    sort(values[]);
    return (values[samples / 2 - 1] + values[samples / 2]) / 2;
}

private long timeFillV02(
    scope ref WritableRasterView!ubyte destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        require(destination.fill(0, fillValue), "fill v0.2 failed");

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeFillLegacy(
    scope ref WritableRasterView!ubyte destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        require(tryFillRasterPlane(destination, 0, fillValue), "legacy fill failed");

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeFillSemantic(
    scope ref WritableRasterView!ubyte destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        require(tryFillRasterPlaneScalar(destination, 0, fillValue), "fill semantic engine failed");

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeCopyV02(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterCopyError error;
        require(source.copyInto(0, destination, 0, error), "copy v0.2 failed");
        require(error == RasterCopyError.none, "copy v0.2 returned error");
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeCopyLegacy(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterCopyError error;
        require(tryCopyRasterPlane(source, 0, destination, 0, error), "legacy copy failed");
        require(error == RasterCopyError.none, "legacy copy returned error");
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeCopySemantic(
    scope RasterView!ubyte source,
    scope ref WritableRasterView!ubyte destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        require(
            copySameTypeRasterPlane(source, 0, destination, 0)
                == SameTypeRasterCopyError.none,
            "copy semantic engine failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private string compilerName()
{
    version (DigitalMars)
        return "dmd";
    else version (LDC)
        return "ldc";
    else
        return "other";
}

private void printPath(
    string operation,
    string path,
    size_t width,
    size_t height,
    size_t iterations,
    long medianNs,
    ulong resultChecksum
)
{
    const logicalSamples = cast(double)(width * height * iterations);

    writefln(
        "fill_copy_benchmark compiler=%s operation=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
        compilerName(),
        operation,
        path,
        width,
        height,
        iterations,
        samples,
        medianNs,
        cast(double) medianNs / logicalSamples,
        resultChecksum
    );
}

void main(string[] args)
@system
{
    const width = args.length >= 2 ? args[1].to!size_t : 2048;
    const height = args.length >= 3 ? args[2].to!size_t : 512;
    const iterations = args.length >= 4 ? args[3].to!size_t : 16;
    enum size_t rowPadding = 32;

    RasterLease!ubyte sourceLease;
    ubyte* sourceBase;
    size_t sourceRow;

    require(
        makeLease(width, height, rowPadding, 31, false,
            sourceLease, sourceBase, sourceRow),
        "source construction failed"
    );

    enum size_t pathCount = 6;
    RasterLease!ubyte[pathCount] destinationLeases;
    ubyte*[pathCount] destinationBases;
    size_t[pathCount] destinationRows;
    WritableRasterView!ubyte[pathCount] destinations;

    foreach (i; 0 .. pathCount)
    {
        require(
            makeLease(width, height, rowPadding, 0, true,
                destinationLeases[i], destinationBases[i], destinationRows[i]),
            "destination construction failed"
        );

        bool ok;
        destinations[i] = destinationLeases[i].tryWritableView(ok);
        require(ok, "writable destination unavailable");
    }

    scope auto source = sourceLease.view();

    // qualification pass
    timeFillV02(destinations[0], 1);
    timeFillLegacy(destinations[1], 1);
    timeFillSemantic(destinations[2], 1);
    timeCopyV02(source, destinations[3], 1);
    timeCopyLegacy(source, destinations[4], 1);
    timeCopySemantic(source, destinations[5], 1);

    ulong[pathCount] firstChecksums;

    foreach (i; 0 .. pathCount)
    {
        firstChecksums[i] = checksum(
            destinationBases[i], width, height, destinationRows[i]);

        require(
            paddingIsIntact(destinationBases[i], width, height, destinationRows[i]),
            "destination padding modified during qualification"
        );
    }

    require(
        firstChecksums[0] == firstChecksums[1]
        && firstChecksums[1] == firstChecksums[2],
        "fill path checksum mismatch"
    );

    require(
        firstChecksums[3] == firstChecksums[4]
        && firstChecksums[4] == firstChecksums[5],
        "copy path checksum mismatch"
    );

    foreach (warmup; 0 .. warmups)
    {
        final switch (warmup % 3)
        {
            case 0:
                timeFillV02(destinations[0], 1);
                timeFillLegacy(destinations[1], 1);
                timeFillSemantic(destinations[2], 1);
                timeCopyV02(source, destinations[3], 1);
                timeCopyLegacy(source, destinations[4], 1);
                timeCopySemantic(source, destinations[5], 1);
                break;

            case 1:
                timeFillSemantic(destinations[2], 1);
                timeFillV02(destinations[0], 1);
                timeFillLegacy(destinations[1], 1);
                timeCopySemantic(source, destinations[5], 1);
                timeCopyV02(source, destinations[3], 1);
                timeCopyLegacy(source, destinations[4], 1);
                break;

            case 2:
                timeFillLegacy(destinations[1], 1);
                timeFillSemantic(destinations[2], 1);
                timeFillV02(destinations[0], 1);
                timeCopyLegacy(source, destinations[4], 1);
                timeCopySemantic(source, destinations[5], 1);
                timeCopyV02(source, destinations[3], 1);
                break;
        }
    }

    long[samples] fillV02Times;
    long[samples] fillLegacyTimes;
    long[samples] fillSemanticTimes;
    long[samples] copyV02Times;
    long[samples] copyLegacyTimes;
    long[samples] copySemanticTimes;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 3)
        {
            case 0:
                fillV02Times[sample] =
                    timeFillV02(destinations[0], iterations);
                fillLegacyTimes[sample] =
                    timeFillLegacy(destinations[1], iterations);
                fillSemanticTimes[sample] =
                    timeFillSemantic(destinations[2], iterations);
                copyV02Times[sample] =
                    timeCopyV02(source, destinations[3], iterations);
                copyLegacyTimes[sample] =
                    timeCopyLegacy(source, destinations[4], iterations);
                copySemanticTimes[sample] =
                    timeCopySemantic(source, destinations[5], iterations);
                break;

            case 1:
                fillSemanticTimes[sample] =
                    timeFillSemantic(destinations[2], iterations);
                fillV02Times[sample] =
                    timeFillV02(destinations[0], iterations);
                fillLegacyTimes[sample] =
                    timeFillLegacy(destinations[1], iterations);
                copySemanticTimes[sample] =
                    timeCopySemantic(source, destinations[5], iterations);
                copyV02Times[sample] =
                    timeCopyV02(source, destinations[3], iterations);
                copyLegacyTimes[sample] =
                    timeCopyLegacy(source, destinations[4], iterations);
                break;

            case 2:
                fillLegacyTimes[sample] =
                    timeFillLegacy(destinations[1], iterations);
                fillSemanticTimes[sample] =
                    timeFillSemantic(destinations[2], iterations);
                fillV02Times[sample] =
                    timeFillV02(destinations[0], iterations);
                copyLegacyTimes[sample] =
                    timeCopyLegacy(source, destinations[4], iterations);
                copySemanticTimes[sample] =
                    timeCopySemantic(source, destinations[5], iterations);
                copyV02Times[sample] =
                    timeCopyV02(source, destinations[3], iterations);
                break;
        }
    }

    ulong[pathCount] finalChecksums;

    foreach (i; 0 .. pathCount)
    {
        finalChecksums[i] = checksum(
            destinationBases[i], width, height, destinationRows[i]);

        require(
            paddingIsIntact(destinationBases[i], width, height, destinationRows[i]),
            "destination padding modified during timed work"
        );
    }

    require(
        finalChecksums[0] == finalChecksums[1]
        && finalChecksums[1] == finalChecksums[2],
        "timed fill path checksum mismatch"
    );

    require(
        finalChecksums[3] == finalChecksums[4]
        && finalChecksums[4] == finalChecksums[5],
        "timed copy path checksum mismatch"
    );

    const fillV02Median = median(fillV02Times);
    const fillLegacyMedian = median(fillLegacyTimes);
    const fillSemanticMedian = median(fillSemanticTimes);
    const copyV02Median = median(copyV02Times);
    const copyLegacyMedian = median(copyLegacyTimes);
    const copySemanticMedian = median(copySemanticTimes);

    printPath("fill", "public_v0_2", width, height, iterations,
        fillV02Median, finalChecksums[0]);
    printPath("fill", "public_legacy", width, height, iterations,
        fillLegacyMedian, finalChecksums[1]);
    printPath("fill", "semantic_engine", width, height, iterations,
        fillSemanticMedian, finalChecksums[2]);

    printPath("copy", "public_v0_2", width, height, iterations,
        copyV02Median, finalChecksums[3]);
    printPath("copy", "public_legacy", width, height, iterations,
        copyLegacyMedian, finalChecksums[4]);
    printPath("copy", "semantic_engine", width, height, iterations,
        copySemanticMedian, finalChecksums[5]);

    writefln(
        "fill_copy_ratio compiler=%s operation=fill v0_2_over_semantic=%.6f legacy_over_semantic=%.6f v0_2_over_legacy=%.6f",
        compilerName(),
        cast(double) fillV02Median / cast(double) fillSemanticMedian,
        cast(double) fillLegacyMedian / cast(double) fillSemanticMedian,
        cast(double) fillV02Median / cast(double) fillLegacyMedian
    );

    writefln(
        "fill_copy_ratio compiler=%s operation=copy v0_2_over_semantic=%.6f legacy_over_semantic=%.6f v0_2_over_legacy=%.6f",
        compilerName(),
        cast(double) copyV02Median / cast(double) copySemanticMedian,
        cast(double) copyLegacyMedian / cast(double) copySemanticMedian,
        cast(double) copyV02Median / cast(double) copyLegacyMedian
    );
}
