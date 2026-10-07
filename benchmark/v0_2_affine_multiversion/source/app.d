module raster.benchmark_affine_multiversion;

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
    require(
        logicalWidth <= (size_t.max - rowPadding) / sampleStride,
        "row overflow"
    );

    const rowElements =
        logicalWidth * sampleStride + rowPadding;

    require(
        height == 0 || rowElements <= size_t.max / height,
        "buffer overflow"
    );

    const count = rowElements * height;

    require(
        count <= size_t.max / float.sizeof,
        "byte-size overflow"
    );

    auto memory =
        cast(float*) malloc(count * float.sizeof);

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
                        cast(int)(
                            (y * 131 + x * 17 + 23) % 509
                        )
                        - 254
                    )
                    * 0.015625f;
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
            base
            + cast(ptrdiff_t) y * rowStride;

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

            *destinationSample =
                weighted5x3(neighbourhood);

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

            *destinationSample =
                weighted5x3(neighbourhood);

            sourceWindow += SourceSampleStride;
            destinationSample += DestinationSampleStride;
        }

        sourceOutputRow += sourceRowStride;
        destinationRow += destinationRowStride;
    }
}


private void dispatchDestination(
    ptrdiff_t SourceSampleStride
)(
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
    final switch (destinationSampleStride)
    {
        case 1:
            affineStatic!(SourceSampleStride, 1)(
                sourceBase,
                sourceRowStride,
                width,
                height,
                destinationBase,
                destinationRowStride
            );
            return;

        case 2:
            affineStatic!(SourceSampleStride, 2)(
                sourceBase,
                sourceRowStride,
                width,
                height,
                destinationBase,
                destinationRowStride
            );
            return;

        case 3:
            affineStatic!(SourceSampleStride, 3)(
                sourceBase,
                sourceRowStride,
                width,
                height,
                destinationBase,
                destinationRowStride
            );
            return;

        case 4:
            affineStatic!(SourceSampleStride, 4)(
                sourceBase,
                sourceRowStride,
                width,
                height,
                destinationBase,
                destinationRowStride
            );
            return;

        default:
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
            return;
    }
}


