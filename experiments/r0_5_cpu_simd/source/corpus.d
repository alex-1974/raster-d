module corpus;

ulong nextRandom(ref ulong state)
@safe
pure
nothrow
@nogc
{
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return state;
}

void fillDeterministic(float[] values, ulong seed)
@safe
pure
nothrow
@nogc
{
    auto state = seed;

    foreach (ref value; values)
    {
        const bits = nextRandom(state);
        value = cast(float)(bits & 0xffffUL) * (1.0f / 65535.0f);
    }
}

ulong fingerprint(const(float)[] values)
@safe
pure
nothrow
@nogc
{
    ulong hash = 1469598103934665603UL;

    foreach (value; values)
    {
        import std.bitmanip : FloatRep;

        FloatRep rep;
        rep.value = value;
        hash ^= cast(ulong)rep.fraction;
        hash ^= cast(ulong)rep.exponent << 23;
        hash ^= cast(ulong)rep.sign << 31;
        hash *= 1099511628211UL;
    }

    return hash;
}
