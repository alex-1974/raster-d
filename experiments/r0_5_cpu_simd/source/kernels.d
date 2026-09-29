module kernels;

void copyScalar(
    const(float)[] source,
    float[] destination
)
@safe
pure
nothrow
@nogc
{
    assert(source.length == destination.length);

    foreach (i; 0 .. source.length)
        destination[i] = source[i];
}

void fillScalar(
    float[] destination,
    float value
)
@safe
pure
nothrow
@nogc
{
    foreach (ref element; destination)
        element = value;
}
