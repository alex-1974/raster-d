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


/++
    R0.5f research candidate.

    Keeps RasterView/RasterTargetPlane as the semantic boundary, then extracts
    already-validated execution metadata once and runs a narrow trusted
    check-free kernel. This is not a public pointer API and establishes no
    persistent noalias capability.
+/
bool box3CanonicalTrusted(
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

    PlaneExecutionTraits traits;
    if (!source.tryPlaneExecutionTraits(0, traits) ||
        traits.layout2D == PlaneExecutionLayout2D.universal)
        return false;

    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
    if (!source.tryExecutionPlaneStrides(0, rowStride, sampleStride) ||
        sampleStride != 1)
        return false;

    const src = source.executionRegionBase(0);
    auto dst = target.executionBase();
    if (src is null || dst is null)
        return false;

    box3CanonicalTrustedUnchecked(
        src, rowStride, dst, target.width, target.height
    );
    return true;
}

private void box3CanonicalTrustedUnchecked(
    scope const(float)* src,
    ptrdiff_t rowStride,
    scope float* dst,
    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    if (rowStride >= 0)
    {
        const pitch = cast(size_t) rowStride;
        foreach (y; 0 .. height)
        {
            const r0 = src + y * pitch;
            const r1 = r0 + pitch;
            const r2 = r1 + pitch;
            auto dstRow = dst + y * width;
            foreach (x; 0 .. width)
                dstRow[x] =
                    r0[x] + r0[x + 1] + r0[x + 2] +
                    r1[x] + r1[x + 1] + r1[x + 2] +
                    r2[x] + r2[x + 1] + r2[x + 2];
        }
    }
    else
    {
        /*
         * Branch once, outside the hot loops.  The negative Canonical
         * contract remains unchanged; only the execution spelling uses a
         * positive pitch magnitude and pointer subtraction.
         *
         * Validation has already excluded ptrdiff_t.min for a traversed
         * multi-row layout because the represented backing range must be
         * reachable. Keep the negation here inside this research-only trusted
         * boundary rather than changing the public layout classifier.
         */
        assert(rowStride != ptrdiff_t.min);
        const pitch = cast(size_t)(-rowStride);
        foreach (y; 0 .. height)
        {
            const r0 = src - y * pitch;
            const r1 = r0 - pitch;
            const r2 = r1 - pitch;
            auto dstRow = dst + y * width;
            foreach (x; 0 .. width)
                dstRow[x] =
                    r0[x] + r0[x + 1] + r0[x + 2] +
                    r1[x] + r1[x + 1] + r1[x + 2] +
                    r2[x] + r2[x + 1] + r2[x + 2];
        }
    }
}


/++
    R0.5f LDC direction control.

    For negative Canonical rows only, traverse logical output rows in reverse
    order so source row addresses advance physically forward. Each output
    sample keeps the exact same nine-load/eight-add expression and is written
    to its original logical destination row.
+/
bool box3CanonicalNegativePhysicalForward(
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

    PlaneExecutionTraits traits;
    if (!source.tryPlaneExecutionTraits(0, traits) ||
        traits.layout2D == PlaneExecutionLayout2D.universal)
        return false;

    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
    if (!source.tryExecutionPlaneStrides(0, rowStride, sampleStride) ||
        sampleStride != 1 || rowStride >= 0 || rowStride == ptrdiff_t.min)
        return false;

    const src = source.executionRegionBase(0);
    auto dst = target.executionBase();
    if (src is null || dst is null)
        return false;

    box3NegativePhysicalForwardUnchecked(
        src, cast(size_t)(-rowStride), dst, target.width, target.height
    );
    return true;
}

private void box3NegativePhysicalForwardUnchecked(
    scope const(float)* src,
    size_t pitch,
    scope float* dst,
    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    foreach_reverse (y; 0 .. height)
    {
        const r0 = src - y * pitch;
        const r1 = r0 - pitch;
        const r2 = r1 - pitch;
        auto dstRow = dst + y * width;
        foreach (x; 0 .. width)
            dstRow[x] =
                r0[x] + r0[x + 1] + r0[x + 2] +
                r1[x] + r1[x + 1] + r1[x + 2] +
                r2[x] + r2[x + 1] + r2[x + 2];
    }
}


/++
    R0.5f row-kernel specialization candidate.

    Keep signed Canonical row traversal in the validated outer execution layer,
    but present the vectorizable inner operation only with three concrete row
    pointers and one destination row. This removes signed-stride arithmetic
    from the loop LLVM must prove safe to vectorize.
+/
bool box3CanonicalRowKernel(
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

    PlaneExecutionTraits traits;
    if (!source.tryPlaneExecutionTraits(0, traits) ||
        traits.layout2D == PlaneExecutionLayout2D.universal)
        return false;

    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
    if (!source.tryExecutionPlaneStrides(0, rowStride, sampleStride) ||
        sampleStride != 1)
        return false;

    const src = source.executionRegionBase(0);
    auto dst = target.executionBase();
    if (src is null || dst is null)
        return false;

    box3CanonicalRowsUnchecked(
        src, rowStride, dst, target.width, target.height
    );
    return true;
}

