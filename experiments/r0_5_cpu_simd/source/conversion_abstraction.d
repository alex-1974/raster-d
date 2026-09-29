module raster.internal.r0_5_conversion_bench;

import raster.descriptor : PlaneDescriptor;
import raster.internal.conversion_dispatch : tryConvertUbyteToFloatContiguous1D;
import raster.internal.mir_adapter : asMirContiguousFlat;
import raster.internal.mir_target_adapter : asMirTargetContiguousFlat;
import raster.internal.scalar_conversion : scalarConvertUbyteToFloatContiguous1D;
import raster.internal.target : RasterTargetPlane, tryBorrowContiguousTarget;
import raster.region : Region2D;
import raster.view : RasterView, makeRasterViewAssumeValidated;

struct ConversionFixture
{
    PlaneDescriptor[1] descriptors;
    RasterView!ubyte source;
    RasterTargetPlane!float target;
}

ConversionFixture makeConversionFixture(
    const(ubyte)[] sourceStorage,
    float[] targetStorage,
    size_t width,
    size_t height
)
{
    assert(width != 0);
    assert(height != 0);
    assert(width <= size_t.max / height);
    assert(width * height == sourceStorage.length);
    assert(sourceStorage.length == targetStorage.length);

    ConversionFixture result;

    result.descriptors[0] = PlaneDescriptor(
        sourceStorage.ptr,
        cast(ptrdiff_t) width,
        1
    );

    result.source = makeRasterViewAssumeValidated!ubyte(
        result.descriptors[],
        Region2D(0, 0, width, height)
    );

    bool success;
    result.target = tryBorrowContiguousTarget(
        targetStorage,
        width,
        height,
        success
    );
    assert(success);

    return result;
}

bool convertKernel(scope ConversionFixture fixture)
@safe nothrow @nogc
{
    return scalarConvertUbyteToFloatContiguous1D(
        asMirContiguousFlat(fixture.source, 0),
        asMirTargetContiguousFlat(fixture.target)
    );
}

bool convertDispatch(scope ConversionFixture fixture)
@safe nothrow @nogc
{
    return tryConvertUbyteToFloatContiguous1D(
        fixture.source,
        0,
        fixture.target
    ).ok;
}


bool convertSlice(scope const(ubyte)[] source, scope float[] target)
@safe pure nothrow @nogc
{
    if (source.length != target.length)
        return false;

    foreach (i; 0 .. source.length)
        target[i] = cast(float) source[i];

    return true;
}

bool convertPointer(scope const(ubyte)[] source, scope float[] target)
@trusted pure nothrow @nogc
{
    if (source.length != target.length)
        return false;

    const(ubyte)* input = source.ptr;
    float* output = target.ptr;

    foreach (i; 0 .. source.length)
        output[i] = cast(float) input[i];

    return true;
}
