module plane_extraction_bench;

import harness : measureFour;
import mir.ndslice : Universal, Slice;
import std.stdio : writefln, writeln;

enum size_t extractionRepetitions = 12;
enum size_t extractionWarmupRounds = 2;

private ulong fingerprint(const(ubyte)[] values)
@safe pure nothrow @nogc
{
    ulong hash = 0xcbf29ce484222325UL;
    foreach (value; values)
    {
        hash ^= value;
        hash *= 0x100000001b3UL;
    }
    return hash;
}

private void extractSlice(
    scope const(ubyte)[] source,
    scope ubyte[] target,
    size_t channels,
    size_t channel
)
@safe pure nothrow @nogc
{
    assert(channels != 0);
    assert(channel < channels);
    assert(source.length == target.length * channels);

    foreach (i; 0 .. target.length)
        target[i] = source[i * channels + channel];
}

private void extractPointer(
    scope const(ubyte)[] source,
    scope ubyte[] target,
    size_t channels,
    size_t channel
)
@trusted pure nothrow @nogc
{
    assert(channels != 0);
    assert(channel < channels);
    assert(source.length == target.length * channels);

    auto input = source.ptr + channel;
    auto output = target.ptr;

    foreach (i; 0 .. target.length)
        output[i] = input[i * channels];
}

private void extractMir(
    scope const(ubyte)[] source,
    scope ubyte[] target,
    size_t channels,
    size_t channel
)
@trusted nothrow @nogc
{
    assert(channels != 0);
    assert(channel < channels);
    assert(source.length == target.length * channels);

    auto plane = Slice!(const(ubyte)*, 1, Universal)(
        [target.length],
        [cast(ptrdiff_t) channels],
        source.ptr + channel
    );

    foreach (i; 0 .. target.length)
        target[i] = plane[i];
}

private int runCase(size_t pixels, size_t channels, size_t channel)
{
    assert(pixels != 0);
    assert(channels == 3 || channels == 4);
    assert(channel < channels);

    auto source = new ubyte[pixels * channels];
    auto destination = new ubyte[pixels];

    foreach (i; 0 .. source.length)
        source[i] = cast(ubyte) ((i * 131 + 17) & 0xff);

    extractSlice(source, destination, channels, channel);
    const expected = fingerprint(destination);

    extractMir(source, destination, channels, channel);
    if (fingerprint(destination) != expected)
        return 1;

    extractPointer(source, destination, channels, channel);
    if (fingerprint(destination) != expected)
        return 1;

    const samples = measureFour!(
        () => extractMir(source, destination, channels, channel),
        () => extractSlice(source, destination, channels, channel),
        () => extractPointer(source, destination, channels, channel),
        () => extractSlice(source, destination, channels, channel)
    )(extractionRepetitions, extractionWarmupRounds);

    if (fingerprint(destination) != expected)
    {
        writefln(
            "plane_extract postflight failed pixels=%s channels=%s channel=%s",
            pixels, channels, channel
        );
        return 1;
    }

    writefln(
        "plane_extract pixels=%s channels=%s channel=%s mir_ns=%s slice_ns=%s pointer_ns=%s slice_control_ns=%s",
        pixels, channels, channel,
        samples.first.median,
        samples.second.median,
        samples.third.median,
        samples.fourth.median
    );
    writefln(
        "plane_extract pixels=%s channels=%s mir_raw_ns=%(%s,%)",
        pixels, channels, samples.first.nanoseconds
    );
    writefln(
        "plane_extract pixels=%s channels=%s slice_raw_ns=%(%s,%)",
        pixels, channels, samples.second.nanoseconds
    );
    writefln(
        "plane_extract pixels=%s channels=%s pointer_raw_ns=%(%s,%)",
        pixels, channels, samples.third.nanoseconds
    );
    writefln(
        "plane_extract pixels=%s channels=%s slice_control_raw_ns=%(%s,%) fingerprint=%016x",
        pixels, channels, samples.fourth.nanoseconds, expected
    );

    return 0;
}

int runPlaneExtractionMatrix()
{
    static immutable size_t[] sizes = [
        64 * 1024,
        1024 * 1024,
        8 * 1024 * 1024
    ];

    writeln("=== research interleaved plane extraction matrix ===");

    foreach (pixels; sizes)
    {
        if (runCase(pixels, 3, 1) != 0)
            return 1;
        if (runCase(pixels, 4, 1) != 0)
            return 1;
    }

    return 0;
}
