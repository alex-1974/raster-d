module histogram_bench;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln;

private enum size_t binCount = 256;
private enum size_t repetitions = 12;
private enum size_t warmups = 2;

private __gshared ulong sink;
private __gshared ulong invocation;

private void consume(scope const(ulong)[binCount] histogram)
@trusted nothrow @nogc
{
    ulong value = ++invocation * 0x9e3779b97f4a7c15UL;
    foreach (i; 0 .. binCount)
        value = (value ^ (histogram[i] + i * 0x100000001b3UL)) * 0x9e3779b185ebca87UL;
    sink ^= value;
}

private void histogramSlice(scope const(ubyte)[] source, scope ulong[binCount] histogram)
@safe nothrow @nogc
{
    histogram[] = 0;
    foreach (value; source)
        ++histogram[value];
}

private void histogramPointer(scope const(ubyte)[] source, scope ulong[binCount] histogram)
@trusted nothrow @nogc
{
    histogram[] = 0;
    const p = source.ptr;
    foreach (i; 0 .. source.length)
        ++histogram[p[i]];
}

private void histogramFourLane(scope const(ubyte)[] source, scope ulong[binCount] histogram)
@safe nothrow @nogc
{
    ulong[binCount] h0;
    ulong[binCount] h1;
    ulong[binCount] h2;
    ulong[binCount] h3;

    size_t i;
    for (; i + 4 <= source.length; i += 4)
    {
        ++h0[source[i]];
        ++h1[source[i + 1]];
        ++h2[source[i + 2]];
        ++h3[source[i + 3]];
    }

    histogram[] = 0;
    foreach (bin; 0 .. binCount)
        histogram[bin] = h0[bin] + h1[bin] + h2[bin] + h3[bin];

    for (; i < source.length; ++i)
        ++histogram[source[i]];
}

private void fillCorpus(scope ubyte[] source)
@safe nothrow @nogc
{
    foreach (i; 0 .. source.length)
        source[i] = cast(ubyte)((i * 131 + (i >> 3) * 17 + (i >> 11) * 29) & 0xff);
}

private bool equalHistogram(scope const(ulong)[binCount] a, scope const(ulong)[binCount] b)
@safe pure nothrow @nogc
{
    return a[] == b[];
}

private long median(scope long[] values)
{
    sort(values);
    return values[values.length / 2];
}

private long measure(void delegate() operation)
{
    const start = MonoTime.currTime;
    operation();
    return (MonoTime.currTime - start).total!"nsecs";
}

private void printRaw(string name, size_t elements, scope const(long)[] values)
{
    import std.array : join;
    import std.conv : to;
    auto parts = new string[values.length];
    foreach (i, value; values)
        parts[i] = value.to!string;
    writefln("histogram_u8 elements=%s %s_raw_ns=%s", elements, name, parts.join(","));
}

private int runCase(size_t elements)
{
    auto source = new ubyte[elements];
    fillCorpus(source);

    ulong[binCount] reference;
    ulong[binCount] candidate;
    histogramSlice(source, reference);
    histogramPointer(source, candidate);
    if (!equalHistogram(reference, candidate))
        return 1;
    histogramFourLane(source, candidate);
    if (!equalHistogram(reference, candidate))
        return 1;

    foreach (_; 0 .. warmups)
    {
        histogramSlice(source, candidate); consume(candidate);
        histogramPointer(source, candidate); consume(candidate);
        histogramFourLane(source, candidate); consume(candidate);
        histogramPointer(source, candidate); consume(candidate);
    }

    long[repetitions] sliceSamples;
    long[repetitions] pointerSamples;
    long[repetitions] fourLaneSamples;
    long[repetitions] pointerControlSamples;

    foreach (r; 0 .. repetitions)
    {
        const rotation = r & 3;
        foreach (step; 0 .. 4)
        {
            const which = (rotation + step) & 3;
            final switch (which)
            {
                case 0:
                    sliceSamples[r] = measure({ histogramSlice(source, candidate); consume(candidate); });
                    break;
                case 1:
                    pointerSamples[r] = measure({ histogramPointer(source, candidate); consume(candidate); });
                    break;
                case 2:
                    fourLaneSamples[r] = measure({ histogramFourLane(source, candidate); consume(candidate); });
                    break;
                case 3:
                    pointerControlSamples[r] = measure({ histogramPointer(source, candidate); consume(candidate); });
                    break;
            }
        }
    }

    auto s = sliceSamples;
    auto p = pointerSamples;
    auto f = fourLaneSamples;
    auto pc = pointerControlSamples;
    writefln(
        "histogram_u8 elements=%s slice_ns=%s pointer_ns=%s four_lane_ns=%s pointer_control_ns=%s sink=%s",
        elements, median(s[]), median(p[]), median(f[]), median(pc[]), sink);
    printRaw("slice", elements, sliceSamples[]);
    printRaw("pointer", elements, pointerSamples[]);
    printRaw("four_lane", elements, fourLaneSamples[]);
    printRaw("pointer_control", elements, pointerControlSamples[]);
    return 0;
}

int runHistogramMatrix()
{
    foreach (elements; [65_536UL, 1_048_576UL, 8_388_608UL])
        if (runCase(cast(size_t) elements) != 0)
            return 1;
    return 0;
}
