/++
    Public raster reduction operations.

    This module exposes semantic operations only. Execution-layout
    classification, Mir adaptation, fixed-lane reduction graphs and kernel
    dispatch remain package-internal.
+/
module imagery.raster.reduction;

import imagery.raster.internal.reduction_dispatch :
    tryStrictFloatToDoubleSum;

import imagery.raster.view :
    RasterView;

/++
    Sums one logical `float` plane into a `double` result using the strict
    row-major reduction semantic.

    All validated resident layouts are semantically supported. A valid empty
    plane succeeds with `sum == 0.0`.

    Returns false only when `planeIndex` does not select a logical source
    plane. On failure `sum` is reset to `0.0`.

    The operation is allocation-free and does not retain `source`.
+/
bool trySumFloatToDouble(
    scope RasterView!float source,
    size_t planeIndex,
    out double sum
)
@safe
nothrow
@nogc
{
    return tryStrictFloatToDoubleSum(
        source,
        planeIndex,
        sum
    );
}

version (unittest)
{
import imagery.raster.descriptor : PlaneDescriptor;
import imagery.raster.region : Region2D;
import imagery.raster.view : makeRasterViewAssumeValidated;

unittest
{
    float[6] storage = [1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr, 3, 2)
    ];

    scope auto source = makeRasterViewAssumeValidated!float(
        descriptors[],
        Region2D(0, 0, 2, 2)
    );

    double sum = -1.0;
    assert(trySumFloatToDouble(source, 0, sum));
    assert(sum == 14.0);
}

unittest
{
    float[1] storage = [42.0f];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr, 1, 1)
    ];

    scope auto source = makeRasterViewAssumeValidated!float(
        descriptors[],
        Region2D(0, 0, 0, 1)
    );

    double sum = -1.0;
    assert(trySumFloatToDouble(source, 0, sum));
    assert(sum == 0.0);
}

unittest
{
    float[1] storage = [7.0f];
    const PlaneDescriptor[1] descriptors =
    [
        PlaneDescriptor(storage.ptr, 1, 1)
    ];

    scope auto source = makeRasterViewAssumeValidated!float(
        descriptors[],
        Region2D(0, 0, 1, 1)
    );

    double sum = 123.0;
    assert(!trySumFloatToDouble(source, 1, sum));
    assert(sum == 0.0);
}

} // version (unittest)
