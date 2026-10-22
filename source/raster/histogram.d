/++
    Exact discrete histogram for one numeric 8-bit raster plane.

    This is a generic raster reduction, not an RGB, colour, alpha or
    radiometric operation. Only the explicitly admitted ubyte domain is
    supported; configurable ranges and other numeric types are separate
    future API decisions.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-22
+/
module raster.histogram;

import raster.view : RasterView;


/++
    Failure category for histogram256.

    The error enum defaults to none; RasterHistogram256Result.init is
    deliberately unsuccessful.
+/
enum RasterHistogram256Error : ubyte
{
    none,
    invalidPlane,
    countOverflow
}

/// Example inspecting the histogram error categories.
@safe unittest
{
    import raster;

    assert(RasterHistogram256Error.init == RasterHistogram256Error.none);
    assert(RasterHistogram256Error.countOverflow != RasterHistogram256Error.none);
}


/++
    Value result of an exact ubyte frequency histogram.

    bins[v] contains the number of selected logical samples equal to v.
    All 256 counts belong to the result value; no source storage is borrowed
    or retained. The caller may independently copy or modify the bins.

    The default state is an unsuccessful invalid-plane result with 256 zero
    counts. On every failure the complete returned bins array is zero, never
    a partial accumulation. Inspect ok before using a result as a histogram.
+/
struct RasterHistogram256Result
{
    /// Exact frequency counts indexed by the original ubyte sample value.
    ulong[256] bins;

    /// Example inspecting the fixed 256-value count buffer.
    @safe unittest
    {
        import raster;
        RasterHistogram256Result result;
        assert(result.bins.length == 256);
        assert(result.bins[0] == 0);
        assert(result.bins[255] == 0);
    }

private:
    RasterHistogram256Error error_ = RasterHistogram256Error.invalidPlane;

public:
    /++ Returns the reduction's success or failure category. +/
    @property
    RasterHistogram256Error error() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_;
    }

    /// Example reading the default error category.
    @safe unittest
    {
        import raster;
        RasterHistogram256Result result;
        assert(result.error == RasterHistogram256Error.invalidPlane);
    }

    /++ Whether the complete histogram was calculated successfully. +/
    @property
    bool ok() const
    @safe
    pure
    nothrow
    @nogc
    {
        return error_ == RasterHistogram256Error.none;
    }

    /// Example checking that an uncomputed histogram is not success.
    @safe unittest
    {
        import raster;
        RasterHistogram256Result result;
        assert(!result.ok);
        assert(result.bins[0] == 0);
        assert(result.bins[255] == 0);
    }
}

/// Example checking the deliberately failing default result.
@safe unittest
{
    import raster;

    RasterHistogram256Result result;
    assert(!result.ok);
    assert(result.error == RasterHistogram256Error.invalidPlane);

    foreach (count; result.bins)
        assert(count == 0);
}


/++
    Counts all ubyte values of one selected logical raster plane.

    The source may be a full resident view or a zero-copy ROI. Counts are
    indexed by the exact numeric sample value, from 0 through 255 inclusive;
    there are no interval boundaries, out-of-range values, floating values,
    masks, channel interpretation or implicit NoData filtering.

    The selected plane must exist. A valid empty plane succeeds with 256
    zero counts. An invalid plane fails with invalidPlane; a count that
    cannot be represented in ulong fails with countOverflow. In either
    failure case all bins are zero. RasterHistogram256Result.init is failure.

    All validated resident layouts are supported, including planar,
    interleaved and signed row/sample strides. Traversal covers each
    represented logical sample exactly once, regardless of physical layout.
    The operation does not modify or retain the source, allocate from the
    heap, create worker threads or materialize a larger raster.

    Adjacent non-overlapping windows using the same value domain are exactly
    composable: for every v, whole.bins[v] equals the sum of the windows'
    bins[v]. Callers merging counts must check ulong overflow themselves;
    this first API does not publish a redundant merge operation.

    Time complexity: O(width * height). Auxiliary storage: 256 ulong counts,
    independent of raster size.

    Params:
        source = Borrowed, validated read-only raster view.
        planeIndex = Zero-based logical plane to count.

    Returns:
        A self-contained 256-bin value result with explicit error/ok state.
