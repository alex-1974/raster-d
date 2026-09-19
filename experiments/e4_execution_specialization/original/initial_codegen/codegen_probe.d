module imagery.raster.internal.codegen_probe;

import imagery.raster.internal.scalar_kernels :
    scalarSumContiguous1D;

import imagery.raster.internal.scalar_pointwise :
    scalarCopyContiguous1D;

import mir.ndslice :
    Contiguous,
    Slice;


/*
 * --------------------------------------------------------------------------
 * COPY: E3c/Mir path
 * --------------------------------------------------------------------------
 */

extern(C)
bool d_imagery_copy_u8_mir(
    const(ubyte)* source,
    ubyte* target,
    size_t length
)
@system
nothrow
@nogc
{
    auto sourceSlice =
        Slice!(
            const(ubyte)*,
            1,
            Contiguous
        )(
            [length],
            source
        );

    auto targetSlice =
        Slice!(
            ubyte*,
            1,
            Contiguous
        )(
            [length],
            target
        );

    return scalarCopyContiguous1D(
        sourceSlice,
        targetSlice
    );
}


/*
 * Raw reference with the same forward traversal semantics.
 */
extern(C)
bool d_imagery_copy_u8_raw(
    const(ubyte)* source,
    ubyte* target,
    size_t length
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. length)
    {
        target[i] =
            source[i];
    }

    return true;
}


/*
 * --------------------------------------------------------------------------
 * INTEGER REDUCTION: E3a/Mir path
 * --------------------------------------------------------------------------
 */

extern(C)
ulong d_imagery_sum_u8_u64_mir(
    const(ubyte)* source,
    size_t length
)
@system
nothrow
@nogc
{
    auto sourceSlice =
        Slice!(
            const(ubyte)*,
            1,
            Contiguous
        )(
            [length],
            source
        );

    return scalarSumContiguous1D!ulong(
        sourceSlice
    );
}


/*
 * Raw integer-reduction reference.
 */
extern(C)
ulong d_imagery_sum_u8_u64_raw(
    const(ubyte)* source,
    size_t length
)
@system
nothrow
@nogc
{
    ulong total = 0;

    foreach (i; 0 .. length)
    {
        total +=
            source[i];
    }

    return total;
}


/*
 * --------------------------------------------------------------------------
 * FLOATING-POINT REDUCTION: E3a/Mir path
 * --------------------------------------------------------------------------
 */

extern(C)
double d_imagery_sum_f32_f64_mir(
    const(float)* source,
    size_t length
)
@system
nothrow
@nogc
{
    auto sourceSlice =
        Slice!(
            const(float)*,
            1,
            Contiguous
        )(
            [length],
            source
        );

    return scalarSumContiguous1D!double(
        sourceSlice
    );
}


/*
 * Raw floating-point reference with the same strict accumulation order.
 */
extern(C)
double d_imagery_sum_f32_f64_raw(
    const(float)* source,
    size_t length
)
@system
nothrow
@nogc
{
    double total = 0.0;

    foreach (i; 0 .. length)
    {
        total +=
            source[i];
    }

    return total;
}
