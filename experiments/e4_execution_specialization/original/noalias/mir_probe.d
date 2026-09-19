module imagery.raster.e43b_mir_probe;

version (LDC)
{
    import ldc.attributes :
        restrict;
}

import mir.ndslice :
    Contiguous,
    Slice;


alias Source =
    Slice!(const(ubyte)*, 1, Contiguous);

alias Target =
    Slice!(ubyte*, 1, Contiguous);


extern(C)
pragma(inline, false)
bool e43CopyMirUnknown(
    scope Source source,
    scope Target target
)
@safe
nothrow
@nogc
{
    if (source.length!0 != target.length!0)
        return false;

    foreach (i; 0 .. source.length!0)
    {
        target[i] =
            source[i];
    }

    return true;
}


extern(C)
pragma(inline, false)
bool e43CopyMirRestrict(
    @restrict scope Source source,
    @restrict scope Target target
)
@safe
nothrow
@nogc
{
    if (source.length!0 != target.length!0)
        return false;

    foreach (i; 0 .. source.length!0)
    {
        target[i] =
            source[i];
    }

    return true;
}
