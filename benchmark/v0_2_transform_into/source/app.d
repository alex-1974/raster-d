module app;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;


private enum size_t warmups = 4;
private enum size_t samples = 16;


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPaddingElements,
    ref RasterLease!float lease
)
@system
{
    const rowElements = width + rowPaddingElements;

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

    auto typed =
        (cast(float*) memory)[0 .. physicalElements];

    foreach (i; 0 .. typed.length)
    {
        typed[i] =
            cast(float)(
                cast(int)(i % 251)
                - 125
            )
            * 0.03125f;
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            byteLength,
            resource
        )
    )
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(rowElements * float.sizeof),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    const result =
        tryImportOwnedRaster!float(
            resource,
            layouts[],
            Region2D(0, 0, width, height),
            lease
        );

    return result.ok;
}


private float pointTransform(float value)
@safe
pure
nothrow
@nogc
{
    return value * 1.0009765625f + 0.25f;
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


private long median(long[samples] values)
{
    sort(values[]);
    return (
        values[samples / 2 - 1]
        + values[samples / 2]
    ) / 2;
}


private long timeLegacy(
    scope RasterView!float source,
    scope ref WritableRasterView!float target,
    size_t iterations
)
@safe
{
    RasterTransformError error;

    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        require(
            tryTransformRasterPlane!pointTransform(
                source,
                0,
                target,
                0,
                error
            ),
            "legacy transform failed"
        );
    }

    return (
        MonoTime.currTime
        - start
    ).total!"nsecs";
}


private long timeTransformInto(
    scope RasterView!float source,
    scope ref WritableRasterView!float target,
    size_t iterations
)
@safe
{
    RasterTransformError error;

    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        require(
            source.transformInto!pointTransform(
                0,
                target,
                0,
                error
            ),
            "transformInto failed"
        );
    }

    return (
        MonoTime.currTime
        - start
    ).total!"nsecs";
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
        : 16;

    RasterLease!float sourceLease;
    RasterLease!float legacyTargetLease;
    RasterLease!float currentTargetLease;

    require(
        makeFloatLease(width, height, 32, sourceLease),
        "source lease construction failed"
    );

    require(
        makeFloatLease(width, height, 32, legacyTargetLease),
        "legacy target lease construction failed"
    );

    require(
        makeFloatLease(width, height, 32, currentTargetLease),
        "transformInto target lease construction failed"
    );

    scope auto source = sourceLease.view();

    bool legacyWritableOk;
    bool currentWritableOk;

    scope auto legacyTarget =
        legacyTargetLease.tryWritableView(
            legacyWritableOk
        );

    scope auto currentTarget =
        currentTargetLease.tryWritableView(
            currentWritableOk
        );

    require(
        legacyWritableOk && currentWritableOk,
        "writable view construction failed"
    );

    /*
     * Warm both call surfaces before timed work. Alternate order so no API is
     * systematically the first or second hot consumer.
     */
    foreach (warmup; 0 .. warmups)
    {
        if ((warmup & 1) == 0)
        {
            timeLegacy(source, legacyTarget, 1);
            timeTransformInto(source, currentTarget, 1);
        }
        else
        {
            timeTransformInto(source, currentTarget, 1);
            timeLegacy(source, legacyTarget, 1);
        }
    }

    long[samples] legacyTimes;
    long[samples] currentTimes;

    /*
     * Pair the two measurements inside each sample and rotate order on every
     * sample. This removes the systematic "all legacy first, all new second"
     * thermal/frequency bias of the first qualification harness.
     */
    foreach (sample; 0 .. samples)
    {
        if ((sample & 1) == 0)
        {
            legacyTimes[sample] =
                timeLegacy(
                    source,
                    legacyTarget,
                    iterations
                );

            currentTimes[sample] =
                timeTransformInto(
                    source,
                    currentTarget,
                    iterations
                );
        }
        else
        {
            currentTimes[sample] =
                timeTransformInto(
                    source,
                    currentTarget,
                    iterations
                );

            legacyTimes[sample] =
                timeLegacy(
                    source,
                    legacyTarget,
                    iterations
                );
        }
    }

    const legacyChecksum =
        checksumFloat(
            legacyTargetLease.view()
        );

    const currentChecksum =
        checksumFloat(
            currentTargetLease.view()
        );

    require(
        legacyChecksum == currentChecksum,
        "legacy/new checksum mismatch"
    );

    const legacyMedian =
        median(legacyTimes);

    const currentMedian =
        median(currentTimes);

    const pixels =
        cast(double)(
            width
            * height
            * iterations
        );

    writefln(
        "transform_into_benchmark compiler=%s api=legacy width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        samples,
        legacyMedian,
        cast(double) legacyMedian / pixels,
        legacyChecksum
    );

    writefln(
        "transform_into_benchmark compiler=%s api=transformInto width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        samples,
        currentMedian,
        cast(double) currentMedian / pixels,
        currentChecksum
    );

    writefln(
        "transform_into_ratio compiler=%s legacy_over_new=%.6f",
        compilerName(),
        cast(double) legacyMedian
            / cast(double) currentMedian
    );
}
