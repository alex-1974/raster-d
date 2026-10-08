module raster.benchmark_binary_codegen;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;
import raster.internal.zip_transform_dispatch :
    executeApprovedCanonicalZipTransform;

private enum size_t warmups = 6;
private enum size_t samples = 18;
private enum float paddingCanary = 123.25f;

private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}

private float multiplyFloat(float left, float right)
@safe pure nothrow @nogc
{
    return left * right;
}

private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPaddingElements,
    int seed,
    ref RasterLease!float lease,
    out float* base,
    out size_t rowElements
)
@system
{
    rowElements = width + rowPaddingElements;

    if (
        width == 0
        || height == 0
        || rowElements < width
        || rowElements > size_t.max / height
    )
        return false;

    const physicalElements = rowElements * height;

    if (physicalElements > size_t.max / float.sizeof)
        return false;

    const byteLength = physicalElements * float.sizeof;
    void* memory = malloc(byteLength);

    if (memory is null)
        return false;

    base = cast(float*) memory;
    auto typed = base[0 .. physicalElements];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            if (x >= width)
            {
                typed[y * rowElements + x] = paddingCanary;
                continue;
            }

            const raw = cast(int)((y * 131 + x * 17 + seed) % 251) - 125;
            typed[y * rowElements + x] = cast(float) raw * 0.03125f;
        }
    }

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(memory, byteLength, resource))
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(rowElements * float.sizeof),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    const result = tryImportOwnedRaster!float(
        resource,
        layouts[],
        Region2D(0, 0, width, height),
        lease
    );

    return result.ok;
}

private ulong checksum(
    scope const(float)* base,
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
            union Bits
            {
                float value;
                uint bits;
            }

            Bits bits;
            bits.value = row[x];

            hash ^= bits.bits;
            hash *= 1099511628211UL;
        }
    }

    return hash;
}

