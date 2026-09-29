module raster.internal.r0_5_abstraction_bench;

import mir.ndslice : Contiguous, Slice;

import raster.descriptor : PlaneDescriptor;
import raster.internal.copy_dispatch : tryCopyNonOverlappingContiguous1D;
import raster.internal.mir_adapter : asMirContiguousFlat;
import raster.internal.mir_target_adapter : asMirTargetContiguousFlat;
import raster.internal.scalar_pointwise : scalarCopyContiguous1D;
import raster.internal.target : RasterTargetPlane, tryBorrowContiguousTarget;
import raster.region : Region2D;
import raster.view : RasterView, makeRasterViewAssumeValidated;

struct ContiguousCopyFixture(T)
{
    PlaneDescriptor[1] descriptors;
    RasterView!T source;
    RasterTargetPlane!T target;
}

ContiguousCopyFixture!T makeContiguousCopyFixture(T)(
    const(T)[] sourceStorage,
    T[] targetStorage,
    size_t width,
    size_t height
)
{
    assert(width != 0);
    assert(height != 0);
    assert(width <= size_t.max / height);
    assert(width * height == sourceStorage.length);
    assert(sourceStorage.length == targetStorage.length);

    ContiguousCopyFixture!T result;

    result.descriptors[0] =
        PlaneDescriptor(
            sourceStorage.ptr,
            cast(ptrdiff_t) width,
            1
        );

    result.source =
        makeRasterViewAssumeValidated!T(
            result.descriptors[],
            Region2D(
                0,
                0,
                width,
                height
            )
        );

    bool success;

    result.target =
        tryBorrowContiguousTarget(
            targetStorage,
            width,
            height,
            success
        );

    assert(success);

    return result;
}

bool copyMirContiguous1D(T)(
    scope RasterView!T source,
    scope RasterTargetPlane!T target
)
@safe
nothrow
@nogc
{
    return scalarCopyContiguous1D(
        asMirContiguousFlat(
            source,
            0
        ),
        asMirTargetContiguousFlat(
            target
        )
    );
}

bool copyCheckedContiguous1D(T)(
    scope RasterView!T source,
    scope RasterTargetPlane!T target
)
@safe
nothrow
@nogc
{
    return tryCopyNonOverlappingContiguous1D(
        source,
        0,
        target
    ).ok;
}