pragma(inline, false)
private void affineDispatch(
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
    final switch (sourceSampleStride)
    {
        case 1:
            dispatchDestination!1(
                sourceBase,
                sourceRowStride,
                sourceSampleStride,
                width,
                height,
                destinationBase,
                destinationRowStride,
                destinationSampleStride
            );
            return;

        case 2:
            dispatchDestination!2(
                sourceBase,
                sourceRowStride,
                sourceSampleStride,
                width,
                height,
                destinationBase,
                destinationRowStride,
                destinationSampleStride
            );
            return;

        case 3:
            dispatchDestination!3(
                sourceBase,
                sourceRowStride,
                sourceSampleStride,
                width,
                height,
                destinationBase,
                destinationRowStride,
                destinationSampleStride
            );
            return;

        case 4:
            dispatchDestination!4(
                sourceBase,
                sourceRowStride,
                sourceSampleStride,
                width,
                height,
                destinationBase,
                destinationRowStride,
                destinationSampleStride
            );
            return;

        default:
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
            return;
    }
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


private long timeRuntime(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sampleStride,
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
        affineRuntime(
            sourceBase,
            sourceRowStride,
            sampleStride,
            width,
            height,
            destinationBase,
            destinationRowStride,
            sampleStride
        );

    return (
        MonoTime.currTime - start
    ).total!"nsecs";
}


private long timeDispatch(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sampleStride,
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
        affineDispatch(
            sourceBase,
            sourceRowStride,
            sampleStride,
            width,
            height,
            destinationBase,
            destinationRowStride,
            sampleStride
        );

    return (
        MonoTime.currTime - start
    ).total!"nsecs";
}


private long timeStatic(
    ptrdiff_t SampleStride
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
        affineStatic!(SampleStride, SampleStride)(
            sourceBase,
            sourceRowStride,
            width,
            height,
            destinationBase,
            destinationRowStride
        );

    return (
        MonoTime.currTime - start
    ).total!"nsecs";
}


private void emit(
    string path,
    ptrdiff_t sampleStride,
    size_t width,
    size_t height,
    size_t iterations,
    long medianNs,
    ulong resultChecksum
)
{
    const logicalSamples =
        cast(double)(
            width * height * iterations
        );

    writefln(
        "affine_multiversion compiler=%s path=%s stride=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
        compilerName(),
        path,
        sampleStride,
        width,
        height,
        iterations,
        samples,
        medianNs,
        cast(double) medianNs / logicalSamples,
        resultChecksum
    );
}


private void runStride(
    ptrdiff_t SampleStride
)(
    size_t width,
    size_t height,
    size_t iterations,
    ref long[samples] runtimeTimes,
    ref long[samples] dispatchTimes,
    ref long[samples] staticTimes,
    out ulong resultChecksum
)
@system
{
    enum sourceHaloX = 4;
    enum sourceHaloY = 2;

    auto source =
        makeBuffer(
            width + sourceHaloX,
            height + sourceHaloY,
            SampleStride,
            32,
            true
        );

    auto destinationRuntime =
        makeBuffer(
            width,
            height,
            SampleStride,
            0,
            false
        );

    auto destinationDispatch =
        makeBuffer(
            width,
            height,
            SampleStride,
            0,
            false
        );

    auto destinationStatic =
        makeBuffer(
            width,
            height,
            SampleStride,
            0,
            false
        );

    const sourceRowStride =
        cast(ptrdiff_t)(
            (width + sourceHaloX)
            * SampleStride
            + 32
        );

    const destinationRowStride =
        cast(ptrdiff_t)(
            width * SampleStride
        );

    affineStatic!(SampleStride, SampleStride)(
        source.data,
        sourceRowStride,
        width,
        height,
        destinationStatic.data,
        destinationRowStride
    );

    resultChecksum =
        checksum(
            destinationStatic.data,
            destinationRowStride,
            SampleStride,
            width,
            height
        );

    affineRuntime(
        source.data,
        sourceRowStride,
        SampleStride,
        width,
        height,
        destinationRuntime.data,
        destinationRowStride,
        SampleStride
    );

    require(
        checksum(
            destinationRuntime.data,
            destinationRowStride,
            SampleStride,
            width,
            height
        ) == resultChecksum,
        "runtime semantic mismatch"
    );

    affineDispatch(
        source.data,
        sourceRowStride,
        SampleStride,
        width,
        height,
        destinationDispatch.data,
        destinationRowStride,
        SampleStride
    );

    require(
        checksum(
            destinationDispatch.data,
            destinationRowStride,
            SampleStride,
            width,
            height
        ) == resultChecksum,
        "dispatch semantic mismatch"
    );

    foreach (_; 0 .. warmups)
    {
        timeRuntime(
            source.data,
            sourceRowStride,
            SampleStride,
            width,
            height,
            destinationRuntime.data,
            destinationRowStride,
            1
        );

        timeDispatch(
            source.data,
            sourceRowStride,
            SampleStride,
            width,
            height,
            destinationDispatch.data,
            destinationRowStride,
            1
        );

        timeStatic!SampleStride(
            source.data,
            sourceRowStride,
            width,
            height,
            destinationStatic.data,
            destinationRowStride,
            1
        );
    }

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 3)
        {
            case 0:
                runtimeTimes[sample] =
                    timeRuntime(
                        source.data,
                        sourceRowStride,
                        SampleStride,
                        width,
                        height,
                        destinationRuntime.data,
                        destinationRowStride,
                        iterations
                    );

                dispatchTimes[sample] =
                    timeDispatch(
                        source.data,
                        sourceRowStride,
                        SampleStride,
                        width,
                        height,
                        destinationDispatch.data,
                        destinationRowStride,
                        iterations
                    );

                staticTimes[sample] =
                    timeStatic!SampleStride(
                        source.data,
                        sourceRowStride,
                        width,
                        height,
                        destinationStatic.data,
                        destinationRowStride,
                        iterations
                    );
                break;

            case 1:
                dispatchTimes[sample] =
                    timeDispatch(
                        source.data,
                        sourceRowStride,
                        SampleStride,
                        width,
                        height,
                        destinationDispatch.data,
                        destinationRowStride,
                        iterations
                    );

                staticTimes[sample] =
                    timeStatic!SampleStride(
                        source.data,
                        sourceRowStride,
                        width,
                        height,
                        destinationStatic.data,
                        destinationRowStride,
                        iterations
                    );

                runtimeTimes[sample] =
                    timeRuntime(
                        source.data,
                        sourceRowStride,
                        SampleStride,
                        width,
                        height,
                        destinationRuntime.data,
                        destinationRowStride,
                        iterations
                    );
                break;

            case 2:
                staticTimes[sample] =
                    timeStatic!SampleStride(
                        source.data,
                        sourceRowStride,
                        width,
                        height,
                        destinationStatic.data,
                        destinationRowStride,
                        iterations
                    );

                runtimeTimes[sample] =
                    timeRuntime(
                        source.data,
                        sourceRowStride,
                        SampleStride,
                        width,
                        height,
                        destinationRuntime.data,
                        destinationRowStride,
                        iterations
                    );

                dispatchTimes[sample] =
                    timeDispatch(
                        source.data,
                        sourceRowStride,
                        SampleStride,
                        width,
                        height,
                        destinationDispatch.data,
                        destinationRowStride,
                        iterations
                    );
                break;
        }
    }
}