private void box3CanonicalRowsUnchecked(
    scope const(float)* src,
    ptrdiff_t rowStride,
    scope float* dst,
    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    auto r0 = src;
    auto r1 = src + rowStride;
    auto r2 = r1 + rowStride;
    auto dstRow = dst;

    foreach (_; 0 .. height)
    {
        box3RowUnchecked(r0, r1, r2, dstRow, width);
        r0 += rowStride;
        r1 += rowStride;
        r2 += rowStride;
        dstRow += width;
    }
}

private void box3RowUnchecked(
    scope const(float)* r0,
    scope const(float)* r1,
    scope const(float)* r2,
    scope float* dstRow,
    size_t width
)
@system
pure
nothrow
@nogc
{
    foreach (x; 0 .. width)
        dstRow[x] =
            r0[x] + r0[x + 1] + r0[x + 2] +
            r1[x] + r1[x + 1] + r1[x + 2] +
            r2[x] + r2[x + 1] + r2[x + 2];
}


/++
    R0.5f causal control for compiler inlining.

    Identical execution decomposition to box3CanonicalRowKernel, except the
    inner row kernel is explicitly kept out of line. This is research evidence
    only; pragma(inline, false) is not proposed as a production policy.
+/
bool box3CanonicalRowKernelNoInline(
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

    PlaneExecutionTraits traits;
    if (!source.tryPlaneExecutionTraits(0, traits) ||
        traits.layout2D == PlaneExecutionLayout2D.universal)
        return false;

    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
    if (!source.tryExecutionPlaneStrides(0, rowStride, sampleStride) ||
        sampleStride != 1)
        return false;

    const src = source.executionRegionBase(0);
    auto dst = target.executionBase();
    if (src is null || dst is null)
        return false;

    box3CanonicalRowsNoInlineUnchecked(
        src, rowStride, dst, target.width, target.height
    );
    return true;
}

private void box3CanonicalRowsNoInlineUnchecked(
    scope const(float)* src,
    ptrdiff_t rowStride,
    scope float* dst,
    size_t width,
    size_t height
)
@trusted
nothrow
@nogc
{
    auto r0 = src;
    auto r1 = src + rowStride;
    auto r2 = r1 + rowStride;
    auto dstRow = dst;

    foreach (_; 0 .. height)
    {
        box3RowNoInlineUnchecked(r0, r1, r2, dstRow, width);
        r0 += rowStride;
        r1 += rowStride;
        r2 += rowStride;
        dstRow += width;
    }
}


/++
    R0.5g research-only row-range entry.

    The semantic RasterView/RasterTargetPlane validation remains identical to
    the serial row-kernel path.  Callers may assign disjoint output row ranges
    to independent workers.  This function creates no threads and establishes
    no scheduling policy.

    noInline selects the already-qualified R0.5f inner-row source shape.  The
    arithmetic graph is otherwise identical.
+/
bool box3CanonicalRowRange(
    scope RasterView!float source,
    scope RasterTargetPlane!float target,
    size_t rowBegin,
    size_t rowEnd,
    bool noInline
)
@safe
nothrow
@nogc
{
    if (source.width != target.width + 2 ||
        source.height != target.height + 2 ||
        rowBegin > rowEnd ||
        rowEnd > target.height)
        return false;

    PlaneExecutionTraits traits;
    if (!source.tryPlaneExecutionTraits(0, traits) ||
        traits.layout2D == PlaneExecutionLayout2D.universal)
        return false;

    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
    if (!source.tryExecutionPlaneStrides(0, rowStride, sampleStride) ||
        sampleStride != 1)
        return false;

    const src = source.executionRegionBase(0);
    auto dst = target.executionBase();
    if (src is null || dst is null)
        return false;

    box3CanonicalRowRangeUnchecked(
        src, rowStride, dst, target.width,
        rowBegin, rowEnd, noInline
    );
    return true;
}

private void box3CanonicalRowRangeUnchecked(
    scope const(float)* src,
    ptrdiff_t rowStride,
    scope float* dst,
    size_t width,
    size_t rowBegin,
    size_t rowEnd,
    bool noInline
)
@trusted
nothrow
@nogc
{
    auto r0 = src + cast(ptrdiff_t) rowBegin * rowStride;
    auto r1 = r0 + rowStride;
    auto r2 = r1 + rowStride;
    auto dstRow = dst + rowBegin * width;

    foreach (_; rowBegin .. rowEnd)
    {
        if (noInline)
            box3RowNoInlineUnchecked(r0, r1, r2, dstRow, width);
        else
            box3RowUnchecked(r0, r1, r2, dstRow, width);

        r0 += rowStride;
        r1 += rowStride;
        r2 += rowStride;
        dstRow += width;
    }
}

pragma(inline, false)
private void box3RowNoInlineUnchecked(
    scope const(float)* r0,
    scope const(float)* r1,
    scope const(float)* r2,
    scope float* dstRow,
    size_t width
)
@system
pure
nothrow
@nogc
{
    foreach (x; 0 .. width)
        dstRow[x] =
            r0[x] + r0[x + 1] + r0[x + 2] +
            r1[x] + r1[x + 1] + r1[x + 2] +
            r2[x] + r2[x + 1] + r2[x + 2];
}
