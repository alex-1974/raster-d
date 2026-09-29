module plane_extraction_codegen_probe;

import mir.ndslice : Universal, Slice;

private void extractSlice(size_t channels)(
    scope const(ubyte)[] source,
    scope ubyte[] target,
    size_t channel
)
@safe pure nothrow @nogc
{
    assert(channel < channels);
    assert(source.length == target.length * channels);

    foreach (i; 0 .. target.length)
        target[i] = source[i * channels + channel];
}

private void extractPointer(size_t channels)(
    scope const(ubyte)[] source,
    scope ubyte[] target,
    size_t channel
)
@trusted pure nothrow @nogc
{
    assert(channel < channels);
    assert(source.length == target.length * channels);

    auto input = source.ptr + channel;
    auto output = target.ptr;

    foreach (i; 0 .. target.length)
        output[i] = input[i * channels];
}

private void extractMir(size_t channels)(
    scope const(ubyte)[] source,
    scope ubyte[] target,
    size_t channel
)
@trusted nothrow @nogc
{
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

extern(C):

void probePlaneSlice3(const(ubyte)[] source, ubyte[] target)
@safe pure nothrow @nogc
{
    extractSlice!3(source, target, 1);
}

void probePlaneSlice4(const(ubyte)[] source, ubyte[] target)
@safe pure nothrow @nogc
{
    extractSlice!4(source, target, 1);
}

void probePlanePointer3(const(ubyte)[] source, ubyte[] target)
@trusted pure nothrow @nogc
{
    extractPointer!3(source, target, 1);
}

void probePlanePointer4(const(ubyte)[] source, ubyte[] target)
@trusted pure nothrow @nogc
{
    extractPointer!4(source, target, 1);
}

void probePlaneMir3(const(ubyte)[] source, ubyte[] target)
@trusted nothrow @nogc
{
    extractMir!3(source, target, 1);
}

void probePlaneMir4(const(ubyte)[] source, ubyte[] target)
@trusted nothrow @nogc
{
    extractMir!4(source, target, 1);
}
