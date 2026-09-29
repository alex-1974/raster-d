module float_reduction_bench;

import harness : measureFour;
import std.stdio : writefln, writeln;

enum size_t repetitions = 12;
enum size_t warmupRounds = 2;

private struct MinMaxFloat
{
    float minimum;
    float maximum;
}

private MinMaxFloat minMaxSlice(scope const(float)[] source)
@safe pure nothrow @nogc
{
    assert(source.length != 0);
    float minimum = source[0];
    float maximum = source[0];
    foreach (i; 1 .. source.length)
    {
        const value = source[i];
        if (value < minimum) minimum = value;
        if (value > maximum) maximum = value;
    }
    return MinMaxFloat(minimum, maximum);
}

private MinMaxFloat minMaxPointer(scope const(float)[] source)
@trusted pure nothrow @nogc
{
    assert(source.length != 0);
    const base = source.ptr;
    const length = source.length;
    float minimum = base[0];
    float maximum = base[0];
    foreach (i; 1 .. length)
    {
        const value = base[i];
        if (value < minimum) minimum = value;
        if (value > maximum) maximum = value;
    }
    return MinMaxFloat(minimum, maximum);
}

private MinMaxFloat minMaxFourLane(scope const(float)[] source)
@trusted pure nothrow @nogc
{
    assert(source.length != 0);
    const base = source.ptr;
    const length = source.length;
    float min0 = base[0], max0 = base[0];
    float min1 = min0, max1 = max0;
    float min2 = min0, max2 = max0;
    float min3 = min0, max3 = max0;
    size_t i = 1;
    while (length - i >= 4)
    {
        const v0 = base[i], v1 = base[i + 1], v2 = base[i + 2], v3 = base[i + 3];
        if (v0 < min0) min0 = v0; if (v0 > max0) max0 = v0;
        if (v1 < min1) min1 = v1; if (v1 > max1) max1 = v1;
        if (v2 < min2) min2 = v2; if (v2 > max2) max2 = v2;
        if (v3 < min3) min3 = v3; if (v3 > max3) max3 = v3;
        i += 4;
    }
    float minimum = min0, maximum = max0;
    if (min1 < minimum) minimum = min1; if (min2 < minimum) minimum = min2; if (min3 < minimum) minimum = min3;
    if (max1 > maximum) maximum = max1; if (max2 > maximum) maximum = max2; if (max3 > maximum) maximum = max3;
    while (i < length)
    {
        const value = base[i];
        if (value < minimum) minimum = value;
        if (value > maximum) maximum = value;
        ++i;
    }
    return MinMaxFloat(minimum, maximum);
}

private ulong resultBits(MinMaxFloat result)
@trusted pure nothrow @nogc
{
    union Bits { float f; uint u; }
    Bits lo, hi;
    lo.f = result.minimum;
    hi.f = result.maximum;
    return (cast(ulong) lo.u << 32) | hi.u;
}

private int runCase(size_t elements)
{
    auto source = new float[elements];
    foreach (i; 0 .. source.length)
        source[i] = (cast(float)((i * 131 + (i >> 4) * 29) % 100003) + 1.0f) * 0.001f;
    source[elements / 3] = -12345.25f;
    source[(elements * 2) / 3] = 23456.5f;

    const expected = minMaxSlice(source);
    if (minMaxPointer(source) != expected || minMaxFourLane(source) != expected)
    {
        writeln("float minmax correctness preflight failed");
        return 1;
    }

    ulong sink;
    size_t invocation;
    const samples = measureFour!(
        () { const r = resultBits(minMaxSlice(source)); sink = sink * 0x9E37_79B9_7F4A_7C15UL + r + ++invocation; },
        () { const r = resultBits(minMaxPointer(source)); sink = sink * 0x9E37_79B9_7F4A_7C15UL + r + ++invocation; },
        () { const r = resultBits(minMaxFourLane(source)); sink = sink * 0x9E37_79B9_7F4A_7C15UL + r + ++invocation; },
        () { const r = resultBits(minMaxPointer(source)); sink = sink * 0x9E37_79B9_7F4A_7C15UL + r + ++invocation; }
    )(repetitions, warmupRounds);

    writefln("minmax_float_finite elements=%s slice_ns=%s pointer_ns=%s four_lane_ns=%s pointer_control_ns=%s sink=%s",
        elements, samples.first.median, samples.second.median, samples.third.median, samples.fourth.median, sink);
    writefln("minmax_float_finite elements=%s slice_raw_ns=%(%s,%)", elements, samples.first.nanoseconds);
    writefln("minmax_float_finite elements=%s pointer_raw_ns=%(%s,%)", elements, samples.second.nanoseconds);
    writefln("minmax_float_finite elements=%s four_lane_raw_ns=%(%s,%)", elements, samples.third.nanoseconds);
    writefln("minmax_float_finite elements=%s pointer_control_raw_ns=%(%s,%)", elements, samples.fourth.nanoseconds);
    return 0;
}

int runFloatReductionMatrix()
{
    writeln("=== reduction matrix: finite float min/max ===");
    foreach (elements; [64 * 1024, 1024 * 1024, 8 * 1024 * 1024])
        if (runCase(elements) != 0) return 1;
    return 0;
}
