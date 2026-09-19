module imagery.raster.e43b_current_baseline;

import imagery.raster.internal.scalar_pointwise :
    scalarCopyContiguous1D;

import mir.ndslice :
    Contiguous,
    Slice;


alias Source =
    Slice!(const(ubyte)*, 1, Contiguous);

alias Target =
    Slice!(ubyte*, 1, Contiguous);


extern(C)
pragma(inline, false)
bool e43CurrentScalarCopy(
    scope Source source,
    scope Target target
)
@safe
nothrow
@nogc
{
    return scalarCopyContiguous1D(
        source,
        target
    );
}
