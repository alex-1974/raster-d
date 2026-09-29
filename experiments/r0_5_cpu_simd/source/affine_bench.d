module affine_bench;

import corpus : fillDeterministic, fingerprint;
import harness : FourSamples, measureFour;
import raster.internal.r0_5_abstraction_bench :
    affineMirContiguous1D,
    makeContiguousCopyFixture;

import std.stdio : writefln, writeln;

enum size_t affineRepetitions = 12;
enum size_t affineWarmupRounds = 2;
enum float affineGain = 1.125f;
enum float affineBias = -0.0625f;

private void affineScalar(
    const(float)[] source,
    float[] destination,
    float gain,
    float bias
)
@safe pure nothrow @nogc
{
    assert(source.length == destination.length);

    foreach (i; 0 .. source.length)
        destination[i] = source[i] * gain + bias;
}

private void affineArray(
    const(float)[] source,
    float[] destination,
    float gain,
    float bias
)
@safe pure nothrow @nogc
{
    assert(source.length == destination.length);
    destination[] = source[] * gain + bias;
}

private void affinePointer(
    const(float)[] source,
    float[] destination,
    float gain,
    float bias
)
@trusted pure nothrow @nogc
{
    assert(source.length == destination.length);

    const(float)* input = source.ptr;
    float* output = destination.ptr;

    foreach (i; 0 .. source.length)
        output[i] = input[i] * gain + bias;
}

private void printSamples(
    size_t elements,
    string label,
    const(long)[] raw,
    long median
)
{
    writefln(
        "affine elements=%s variant=%s median_ns=%s raw_ns=%(%s,%)",
        elements,
        label,
        median,
        raw
    );
}

private bool preflight(
    const(float)[] source,
    float[] destination,
    size_t width,
    size_t height,
    ulong expected
)
{
    affineArray(source, destination, affineGain, affineBias);
    if (fingerprint(destination) != expected)
        return false;

    affinePointer(source, destination, affineGain, affineBias);
    if (fingerprint(destination) != expected)
        return false;

    auto fixture =
        makeContiguousCopyFixture(
            source,
            destination,
            width,
            height
        );

    if (!affineMirContiguous1D(
        fixture.source,
        fixture.target,
        affineGain,
        affineBias
    ))
        return false;

    return fingerprint(destination) == expected;
}

private int runAffineSize(size_t elementCount)
{
    assert(elementCount != 0);
    assert((elementCount % 1024) == 0);

    auto source = new float[elementCount];
    auto destination = new float[elementCount];

    fillDeterministic(
        source,
        0x5230_3500_2026_0929UL ^ cast(ulong) elementCount
    );

    affineScalar(source, destination, affineGain, affineBias);
    const expected = fingerprint(destination);

    enum size_t width = 1024;
    const height = elementCount / width;

    if (!preflight(source, destination, width, height, expected))
    {
        writefln("affine correctness preflight failed elements=%s", elementCount);
        return 1;
    }

    auto fixture =
        makeContiguousCopyFixture(
            source,
            destination,
            width,
            height
        );

    const samples = measureFour!(
        () => affineScalar(source, destination, affineGain, affineBias),
        () => affineArray(source, destination, affineGain, affineBias),
        () => affinePointer(source, destination, affineGain, affineBias),
        () => affineMirContiguous1D(
            fixture.source,
            fixture.target,
            affineGain,
            affineBias
        )
    )(
        affineRepetitions,
        affineWarmupRounds
    );

    if (fingerprint(destination) != expected)
    {
        writefln("affine benchmark postflight failed elements=%s", elementCount);
        return 1;
    }

    printSamples(
        elementCount,
        "scalar",
        samples.first.nanoseconds,
        samples.first.median
    );
    printSamples(
        elementCount,
        "array",
        samples.second.nanoseconds,
        samples.second.median
    );
    printSamples(
        elementCount,
        "pointer",
        samples.third.nanoseconds,
        samples.third.median
    );
    printSamples(
        elementCount,
        "mir_contiguous1d",
        samples.fourth.nanoseconds,
        samples.fourth.median
    );

    writefln(
        "affine elements=%s fingerprint=%016x ratio_array_over_scalar=%.6f ratio_pointer_over_scalar=%.6f ratio_mir_over_scalar=%.6f",
        elementCount,
        expected,
        cast(double) samples.second.median / cast(double) samples.first.median,
        cast(double) samples.third.median / cast(double) samples.first.median,
        cast(double) samples.fourth.median / cast(double) samples.first.median
    );

    return 0;
}

int runAffineMatrix()
{
    static immutable size_t[] sizes = [
        64 * 1024,
        1024 * 1024,
        8 * 1024 * 1024
    ];

    writeln("=== affine transform matrix ===");

    foreach (elementCount; sizes)
    {
        if (runAffineSize(elementCount) != 0)
            return 1;
    }

    return 0;
}
