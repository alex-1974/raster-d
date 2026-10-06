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
    const rowElements =
        width + rowPaddingElements;

    if (
        width == 0
        || height == 0
        || rowElements < width
        || rowElements > size_t.max / height
    )
        return false;

    const physicalElements =
        rowElements * height;

    if (
        physicalElements
        > size_t.max / float.sizeof
    )
        return false;

    const byteLength =
        physicalElements * float.sizeof;

    void* memory =
        malloc(byteLength);

    if (memory is null)
        return false;

    auto typed =
        (cast(float*) memory)[0 .. physicalElements];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            typed[y * rowElements + x] =
                cast(float)(
                    cast(int)(
                        (y * 131 + x * 17) % 251
                    )
                    - 125
                )
                * 0.03125f;
        }
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
            cast(ptrdiff_t)(
                rowElements * float.sizeof
            ),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    const result =
        tryImportOwnedRaster!float(
            resource,
            layouts[],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );

    return result.ok;
}


private ulong doubleBits(double value)
@safe
pure
nothrow
@nogc
{
    union Bits
    {
        double value;
        ulong bits;
    }

    Bits bits;
    bits.value = value;

    return bits.bits;
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
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;

    const start =
        MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        double value;

        require(
            source.trySumFloatToDouble(
                0,
                value
            ),
            "legacy strict sum failed"
        );

        checksum ^=
            doubleBits(value)
            + cast(ulong) i;
    }

    return (
        MonoTime.currTime
        - start
    ).total!"nsecs";
}


private long timeGeneric(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;

    const start =
        MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const result =
            source.sum!double(
                0
            );

        require(
            result.ok,
            "generic strict sum failed"
        );

        checksum ^=
            doubleBits(result.value)
            + cast(ulong) i;
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
        : 32;

    RasterLease!float lease;

    require(
        makeFloatLease(
            width,
            height,
            32,
            lease
        ),
        "source lease construction failed"
    );

    scope auto source =
        lease.view();

    double legacyValue;

    require(
        source.trySumFloatToDouble(
            0,
            legacyValue
        ),
        "legacy qualification sum failed"
    );

    const genericValue =
        source.sum!double(
            0
        );

    require(
        genericValue.ok,
        "generic qualification sum failed"
    );

    require(
        doubleBits(legacyValue)
        == doubleBits(genericValue.value),
        "legacy/generic result mismatch"
    );

    foreach (warmup; 0 .. warmups)
    {
        ulong checksum;

        if ((warmup & 1) == 0)
        {
            timeLegacy(
                source,
                1,
                checksum
            );

            timeGeneric(
                source,
                1,
                checksum
            );
        }
        else
        {
            timeGeneric(
                source,
                1,
                checksum
            );

            timeLegacy(
                source,
                1,
                checksum
            );
        }
    }

    long[samples] legacyTimes;
    long[samples] genericTimes;

    ulong legacyChecksum;
    ulong genericChecksum;

    foreach (sample; 0 .. samples)
    {
        ulong firstChecksum;
        ulong secondChecksum;

        if ((sample & 1) == 0)
        {
            legacyTimes[sample] =
                timeLegacy(
                    source,
                    iterations,
                    firstChecksum
                );

            genericTimes[sample] =
                timeGeneric(
                    source,
                    iterations,
                    secondChecksum
                );

            legacyChecksum ^= firstChecksum;
            genericChecksum ^= secondChecksum;
        }
        else
        {
            genericTimes[sample] =
                timeGeneric(
                    source,
                    iterations,
                    firstChecksum
                );

            legacyTimes[sample] =
                timeLegacy(
                    source,
                    iterations,
                    secondChecksum
                );

            genericChecksum ^= firstChecksum;
            legacyChecksum ^= secondChecksum;
        }
    }

    require(
        legacyChecksum
        == genericChecksum,
        "legacy/generic timed checksum mismatch"
    );

    const logicalSamples =
        cast(double)(
            width
            * height
            * iterations
        );

    const legacyMedian =
        median(legacyTimes);

    const genericMedian =
        median(genericTimes);

    writefln(
        "sum_benchmark compiler=%s api=legacy width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f result_bits=%016x checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        samples,
        legacyMedian,
        cast(double) legacyMedian
            / logicalSamples,
        doubleBits(legacyValue),
        legacyChecksum
    );

    writefln(
        "sum_benchmark compiler=%s api=generic width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f result_bits=%016x checksum=%016x",
        compilerName(),
        width,
        height,
        iterations,
        samples,
        genericMedian,
        cast(double) genericMedian
            / logicalSamples,
        doubleBits(genericValue.value),
        genericChecksum
    );

    writefln(
        "sum_ratio compiler=%s legacy_over_generic=%.6f",
        compilerName(),
        cast(double) legacyMedian
            / cast(double) genericMedian
    );
}
