module reduction_bench;

import harness : measureFour;
import std.stdio : writefln, writeln;

enum size_t repetitions = 12;
enum size_t warmupRounds = 2;

private struct MinMaxUbyte
{
    ubyte minimum;
    ubyte maximum;
}

private MinMaxUbyte minMaxSlice(scope const(ubyte)[] source)
@safe pure nothrow @nogc
{
    assert(source.length != 0);

    ubyte minimum = source[0];
    ubyte maximum = source[0];

    foreach (i; 1 .. source.length)
    {
        const value = source[i];
        if (value < minimum)
            minimum = value;
        if (value > maximum)
            maximum = value;
    }

    return MinMaxUbyte(minimum, maximum);
}

private MinMaxUbyte minMaxPointer(scope const(ubyte)[] source)
@trusted pure nothrow @nogc
{
    assert(source.length != 0);

    const base = source.ptr;
    const length = source.length;
    ubyte minimum = base[0];
    ubyte maximum = base[0];

    foreach (i; 1 .. length)
    {
        const value = base[i];
        if (value < minimum)
            minimum = value;
        if (value > maximum)
            maximum = value;
    }

    return MinMaxUbyte(minimum, maximum);
}

private MinMaxUbyte minMaxFourLane(scope const(ubyte)[] source)
@trusted pure nothrow @nogc
{
    assert(source.length != 0);

    const base = source.ptr;
    const length = source.length;

    ubyte min0 = base[0], max0 = base[0];
    ubyte min1 = min0, max1 = max0;
    ubyte min2 = min0, max2 = max0;
    ubyte min3 = min0, max3 = max0;

    size_t i = 1;
    while (length - i >= 4)
    {
        const v0 = base[i];
        const v1 = base[i + 1];
        const v2 = base[i + 2];
        const v3 = base[i + 3];

        if (v0 < min0) min0 = v0;
        if (v0 > max0) max0 = v0;
        if (v1 < min1) min1 = v1;
        if (v1 > max1) max1 = v1;
        if (v2 < min2) min2 = v2;
        if (v2 > max2) max2 = v2;
        if (v3 < min3) min3 = v3;
        if (v3 > max3) max3 = v3;

        i += 4;
    }

    ubyte minimum = min0;
    ubyte maximum = max0;
    if (min1 < minimum) minimum = min1;
    if (min2 < minimum) minimum = min2;
    if (min3 < minimum) minimum = min3;
    if (max1 > maximum) maximum = max1;
    if (max2 > maximum) maximum = max2;
    if (max3 > maximum) maximum = max3;

    while (i < length)
    {
        const value = base[i];
        if (value < minimum)
            minimum = value;
        if (value > maximum)
            maximum = value;
        ++i;
    }

    return MinMaxUbyte(minimum, maximum);
}

private ulong sinkValue(MinMaxUbyte result)
@safe pure nothrow @nogc
{
    return (cast(ulong) result.minimum << 8) | result.maximum;
}

private int runCase(size_t elements)
{
    assert(elements != 0);

    auto source = new ubyte[elements];
    foreach (i; 0 .. source.length)
        source[i] = cast(ubyte)((i * 131 + (i >> 4) * 29 + 73) & 0xff);

    // Force extrema away from the first element and make the expected result
    // independent of the deterministic generator's period.
    source[elements / 3] = ubyte.min;
    source[(elements * 2) / 3] = ubyte.max;

    const expected = minMaxSlice(source);
    if (expected.minimum != ubyte.min || expected.maximum != ubyte.max)
    {
        writeln("minmax expected-value preflight failed");
        return 1;
    }

    if (minMaxPointer(source) != expected || minMaxFourLane(source) != expected)
    {
        writeln("minmax variant correctness preflight failed");
        return 1;
    }

    ulong sink;
    size_t invocation;
    const samples = measureFour!(
        () {
            const result = sinkValue(minMaxSlice(source));
            sink = sink * 0x9E37_79B9_7F4A_7C15UL
                + result + ++invocation;
        },
        () {
            const result = sinkValue(minMaxPointer(source));
            sink = sink * 0x9E37_79B9_7F4A_7C15UL
                + result + ++invocation;
        },
        () {
            const result = sinkValue(minMaxFourLane(source));
            sink = sink * 0x9E37_79B9_7F4A_7C15UL
                + result + ++invocation;
        },
        () {
            const result = sinkValue(minMaxPointer(source));
            sink = sink * 0x9E37_79B9_7F4A_7C15UL
                + result + ++invocation;
        }
    )(repetitions, warmupRounds);

    if (minMaxSlice(source) != expected ||
        minMaxPointer(source) != expected ||
        minMaxFourLane(source) != expected)
    {
        writeln("minmax benchmark postflight failed");
        return 1;
    }

    writefln(
        "minmax_ubyte elements=%s slice_ns=%s pointer_ns=%s four_lane_ns=%s pointer_control_ns=%s sink=%s",
        elements,
        samples.first.median,
        samples.second.median,
        samples.third.median,
        samples.fourth.median,
        sink
    );
    writefln("minmax_ubyte elements=%s slice_raw_ns=%(%s,%)", elements, samples.first.nanoseconds);
    writefln("minmax_ubyte elements=%s pointer_raw_ns=%(%s,%)", elements, samples.second.nanoseconds);
    writefln("minmax_ubyte elements=%s four_lane_raw_ns=%(%s,%)", elements, samples.third.nanoseconds);
    writefln("minmax_ubyte elements=%s pointer_control_raw_ns=%(%s,%)", elements, samples.fourth.nanoseconds);

    return 0;
}

int runReductionMatrix()
{
    writeln("=== reduction matrix: ubyte min/max ===");
    foreach (elements; [64 * 1024, 1024 * 1024, 8 * 1024 * 1024])
        if (runCase(elements) != 0)
            return 1;
    return 0;
}
