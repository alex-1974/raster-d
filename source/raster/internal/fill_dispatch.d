module raster.internal.fill_dispatch;

import raster.writable_view :
    WritableRasterView;


/++
    Fills one selected writable raster plane with one exact sample value.

    M3.3 selects safe Canonical row-slice assignment after validation.
    Other layouts retain the scalar semantic reference traversal for M2.1.

    It deliberately:

    - supports every validated writable affine layout;
    - permits non-injective mappings because every logical coordinate writes
      the same exact T value;
    - performs no allocation;
    - retains no operand;
    - selects no SIMD, scheduler or image-domain policy.

    False means only that planeIndex does not select a destination plane.
+/
package(raster)
bool tryFillRasterPlaneScalar(T)(
    scope ref WritableRasterView!T destination,
    size_t planeIndex,
    T value
)
@safe
nothrow
@nogc
{
    ptrdiff_t rowStrideElements;
    ptrdiff_t sampleStrideElements;

    if (
        !destination.tryExecutionPlaneStrides(
            planeIndex,
            rowStrideElements,
            sampleStrideElements
        )
    )
    {
        return false;
    }

    if (destination.empty)
    {
        return true;
    }

    if (sampleStrideElements == 1)
    {
        /++
            Fills an already-approved Canonical destination plane using its signed row stride and unit sample stride.
        +/
        fillCanonical(destination.executionRegionBase(planeIndex), rowStrideElements,
            destination.width, destination.height, value);
        return true;
    }

    foreach (y; 0 .. destination.height)
    {
        foreach (x; 0 .. destination.width)
        {
            const written =
                destination.trySetSample(
                    planeIndex,
                    x,
                    y,
                    value
                );

            assert(written);
        }
    }

    return true;
}

/++
    Safety: the caller selects a valid, non-empty writable plane with sample
    stride one. Retained backing validation establishes coordinate products,
    signed row offsets and all width samples as reachable writable addresses.
    The returned slice remains scoped to the borrow. Repeated/overlapping rows
    are permitted; no injectivity or persistent noalias property is asserted.
    Only pointer arithmetic and bounded slice construction require trust.
+/
private T[] writeFillRow(T)(return scope T* base, size_t y,
    ptrdiff_t stride, size_t width) @trusted nothrow @nogc
{
    return (base + cast(ptrdiff_t)y * stride)[0 .. width];
}

/++
    Fills an already-approved Canonical destination plane using its signed row stride and unit sample stride.
+/
private void fillCanonical(T)(scope T* base, ptrdiff_t stride,
    size_t width, size_t height, T value) @safe nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        scope auto row = writeFillRow(base, y, stride, width);
        row[] = value;
    }
}
