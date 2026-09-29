module reduction_codegen_probe;

private struct MinMaxUbyte
{
    ubyte minimum;
    ubyte maximum;
}

private MinMaxUbyte minMaxPointer(
    scope const(ubyte)* source,
    size_t length
)
@system pure nothrow @nogc
{
    ubyte minimum = source[0];
    ubyte maximum = source[0];

    foreach (i; 1 .. length)
    {
        const value = source[i];
        if (value < minimum)
            minimum = value;
        if (value > maximum)
            maximum = value;
    }

    return MinMaxUbyte(minimum, maximum);
}

private MinMaxUbyte minMaxFourLane(
    scope const(ubyte)* source,
    size_t length
)
@system pure nothrow @nogc
{
    ubyte min0 = source[0], max0 = source[0];
    ubyte min1 = min0, max1 = max0;
    ubyte min2 = min0, max2 = max0;
    ubyte min3 = min0, max3 = max0;

    size_t i = 1;
    while (length - i >= 4)
    {
        const v0 = source[i];
        const v1 = source[i + 1];
        const v2 = source[i + 2];
        const v3 = source[i + 3];

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
        const value = source[i];
        if (value < minimum) minimum = value;
        if (value > maximum) maximum = value;
        ++i;
    }

    return MinMaxUbyte(minimum, maximum);
}

extern(C):

ushort probeMinMaxPointer(const(ubyte)* source, size_t length)
@system pure nothrow @nogc
{
    const result = minMaxPointer(source, length);
    return cast(ushort)((cast(ushort) result.minimum << 8) | result.maximum);
}

ushort probeMinMaxFourLane(const(ubyte)* source, size_t length)
@system pure nothrow @nogc
{
    const result = minMaxFourLane(source, length);
    return cast(ushort)((cast(ushort) result.minimum << 8) | result.maximum);
}
