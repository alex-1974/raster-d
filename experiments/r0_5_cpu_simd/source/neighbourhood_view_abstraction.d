module raster.internal.r0_5_neighbourhood_view_bench;

import raster.descriptor : PlaneDescriptor;
import raster.internal.execution_layout : PlaneExecutionLayout2D, PlaneExecutionTraits;
import raster.internal.mir_adapter : asMirCanonical;
import raster.internal.mir_target_adapter : asMirTargetContiguousFlat;
import raster.internal.target : RasterTargetPlane, tryBorrowContiguousTarget;
import raster.region : Region2D;
import raster.resource : ResourceAccess, ResourceEntry;
import raster.validation : validateRasterBackingLayout;
import raster.view : RasterView, makeRasterViewAssumeValidated;

struct CanonicalNeighbourhoodFixture
{
    ResourceEntry[1] resources;
    PlaneDescriptor[1] descriptors;
    RasterView!float source;
    RasterTargetPlane!float target;
}

CanonicalNeighbourhoodFixture makeCanonicalNeighbourhoodFixture(
    float[] sourceStorage,
    float[] targetStorage,
    size_t width,
    size_t height,
    size_t pitch,
    bool negativeRows
)
@trusted
{
    assert(width != 0 && height != 0);
    assert(pitch >= width + 2);
    assert(sourceStorage.length == pitch * (height + 2));
    assert(targetStorage.length == width * height);

    CanonicalNeighbourhoodFixture result;
    result.resources[0] = ResourceEntry(
        sourceStorage.ptr,
        sourceStorage.length * float.sizeof,
        null,
        null,
        ResourceAccess.readOnly
    );

    const base = negativeRows
        ? sourceStorage.ptr + (height + 1) * pitch
        : sourceStorage.ptr;

    result.descriptors[0] = PlaneDescriptor(
        base,
        negativeRows ? -cast(ptrdiff_t)pitch : cast(ptrdiff_t)pitch,
        1
    );

    const sourceRegion = Region2D(0, 0, width + 2, height + 2);
    const validation = validateRasterBackingLayout!float(
        result.resources[],
        result.descriptors[],
        sourceRegion
    );
    assert(validation.ok);

    result.source = makeRasterViewAssumeValidated!float(
        result.descriptors[],
        sourceRegion
    );

    PlaneExecutionTraits traits;
    assert(result.source.tryPlaneExecutionTraits(0, traits));
    assert(traits.layout2D == PlaneExecutionLayout2D.canonical);

    bool targetOk;
    result.target = tryBorrowContiguousTarget(
        targetStorage,
        width,
        height,
        targetOk
    );
    assert(targetOk);
    return result;
}

bool box3CanonicalView(
    scope RasterView!float source,
    scope RasterTargetPlane!float target
)
@safe
nothrow
@nogc
{
    if (source.width != target.width + 2 ||
        source.height != target.height + 2)
        return false;

    auto input = asMirCanonical(source, 0);
    auto output = asMirTargetContiguousFlat(target);
    const width = target.width;
    const height = target.height;

    foreach (y; 0 .. height)
        foreach (x; 0 .. width)
            output[y * width + x] =
                input[y, x] + input[y, x + 1] + input[y, x + 2] +
                input[y + 1, x] + input[y + 1, x + 1] + input[y + 1, x + 2] +
                input[y + 2, x] + input[y + 2, x + 1] + input[y + 2, x + 2];

    return true;
}
