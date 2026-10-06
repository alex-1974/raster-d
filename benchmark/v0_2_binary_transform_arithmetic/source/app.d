module raster.benchmark_binary_transform_arithmetic;

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

private float addFloat(float left, float right)
@safe pure nothrow @nogc
{
    return left + right;
}

private float subtractFloat(float left, float right)
@safe pure nothrow @nogc
{
    return left - right;
}

private float multiplyFloat(float left, float right)
@safe pure nothrow @nogc
{
    return left * right;
}

private float divideFloat(float left, float right)
@safe pure nothrow @nogc
{
    return left / right;
}

private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPaddingElements,
    int seed,
    bool denominator,
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

            if (denominator)
            {
                typed[y * rowElements + x] =
                    cast(float)((raw >= 0 ? raw : -raw) + 1) * 0.03125f;
            }
            else
            {
                typed[y * rowElements + x] =
                    cast(float) raw * 0.03125f;
            }
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

private bool makeDestination(
    size_t width,
    size_t height,
    size_t rowPaddingElements,
    ref RasterLease!float lease,
    out float* base,
    out size_t rowElements
)
@system
{
    return makeFloatLease(
        width,
        height,
        rowPaddingElements,
        0,
        false,
        lease,
        base,
        rowElements
    );
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

private long timePublicZipAdd(
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
            left.zipTransformInto!addFloat(
                0,
                right,
                0,
                destination,
                0,
                error
            ),
            "public zip add failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timePublicAdd(
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
            left.addInto(0, right, 0, destination, 0, error),
            "public addInto failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timePublicSubtract(
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
            left.subtractInto(0, right, 0, destination, 0, error),
            "public subtractInto failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timePublicMultiply(
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

private long timePublicDivide(
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
            left.divideInto(0, right, 0, destination, 0, error),
            "public divideInto failed"
        );
    }

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeExecutor(alias transform)(
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
            executeApprovedCanonicalZipTransform!transform(
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
            "approved zip executor declined canonical layout"
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
    const logicalSamples =
        cast(double)(width * height * iterations);

    writefln(
        "binary_transform_benchmark compiler=%s operation=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
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
    const iterations = args.length >= 4 ? args[3].to!size_t : 8;
    enum size_t rowPadding = 32;

    RasterLease!float leftLease;
    RasterLease!float rightLease;

    float* leftBase;
    float* rightBase;
    size_t leftRowElements;
    size_t rightRowElements;

    require(
        makeFloatLease(
            width,
            height,
            rowPadding,
            7,
            false,
            leftLease,
            leftBase,
            leftRowElements
        ),
        "left construction failed"
    );

    require(
        makeFloatLease(
            width,
            height,
            rowPadding,
            53,
            true,
            rightLease,
            rightBase,
            rightRowElements
        ),
        "right construction failed"
    );

    enum size_t pathCount = 9;
    RasterLease!float[pathCount] destinationLeases;
    float*[pathCount] destinationBases;
    size_t[pathCount] destinationRows;
    WritableRasterView!float[pathCount] destinations;

    foreach (i; 0 .. pathCount)
    {
        require(
            makeDestination(
                width,
                height,
                rowPadding,
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

    /*
     * Path mapping:
     * 0 zip-add public
     * 1 add wrapper
     * 2 add executor
     * 3 subtract wrapper
     * 4 subtract executor
     * 5 multiply wrapper
     * 6 multiply executor
     * 7 divide wrapper
     * 8 divide executor
     */
    timePublicZipAdd(left, right, destinations[0], 1);
    timePublicAdd(left, right, destinations[1], 1);
    timeExecutor!addFloat(
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

    timePublicSubtract(left, right, destinations[3], 1);
    timeExecutor!subtractFloat(
        leftBase,
        cast(ptrdiff_t) leftRowElements,
        rightBase,
        cast(ptrdiff_t) rightRowElements,
        width,
        height,
        destinationBases[4],
        cast(ptrdiff_t) destinationRows[4],
        1
    );

    timePublicMultiply(left, right, destinations[5], 1);
    timeExecutor!multiplyFloat(
        leftBase,
        cast(ptrdiff_t) leftRowElements,
        rightBase,
        cast(ptrdiff_t) rightRowElements,
        width,
        height,
        destinationBases[6],
        cast(ptrdiff_t) destinationRows[6],
        1
    );

    timePublicDivide(left, right, destinations[7], 1);
    timeExecutor!divideFloat(
        leftBase,
        cast(ptrdiff_t) leftRowElements,
        rightBase,
        cast(ptrdiff_t) rightRowElements,
        width,
        height,
        destinationBases[8],
        cast(ptrdiff_t) destinationRows[8],
        1
    );

    ulong[pathCount] qualificationChecksums;

    foreach (i; 0 .. pathCount)
    {
        qualificationChecksums[i] = checksum(
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
        qualificationChecksums[0]
            == qualificationChecksums[1]
        && qualificationChecksums[1]
            == qualificationChecksums[2],
        "add path checksum mismatch"
    );

    require(
        qualificationChecksums[3]
            == qualificationChecksums[4],
        "subtract path checksum mismatch"
    );

    require(
        qualificationChecksums[5]
            == qualificationChecksums[6],
        "multiply path checksum mismatch"
    );

    require(
        qualificationChecksums[7]
            == qualificationChecksums[8],
        "divide path checksum mismatch"
    );

    foreach (warmup; 0 .. warmups)
    {
        final switch (warmup % 3)
        {
            case 0:
                timePublicZipAdd(left, right, destinations[0], 1);
                timePublicAdd(left, right, destinations[1], 1);
                timeExecutor!addFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[2],
                    cast(ptrdiff_t) destinationRows[2],
                    1
                );
                break;

            case 1:
                timeExecutor!addFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[2],
                    cast(ptrdiff_t) destinationRows[2],
                    1
                );
                timePublicZipAdd(left, right, destinations[0], 1);
                timePublicAdd(left, right, destinations[1], 1);
                break;

            case 2:
                timePublicAdd(left, right, destinations[1], 1);
                timeExecutor!addFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[2],
                    cast(ptrdiff_t) destinationRows[2],
                    1
                );
                timePublicZipAdd(left, right, destinations[0], 1);
                break;
        }

        if ((warmup & 1) == 0)
        {
            timePublicSubtract(left, right, destinations[3], 1);
            timeExecutor!subtractFloat(
                leftBase, cast(ptrdiff_t) leftRowElements,
                rightBase, cast(ptrdiff_t) rightRowElements,
                width, height,
                destinationBases[4],
                cast(ptrdiff_t) destinationRows[4],
                1
            );

            timePublicMultiply(left, right, destinations[5], 1);
            timeExecutor!multiplyFloat(
                leftBase, cast(ptrdiff_t) leftRowElements,
                rightBase, cast(ptrdiff_t) rightRowElements,
                width, height,
                destinationBases[6],
                cast(ptrdiff_t) destinationRows[6],
                1
            );

            timePublicDivide(left, right, destinations[7], 1);
            timeExecutor!divideFloat(
                leftBase, cast(ptrdiff_t) leftRowElements,
                rightBase, cast(ptrdiff_t) rightRowElements,
                width, height,
                destinationBases[8],
                cast(ptrdiff_t) destinationRows[8],
                1
            );
        }
        else
        {
            timeExecutor!subtractFloat(
                leftBase, cast(ptrdiff_t) leftRowElements,
                rightBase, cast(ptrdiff_t) rightRowElements,
                width, height,
                destinationBases[4],
                cast(ptrdiff_t) destinationRows[4],
                1
            );
            timePublicSubtract(left, right, destinations[3], 1);

            timeExecutor!multiplyFloat(
                leftBase, cast(ptrdiff_t) leftRowElements,
                rightBase, cast(ptrdiff_t) rightRowElements,
                width, height,
                destinationBases[6],
                cast(ptrdiff_t) destinationRows[6],
                1
            );
            timePublicMultiply(left, right, destinations[5], 1);

            timeExecutor!divideFloat(
                leftBase, cast(ptrdiff_t) leftRowElements,
                rightBase, cast(ptrdiff_t) rightRowElements,
                width, height,
                destinationBases[8],
                cast(ptrdiff_t) destinationRows[8],
                1
            );
            timePublicDivide(left, right, destinations[7], 1);
        }
    }

    long[samples] zipAddTimes;
    long[samples] addTimes;
    long[samples] addExecutorTimes;
    long[samples] subtractTimes;
    long[samples] subtractExecutorTimes;
    long[samples] multiplyTimes;
    long[samples] multiplyExecutorTimes;
    long[samples] divideTimes;
    long[samples] divideExecutorTimes;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 3)
        {
            case 0:
                zipAddTimes[sample] =
                    timePublicZipAdd(left, right, destinations[0], iterations);
                addTimes[sample] =
                    timePublicAdd(left, right, destinations[1], iterations);
                addExecutorTimes[sample] =
                    timeExecutor!addFloat(
                        leftBase, cast(ptrdiff_t) leftRowElements,
                        rightBase, cast(ptrdiff_t) rightRowElements,
                        width, height,
                        destinationBases[2],
                        cast(ptrdiff_t) destinationRows[2],
                        iterations
                    );
                break;

            case 1:
                addExecutorTimes[sample] =
                    timeExecutor!addFloat(
                        leftBase, cast(ptrdiff_t) leftRowElements,
                        rightBase, cast(ptrdiff_t) rightRowElements,
                        width, height,
                        destinationBases[2],
                        cast(ptrdiff_t) destinationRows[2],
                        iterations
                    );
                zipAddTimes[sample] =
                    timePublicZipAdd(left, right, destinations[0], iterations);
                addTimes[sample] =
                    timePublicAdd(left, right, destinations[1], iterations);
                break;

            case 2:
                addTimes[sample] =
                    timePublicAdd(left, right, destinations[1], iterations);
                addExecutorTimes[sample] =
                    timeExecutor!addFloat(
                        leftBase, cast(ptrdiff_t) leftRowElements,
                        rightBase, cast(ptrdiff_t) rightRowElements,
                        width, height,
                        destinationBases[2],
                        cast(ptrdiff_t) destinationRows[2],
                        iterations
                    );
                zipAddTimes[sample] =
                    timePublicZipAdd(left, right, destinations[0], iterations);
                break;
        }

        if ((sample & 1) == 0)
        {
            subtractTimes[sample] =
                timePublicSubtract(left, right, destinations[3], iterations);
            subtractExecutorTimes[sample] =
                timeExecutor!subtractFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[4],
                    cast(ptrdiff_t) destinationRows[4],
                    iterations
                );

            multiplyTimes[sample] =
                timePublicMultiply(left, right, destinations[5], iterations);
            multiplyExecutorTimes[sample] =
                timeExecutor!multiplyFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[6],
                    cast(ptrdiff_t) destinationRows[6],
                    iterations
                );

            divideTimes[sample] =
                timePublicDivide(left, right, destinations[7], iterations);
            divideExecutorTimes[sample] =
                timeExecutor!divideFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[8],
                    cast(ptrdiff_t) destinationRows[8],
                    iterations
                );
        }
        else
        {
            subtractExecutorTimes[sample] =
                timeExecutor!subtractFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[4],
                    cast(ptrdiff_t) destinationRows[4],
                    iterations
                );
            subtractTimes[sample] =
                timePublicSubtract(left, right, destinations[3], iterations);

            multiplyExecutorTimes[sample] =
                timeExecutor!multiplyFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[6],
                    cast(ptrdiff_t) destinationRows[6],
                    iterations
                );
            multiplyTimes[sample] =
                timePublicMultiply(left, right, destinations[5], iterations);

            divideExecutorTimes[sample] =
                timeExecutor!divideFloat(
                    leftBase, cast(ptrdiff_t) leftRowElements,
                    rightBase, cast(ptrdiff_t) rightRowElements,
                    width, height,
                    destinationBases[8],
                    cast(ptrdiff_t) destinationRows[8],
                    iterations
                );
            divideTimes[sample] =
                timePublicDivide(left, right, destinations[7], iterations);
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
        "timed add path checksum mismatch"
    );
    require(
        finalChecksums[3] == finalChecksums[4],
        "timed subtract path checksum mismatch"
    );
    require(
        finalChecksums[5] == finalChecksums[6],
        "timed multiply path checksum mismatch"
    );
    require(
        finalChecksums[7] == finalChecksums[8],
        "timed divide path checksum mismatch"
    );

    const zipAddMedian = median(zipAddTimes);
    const addMedian = median(addTimes);
    const addExecutorMedian = median(addExecutorTimes);
    const subtractMedian = median(subtractTimes);
    const subtractExecutorMedian = median(subtractExecutorTimes);
    const multiplyMedian = median(multiplyTimes);
    const multiplyExecutorMedian = median(multiplyExecutorTimes);
    const divideMedian = median(divideTimes);
    const divideExecutorMedian = median(divideExecutorTimes);

    printPath("add", "public_zip", width, height, iterations, zipAddMedian, finalChecksums[0]);
    printPath("add", "public_wrapper", width, height, iterations, addMedian, finalChecksums[1]);
    printPath("add", "hot_executor", width, height, iterations, addExecutorMedian, finalChecksums[2]);
    printPath("subtract", "public_wrapper", width, height, iterations, subtractMedian, finalChecksums[3]);
    printPath("subtract", "hot_executor", width, height, iterations, subtractExecutorMedian, finalChecksums[4]);
    printPath("multiply", "public_wrapper", width, height, iterations, multiplyMedian, finalChecksums[5]);
    printPath("multiply", "hot_executor", width, height, iterations, multiplyExecutorMedian, finalChecksums[6]);
    printPath("divide", "public_wrapper", width, height, iterations, divideMedian, finalChecksums[7]);
    printPath("divide", "hot_executor", width, height, iterations, divideExecutorMedian, finalChecksums[8]);

    writefln(
        "binary_transform_ratio compiler=%s operation=add public_zip_over_executor=%.6f wrapper_over_executor=%.6f public_zip_over_wrapper=%.6f",
        compilerName(),
        cast(double) zipAddMedian / cast(double) addExecutorMedian,
        cast(double) addMedian / cast(double) addExecutorMedian,
        cast(double) zipAddMedian / cast(double) addMedian
    );

    writefln(
        "binary_transform_ratio compiler=%s operation=subtract wrapper_over_executor=%.6f",
        compilerName(),
        cast(double) subtractMedian / cast(double) subtractExecutorMedian
    );

    writefln(
        "binary_transform_ratio compiler=%s operation=multiply wrapper_over_executor=%.6f",
        compilerName(),
        cast(double) multiplyMedian / cast(double) multiplyExecutorMedian
    );

    writefln(
        "binary_transform_ratio compiler=%s operation=divide wrapper_over_executor=%.6f",
        compilerName(),
        cast(double) divideMedian / cast(double) divideExecutorMedian
    );
}
