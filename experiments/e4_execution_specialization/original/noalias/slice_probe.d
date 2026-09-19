module slice_probe;

version (LDC)
{
    import ldc.attributes :
        restrict;
}


extern(C)
pragma(inline, false)
void e43CopySliceUnknown(
    scope const(ubyte)[] source,
    scope ubyte[] target
)
@safe
nothrow
@nogc
{
    const length =
        source.length < target.length
        ? source.length
        : target.length;

    foreach (i; 0 .. length)
    {
        target[i] =
            source[i];
    }
}


extern(C)
pragma(inline, false)
void e43CopySliceRestrict(
    @restrict scope const(ubyte)[] source,
    @restrict scope ubyte[] target
)
@safe
nothrow
@nogc
{
    const length =
        source.length < target.length
        ? source.length
        : target.length;

    foreach (i; 0 .. length)
    {
        target[i] =
            source[i];
    }
}
