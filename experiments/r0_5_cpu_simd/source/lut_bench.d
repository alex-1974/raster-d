module lut_bench;

import corpus : fingerprint;
import harness : measureFour;
import std.stdio : writefln, writeln;

enum size_t repetitions = 12;
enum size_t warmupRounds = 2;
enum size_t lutSize = 256;

private void transformSlice(scope const(ubyte)[] source, scope const(float)[] lut, scope float[] target)
@safe pure nothrow @nogc
{
    assert(lut.length == lutSize);
    assert(source.length == target.length);
    foreach (i; 0 .. target.length)
        target[i] = lut[source[i]];
}

private void transformPointer(scope const(ubyte)[] source, scope const(float)[] lut, scope float[] target)
@trusted pure nothrow @nogc
{
    assert(lut.length == lutSize);
    assert(source.length == target.length);
    foreach (i; 0 .. target.length)
        target.ptr[i] = lut.ptr[source.ptr[i]];
}

private int runCase(size_t elements)
{
    auto source = new ubyte[elements];
    auto lut = new float[lutSize];
    auto target = new float[elements];

    foreach (i; 0 .. source.length)
        source[i] = cast(ubyte)((i * 131 + (i >> 3) * 17 + 29) & 0xff);
    foreach (i; 0 .. lut.length)
        lut[i] = (cast(float) i - 127.5f) * 0.0078125f;

    transformSlice(source, lut, target);
    const expected = fingerprint(target);

    transformPointer(source, lut, target);
    if (fingerprint(target) != expected)
    {
        writeln("lut pointer correctness preflight failed");
        return 1;
    }

    const samples = measureFour!(
        () => transformSlice(source, lut, target),
        () => transformPointer(source, lut, target),
        () => transformSlice(source, lut, target),
        () => transformPointer(source, lut, target)
    )(repetitions, warmupRounds);

    if (fingerprint(target) != expected)
    {
        writeln("lut benchmark postflight failed");
        return 1;
    }

    writefln(
        "lut_transform elements=%s slice_ns=%s pointer_ns=%s slice_control_ns=%s pointer_control_ns=%s",
        elements,
        samples.first.median,
        samples.second.median,
        samples.third.median,
        samples.fourth.median
    );
    return 0;
}

int runLutMatrix()
{
    writeln("=== LUT scalar transform matrix ===");
    foreach (elements; [64 * 1024, 1024 * 1024, 8 * 1024 * 1024])
        if (runCase(elements) != 0)
            return 1;
    return 0;
}
