module histogram_codegen_probe;

extern(C) void probeHistogramSlice(
    scope const(ubyte)[] source,
    scope ulong[] histogram
)
@safe nothrow @nogc
{
    assert(histogram.length >= 256);
    histogram[0 .. 256] = 0;
    foreach (value; source)
        ++histogram[value];
}

extern(C) void probeHistogramPointer(
    scope const(ubyte)* source,
    size_t length,
    scope ulong* histogram
)
@system nothrow @nogc
{
    assert(source !is null);
    assert(histogram !is null);

    foreach (bin; 0 .. 256)
        histogram[bin] = 0;

    foreach (i; 0 .. length)
        ++histogram[source[i]];
}

extern(C) void probeHistogramFourLane(
    scope const(ubyte)* source,
    size_t length,
    scope ulong* histogram
)
@system nothrow @nogc
{
    assert(source !is null);
    assert(histogram !is null);

    ulong[256] h0;
    ulong[256] h1;
    ulong[256] h2;
    ulong[256] h3;

    size_t i;
    for (; i + 4 <= length; i += 4)
    {
        ++h0[source[i]];
        ++h1[source[i + 1]];
        ++h2[source[i + 2]];
        ++h3[source[i + 3]];
    }

    foreach (bin; 0 .. 256)
        histogram[bin] = h0[bin] + h1[bin] + h2[bin] + h3[bin];

    for (; i < length; ++i)
        ++histogram[source[i]];
}
