module app;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;
import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writeln, writefln;

import raster;


private enum size_t warmups = 3;
private enum size_t samples = 11;


private struct Measurement
{
    long medianNs;
    ulong checksum;
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


private bool makeLease(T)(
    size_t width,
    size_t height,
    size_t rowPaddingElements,
    bool negativeRow,
    ref RasterLease!T lease
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

    if (physicalElements > size_t.max / T.sizeof)
        return false;

    const byteLength =
        physicalElements * T.sizeof;

    void* memory =
        malloc(byteLength);

    if (memory is null)
        return false;

    auto typed =
        (cast(T*) memory)[0 .. physicalElements];

    static if (is(T == ubyte))
    {
        foreach (i; 0 .. typed.length)
            typed[i] = cast(ubyte)((i * 37 + 11) & 0xff);
    }
    else static if (is(T == float))
    {
        foreach (i; 0 .. typed.length)
            typed[i] = cast(float)((i % 251) - 125) * 0.03125f;
    }
    else
        static assert(0, "release benchmark only uses ubyte and float");

    OwnedByteResource resource;

    if (!tryAdoptMallocResource(memory, byteLength, resource))
        return false;

    const rowStrideBytesPositive =
        cast(ptrdiff_t)(rowElements * T.sizeof);

    const rowStrideBytes =
        negativeRow
        ? -rowStrideBytesPositive
        : rowStrideBytesPositive;

    const byteOffset =
        negativeRow
        ? (height - 1) * rowElements * T.sizeof
        : 0;

    const PlaneByteLayout[1] layouts =
    [
        PlaneByteLayout(
            byteOffset,
            rowStrideBytes,
            cast(ptrdiff_t) T.sizeof
        )
    ];

    const result =
        tryImportOwnedRaster!T(
            resource,
            layouts[],
            Region2D(0, 0, width, height),
            lease
        );

    return result.ok;
}


private long median(long[samples] values)
{
    sort(values[]);
    return values[samples / 2];
}


private ulong checksumUbyte(
    scope RasterView!ubyte view
)
@safe
{
    ulong hash = 1469598103934665603UL;

    foreach (y; 0 .. view.height)
    {
        foreach (x; 0 .. view.width)
        {
            ubyte value;
            assert(view.trySample(0, x, y, value));
            hash ^= value;
            hash *= 1099511628211UL;
        }
    }

    return hash;
}


private ulong checksumFloat(
    scope RasterView!float view
)
@safe
{
    ulong hash = 1469598103934665603UL;

    foreach (y; 0 .. view.height)
    {
        foreach (x; 0 .. view.width)
        {
            float value;
            assert(view.trySample(0, x, y, value));

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


private float pointTransform(float value)
@safe
pure
nothrow
@nogc
{
    return value * 1.0009765625f + 0.25f;
}


private float neighbourhoodKernel(
    ref const(float)[9] values
)
@safe
pure
nothrow
@nogc
{
    return (
        values[0] + values[1] + values[2]
        + values[3] + values[4] + values[5]
        + values[6] + values[7] + values[8]
    ) / 9.0f;
}


private Measurement benchCopy(
    size_t width,
    size_t height,
    size_t iterations
)
@system
{
    RasterLease!ubyte sourceLease;
    RasterLease!ubyte targetLease;

    assert(makeLease!ubyte(width, height, 32, false, sourceLease));
    assert(makeLease!ubyte(width, height, 32, false, targetLease));

    scope auto source = sourceLease.view();

    bool writableOk;
    scope auto target = targetLease.tryWritableView(writableOk);
    assert(writableOk);

    RasterCopyError error;

    foreach (_; 0 .. warmups)
        assert(tryCopyRasterPlane(source, 0, target, 0, error));

    long[samples] times;

    foreach (sample; 0 .. samples)
    {
        const start = MonoTime.currTime;

        foreach (_; 0 .. iterations)
            assert(tryCopyRasterPlane(source, 0, target, 0, error));

        times[sample] =
            (MonoTime.currTime - start).total!"nsecs";
    }

    return Measurement(
        median(times),
        checksumUbyte(targetLease.view())
    );
}


private Measurement benchConversion(
    size_t width,
    size_t height,
    size_t iterations,
    bool negativeSource
)
@system
{
    RasterLease!ubyte sourceLease;
    RasterLease!float targetLease;

    assert(makeLease!ubyte(width, height, 32, negativeSource, sourceLease));
    assert(makeLease!float(width, height, 32, false, targetLease));

    scope auto source = sourceLease.view();

    bool writableOk;
    scope auto target = targetLease.tryWritableView(writableOk);
    assert(writableOk);

    UbyteToFloatConversionError error;

    foreach (_; 0 .. warmups)
        assert(tryConvertUbyteToFloatPlane(source, 0, target, 0, error));

    long[samples] times;

    foreach (sample; 0 .. samples)
    {
        const start = MonoTime.currTime;

        foreach (_; 0 .. iterations)
            assert(tryConvertUbyteToFloatPlane(source, 0, target, 0, error));

        times[sample] =
            (MonoTime.currTime - start).total!"nsecs";
    }

    return Measurement(
        median(times),
        checksumFloat(targetLease.view())
    );
}


private Measurement benchFill(
    size_t width,
    size_t height,
    size_t iterations
)
@system
{
    RasterLease!ubyte lease;
    assert(makeLease!ubyte(width, height, 32, false, lease));

    bool writableOk;
    scope auto target = lease.tryWritableView(writableOk);
    assert(writableOk);

    foreach (_; 0 .. warmups)
        assert(tryFillRasterPlane(target, 0, cast(ubyte)173));

    long[samples] times;

    foreach (sample; 0 .. samples)
    {
        const start = MonoTime.currTime;

        foreach (i; 0 .. iterations)
            assert(
                tryFillRasterPlane(
                    target,
                    0,
                    cast(ubyte)(173 + (i & 1))
                )
            );

        times[sample] =
            (MonoTime.currTime - start).total!"nsecs";
    }

    return Measurement(
        median(times),
        checksumUbyte(lease.view())
    );
}


private Measurement benchTransform(
    size_t width,
    size_t height,
    size_t iterations
)
@system
{
    RasterLease!float sourceLease;
    RasterLease!float targetLease;

    assert(makeLease!float(width, height, 32, false, sourceLease));
    assert(makeLease!float(width, height, 32, false, targetLease));

    scope auto source = sourceLease.view();

    bool writableOk;
    scope auto target = targetLease.tryWritableView(writableOk);
    assert(writableOk);

    RasterTransformError error;

    foreach (_; 0 .. warmups)
        assert(
            tryTransformRasterPlane!pointTransform(
                source, 0, target, 0, error
            )
        );

    long[samples] times;

    foreach (sample; 0 .. samples)
    {
        const start = MonoTime.currTime;

        foreach (_; 0 .. iterations)
            assert(
                tryTransformRasterPlane!pointTransform(
                    source, 0, target, 0, error
                )
            );

        times[sample] =
            (MonoTime.currTime - start).total!"nsecs";
    }

    return Measurement(
        median(times),
        checksumFloat(targetLease.view())
    );
}


private Measurement benchReduction(
    size_t width,
    size_t height,
    size_t iterations
)
@system
{
    RasterLease!float sourceLease;
    assert(makeLease!float(width, height, 32, true, sourceLease));

    scope auto source = sourceLease.view();

    double sum;
    foreach (_; 0 .. warmups)
        assert(trySumFloatToDouble(source, 0, sum));

    long[samples] times;
    double sink;

    foreach (sample; 0 .. samples)
    {
        const start = MonoTime.currTime;

        foreach (_; 0 .. iterations)
        {
            assert(trySumFloatToDouble(source, 0, sum));
            sink += sum;
        }

        times[sample] =
            (MonoTime.currTime - start).total!"nsecs";
    }

    union Bits
    {
        double value;
        ulong bits;
    }

    Bits bits;
    bits.value = sink;

    return Measurement(
        median(times),
        bits.bits
    );
}


private Measurement benchNeighbourhood(
    size_t width,
    size_t height,
    size_t iterations
)
@system
{
    RasterLease!float sourceLease;
    RasterLease!float targetLease;

    assert(
        makeLease!float(
            width + 2,
            height + 2,
            32,
            true,
            sourceLease
        )
    );

    assert(makeLease!float(width, height, 32, false, targetLease));

    scope auto source = sourceLease.view();

    bool writableOk;
    scope auto target = targetLease.tryWritableView(writableOk);
    assert(writableOk);

    RasterNeighbourhood3x3Error error;

    const outputRegion =
        Region2D(1, 1, width, height);

    foreach (_; 0 .. warmups)
        assert(
            tryApplyRasterNeighbourhood3x3!neighbourhoodKernel(
                source,
                0,
                outputRegion,
                target,
                0,
                error
            )
        );

    long[samples] times;

    foreach (sample; 0 .. samples)
    {
        const start = MonoTime.currTime;

        foreach (_; 0 .. iterations)
            assert(
                tryApplyRasterNeighbourhood3x3!neighbourhoodKernel(
                    source,
                    0,
                    outputRegion,
                    target,
                    0,
                    error
                )
            );

        times[sample] =
            (MonoTime.currTime - start).total!"nsecs";
    }

    return Measurement(
        median(times),
        checksumFloat(targetLease.view())
    );
}


private void emit(
    string workload,
    size_t width,
    size_t height,
    size_t iterations,
    Measurement measurement
)
{
    const pixels =
        cast(double)(width * height * iterations);

    writefln(
        "release_benchmark compiler=%s workload=%s width=%s height=%s iterations=%s median_ns=%s ns_per_pixel=%.6f checksum=%016x",
        compilerName(),
        workload,
        width,
        height,
        iterations,
        measurement.medianNs,
        cast(double)measurement.medianNs / pixels,
        measurement.checksum
    );
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

    const neighbourhoodIterations =
        iterations > 4
        ? iterations / 4
        : 1;

    emit(
        "copy_ubyte_padded",
        width,
        height,
        iterations,
        benchCopy(width, height, iterations)
    );

    emit(
        "convert_ubyte_float_padded",
        width,
        height,
        iterations,
        benchConversion(width, height, iterations, false)
    );

    emit(
        "convert_ubyte_float_negative_source",
        width,
        height,
        iterations,
        benchConversion(width, height, iterations, true)
    );

    emit(
        "fill_ubyte_padded",
        width,
        height,
        iterations,
        benchFill(width, height, iterations)
    );

    emit(
        "transform_float_padded",
        width,
        height,
        iterations,
        benchTransform(width, height, iterations)
    );

    emit(
        "reduce_float_negative_source",
        width,
        height,
        iterations,
        benchReduction(width, height, iterations)
    );

    emit(
        "neighbourhood_float_negative_source",
        width,
        height,
        neighbourhoodIterations,
        benchNeighbourhood(
            width,
            height,
            neighbourhoodIterations
        )
    );
}