+/
RasterHistogram256Result histogram256(
    scope RasterView!ubyte source,
    size_t planeIndex
)
@safe
nothrow
@nogc
{
    RasterHistogram256Result result;

    if (planeIndex >= source.planeCount)
        return result;

    // Check the logical count before any sample access, including empty views.
    if (
        source.height != 0
        && cast(ulong) source.width > ulong.max / source.height
    )
    {
        result.error_ = RasterHistogram256Error.countOverflow;
        return result;
    }

    if (!executeHistogram256(source, planeIndex, result.bins))
    {
        // Partial private accumulation must never become a public result.
        result.bins[] = 0;
        result.error_ = RasterHistogram256Error.countOverflow;
        return result;
    }

    result.error_ = RasterHistogram256Error.none;
    return result;
}

/// Example counting exact raster values through the public, owned import API.
@system unittest
{
    import core.stdc.stdlib : malloc;
    import raster;

    void* memory = malloc(4);
    assert(memory !is null);

    auto bytes = (cast(ubyte*) memory)[0 .. 4];
    bytes[] = [0, 1, 1, 255];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 4, resource));

    const PlaneByteLayout[1] layout = [PlaneByteLayout(0, 2, 1)];
    RasterLease!ubyte lease;
    assert(tryImportOwnedRaster!ubyte(
        resource, layout[], Region2D(0, 0, 2, 2), lease
    ).ok);

    scope auto source = lease.view();
    const result = source.histogram256(0);
    assert(result.ok);
    assert(result.bins[0] == 1);
    assert(result.bins[1] == 2);
    assert(result.bins[255] == 1);
}


/++
    Small trusted execution boundary for validated RasterView storage.

    RasterView construction has already established that all reachable
    samples have valid, aligned addresses for the selected physical plane.
    tryExecutionPlaneStrides validates the plane before pointer formation.
    An empty view never forms a data pointer. For nonempty views, pointer
    advancement occurs only while another logical sample exists.

    This function does not publish its ref output. Its caller discards partial
    counts on overflow. No dynamic allocation or retained state is involved.
+/
private
bool executeHistogram256(
    scope RasterView!ubyte source,
    size_t planeIndex,
    ref ulong[256] bins
)
@trusted
nothrow
@nogc
{
    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;

    if (!source.tryExecutionPlaneStrides(
        planeIndex, rowStride, sampleStride
    ))
        return false;

    if (source.empty)
        return true;

    const(ubyte)* row = source.executionRegionBase(planeIndex);
    assert(row !is null);

    foreach (y; 0 .. source.height)
    {
        const(ubyte)* sample = row;

        foreach (x; 0 .. source.width)
        {
            const value = *sample;

            if (bins[value] == ulong.max)
                return false;

            ++bins[value];

            if (x + 1 < source.width)
                sample += sampleStride;
        }

        if (y + 1 < source.height)
            row += rowStride;
    }

    return true;
}