void main(string[] args)
@system
{
    const width =
        args.length >= 2
        ? args[1].to!size_t
        : 1024;

    const height =
        args.length >= 3
        ? args[2].to!size_t
        : 512;

    const iterations =
        args.length >= 4
        ? args[3].to!size_t
        : 8;

    long[samples] runtime2;
    long[samples] dispatch2;
    long[samples] static2;
    ulong checksum2;

    runStride!2(
        width,
        height,
        iterations,
        runtime2,
        dispatch2,
        static2,
        checksum2
    );

    long[samples] runtime3;
    long[samples] dispatch3;
    long[samples] static3;
    ulong checksum3;

    runStride!3(
        width,
        height,
        iterations,
        runtime3,
        dispatch3,
        static3,
        checksum3
    );

    long[samples] runtime4;
    long[samples] dispatch4;
    long[samples] static4;
    ulong checksum4;

    runStride!4(
        width,
        height,
        iterations,
        runtime4,
        dispatch4,
        static4,
        checksum4
    );

    require(
        checksum2 == checksum3
        && checksum2 == checksum4,
        "logical checksum mismatch across strides"
    );

    const runtime2Median = median(runtime2);
    const dispatch2Median = median(dispatch2);
    const static2Median = median(static2);

    const runtime3Median = median(runtime3);
    const dispatch3Median = median(dispatch3);
    const static3Median = median(static3);

    const runtime4Median = median(runtime4);
    const dispatch4Median = median(dispatch4);
    const static4Median = median(static4);

    emit("runtime", 2, width, height, iterations, runtime2Median, checksum2);
    emit("dispatch", 2, width, height, iterations, dispatch2Median, checksum2);
    emit("static", 2, width, height, iterations, static2Median, checksum2);

    emit("runtime", 3, width, height, iterations, runtime3Median, checksum3);
    emit("dispatch", 3, width, height, iterations, dispatch3Median, checksum3);
    emit("static", 3, width, height, iterations, static3Median, checksum3);

    emit("runtime", 4, width, height, iterations, runtime4Median, checksum4);
    emit("dispatch", 4, width, height, iterations, dispatch4Median, checksum4);
    emit("static", 4, width, height, iterations, static4Median, checksum4);

    writefln(
        "affine_multiversion_ratio compiler=%s stride=2 runtime_over_static=%.6f dispatch_over_static=%.6f dispatch_over_runtime=%.6f",
        compilerName(),
        cast(double) runtime2Median / cast(double) static2Median,
        cast(double) dispatch2Median / cast(double) static2Median,
        cast(double) dispatch2Median / cast(double) runtime2Median
    );

    writefln(
        "affine_multiversion_ratio compiler=%s stride=3 runtime_over_static=%.6f dispatch_over_static=%.6f dispatch_over_runtime=%.6f",
        compilerName(),
        cast(double) runtime3Median / cast(double) static3Median,
        cast(double) dispatch3Median / cast(double) static3Median,
        cast(double) dispatch3Median / cast(double) runtime3Median
    );

    writefln(
        "affine_multiversion_ratio compiler=%s stride=4 runtime_over_static=%.6f dispatch_over_static=%.6f dispatch_over_runtime=%.6f",
        compilerName(),
        cast(double) runtime4Median / cast(double) static4Median,
        cast(double) dispatch4Median / cast(double) static4Median,
        cast(double) dispatch4Median / cast(double) runtime4Median
    );
}
