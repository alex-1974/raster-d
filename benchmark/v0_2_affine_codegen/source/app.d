module raster.benchmark_affine_codegen;

import core.stdc.stdlib : free, malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;


private enum size_t warmups = 6;
private enum size_t samples = 18;


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private float weighted5x3(ref const(float)[15] values)
@safe pure nothrow @nogc
{
    float total = 0.0f;

    static foreach (i; 0 .. 15)
        total += values[i] * cast(float)(i + 1) * 0.015625f;

    return total;
}


private struct Buffer
{
    float* data;
    size_t count;

    ~this()
    {
        if (data !is null)
            free(data);
    }

    @disable this(this);
}


private Buffer makeBuffer(
    size_t logicalWidth,
    size_t height,
    size_t sampleStride,
    size_t rowPadding,
    bool sourcePattern
)
@system
{
    require(sampleStride != 0, "zero sample stride");

    const rowElements =
        logicalWidth * sampleStride + rowPadding;

    require(
        rowElements >= logicalWidth * sampleStride,
        "row overflow"
    );

    const count = rowElements * height;
    require(count / height == rowElements, "buffer overflow");

    auto memory = cast(float*) malloc(count * float.sizeof);
    require(memory !is null, "malloc failed");

    foreach (i; 0 .. count)
        memory[i] = -9999.0f;

    if (sourcePattern)
    {
        foreach (y; 0 .. height)
        {
            foreach (x; 0 .. logicalWidth)
            {
                memory[
                    y * rowElements
                    + x * sampleStride
                ] =
                    cast(float)(
                        cast(int)((y * 131 + x * 17 + 23) % 509)
                        - 254
                    ) * 0.015625f;
            }
        }
    }

    Buffer result;
    result.data = memory;
    result.count = count;
    return result;
}


private ulong checksum(
    scope const(float)* base,
    ptrdiff_t rowStride,
    ptrdiff_t sampleStride,
    size_t width,
    size_t height
)
@trusted
{
    ulong hash = 1469598103934665603UL;

    foreach (y; 0 .. height)
    {
        auto sample =
            base + cast(ptrdiff_t) y * rowStride;

        foreach (x; 0 .. width)
        {
            union Bits
            {
                float value;
                uint bits;
            }

            Bits bits;
            bits.value = *sample;

            hash ^= bits.bits;
            hash *= 1099511628211UL;

            sample += sampleStride;
        }
    }

    return hash;
}


pragma(inline, false)
private void canonicalStatic1(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride
)
@trusted pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t) y * destinationRowStride;

        foreach (x; 0 .. width)
        {
            float[15] neighbourhood;
            size_t index;

            foreach (dy; 0 .. 3)
            {
                const sourceRow =
                    sourceBase
                    + cast(ptrdiff_t)(y + dy) * sourceRowStride
                    + cast(ptrdiff_t) x;

                static foreach (dx; 0 .. 5)
                    neighbourhood[index++] = sourceRow[dx];
            }

            destinationRow[x] = weighted5x3(neighbourhood);
        }
    }
}


pragma(inline, false)
private void affineRuntime(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sourceSampleStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride,
    ptrdiff_t destinationSampleStride
)
@trusted pure nothrow @nogc
{
    auto sourceOutputRow = sourceBase;
    auto destinationRow = destinationBase;

    foreach (y; 0 .. height)
    {
        auto sourceWindow = sourceOutputRow;
        auto destinationSample = destinationRow;

        foreach (x; 0 .. width)
        {
            float[15] neighbourhood;
            size_t index;

            auto sourceWindowRow = sourceWindow;

            foreach (dy; 0 .. 3)
            {
                auto sourceSample = sourceWindowRow;

                static foreach (dx; 0 .. 5)
                {
                    neighbourhood[index++] = *sourceSample;
                    sourceSample += sourceSampleStride;
                }

                sourceWindowRow += sourceRowStride;
            }

            *destinationSample = weighted5x3(neighbourhood);

            sourceWindow += sourceSampleStride;
            destinationSample += destinationSampleStride;
        }

        sourceOutputRow += sourceRowStride;
        destinationRow += destinationRowStride;
    }
}


pragma(inline, false)
private void affineStatic(
    ptrdiff_t SourceSampleStride,
    ptrdiff_t DestinationSampleStride
)(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride
)
@trusted pure nothrow @nogc
{
    auto sourceOutputRow = sourceBase;
    auto destinationRow = destinationBase;

    foreach (y; 0 .. height)
    {
        auto sourceWindow = sourceOutputRow;
        auto destinationSample = destinationRow;

        foreach (x; 0 .. width)
        {
            float[15] neighbourhood;
            size_t index;

            auto sourceWindowRow = sourceWindow;

            foreach (dy; 0 .. 3)
            {
                auto sourceSample = sourceWindowRow;

                static foreach (dx; 0 .. 5)
                {
                    neighbourhood[index++] = *sourceSample;
                    sourceSample += SourceSampleStride;
                }

                sourceWindowRow += sourceRowStride;
            }

            *destinationSample = weighted5x3(neighbourhood);

            sourceWindow += SourceSampleStride;
            destinationSample += DestinationSampleStride;
        }

        sourceOutputRow += sourceRowStride;
        destinationRow += destinationRowStride;
    }
}


