module raster.benchmark_reduction_family;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;

import raster.internal.extrema :
    ExtremaMode,
    ExtremaStatus,
    executeExtrema;


private enum size_t warmups = 6;
private enum size_t samples = 18;


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private bool makeFloatLease(
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
                    cast(int)((y * 977 + x * 131 + 17) % 8191)
                    - 4095
                )
                * 0.001953125f;
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


private ulong floatBits(float value)
@safe
pure
nothrow
@nogc
{
    union Bits
    {
        float value;
        uint bits;
    }

    Bits bits;
    bits.value = value;
    return bits.bits;
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
    return (values[samples / 2 - 1] + values[samples / 2]) / 2;
}


private long timePublicMin(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const result = source.min(0);
        require(result.ok, "public min failed");
        checksum ^= floatBits(result.value) + cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeSemanticMin(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const result =
            executeExtrema!(ExtremaMode.minimum, float)(source, 0);

        require(result.status == ExtremaStatus.none, "semantic min failed");
        checksum ^= floatBits(result.minimum) + cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timePublicMax(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const result = source.max(0);
        require(result.ok, "public max failed");
        checksum ^= floatBits(result.value) + cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeSemanticMax(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const result =
            executeExtrema!(ExtremaMode.maximum, float)(source, 0);

        require(result.status == ExtremaStatus.none, "semantic max failed");
        checksum ^= floatBits(result.maximum) + cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timePublicMinMax(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const result = source.minMax(0);
        require(result.ok, "public minMax failed");

        checksum ^=
            floatBits(result.minimum)
            ^ (floatBits(result.maximum) << 1)
            ^ cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeSemanticMinMax(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const result =
            executeExtrema!(ExtremaMode.minMax, float)(source, 0);

        require(result.status == ExtremaStatus.none, "semantic minMax failed");

        checksum ^=
            floatBits(result.minimum)
            ^ (floatBits(result.maximum) << 1)
            ^ cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timePublicMinPlusMax(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const minimum = source.min(0);
        const maximum = source.max(0);

        require(minimum.ok && maximum.ok, "public min + max failed");

        checksum ^=
            floatBits(minimum.value)
            ^ (floatBits(maximum.value) << 1)
            ^ cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timePublicMean(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const result = source.mean!(double, double)(0);
        require(result.ok, "public mean failed");
        checksum ^= doubleBits(result.value) + cast(ulong) i;
    }

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeExplicitMean(
    scope RasterView!float source,
    size_t iterations,
    out ulong checksum
)
@safe
{
    checksum = 0;
    const count = source.width * source.height;
    require(count != 0, "explicit mean requires non-empty input");

    const start = MonoTime.currTime;

    foreach (i; 0 .. iterations)
    {
        const accumulated = source.sum!double(0);
        require(accumulated.ok, "explicit mean sum failed");

        const value =
            accumulated.value / cast(double) count;

        checksum ^= doubleBits(value) + cast(ulong) i;
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
    ulong checksum
)
{
    const logicalSamples =
        cast(double)(width * height * iterations);

    writefln(
        "reduction_benchmark compiler=%s operation=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
        compilerName(),
        operation,
        path,
        width,
        height,
        iterations,
        samples,
        medianNs,
        cast(double) medianNs / logicalSamples,
        checksum
    );
}


void main(string[] args)
@system
{
    const width =
        args.length >= 2 ? args[1].to!size_t : 2048;

    const height =
        args.length >= 3 ? args[2].to!size_t : 512;

    const iterations =
        args.length >= 4 ? args[3].to!size_t : 16;

    RasterLease!float lease;

    require(
        makeFloatLease(width, height, 32, lease),
        "source construction failed"
    );

    scope auto source = lease.view();

    const pmin = source.min(0);
    const smin = executeExtrema!(ExtremaMode.minimum, float)(source, 0);
    const pmax = source.max(0);
    const smax = executeExtrema!(ExtremaMode.maximum, float)(source, 0);
    const pmm = source.minMax(0);
    const smm = executeExtrema!(ExtremaMode.minMax, float)(source, 0);
    const pmean = source.mean!(double, double)(0);
    const esum = source.sum!double(0);

    require(
        pmin.ok && smin.status == ExtremaStatus.none
        && floatBits(pmin.value) == floatBits(smin.minimum),
        "min semantic preflight mismatch"
    );

    require(
        pmax.ok && smax.status == ExtremaStatus.none
        && floatBits(pmax.value) == floatBits(smax.maximum),
        "max semantic preflight mismatch"
    );

    require(
        pmm.ok && smm.status == ExtremaStatus.none
        && floatBits(pmm.minimum) == floatBits(smm.minimum)
        && floatBits(pmm.maximum) == floatBits(smm.maximum),
        "minMax semantic preflight mismatch"
    );

    require(pmean.ok && esum.ok, "mean semantic preflight failed");

    const explicitMean =
        esum.value / cast(double)(width * height);

    require(
        doubleBits(pmean.value) == doubleBits(explicitMean),
        "mean semantic preflight mismatch"
    );

    ulong ignored;

    foreach (warmup; 0 .. warmups)
    {
        final switch (warmup % 4)
        {
            case 0:
                timePublicMin(source, 1, ignored);
                timeSemanticMin(source, 1, ignored);
                timePublicMax(source, 1, ignored);
                timeSemanticMax(source, 1, ignored);
                timePublicMinMax(source, 1, ignored);
                timeSemanticMinMax(source, 1, ignored);
                timePublicMinPlusMax(source, 1, ignored);
                timePublicMean(source, 1, ignored);
                timeExplicitMean(source, 1, ignored);
                break;

            case 1:
                timePublicMean(source, 1, ignored);
                timeExplicitMean(source, 1, ignored);
                timePublicMinMax(source, 1, ignored);
                timeSemanticMinMax(source, 1, ignored);
                timePublicMin(source, 1, ignored);
                timeSemanticMin(source, 1, ignored);
                timePublicMax(source, 1, ignored);
                timeSemanticMax(source, 1, ignored);
                timePublicMinPlusMax(source, 1, ignored);
                break;

            case 2:
                timeSemanticMax(source, 1, ignored);
                timePublicMax(source, 1, ignored);
                timePublicMinPlusMax(source, 1, ignored);
                timeSemanticMin(source, 1, ignored);
                timePublicMin(source, 1, ignored);
                timeSemanticMinMax(source, 1, ignored);
                timePublicMinMax(source, 1, ignored);
                timeExplicitMean(source, 1, ignored);
                timePublicMean(source, 1, ignored);
                break;

            case 3:
                timePublicMinPlusMax(source, 1, ignored);
                timePublicMin(source, 1, ignored);
                timePublicMax(source, 1, ignored);
                timePublicMean(source, 1, ignored);
                timeExplicitMean(source, 1, ignored);
                timeSemanticMinMax(source, 1, ignored);
                timePublicMinMax(source, 1, ignored);
                timeSemanticMax(source, 1, ignored);
                timeSemanticMin(source, 1, ignored);
                break;
        }
    }

    long[samples] pminTimes;
    long[samples] sminTimes;
    long[samples] pmaxTimes;
    long[samples] smaxTimes;
    long[samples] pmmTimes;
    long[samples] smmTimes;
    long[samples] twoPassTimes;
    long[samples] pmeanTimes;
    long[samples] emeanTimes;

    ulong pminChecksum;
    ulong sminChecksum;
    ulong pmaxChecksum;
    ulong smaxChecksum;
    ulong pmmChecksum;
    ulong smmChecksum;
    ulong twoPassChecksum;
    ulong pmeanChecksum;
    ulong emeanChecksum;

    foreach (sample; 0 .. samples)
    {
        ulong c;

        pminTimes[sample] = timePublicMin(source, iterations, c);
        pminChecksum ^= c;

        sminTimes[sample] = timeSemanticMin(source, iterations, c);
        sminChecksum ^= c;

        pmaxTimes[sample] = timePublicMax(source, iterations, c);
        pmaxChecksum ^= c;

        smaxTimes[sample] = timeSemanticMax(source, iterations, c);
        smaxChecksum ^= c;

        pmmTimes[sample] = timePublicMinMax(source, iterations, c);
        pmmChecksum ^= c;

        smmTimes[sample] = timeSemanticMinMax(source, iterations, c);
        smmChecksum ^= c;

        twoPassTimes[sample] = timePublicMinPlusMax(source, iterations, c);
        twoPassChecksum ^= c;

        pmeanTimes[sample] = timePublicMean(source, iterations, c);
        pmeanChecksum ^= c;

        emeanTimes[sample] = timeExplicitMean(source, iterations, c);
        emeanChecksum ^= c;
    }

    require(pminChecksum == sminChecksum, "min timed checksum mismatch");
    require(pmaxChecksum == smaxChecksum, "max timed checksum mismatch");
    require(pmmChecksum == smmChecksum, "minMax timed checksum mismatch");
    require(pmmChecksum == twoPassChecksum, "minMax/two-pass checksum mismatch");
    require(pmeanChecksum == emeanChecksum, "mean timed checksum mismatch");

    const pminMedian = median(pminTimes);
    const sminMedian = median(sminTimes);
    const pmaxMedian = median(pmaxTimes);
    const smaxMedian = median(smaxTimes);
    const pmmMedian = median(pmmTimes);
    const smmMedian = median(smmTimes);
    const twoPassMedian = median(twoPassTimes);
    const pmeanMedian = median(pmeanTimes);
    const emeanMedian = median(emeanTimes);

    printPath("min", "public", width, height, iterations, pminMedian, pminChecksum);
    printPath("min", "semantic", width, height, iterations, sminMedian, sminChecksum);
    printPath("max", "public", width, height, iterations, pmaxMedian, pmaxChecksum);
    printPath("max", "semantic", width, height, iterations, smaxMedian, smaxChecksum);
    printPath("minmax", "public", width, height, iterations, pmmMedian, pmmChecksum);
    printPath("minmax", "semantic", width, height, iterations, smmMedian, smmChecksum);
    printPath("minmax", "public_min_plus_max", width, height, iterations, twoPassMedian, twoPassChecksum);
    printPath("mean", "public", width, height, iterations, pmeanMedian, pmeanChecksum);
    printPath("mean", "explicit_sum_divide", width, height, iterations, emeanMedian, emeanChecksum);

    writefln(
        "reduction_ratio compiler=%s operation=min public_over_semantic=%.6f",
        compilerName(),
        cast(double) pminMedian / cast(double) sminMedian
    );

    writefln(
        "reduction_ratio compiler=%s operation=max public_over_semantic=%.6f",
        compilerName(),
        cast(double) pmaxMedian / cast(double) smaxMedian
    );

    writefln(
        "reduction_ratio compiler=%s operation=minmax public_over_semantic=%.6f two_pass_over_minmax=%.6f",
        compilerName(),
        cast(double) pmmMedian / cast(double) smmMedian,
        cast(double) twoPassMedian / cast(double) pmmMedian
    );

    writefln(
        "reduction_ratio compiler=%s operation=mean public_over_explicit=%.6f",
        compilerName(),
        cast(double) pmeanMedian / cast(double) emeanMedian
    );
}
