module codegen_copy_probe;

import mir.ndslice : Contiguous, Slice;

alias FlatConst(T) = Slice!(const(T)*, 1, Contiguous);
alias FlatMutable(T) = Slice!(T*, 1, Contiguous);

extern(C) void probeScalar(
    const(float)[] source,
    float[] destination
)
@safe nothrow @nogc
{
    assert(source.length == destination.length);
    foreach (i; 0 .. source.length)
        destination[i] = source[i];
}

extern(C) void probeSlice(
    const(float)[] source,
    float[] destination
)
@safe nothrow @nogc
{
    assert(source.length == destination.length);
    destination[] = source[];
}

extern(C) void probePointer(
    scope const(float)* source,
    scope float* destination,
    size_t length
)
@trusted nothrow @nogc
{
    foreach (i; 0 .. length)
        destination[i] = source[i];
}

extern(C) bool probeMir(
    FlatConst!float source,
    FlatMutable!float destination
)
@safe nothrow @nogc
{
    if (source.length!0 != destination.length!0)
        return false;

    foreach (i; 0 .. source.length!0)
        destination[i] = source[i];

    return true;
}
