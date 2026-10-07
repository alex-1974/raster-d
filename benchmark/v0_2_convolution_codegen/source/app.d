module raster.benchmark_convolution_codegen;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;

import raster.internal.neighbourhood_dispatch :
    executeApprovedNeighbourhood3x3;


private enum size_t warmups = 6;
private enum size_t samples = 18;


alias Shape3x3 =
    NeighbourhoodShape!(3, 3, 1, 1);


alias FixedKernel =
    FixedConvolutionKernel!(
        Shape3x3,
        float,
         0.125f, -0.250f,  0.375f,
        -0.500f,  1.250f, -0.625f,
         0.750f, -0.875f,  0.500f
    );


private void require(bool condition, string message)
@safe
{
    if (!condition)
        throw new Exception(message);
}


private float loopKernel(
    ref const(float)[9] values
)
@safe
pure
nothrow
@nogc
{
    double total = 0.0;

    foreach (index; 0 .. 9)
    {
        const sample =
            cast(double) values[index];

        const coefficient =
            cast(double) FixedKernel.coefficients[index];

        const product =
            sample * coefficient;

        total =
            total + product;
    }

    return cast(float) total;
}


private float unrolledKernel(
    ref const(float)[9] values
)
@safe
pure
nothrow
@nogc
{
    double total = 0.0;

    total += cast(double) values[0] * cast(double)  0.125f;
    total += cast(double) values[1] * cast(double) -0.250f;
    total += cast(double) values[2] * cast(double)  0.375f;
    total += cast(double) values[3] * cast(double) -0.500f;
    total += cast(double) values[4] * cast(double)  1.250f;
    total += cast(double) values[5] * cast(double) -0.625f;
    total += cast(double) values[6] * cast(double)  0.750f;
    total += cast(double) values[7] * cast(double) -0.875f;
    total += cast(double) values[8] * cast(double)  0.500f;

    return cast(float) total;
}


