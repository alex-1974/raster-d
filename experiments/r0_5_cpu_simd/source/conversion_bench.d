module conversion_bench;

import harness : measurePair;
import raster.internal.r0_5_conversion_bench :
    convertDispatch,
    convertKernel,
    makeConversionFixture;

import std.stdio : writefln, writeln;

enum size_t conversionRepetitions = 12;
enum size_t conversionWarmupRounds = 2;

private ulong conversionFingerprint(const(float)[] values)
@safe pure nothrow @nogc
{
    ulong hash = 0xcbf29ce484222325UL;
    foreach (value; values)
    {
        const bits = *cast(const uint*) &value;
        hash ^= bits;
        hash *= 0x100000001b3UL;
    }
    return hash;
}

private int runConversionSize(size_t elementCount)
{
    assert(elementCount != 0);
    assert((elementCount % 1024) == 0);

    auto source = new ubyte[elementCount];
    auto destination = new float[elementCount];

    foreach (i; 0 .. source.length)
        source[i] = cast(ubyte) ((i * 131 + 17) & 0xff);

    enum size_t width = 1024;
    const height = elementCount / width;

    auto fixture = makeConversionFixture(
        source,
        destination,
        width,
        height
    );

    if (!convertKernel(fixture))
        return 1;

    const expected = conversionFingerprint(destination);

    if (!convertDispatch(fixture) || conversionFingerprint(destination) != expected)
    {
        writefln("conversion correctness preflight failed elements=%s", elementCount);
        return 1;
    }

    const samples = measurePair!(
        () => convertKernel(fixture),
        () => convertDispatch(fixture)
    )(
        conversionRepetitions,
        conversionWarmupRounds
    );

    if (conversionFingerprint(destination) != expected)
    {
        writefln("conversion benchmark postflight failed elements=%s", elementCount);
        return 1;
    }

    writefln(
        "conversion elements=%s kernel_median_ns=%s dispatch_median_ns=%s ratio_dispatch_over_kernel=%.6f",
        elementCount,
        samples.first.median,
        samples.second.median,
        cast(double) samples.second.median / cast(double) samples.first.median
    );
    writefln(
        "conversion elements=%s kernel_raw_ns=%(%s,%)",
        elementCount,
        samples.first.nanoseconds
    );
    writefln(
        "conversion elements=%s dispatch_raw_ns=%(%s,%)",
        elementCount,
        samples.second.nanoseconds
    );
    writefln(
        "conversion elements=%s fingerprint=%016x",
        elementCount,
        expected
    );

    return 0;
}

int runConversionMatrix()
{
    static immutable size_t[] sizes = [
        64 * 1024,
        1024 * 1024,
        8 * 1024 * 1024
    ];

    writeln("=== real ubyte-to-float raster conversion matrix ===");

    foreach (elementCount; sizes)
    {
        if (runConversionSize(elementCount) != 0)
            return 1;
    }

    return 0;
}