private long median(long[samples] values)
{
    sort(values[]);
    return (values[samples / 2 - 1] + values[samples / 2]) / 2;
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


private long timeCanonical(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        canonicalStatic1(
            sourceBase,
            sourceRowStride,
            width,
            height,
            destinationBase,
            destinationRowStride
        );

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeRuntime(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sourceSampleStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride,
    ptrdiff_t destinationSampleStride,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        affineRuntime(
            sourceBase,
            sourceRowStride,
            sourceSampleStride,
            width,
            height,
            destinationBase,
            destinationRowStride,
            destinationSampleStride
        );

    return (MonoTime.currTime - start).total!"nsecs";
}


private long timeStatic(
    ptrdiff_t SourceSampleStride,
    ptrdiff_t DestinationSampleStride
)(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        affineStatic!(
            SourceSampleStride,
            DestinationSampleStride
        )(
            sourceBase,
            sourceRowStride,
            width,
            height,
            destinationBase,
            destinationRowStride
        );

    return (MonoTime.currTime - start).total!"nsecs";
}


private void emit(
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
        "affine_codegen compiler=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
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
    const width = args.length >= 2 ? args[1].to!size_t : 1024;
    const height = args.length >= 3 ? args[2].to!size_t : 512;
    const iterations = args.length >= 4 ? args[3].to!size_t : 8;

    enum sourceHaloX = 4;
    enum sourceHaloY = 2;

    auto source1 =
        makeBuffer(
            width + sourceHaloX,
            height + sourceHaloY,
            1,
            32,
            true
        );

    auto source2 =
        makeBuffer(
            width + sourceHaloX,
            height + sourceHaloY,
            2,
            32,
            true
        );

    auto destination1A = makeBuffer(width, height, 1, 0, false);
    auto destination2A = makeBuffer(width, height, 2, 0, false);
    auto destination2B = makeBuffer(width, height, 2, 0, false);
    auto destination1B = makeBuffer(width, height, 1, 0, false);
    auto destination2C = makeBuffer(width, height, 2, 0, false);

    const source1RowStride =
        cast(ptrdiff_t)((width + sourceHaloX) + 32);

    const source2RowStride =
        cast(ptrdiff_t)((width + sourceHaloX) * 2 + 32);

    const destination1RowStride = cast(ptrdiff_t) width;
    const destination2RowStride = cast(ptrdiff_t)(width * 2);

    canonicalStatic1(
        source1.data,
        source1RowStride,
        width,
        height,
        destination1A.data,
        destination1RowStride
    );

    const expected =
        checksum(
            destination1A.data,
            destination1RowStride,
            1,
            width,
            height
        );

    affineRuntime(
        source2.data,
        source2RowStride,
        2,
        width,
        height,
        destination2A.data,
        destination2RowStride,
        2
    );

    require(
        checksum(destination2A.data, destination2RowStride, 2, width, height)
            == expected,
        "runtime s2/d2 semantic mismatch"
    );

    affineStatic!(2, 2)(
        source2.data,
        source2RowStride,
        width,
        height,
        destination2B.data,
        destination2RowStride
    );

    require(
        checksum(destination2B.data, destination2RowStride, 2, width, height)
            == expected,
        "static s2/d2 semantic mismatch"
    );

    affineRuntime(
        source2.data,
        source2RowStride,
        2,
        width,
        height,
        destination1B.data,
        destination1RowStride,
        1
    );

    require(
        checksum(destination1B.data, destination1RowStride, 1, width, height)
            == expected,
        "runtime s2/d1 semantic mismatch"
    );

    affineRuntime(
        source1.data,
        source1RowStride,
        1,
        width,
        height,
        destination2C.data,
        destination2RowStride,
        2
    );

    require(
        checksum(destination2C.data, destination2RowStride, 2, width, height)
            == expected,
        "runtime s1/d2 semantic mismatch"
    );

    foreach (_; 0 .. warmups)
    {
        timeCanonical(
            source1.data,
            source1RowStride,
            width,
            height,
            destination1A.data,
            destination1RowStride,
            1
        );

        timeRuntime(
            source2.data,
            source2RowStride,
            2,
            width,
            height,
            destination2A.data,
            destination2RowStride,
            2,
            1
        );

        timeStatic!(2, 2)(
            source2.data,
            source2RowStride,
            width,
            height,
            destination2B.data,
            destination2RowStride,
            1
        );

        timeRuntime(
            source2.data,
            source2RowStride,
            2,
            width,
            height,
            destination1B.data,
            destination1RowStride,
            1,
            1
        );

        timeRuntime(
            source1.data,
            source1RowStride,
            1,
            width,
            height,
            destination2C.data,
            destination2RowStride,
            2,
            1
        );
    }

    long[samples] canonicalTimes;
    long[samples] runtime22Times;
    long[samples] static22Times;
    long[samples] runtime21Times;
    long[samples] runtime12Times;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 5)
        {
            case 0:
                canonicalTimes[sample] = timeCanonical(source1.data, source1RowStride, width, height, destination1A.data, destination1RowStride, iterations);
                runtime22Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination2A.data, destination2RowStride, 2, iterations);
                static22Times[sample] = timeStatic!(2, 2)(source2.data, source2RowStride, width, height, destination2B.data, destination2RowStride, iterations);
                runtime21Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination1B.data, destination1RowStride, 1, iterations);
                runtime12Times[sample] = timeRuntime(source1.data, source1RowStride, 1, width, height, destination2C.data, destination2RowStride, 2, iterations);
                break;

            case 1:
                runtime22Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination2A.data, destination2RowStride, 2, iterations);
                static22Times[sample] = timeStatic!(2, 2)(source2.data, source2RowStride, width, height, destination2B.data, destination2RowStride, iterations);
                runtime21Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination1B.data, destination1RowStride, 1, iterations);
                runtime12Times[sample] = timeRuntime(source1.data, source1RowStride, 1, width, height, destination2C.data, destination2RowStride, 2, iterations);
                canonicalTimes[sample] = timeCanonical(source1.data, source1RowStride, width, height, destination1A.data, destination1RowStride, iterations);
                break;

            case 2:
                static22Times[sample] = timeStatic!(2, 2)(source2.data, source2RowStride, width, height, destination2B.data, destination2RowStride, iterations);
                runtime21Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination1B.data, destination1RowStride, 1, iterations);
                runtime12Times[sample] = timeRuntime(source1.data, source1RowStride, 1, width, height, destination2C.data, destination2RowStride, 2, iterations);
                canonicalTimes[sample] = timeCanonical(source1.data, source1RowStride, width, height, destination1A.data, destination1RowStride, iterations);
                runtime22Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination2A.data, destination2RowStride, 2, iterations);
                break;

            case 3:
                runtime21Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination1B.data, destination1RowStride, 1, iterations);
                runtime12Times[sample] = timeRuntime(source1.data, source1RowStride, 1, width, height, destination2C.data, destination2RowStride, 2, iterations);
                canonicalTimes[sample] = timeCanonical(source1.data, source1RowStride, width, height, destination1A.data, destination1RowStride, iterations);
                runtime22Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination2A.data, destination2RowStride, 2, iterations);
                static22Times[sample] = timeStatic!(2, 2)(source2.data, source2RowStride, width, height, destination2B.data, destination2RowStride, iterations);
                break;

            case 4:
                runtime12Times[sample] = timeRuntime(source1.data, source1RowStride, 1, width, height, destination2C.data, destination2RowStride, 2, iterations);
                canonicalTimes[sample] = timeCanonical(source1.data, source1RowStride, width, height, destination1A.data, destination1RowStride, iterations);
                runtime22Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination2A.data, destination2RowStride, 2, iterations);
                static22Times[sample] = timeStatic!(2, 2)(source2.data, source2RowStride, width, height, destination2B.data, destination2RowStride, iterations);
                runtime21Times[sample] = timeRuntime(source2.data, source2RowStride, 2, width, height, destination1B.data, destination1RowStride, 1, iterations);
                break;
        }
    }

    const canonicalMedian = median(canonicalTimes);
    const runtime22Median = median(runtime22Times);
    const static22Median = median(static22Times);
    const runtime21Median = median(runtime21Times);
    const runtime12Median = median(runtime12Times);

    emit("canonical_static1", width, height, iterations, canonicalMedian, expected);
    emit("affine_runtime_s2_d2", width, height, iterations, runtime22Median, expected);
    emit("affine_static_s2_d2", width, height, iterations, static22Median, expected);
    emit("affine_runtime_s2_d1", width, height, iterations, runtime21Median, expected);
    emit("affine_runtime_s1_d2", width, height, iterations, runtime12Median, expected);

    writefln(
        "affine_codegen_ratio compiler=%s runtime22_over_canonical=%.6f static22_over_canonical=%.6f runtime22_over_static22=%.6f runtime21_over_canonical=%.6f runtime12_over_canonical=%.6f",
        compilerName(),
        cast(double) runtime22Median / cast(double) canonicalMedian,
        cast(double) static22Median / cast(double) canonicalMedian,
        cast(double) runtime22Median / cast(double) static22Median,
        cast(double) runtime21Median / cast(double) canonicalMedian,
        cast(double) runtime12Median / cast(double) canonicalMedian
    );
}