private bool paddingIsIntact(
    scope const(float)* base,
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

private long timePublicZip(
    scope RasterView!float left,
    scope RasterView!float right,
    scope ref WritableRasterView!float destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterZipTransformError error;

        require(
            left.zipTransformInto!multiplyFloat(
                0,
                right,
                0,
                destination,
                0,
                error
            ),
            "public zip multiply failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timePublicWrapper(
    scope RasterView!float left,
    scope RasterView!float right,
    scope ref WritableRasterView!float destination,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterZipTransformError error;

        require(
            left.multiplyInto(0, right, 0, destination, 0, error),
            "public multiplyInto failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeExecutor(
    scope const(float)* leftBase,
    ptrdiff_t leftRowElements,
    scope const(float)* rightBase,
    ptrdiff_t rightRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowElements,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        require(
            executeApprovedCanonicalZipTransform!multiplyFloat(
                leftBase,
                leftRowElements,
                1,
                rightBase,
                rightRowElements,
                1,
                width,
                height,
                destinationBase,
                destinationRowElements,
                1
            ),
            "approved Canonical executor declined workload"
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
        "binary_codegen compiler=%s path=%s width=%s height=%s iterations=%s timing_samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
        compilerName(),
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
    const iterations = args.length >= 4 ? args[3].to!size_t : 8;
    enum size_t rowPadding = 32;
    enum size_t pathCount = 3;

    RasterLease!float leftLease;
    RasterLease!float rightLease;
    float* leftBase;
    float* rightBase;
    size_t leftRowElements;
    size_t rightRowElements;

    require(
        makeFloatLease(width, height, rowPadding, 7, leftLease, leftBase, leftRowElements),
        "left construction failed"
    );
    require(
        makeFloatLease(width, height, rowPadding, 53, rightLease, rightBase, rightRowElements),
        "right construction failed"
    );

    RasterLease!float[pathCount] destinationLeases;
    float*[pathCount] destinationBases;
    size_t[pathCount] destinationRows;
    WritableRasterView!float[pathCount] destinations;

    foreach (i; 0 .. pathCount)
    {
        require(
            makeFloatLease(
                width,
                height,
                rowPadding,
                0,
                destinationLeases[i],
                destinationBases[i],
                destinationRows[i]
            ),
            "destination construction failed"
        );

        bool ok;
        destinations[i] = destinationLeases[i].tryWritableView(ok);
        require(ok, "writable destination unavailable");
    }

    scope auto left = leftLease.view();
    scope auto right = rightLease.view();

    timePublicZip(left, right, destinations[0], 1);
    timePublicWrapper(left, right, destinations[1], 1);
    timeExecutor(
        leftBase,
        cast(ptrdiff_t) leftRowElements,
        rightBase,
        cast(ptrdiff_t) rightRowElements,
        width,
        height,
        destinationBases[2],
        cast(ptrdiff_t) destinationRows[2],
        1
    );

    ulong[pathCount] qualifiedChecksums;

    foreach (i; 0 .. pathCount)
    {
        qualifiedChecksums[i] = checksum(
            destinationBases[i],
            width,
            height,
            destinationRows[i]
        );

        require(
            paddingIsIntact(
                destinationBases[i],
                width,
                height,
                destinationRows[i]
            ),
            "destination padding modified during qualification"
        );
    }

    require(
        qualifiedChecksums[0] == qualifiedChecksums[1]
        && qualifiedChecksums[1] == qualifiedChecksums[2],
        "multiply path checksum mismatch"
    );

    foreach (warmup; 0 .. warmups)
    {
        final switch (warmup % 3)
        {
            case 0:
                timePublicZip(left, right, destinations[0], 1);
                timePublicWrapper(left, right, destinations[1], 1);
                timeExecutor(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[2], cast(ptrdiff_t) destinationRows[2], 1
                );
                break;

            case 1:
                timePublicWrapper(left, right, destinations[1], 1);
                timeExecutor(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[2], cast(ptrdiff_t) destinationRows[2], 1
                );
                timePublicZip(left, right, destinations[0], 1);
                break;

            case 2:
                timeExecutor(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[2], cast(ptrdiff_t) destinationRows[2], 1
                );
                timePublicZip(left, right, destinations[0], 1);
                timePublicWrapper(left, right, destinations[1], 1);
                break;
        }
    }

    long[samples] publicZipTimes;
    long[samples] publicWrapperTimes;
    long[samples] executorTimes;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 3)
        {
            case 0:
                publicZipTimes[sample] =
                    timePublicZip(left, right, destinations[0], iterations);
                publicWrapperTimes[sample] =
                    timePublicWrapper(left, right, destinations[1], iterations);
                executorTimes[sample] =
                    timeExecutor(
                        leftBase, cast(ptrdiff_t) leftRowElements,
                        rightBase, cast(ptrdiff_t) rightRowElements,
                        width, height,
                        destinationBases[2],
                        cast(ptrdiff_t) destinationRows[2],
                        iterations
                    );
                break;

            case 1:
                publicWrapperTimes[sample] =
                    timePublicWrapper(left, right, destinations[1], iterations);
                executorTimes[sample] =
                    timeExecutor(
                        leftBase, cast(ptrdiff_t) leftRowElements,
                        rightBase, cast(ptrdiff_t) rightRowElements,
                        width, height,
                        destinationBases[2],
                        cast(ptrdiff_t) destinationRows[2],
                        iterations
                    );
                publicZipTimes[sample] =
                    timePublicZip(left, right, destinations[0], iterations);
                break;

            case 2:
                executorTimes[sample] =
                    timeExecutor(
                        leftBase, cast(ptrdiff_t) leftRowElements,
                        rightBase, cast(ptrdiff_t) rightRowElements,
                        width, height,
                        destinationBases[2],
                        cast(ptrdiff_t) destinationRows[2],
                        iterations
                    );
                publicZipTimes[sample] =
                    timePublicZip(left, right, destinations[0], iterations);
                publicWrapperTimes[sample] =
                    timePublicWrapper(left, right, destinations[1], iterations);
                break;
        }
    }

    ulong[pathCount] finalChecksums;

    foreach (i; 0 .. pathCount)
    {
        finalChecksums[i] = checksum(
            destinationBases[i],
            width,
            height,
            destinationRows[i]
        );

        require(
            paddingIsIntact(
                destinationBases[i],
                width,
                height,
                destinationRows[i]
            ),
            "destination padding modified during timed work"
        );
    }

    require(
        finalChecksums[0] == finalChecksums[1]
        && finalChecksums[1] == finalChecksums[2],
        "timed multiply path checksum mismatch"
    );

    const publicZipMedian = median(publicZipTimes);
    const publicWrapperMedian = median(publicWrapperTimes);
    const executorMedian = median(executorTimes);

    printPath(
        "public_zip",
        width,
        height,
        iterations,
        publicZipMedian,
        finalChecksums[0]
    );
    printPath(
        "public_wrapper",
        width,
        height,
        iterations,
        publicWrapperMedian,
        finalChecksums[1]
    );
    printPath(
        "hot_executor",
        width,
        height,
        iterations,
        executorMedian,
        finalChecksums[2]
    );

    writefln(
        "binary_codegen_ratio compiler=%s public_zip_over_executor=%.6f wrapper_over_executor=%.6f wrapper_over_public_zip=%.6f",
        compilerName(),
        cast(double) publicZipMedian / cast(double) executorMedian,
        cast(double) publicWrapperMedian / cast(double) executorMedian,
        cast(double) publicWrapperMedian / cast(double) publicZipMedian
    );
}
