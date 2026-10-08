module raster.benchmark_simd_convolution;

import core.simd : float4, loadUnaligned, storeUnaligned;
import core.stdc.stdlib : malloc;
import core.time : MonoTime;

import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writefln;

import raster;

private enum size_t warmups = 6;
private enum size_t samples = 18;

alias Shape3x3 = NeighbourhoodShape!(3, 3, 1, 1);

alias FixedKernel = FixedConvolutionKernel!(
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

private bool makeFloatLease(
    size_t width,
    size_t height,
    size_t rowPadding,
    ref RasterLease!float lease,
    out float* base,
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

    const count = rowElements * height;

    if (count > size_t.max / float.sizeof)
        return false;

    void* memory = malloc(count * float.sizeof);

    if (memory is null)
        return false;

    base = cast(float*) memory;

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. rowElements)
        {
            base[y * rowElements + x] =
                cast(float)(
                    cast(int)((y * 131 + x * 17) % 251) - 125
                ) * 0.03125f;
        }
    }

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(memory, count * float.sizeof, resource))
        return false;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            0,
            cast(ptrdiff_t)(rowElements * float.sizeof),
            cast(ptrdiff_t) float.sizeof
        )
    ];

    const imported = tryImportOwnedRaster!float(
        resource,
        layouts[],
        Region2D(0, 0, width, height),
        lease
    );

    return imported.ok;
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

private long median(long[samples] values)
{
    sort(values[]);
    return (values[samples / 2 - 1] + values[samples / 2]) / 2;
}

private float scalarPixel(
    scope const(float)* row0,
    scope const(float)* row1,
    scope const(float)* row2,
    size_t x
)
@trusted pure nothrow @nogc
{
    float total = 0.0f;

    total = total + row0[x + 0] *  0.125f;
    total = total + row0[x + 1] * -0.250f;
    total = total + row0[x + 2] *  0.375f;
    total = total + row1[x + 0] * -0.500f;
    total = total + row1[x + 1] *  1.250f;
    total = total + row1[x + 2] * -0.625f;
    total = total + row2[x + 0] *  0.750f;
    total = total + row2[x + 1] * -0.875f;
    total = total + row2[x + 2] *  0.500f;

    return total;
}

pragma(inline, false)
private void executeDirectScalar(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t destinationRowElements
)
@trusted pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const row0 = sourceBase + y * sourceRowElements;
        const row1 = row0 + sourceRowElements;
        const row2 = row1 + sourceRowElements;
        auto destinationRow = destinationBase + y * destinationRowElements;

        foreach (x; 0 .. width)
            destinationRow[x] = scalarPixel(row0, row1, row2, x);
    }
}

private float4 splat(float value)
@trusted pure nothrow @nogc
{
    float4 result;
    result.array[0] = value;
    result.array[1] = value;
    result.array[2] = value;
    result.array[3] = value;
    return result;
}

pragma(inline, false)
private void executeExplicitFloat4(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t destinationRowElements
)
@trusted pure nothrow @nogc
{
    const c0 = splat( 0.125f);
    const c1 = splat(-0.250f);
    const c2 = splat( 0.375f);
    const c3 = splat(-0.500f);
    const c4 = splat( 1.250f);
    const c5 = splat(-0.625f);
    const c6 = splat( 0.750f);
    const c7 = splat(-0.875f);
    const c8 = splat( 0.500f);

    foreach (y; 0 .. height)
    {
        const row0 = sourceBase + y * sourceRowElements;
        const row1 = row0 + sourceRowElements;
        const row2 = row1 + sourceRowElements;
        auto destinationRow = destinationBase + y * destinationRowElements;

        size_t x = 0;
        const vectorEnd = width & ~cast(size_t) 3;

        for (; x < vectorEnd; x += 4)
        {
            float4 total = splat(0.0f);

            total = total
                + loadUnaligned(cast(const(float4)*)(row0 + x + 0)) * c0;
            total = total
                + loadUnaligned(cast(const(float4)*)(row0 + x + 1)) * c1;
            total = total
                + loadUnaligned(cast(const(float4)*)(row0 + x + 2)) * c2;
            total = total
                + loadUnaligned(cast(const(float4)*)(row1 + x + 0)) * c3;
            total = total
                + loadUnaligned(cast(const(float4)*)(row1 + x + 1)) * c4;
            total = total
                + loadUnaligned(cast(const(float4)*)(row1 + x + 2)) * c5;
            total = total
                + loadUnaligned(cast(const(float4)*)(row2 + x + 0)) * c6;
            total = total
                + loadUnaligned(cast(const(float4)*)(row2 + x + 1)) * c7;
            total = total
                + loadUnaligned(cast(const(float4)*)(row2 + x + 2)) * c8;

            storeUnaligned(
                cast(float4*)(destinationRow + x),
                total
            );
        }

        for (; x < width; ++x)
            destinationRow[x] = scalarPixel(row0, row1, row2, x);
    }
}

