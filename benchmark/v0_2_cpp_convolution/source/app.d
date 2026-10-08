module raster.benchmark_cpp_convolution;

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
    if (width == 0 || height == 0 || rowElements < width || rowElements > size_t.max / height)
        return false;

    const count = rowElements * height;
    if (count > size_t.max / float.sizeof)
        return false;

    void* memory = malloc(count * float.sizeof);
    if (memory is null)
        return false;

    base = cast(float*) memory;

    foreach (y; 0 .. height)
        foreach (x; 0 .. rowElements)
            base[y * rowElements + x] =
                cast(float)(cast(int)((y * 131 + x * 17) % 251) - 125) * 0.03125f;

    OwnedByteResource resource;
    if (!tryAdoptMallocResource(memory, count * float.sizeof, resource))
        return false;

    const PlaneByteLayout[1] layouts = [
        PlaneByteLayout(0, cast(ptrdiff_t)(rowElements * float.sizeof), cast(ptrdiff_t) float.sizeof)
    ];

    return tryImportOwnedRaster!float(
        resource,
        layouts[],
        Region2D(0, 0, width, height),
        lease
    ).ok;
}

private float scalarPixel(
    scope const(float)* r0,
    scope const(float)* r1,
    scope const(float)* r2,
    size_t x
)
@trusted pure nothrow @nogc
{
    float total = 0.0f;
    total = total + r0[x + 0] *  0.125f;
    total = total + r0[x + 1] * -0.250f;
    total = total + r0[x + 2] *  0.375f;
    total = total + r1[x + 0] * -0.500f;
    total = total + r1[x + 1] *  1.250f;
    total = total + r1[x + 2] * -0.625f;
    total = total + r2[x + 0] *  0.750f;
    total = total + r2[x + 1] * -0.875f;
    total = total + r2[x + 2] *  0.500f;
    return total;
}

pragma(inline, false)
private void executeDirectScalar(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase
)
@trusted pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const r0 = sourceBase + y * sourceRowElements;
        const r1 = r0 + sourceRowElements;
        const r2 = r1 + sourceRowElements;
        auto dst = destinationBase + y * width;

        foreach (x; 0 .. width)
            dst[x] = scalarPixel(r0, r1, r2, x);
    }
}

private ulong checksum(scope const(float)* base, size_t width, size_t height)
@trusted nothrow @nogc
{
    ulong hash = 1469598103934665603UL;

    foreach (i; 0 .. width * height)
    {
        union Bits { float value; uint bits; }
        Bits bits;
        bits.value = base[i];
        hash ^= bits.bits;
        hash *= 1099511628211UL;
    }

    return hash;
}

private long median(long[samples] values)
{
    sort(values[]);
    return (values[samples / 2 - 1] + values[samples / 2]) / 2;
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
        require(error == RasterNeighbourhoodError.none, "public convolution error");
    }
    return (MonoTime.currTime - start).total!"nsecs";
}

private long timeDirect(
    scope const(float)* sourceBase,
    size_t sourceRowElements,
    size_t width,
    size_t height,
    scope float* destinationBase,
    size_t iterations
)
@safe
{
    const start = MonoTime.currTime;
    foreach (_; 0 .. iterations)
        executeDirectScalar(sourceBase, sourceRowElements, width, height, destinationBase);
    return (MonoTime.currTime - start).total!"nsecs";
}

private string compilerName()
{
    version (DigitalMars) return "dmd";
    else version (LDC) return "ldc";
    else return "other";
}

void main(string[] args)
@system
{
    const width = args.length >= 2 ? args[1].to!size_t : 1024;
    const height = args.length >= 3 ? args[2].to!size_t : 512;
    const iterations = args.length >= 4 ? args[3].to!size_t : 8;

    RasterLease!float sourceLease;
    RasterLease!float publicLease;
    RasterLease!float directLease;
    float* sourceBase;
    float* publicBase;
    float* directBase;
    size_t sourceRowElements;
    size_t ignored;

    require(makeFloatLease(width + 2, height + 2, 32, sourceLease, sourceBase, sourceRowElements), "source failed");
    require(makeFloatLease(width, height, 0, publicLease, publicBase, ignored), "public dst failed");
    require(makeFloatLease(width, height, 0, directLease, directBase, ignored), "direct dst failed");

    scope auto source = sourceLease.view();
    bool writableOk;
    scope auto publicDestination = publicLease.tryWritableView(writableOk);
    require(writableOk, "public writable unavailable");

    timePublic(source, publicDestination, width, height, 1);
    timeDirect(sourceBase, sourceRowElements, width, height, directBase, 1);

    const qualifiedPublic = checksum(publicBase, width, height);
    const qualifiedDirect = checksum(directBase, width, height);
    require(qualifiedPublic == qualifiedDirect, "qualification checksum mismatch");

    foreach (warmup; 0 .. warmups)
    {
        if ((warmup & 1) == 0)
        {
            timePublic(source, publicDestination, width, height, 1);
            timeDirect(sourceBase, sourceRowElements, width, height, directBase, 1);
        }
        else
        {
            timeDirect(sourceBase, sourceRowElements, width, height, directBase, 1);
            timePublic(source, publicDestination, width, height, 1);
        }
    }

    long[samples] publicTimes;
    long[samples] directTimes;

    foreach (sample; 0 .. samples)
    {
        if ((sample & 1) == 0)
        {
            publicTimes[sample] = timePublic(source, publicDestination, width, height, iterations);
            directTimes[sample] = timeDirect(sourceBase, sourceRowElements, width, height, directBase, iterations);
        }
        else
        {
            directTimes[sample] = timeDirect(sourceBase, sourceRowElements, width, height, directBase, iterations);
            publicTimes[sample] = timePublic(source, publicDestination, width, height, iterations);
        }
    }

    const finalPublic = checksum(publicBase, width, height);
    const finalDirect = checksum(directBase, width, height);
    require(finalPublic == finalDirect, "timed checksum mismatch");

    const publicMedian = median(publicTimes);
    const directMedian = median(directTimes);
    const pixels = cast(double)(width * height * iterations);

    writefln(
        "cpp_gate_d compiler=%s path=public_convolution ns_per_pixel=%.6f checksum=%016x",
        compilerName(), cast(double) publicMedian / pixels, finalPublic
    );
    writefln(
        "cpp_gate_d compiler=%s path=direct_scalar ns_per_pixel=%.6f checksum=%016x",
        compilerName(), cast(double) directMedian / pixels, finalDirect
    );
    writefln(
        "cpp_gate_d_ratio compiler=%s public_over_direct=%.6f",
        compilerName(), cast(double) publicMedian / cast(double) directMedian
    );
}