private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPaddingElements,
    ref RasterLease!float lease,
    out float* base,
    out size_t rowElements
)
@system
{
    base = null;
    rowElements = width + rowPaddingElements;

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

    base =
        cast(float*) memory;

    auto typed =
        base[0 .. physicalElements];

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


private ulong checksum(
    scope const(float)* base,
    size_t width,
    size_t height,
    size_t rowElements
)
@trusted
nothrow
@nogc
{
    ulong hash =
        1469598103934665603UL;

    foreach (y; 0 .. height)
    {
        const row =
            base + y * rowElements;

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


pragma(inline, false)
private void executeDirectUnrolled(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t destinationRowElements
)
@trusted
nothrow
@nogc
{
    foreach (y; 0 .. height)
    {
        const sourceRow0 =
            sourceBase + y * sourceRowElements;

        const sourceRow1 =
            sourceRow0 + sourceRowElements;

        const sourceRow2 =
            sourceRow1 + sourceRowElements;

        auto destinationRow =
            destinationBase
            + y * destinationRowElements;

        foreach (x; 0 .. width)
        {
            double total = 0.0;

            total += cast(double) sourceRow0[x + 0] * cast(double)  0.125f;
            total += cast(double) sourceRow0[x + 1] * cast(double) -0.250f;
            total += cast(double) sourceRow0[x + 2] * cast(double)  0.375f;
            total += cast(double) sourceRow1[x + 0] * cast(double) -0.500f;
            total += cast(double) sourceRow1[x + 1] * cast(double)  1.250f;
            total += cast(double) sourceRow1[x + 2] * cast(double) -0.625f;
            total += cast(double) sourceRow2[x + 0] * cast(double)  0.750f;
            total += cast(double) sourceRow2[x + 1] * cast(double) -0.875f;
            total += cast(double) sourceRow2[x + 2] * cast(double)  0.500f;

            destinationRow[x] =
                cast(float) total;
        }
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


private long timePublicConvolution(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination,
    size_t width,
    size_t height,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterNeighbourhoodError error;

        require(
            source.convolveInto!(
                FixedKernel,
                double
            )(
                0,
                Region2D(1, 1, width, height),
                destination,
                0,
                error
            ),
            "public convolution failed"
        );

        require(
            error == RasterNeighbourhoodError.none,
            "public convolution error"
        );
    }

    return (
        MonoTime.currTime - start
    ).total!"nsecs";
}


private long timePublicNeighbourhoodLoop(
    scope RasterView!float source,
    scope ref WritableRasterView!float destination,
    size_t width,
    size_t height,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        RasterNeighbourhoodError error;

        require(
            source.applyNeighbourhoodInto!(
                Shape3x3,
                loopKernel
            )(
                0,
                Region2D(1, 1, width, height),
                destination,
                0,
                error
            ),
            "public neighbourhood loop failed"
        );

        require(
            error == RasterNeighbourhoodError.none,
            "public neighbourhood loop error"
        );
    }

    return (
        MonoTime.currTime - start
    ).total!"nsecs";
}


private long timeHotLoop(
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
    {
        executeApprovedNeighbourhood3x3!loopKernel(
            sourceBase,
            sourceRowStride,
            1,
            1,
            width,
            height,
            destinationBase,
            destinationRowStride
        );
    }

    return (
        MonoTime.currTime - start
    ).total!"nsecs";
}


private long timeHotUnrolled(
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
    {
        executeApprovedNeighbourhood3x3!unrolledKernel(
            sourceBase,
            sourceRowStride,
            1,
            1,
            width,
            height,
            destinationBase,
            destinationRowStride
        );
    }

    return (
        MonoTime.currTime - start
    ).total!"nsecs";
}


private long timeDirectUnrolled(
    scope const(float)* sourceBase,
    size_t sourceRowStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t destinationRowStride,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
    {
        executeDirectUnrolled(
            sourceBase,
            sourceRowStride,
            width,
            height,
            destinationBase,
            destinationRowStride
        );
    }

    return (
        MonoTime.currTime - start
    ).total!"nsecs";
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
    const logicalPixels =
        cast(double)(
            width * height * iterations
        );

    writefln(
        "convolution_codegen compiler=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        path,
        width,
        height,
        iterations,
        samples,
        medianNs,
        cast(double) medianNs / logicalPixels,
        resultChecksum
    );
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

    RasterLease!float sourceLease;
    float* sourceBase;
    size_t sourceRowElements;

    require(
        makeFloatLease(
            width + 2,
            height + 2,
            32,
            sourceLease,
            sourceBase,
            sourceRowElements
        ),
        "source allocation failed"
    );

    RasterLease!float publicConvolutionLease;
    float* publicConvolutionBase;
    size_t destinationRowElements;

    require(
        makeFloatLease(
            width,
            height,
            0,
            publicConvolutionLease,
            publicConvolutionBase,
            destinationRowElements
        ),
        "public convolution destination failed"
    );

    RasterLease!float publicNeighbourhoodLease;
    float* publicNeighbourhoodBase;
    size_t ignoredRowElements;

    require(
        makeFloatLease(
            width,
            height,
            0,
            publicNeighbourhoodLease,
            publicNeighbourhoodBase,
            ignoredRowElements
        ),
        "public neighbourhood destination failed"
    );

    RasterLease!float hotLoopLease;
    float* hotLoopBase;

    require(
        makeFloatLease(
            width,
            height,
            0,
            hotLoopLease,
            hotLoopBase,
            ignoredRowElements
        ),
        "hot loop destination failed"
    );

    RasterLease!float hotUnrolledLease;
    float* hotUnrolledBase;

    require(
        makeFloatLease(
            width,
            height,
            0,
            hotUnrolledLease,
            hotUnrolledBase,
            ignoredRowElements
        ),
        "hot unrolled destination failed"
    );

    RasterLease!float directLease;
    float* directBase;

    require(
        makeFloatLease(
            width,
            height,
            0,
            directLease,
            directBase,
            ignoredRowElements
        ),
        "direct destination failed"
    );

    auto source = sourceLease.view();

    bool ok;

    auto publicConvolutionDestination =
        publicConvolutionLease.tryWritableView(ok);
    require(ok, "public convolution writable view failed");

    auto publicNeighbourhoodDestination =
        publicNeighbourhoodLease.tryWritableView(ok);
    require(ok, "public neighbourhood writable view failed");

    executeDirectUnrolled(
        sourceBase,
        sourceRowElements,
        width,
        height,
        directBase,
        destinationRowElements
    );

    const expected =
        checksum(
            directBase,
            width,
            height,
            destinationRowElements
        );

    RasterNeighbourhoodError error;

    require(
        source.convolveInto!(
            FixedKernel,
            double
        )(
            0,
            Region2D(1, 1, width, height),
            publicConvolutionDestination,
            0,
            error
        ),
        "public convolution semantic preflight failed"
    );

    require(
        checksum(
            publicConvolutionBase,
            width,
            height,
            destinationRowElements
        ) == expected,
        "public convolution checksum mismatch"
    );

    require(
        source.applyNeighbourhoodInto!(
            Shape3x3,
            loopKernel
        )(
            0,
            Region2D(1, 1, width, height),
            publicNeighbourhoodDestination,
            0,
            error
        ),
        "public neighbourhood semantic preflight failed"
    );

    require(
        checksum(
            publicNeighbourhoodBase,
            width,
            height,
            destinationRowElements
        ) == expected,
        "public neighbourhood checksum mismatch"
    );

    executeApprovedNeighbourhood3x3!loopKernel(
        sourceBase,
        cast(ptrdiff_t) sourceRowElements,
        1,
        1,
        width,
        height,
        hotLoopBase,
        cast(ptrdiff_t) destinationRowElements
    );

    require(
        checksum(
            hotLoopBase,
            width,
            height,
            destinationRowElements
        ) == expected,
        "hot loop checksum mismatch"
    );

    executeApprovedNeighbourhood3x3!unrolledKernel(
        sourceBase,
        cast(ptrdiff_t) sourceRowElements,
        1,
        1,
        width,
        height,
        hotUnrolledBase,
        cast(ptrdiff_t) destinationRowElements
    );

    require(
        checksum(
            hotUnrolledBase,
            width,
            height,
            destinationRowElements
        ) == expected,
        "hot unrolled checksum mismatch"
    );

    foreach (_; 0 .. warmups)
    {
        timePublicConvolution(source, publicConvolutionDestination, width, height, 1);
        timePublicNeighbourhoodLoop(source, publicNeighbourhoodDestination, width, height, 1);
        timeHotLoop(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotLoopBase, cast(ptrdiff_t) destinationRowElements, 1);
        timeHotUnrolled(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotUnrolledBase, cast(ptrdiff_t) destinationRowElements, 1);
        timeDirectUnrolled(sourceBase, sourceRowElements, width, height, directBase, destinationRowElements, 1);
    }

    long[samples] publicConvolutionTimes;
    long[samples] publicNeighbourhoodTimes;
    long[samples] hotLoopTimes;
    long[samples] hotUnrolledTimes;
    long[samples] directTimes;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 5)
        {
            case 0:
                publicConvolutionTimes[sample] = timePublicConvolution(source, publicConvolutionDestination, width, height, iterations);
                publicNeighbourhoodTimes[sample] = timePublicNeighbourhoodLoop(source, publicNeighbourhoodDestination, width, height, iterations);
                hotLoopTimes[sample] = timeHotLoop(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotLoopBase, cast(ptrdiff_t) destinationRowElements, iterations);
                hotUnrolledTimes[sample] = timeHotUnrolled(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotUnrolledBase, cast(ptrdiff_t) destinationRowElements, iterations);
                directTimes[sample] = timeDirectUnrolled(sourceBase, sourceRowElements, width, height, directBase, destinationRowElements, iterations);
                break;

            case 1:
                publicNeighbourhoodTimes[sample] = timePublicNeighbourhoodLoop(source, publicNeighbourhoodDestination, width, height, iterations);
                hotLoopTimes[sample] = timeHotLoop(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotLoopBase, cast(ptrdiff_t) destinationRowElements, iterations);
                hotUnrolledTimes[sample] = timeHotUnrolled(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotUnrolledBase, cast(ptrdiff_t) destinationRowElements, iterations);
                directTimes[sample] = timeDirectUnrolled(sourceBase, sourceRowElements, width, height, directBase, destinationRowElements, iterations);
                publicConvolutionTimes[sample] = timePublicConvolution(source, publicConvolutionDestination, width, height, iterations);
                break;

            case 2:
                hotLoopTimes[sample] = timeHotLoop(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotLoopBase, cast(ptrdiff_t) destinationRowElements, iterations);
                hotUnrolledTimes[sample] = timeHotUnrolled(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotUnrolledBase, cast(ptrdiff_t) destinationRowElements, iterations);
                directTimes[sample] = timeDirectUnrolled(sourceBase, sourceRowElements, width, height, directBase, destinationRowElements, iterations);
                publicConvolutionTimes[sample] = timePublicConvolution(source, publicConvolutionDestination, width, height, iterations);
                publicNeighbourhoodTimes[sample] = timePublicNeighbourhoodLoop(source, publicNeighbourhoodDestination, width, height, iterations);
                break;

            case 3:
                hotUnrolledTimes[sample] = timeHotUnrolled(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotUnrolledBase, cast(ptrdiff_t) destinationRowElements, iterations);
                directTimes[sample] = timeDirectUnrolled(sourceBase, sourceRowElements, width, height, directBase, destinationRowElements, iterations);
                publicConvolutionTimes[sample] = timePublicConvolution(source, publicConvolutionDestination, width, height, iterations);
                publicNeighbourhoodTimes[sample] = timePublicNeighbourhoodLoop(source, publicNeighbourhoodDestination, width, height, iterations);
                hotLoopTimes[sample] = timeHotLoop(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotLoopBase, cast(ptrdiff_t) destinationRowElements, iterations);
                break;

            case 4:
                directTimes[sample] = timeDirectUnrolled(sourceBase, sourceRowElements, width, height, directBase, destinationRowElements, iterations);
                publicConvolutionTimes[sample] = timePublicConvolution(source, publicConvolutionDestination, width, height, iterations);
                publicNeighbourhoodTimes[sample] = timePublicNeighbourhoodLoop(source, publicNeighbourhoodDestination, width, height, iterations);
                hotLoopTimes[sample] = timeHotLoop(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotLoopBase, cast(ptrdiff_t) destinationRowElements, iterations);
                hotUnrolledTimes[sample] = timeHotUnrolled(sourceBase, cast(ptrdiff_t) sourceRowElements, width, height, hotUnrolledBase, cast(ptrdiff_t) destinationRowElements, iterations);
                break;
        }
    }

    const publicConvolutionMedian = median(publicConvolutionTimes);
    const publicNeighbourhoodMedian = median(publicNeighbourhoodTimes);
    const hotLoopMedian = median(hotLoopTimes);
    const hotUnrolledMedian = median(hotUnrolledTimes);
    const directMedian = median(directTimes);

    emit("public_convolution", width, height, iterations, publicConvolutionMedian, expected);
    emit("public_neighbourhood_loop", width, height, iterations, publicNeighbourhoodMedian, expected);
    emit("hot_neighbourhood_loop", width, height, iterations, hotLoopMedian, expected);
    emit("hot_neighbourhood_unrolled", width, height, iterations, hotUnrolledMedian, expected);
    emit("direct_unrolled", width, height, iterations, directMedian, expected);

    writefln(
        "convolution_codegen_ratio compiler=%s public_convolution_over_public_neighbourhood=%.6f public_neighbourhood_over_hot_loop=%.6f hot_loop_over_hot_unrolled=%.6f hot_unrolled_over_direct=%.6f public_convolution_over_direct=%.6f",
        compilerName(),
        cast(double) publicConvolutionMedian / cast(double) publicNeighbourhoodMedian,
        cast(double) publicNeighbourhoodMedian / cast(double) hotLoopMedian,
        cast(double) hotLoopMedian / cast(double) hotUnrolledMedian,
        cast(double) hotUnrolledMedian / cast(double) directMedian,
        cast(double) publicConvolutionMedian / cast(double) directMedian
    );
}