private long timePublic(
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
            source.convolveInto!(FixedKernel, float)(
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

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeDirectScalar(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t destinationRowElements,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        executeDirectScalar(
            sourceBase,
            sourceRowElements,
            width,
            height,
            destinationBase,
            destinationRowElements
        );

    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeExplicitFloat4(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t destinationRowElements,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;

    foreach (_; 0 .. iterations)
        executeExplicitFloat4(
            sourceBase,
            sourceRowElements,
            width,
            height,
            destinationBase,
            destinationRowElements
        );

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

private void emit(
    string path,
    size_t width,
    size_t height,
    size_t iterations,
    long medianNs,
    ulong resultChecksum
)
{
    const logicalPixels = cast(double)(width * height * iterations);

    writefln(
        "simd_convolution compiler=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
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
    const width = args.length >= 2 ? args[1].to!size_t : 1024;
    const height = args.length >= 3 ? args[2].to!size_t : 512;
    const iterations = args.length >= 4 ? args[3].to!size_t : 8;

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

    enum size_t pathCount = 3;
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
                0,
                destinationLeases[i],
                destinationBases[i],
                destinationRows[i]
            ),
            "destination allocation failed"
        );

        bool ok;
        destinations[i] = destinationLeases[i].tryWritableView(ok);
        require(ok, "writable destination unavailable");
    }

    scope auto source = sourceLease.view();

    timePublic(source, destinations[0], width, height, 1);
    timeDirectScalar(
        sourceBase,
        sourceRowElements,
        width,
        height,
        destinationBases[1],
        destinationRows[1],
        1
    );
    timeExplicitFloat4(
        sourceBase,
        sourceRowElements,
        width,
        height,
        destinationBases[2],
        destinationRows[2],
        1
    );

    ulong[pathCount] qualifiedChecksums;

    foreach (i; 0 .. pathCount)
        qualifiedChecksums[i] = checksum(
            destinationBases[i],
            width,
            height,
            destinationRows[i]
        );

    require(
        qualifiedChecksums[0] == qualifiedChecksums[1]
        && qualifiedChecksums[1] == qualifiedChecksums[2],
        "SIMD convolution checksum mismatch"
    );

    foreach (warmup; 0 .. warmups)
    {
        final switch (warmup % 3)
        {
            case 0:
                timePublic(source, destinations[0], width, height, 1);
                timeDirectScalar(
                    sourceBase, sourceRowElements, width, height,
                    destinationBases[1], destinationRows[1], 1
                );
                timeExplicitFloat4(
                    sourceBase, sourceRowElements, width, height,
                    destinationBases[2], destinationRows[2], 1
                );
                break;

            case 1:
                timeDirectScalar(
                    sourceBase, sourceRowElements, width, height,
                    destinationBases[1], destinationRows[1], 1
                );
                timeExplicitFloat4(
                    sourceBase, sourceRowElements, width, height,
                    destinationBases[2], destinationRows[2], 1
                );
                timePublic(source, destinations[0], width, height, 1);
                break;

            case 2:
                timeExplicitFloat4(
                    sourceBase, sourceRowElements, width, height,
                    destinationBases[2], destinationRows[2], 1
                );
                timePublic(source, destinations[0], width, height, 1);
                timeDirectScalar(
                    sourceBase, sourceRowElements, width, height,
                    destinationBases[1], destinationRows[1], 1
                );
                break;
        }
    }

    long[samples] publicTimes;
    long[samples] scalarTimes;
    long[samples] simdTimes;

    foreach (sample; 0 .. samples)
    {
        final switch (sample % 3)
        {
            case 0:
                publicTimes[sample] =
                    timePublic(
                        source,
                        destinations[0],
                        width,
                        height,
                        iterations
                    );
                scalarTimes[sample] =
                    timeDirectScalar(
                        sourceBase, sourceRowElements, width, height,
                        destinationBases[1], destinationRows[1], iterations
                    );
                simdTimes[sample] =
                    timeExplicitFloat4(
                        sourceBase, sourceRowElements, width, height,
                        destinationBases[2], destinationRows[2], iterations
                    );
                break;

            case 1:
                scalarTimes[sample] =
                    timeDirectScalar(
                        sourceBase, sourceRowElements, width, height,
                        destinationBases[1], destinationRows[1], iterations
                    );
                simdTimes[sample] =
                    timeExplicitFloat4(
                        sourceBase, sourceRowElements, width, height,
                        destinationBases[2], destinationRows[2], iterations
                    );
                publicTimes[sample] =
                    timePublic(
                        source,
                        destinations[0],
                        width,
                        height,
                        iterations
                    );
                break;

            case 2:
                simdTimes[sample] =
                    timeExplicitFloat4(
                        sourceBase, sourceRowElements, width, height,
                        destinationBases[2], destinationRows[2], iterations
                    );
                publicTimes[sample] =
                    timePublic(
                        source,
                        destinations[0],
                        width,
                        height,
                        iterations
                    );
                scalarTimes[sample] =
                    timeDirectScalar(
                        sourceBase, sourceRowElements, width, height,
                        destinationBases[1], destinationRows[1], iterations
                    );
                break;
        }
    }

    ulong[pathCount] finalChecksums;

    foreach (i; 0 .. pathCount)
        finalChecksums[i] = checksum(
            destinationBases[i],
            width,
            height,
            destinationRows[i]
        );

    require(
        finalChecksums[0] == finalChecksums[1]
        && finalChecksums[1] == finalChecksums[2],
        "timed SIMD convolution checksum mismatch"
    );

    const publicMedian = median(publicTimes);
    const scalarMedian = median(scalarTimes);
    const simdMedian = median(simdTimes);

    emit(
        "public_convolution",
        width,
        height,
        iterations,
        publicMedian,
        finalChecksums[0]
    );
    emit(
        "direct_scalar",
        width,
        height,
        iterations,
        scalarMedian,
        finalChecksums[1]
    );
    emit(
        "explicit_float4",
        width,
        height,
        iterations,
        simdMedian,
        finalChecksums[2]
    );

    writefln(
        "simd_convolution_ratio compiler=%s public_over_scalar=%.6f simd_over_scalar=%.6f public_over_simd=%.6f",
        compilerName(),
        cast(double) publicMedian / cast(double) scalarMedian,
        cast(double) simdMedian / cast(double) scalarMedian,
        cast(double) publicMedian / cast(double) simdMedian
    );
}
