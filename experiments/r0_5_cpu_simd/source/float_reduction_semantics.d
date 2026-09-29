module float_reduction_semantics;

import std.math : isNaN;
import std.stdio : writefln, writeln;

private struct MinMaxFloat
{
    float minimum;
    float maximum;
}

private MinMaxFloat minMaxScalar(scope const(float)[] source)
@safe pure nothrow @nogc
{
    assert(source.length != 0);
    float minimum = source[0];
    float maximum = source[0];

    foreach (i; 1 .. source.length)
    {
        const value = source[i];
        if (value < minimum)
            minimum = value;
        if (value > maximum)
            maximum = value;
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

    float minimum = min0, maximum = max0;
    if (min1 < minimum) minimum = min1;
    if (min2 < minimum) minimum = min2;
    if (min3 < minimum) minimum = min3;
    if (max1 > maximum) maximum = max1;
    if (max2 > maximum) maximum = max2;
    if (max3 > maximum) maximum = max3;

    while (i < length)
    {
        const value = base[i];
        if (value < minimum) minimum = value;
        if (value > maximum) maximum = value;
        ++i;
    }

    return MinMaxFloat(minimum, maximum);
}

private uint bits(float value)
@trusted pure nothrow @nogc
{
    union Repr { float f; uint u; }
    Repr repr;
    repr.f = value;
    return repr.u;
}

private string classify(float value)
{
    if (isNaN(value))
        return "nan";
    if (bits(value) == 0x8000_0000U)
        return "-0";
    if (bits(value) == 0x0000_0000U)
        return "+0";
    return "finite";
}

private void printCase(string name, scope const(float)[] values)
{
    const scalar = minMaxScalar(values);
    const lanes = minMaxFourLane(values);

    writefln(
        "float_semantics case=%s scalar_min=%s:0x%08x scalar_max=%s:0x%08x lane_min=%s:0x%08x lane_max=%s:0x%08x equal_bits=%s",
        name,
        classify(scalar.minimum), bits(scalar.minimum),
        classify(scalar.maximum), bits(scalar.maximum),
        classify(lanes.minimum), bits(lanes.minimum),
        classify(lanes.maximum), bits(lanes.maximum),
        bits(scalar.minimum) == bits(lanes.minimum) &&
            bits(scalar.maximum) == bits(lanes.maximum));
}

void runFloatReductionSemantics()
{
    writeln("=== reduction semantics: float min/max ===");

    const float qnan = float.nan;

    printCase("nan_first", [qnan, 3.0f, -2.0f, 7.0f, 1.0f]);
    printCase("nan_lane1", [3.0f, qnan, -2.0f, 7.0f, 1.0f]);
    printCase("nan_lane2", [3.0f, -2.0f, qnan, 7.0f, 1.0f]);
    printCase("nan_lane3", [3.0f, -2.0f, 7.0f, qnan, 1.0f]);
    printCase("nan_tail", [3.0f, -2.0f, 7.0f, 1.0f, qnan]);
    printCase("nan_multiple", [3.0f, qnan, -2.0f, qnan, 7.0f, 1.0f]);
    printCase("nan_lane_cycle1", [3.0f, 4.0f, qnan, 2.0f, 8.0f, -5.0f, 9.0f, 1.0f, 6.0f]);
    printCase("nan_lane_cycle2", [3.0f, 4.0f, 2.0f, qnan, 8.0f, -5.0f, 9.0f, 1.0f, 6.0f]);
    printCase("nan_lane_cycle3", [3.0f, 4.0f, 2.0f, 8.0f, qnan, -5.0f, 9.0f, 1.0f, 6.0f]);

    printCase("zero_pos_neg", [+0.0f, -0.0f]);
    printCase("zero_neg_pos", [-0.0f, +0.0f]);
    printCase("zero_pos_neg_long", [+0.0f, 2.0f, -0.0f, 1.0f, +0.0f]);
    printCase("zero_neg_pos_long", [-0.0f, 2.0f, +0.0f, 1.0f, -0.0f]);
    printCase("zero_mixed_negative", [-1.0f, +0.0f, -0.0f, -2.0f, +0.0f]);
    printCase("zero_mixed_positive", [1.0f, -0.0f, +0.0f, 2.0f, -0.0f]);

    // Force different lanes to retain different signed-zero extrema before
    // the lane-combine phase.
    printCase("zero_lane_min_pos_first", [+0.0f, 4.0f, -0.0f, 3.0f, 2.0f, +0.0f, -0.0f, 1.0f, 5.0f]);
    printCase("zero_lane_min_neg_first", [-0.0f, 4.0f, +0.0f, 3.0f, 2.0f, -0.0f, +0.0f, 1.0f, 5.0f]);
    printCase("zero_lane_max_pos_first", [+0.0f, -4.0f, -0.0f, -3.0f, -2.0f, +0.0f, -0.0f, -1.0f, -5.0f]);
    printCase("zero_lane_max_neg_first", [-0.0f, -4.0f, +0.0f, -3.0f, -2.0f, -0.0f, +0.0f, -1.0f, -5.0f]);

    // Alternating zeros exercise equality across several lane cycles.
    printCase("zero_alternating_pos", [+0.0f, -0.0f, +0.0f, -0.0f, +0.0f, -0.0f, +0.0f, -0.0f, +0.0f]);
    printCase("zero_alternating_neg", [-0.0f, +0.0f, -0.0f, +0.0f, -0.0f, +0.0f, -0.0f, +0.0f, -0.0f]);
}
