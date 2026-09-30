module raster.internal.fill_dispatch;

import raster.writable_view :
    WritableRasterView;


/++
    Fills one selected writable raster plane with one exact sample value.

    This is the scalar semantic reference path for M2.1.

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