version (unittest)
{
    import raster.descriptor : PlaneDescriptor;
    import raster.region : Region2D;
    import raster.view : makeRasterViewAssumeValidated;

    // Exact frequencies, boundary values, and failure publication.
    unittest
    {
        ubyte[6] data = [0, 255, 2, 2, 2, 1];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(data.ptr, 3, 1)
        ];

        scope auto source = makeRasterViewAssumeValidated!ubyte(
            planes[], Region2D(0, 0, 3, 2)
        );

        const result = histogram256(source, 0);
        assert(result.ok);
        assert(result.bins[0] == 1);
        assert(result.bins[1] == 1);
        assert(result.bins[2] == 3);
        assert(result.bins[255] == 1);
        assert(result.bins[3] == 0);

        ulong total;
        foreach (count; result.bins)
            total += count;
        assert(total == 6);

        const failed = source.histogram256(1);
        assert(!failed.ok);
        assert(failed.error == RasterHistogram256Error.invalidPlane);
        foreach (count; failed.bins)
            assert(count == 0);
    }

    // Equivalent three-plane planar and interleaved layouts.
    unittest
    {
        ubyte[12] planar = [
            4, 5, 6, 7,
            14, 15, 16, 17,
            24, 25, 26, 27
        ];
        ubyte[12] interleaved = [
            4, 14, 24, 5, 15, 25,
            6, 16, 26, 7, 17, 27
        ];

        const PlaneDescriptor[3] planarPlanes = [
            PlaneDescriptor(planar.ptr, 2, 1),
            PlaneDescriptor(planar.ptr + 4, 2, 1),
            PlaneDescriptor(planar.ptr + 8, 2, 1)
        ];
        const PlaneDescriptor[3] interleavedPlanes = [
            PlaneDescriptor(interleaved.ptr, 6, 3),
            PlaneDescriptor(interleaved.ptr + 1, 6, 3),
            PlaneDescriptor(interleaved.ptr + 2, 6, 3)
        ];

        scope auto a = makeRasterViewAssumeValidated!ubyte(
            planarPlanes[], Region2D(0, 0, 2, 2)
        );
        scope auto b = makeRasterViewAssumeValidated!ubyte(
            interleavedPlanes[], Region2D(0, 0, 2, 2)
        );

        foreach (plane; 0 .. 3)
        {
            const left = a.histogram256(plane);
            const right = b.histogram256(plane);
            assert(left.ok && right.ok);
            assert(left.bins == right.bins);
        }
    }

    // Both signed row and signed sample strides preserve logical counts.
    unittest
    {
        ubyte[8] data = [1, 99, 2, 99, 3, 99, 4, 99];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(data.ptr + 6, -4, -2)
        ];

        scope auto source = makeRasterViewAssumeValidated!ubyte(
            planes[], Region2D(0, 0, 2, 2)
        );

        const result = source.histogram256(0);
        assert(result.ok);
        foreach (value; 1 .. 5)
            assert(result.bins[value] == 1);
        assert(result.bins[99] == 0);
    }

    // A full view and its adjacent, complete windows compose exactly.
    // Nested ROI coordinates are relative to their parent view.
    unittest
    {
        ubyte[12] data = [
            0, 1, 1, 255,
            1, 2, 2, 255,
            0, 2, 3, 255
        ];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(data.ptr, 4, 1)
        ];

        scope auto source = makeRasterViewAssumeValidated!ubyte(
            planes[], Region2D(0, 0, 4, 3)
        );

        bool ok;
        scope auto left = source.tryRoi(Region2D(0, 0, 2, 3), ok);
        assert(ok);
        scope auto right = source.tryRoi(Region2D(2, 0, 2, 3), ok);
        assert(ok);
        scope auto inner = source.tryRoi(Region2D(1, 1, 2, 2), ok);
        assert(ok);

        const whole = source.histogram256(0);
        const first = left.histogram256(0);
        const second = right.histogram256(0);
        const cropped = inner.histogram256(0);

        assert(whole.ok && first.ok && second.ok && cropped.ok);
        foreach (index; 0 .. 256)
        {
            assert(first.bins[index] <= ulong.max - second.bins[index]);
            assert(whole.bins[index] ==
                first.bins[index] + second.bins[index]);
        }

        assert(cropped.bins[2] == 3);
        assert(cropped.bins[3] == 1);
    }

    // An empty selected plane succeeds and never forms a sample pointer.
    unittest
    {
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(null, ptrdiff_t.min, ptrdiff_t.min)
        ];

        scope auto source = makeRasterViewAssumeValidated!ubyte(
            planes[], Region2D(size_t.max, size_t.max, 0, 3)
        );

        const result = source.histogram256(0);
        assert(result.ok);
        foreach (count; result.bins)
            assert(count == 0);
    }

    // Exercise the checked bin increment without materializing a huge raster.
    unittest
    {
        ubyte[1] data = [7];
        const PlaneDescriptor[1] planes = [
            PlaneDescriptor(data.ptr, 1, 1)
        ];

        scope auto source = makeRasterViewAssumeValidated!ubyte(
            planes[], Region2D(0, 0, 1, 1)
        );

        ulong[256] counts;
        counts[7] = ulong.max;
        assert(!executeHistogram256(source, 0, counts));
        assert(counts[7] == ulong.max);
    }
} // version (unittest)
