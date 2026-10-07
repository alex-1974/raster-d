module raster.benchmark_transform_allocated;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;

import raster.internal.compact_allocation :
    CompactAllocationError,
    allocateCompactRaster;


private enum size_t warmups = 6;
private enum size_t samples = 18;


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private float pointTransform(float value)
@safe
pure
nothrow
@nogc
{
    return value * 1.0009765625f + 0.25f;
}


private bool makeSourceLease(
    size_t width,
    size_t height,
    size_t rowPadding,
    ref RasterLease!float lease
)
@system
{
    const rowElements = width + rowPadding;

    if (
        width == 0
        || height == 0
        || rowElements < width
        || rowElements > size_t.max / height
    )
        return false;

    const elementCount = rowElements * height;

    if (elementCount > size_t.max / float.sizeof)
        return false;

    const byteLength = elementCount * float.sizeof;

    void* memory = malloc(byteLength);

    if (memory is null)
        return false;

    auto data = (cast(float*) memory)[0 .. elementCount];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            data[y * rowElements + x] =
                cast(float)(
                    cast(int)((y * 131 + x * 17 + 29) % 4093)
                    - 2046
                ) * 0.00390625f;
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

    const imported =
        tryImportOwnedRaster!float(
            resource,
            layouts[],
            Region2D(0, 0, width, height),
            lease
        );

    return imported.ok;
}


private ulong checksumFloat(scope RasterView!float view)
@safe
{
    ulong hash = 1469598103934665603UL;

    foreach (y; 0 .. view.height)
    {
        foreach (x; 0 .. view.width)
        {
            float value;

            require(
                view.trySample(0, x, y, value),
                "checksum sample read failed"
            );

            union Bits
            {
                float value;
                uint bits;
            }

            Bits bits;
            bits.value = value;

            hash ^= bits.bits;
            hash *= 1099511628211UL;
        }
    }

    return hash;
}


private RasterLease!float explicitTransformOnce(
    scope RasterView!float source
)
@safe
{
    auto allocated =
        allocateCompactRaster!float(
            source.width,
            source.height
        );

    require(
        allocated.error == CompactAllocationError.none,
        "explicit compact allocation failed"
    );

    bool writableOk;

    scope auto destination =
        allocated.lease.tryWritableView(
            writableOk
        );

    require(
        writableOk,
        "explicit writable destination unavailable"
    );

    RasterTransformError error;

    require(
        source.transformInto!pointTransform(
            0,
            destination,
            0,
            error
        ),
        "explicit transformInto failed"
    );

    require(
        error == RasterTransformError.none,
        "explicit transformInto returned an error"
    );

    return allocated.lease;
}


private long timePublicAllocated(
    scope RasterView!float source,
    size_t iterations,
    out size_t successes
)
@safe
{
    successes = 0;

    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        auto result =
            source.tryTransformAllocated!pointTransform(0);

        require(
            result.ok,
            "public allocated transform failed"
        );

        ++successes;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeExplicitAllocated(
    scope RasterView!float source,
    size_t iterations,
    out size_t successes
)
@safe
{
    successes = 0;

    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        auto result =
            explicitTransformOnce(source);

        require(
            result.view().planeCount == 1,
            "explicit allocated result invalid"
        );

        ++successes;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long median(long[samples] values)
{
    sort(values[]);

    return (
        values[samples / 2 - 1]
        + values[samples / 2]
    ) / 2;
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


void main(string[] args)
@system
{
    const width =
        args.length >= 2
        ? args[1].to!size_t
        : 2048;

    const height =
        args.length >= 3
        ? args[2].to!size_t
        : 512;

    const iterations =
        args.length >= 4
        ? args[3].to!size_t
        : 4;

    enum size_t rowPadding = 32;

    RasterLease!float sourceLease;

    require(
        makeSourceLease(
            width,
            height,
            rowPadding,
            sourceLease
        ),
        "source construction failed"
    );

    scope auto source = sourceLease.view();

    // Semantic preflight for both materialization surfaces.
    auto publicCheck =
        source.tryTransformAllocated!pointTransform(0);

    require(
        publicCheck.ok,
        "public allocated semantic preflight failed"
    );

    auto explicitCheck =
        explicitTransformOnce(source);

    const publicChecksum =
        checksumFloat(publicCheck.lease().view());

    const explicitChecksum =
        checksumFloat(explicitCheck.view());

    require(
        publicChecksum == explicitChecksum,
        "public/explicit allocated checksum mismatch"
    );

    size_t ignoredSuccesses;

    foreach (warmup; 0 .. warmups)
    {
        if ((warmup & 1) == 0)
        {
            timePublicAllocated(
                source,
                1,
                ignoredSuccesses
            );

            timeExplicitAllocated(
                source,
                1,
                ignoredSuccesses
            );
        }
        else
        {
            timeExplicitAllocated(
                source,
                1,
                ignoredSuccesses
            );

            timePublicAllocated(
                source,
                1,
                ignoredSuccesses
            );
        }
    }

    long[samples] publicTimes;
    long[samples] explicitTimes;
    double[samples] ratios;

    size_t publicSuccesses;
    size_t explicitSuccesses;

    foreach (sample; 0 .. samples)
    {
        if ((sample & 1) == 0)
        {
            publicTimes[sample] =
                timePublicAllocated(
                    source,
                    iterations,
                    publicSuccesses
                );

            explicitTimes[sample] =
                timeExplicitAllocated(
                    source,
                    iterations,
                    explicitSuccesses
                );
        }
        else
        {
            explicitTimes[sample] =
                timeExplicitAllocated(
                    source,
                    iterations,
                    explicitSuccesses
                );

            publicTimes[sample] =
                timePublicAllocated(
                    source,
                    iterations,
                    publicSuccesses
                );
        }

        ratios[sample] =
            cast(double) publicTimes[sample]
            / cast(double) explicitTimes[sample];
    }

    const publicMedian = median(publicTimes);
    const explicitMedian = median(explicitTimes);

    double[samples] sortedRatios = ratios;
    sort(sortedRatios[]);

    const ratioMedian =
        (
            sortedRatios[samples / 2 - 1]
            + sortedRatios[samples / 2]
        ) / 2.0;

    const logicalSamples =
        cast(double)(width * height * iterations);

    writefln(
        "transform_allocated_benchmark compiler=%s path=public_allocated width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f successes=%s checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        samples,
        publicMedian,
        cast(double) publicMedian / logicalSamples,
        publicSuccesses,
        publicChecksum
    );

    writefln(
        "transform_allocated_benchmark compiler=%s path=explicit_allocate_transform width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f successes=%s checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        samples,
        explicitMedian,
        cast(double) explicitMedian / logicalSamples,
        explicitSuccesses,
        explicitChecksum
    );

    writefln(
        "transform_allocated_ratio compiler=%s public_over_explicit=%.6f",
        compilerName(),
        ratioMedian
    );
}
