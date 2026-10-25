/**
    Scoped data-plane access for downstream kernels.

    This is the first, deliberately narrow, public step toward the data-plane
    contract tracked by raster-d issue #261.  The contiguous helper admits a
    flat logical region; the affine helper below additionally supports signed
    row and sample strides, including interleaved layouts, while keeping the
    same callback-scoped lifetime and aliasing rules.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-23
*/
module raster.data_plane;

import raster.view : RasterView;
import raster.view : makeRasterViewAssumeValidated;
import raster.writable_view : WritableRasterView;
import raster.writable_view : tryMakeWritableRasterView;
import raster.descriptor : PlaneDescriptor;
import raster.region : Region2D;
import raster.resource : ResourceAccess, ResourceEntry;
import raster.validation : BackingValidationResult,
    WritableBackingCertificationResult;
import core.atomic : MemoryOrder, atomicFetchAdd;
import raster.internal.affine_relation : AffineByteOverlapRelation;
import raster.internal.validated_affine_relation : classifyValidatedUbyteToFloatAffine2DByteOverlap;
import raster.parallel_rows : ParallelRowsResult, ParallelRowsOperation, parallelRows;

/** A validated, read-only affine plane window valid only inside one callback. */
struct RasterPlaneWindow(T)
{
private:
    const(T)* base_;
    size_t width_;
    size_t height_;
    ptrdiff_t rowStride_;
    ptrdiff_t sampleStride_;

    this(const(T)* base, size_t width, size_t height,
        ptrdiff_t rowStride, ptrdiff_t sampleStride)
    @safe pure nothrow @nogc
    {
        base_ = base;
        width_ = width;
        height_ = height;
        rowStride_ = rowStride;
        sampleStride_ = sampleStride;
    }

public:
    @property size_t width() const @safe pure nothrow @nogc { return width_; }
    @property size_t height() const @safe pure nothrow @nogc { return height_; }
    @property ptrdiff_t rowStride() const @safe pure nothrow @nogc { return rowStride_; }
    @property ptrdiff_t sampleStride() const @safe pure nothrow @nogc { return sampleStride_; }

    /**
        Loads a previously validated logical coordinate; no bounds check.

        Example:
        ---
        // `window` is supplied by withPlane inside its scoped callback.
        auto sample = window.load(x, y);
        ---
    */
    T load(size_t x, size_t y) const @safe nothrow @nogc
    {
        return loadUnchecked(base_, x, y, rowStride_, sampleStride_);
    }

    /** Returns a row view with the row offset hoisted out of the sample loop. */
    RasterPlaneRow!T row(size_t y) const @safe nothrow @nogc
    {
        return RasterPlaneRow!T(rowBase(base_, y, rowStride_), width_, sampleStride_);
    }

    /**
        Returns one validated contiguous row as a scoped slice.
        Returns an empty slice when the row has a non-unit sample stride.
    */
    scope const(T)[] contiguousRowSpan(size_t y) const @safe nothrow @nogc
    { return makeConstRowSpan(rowBase(base_, y, rowStride_), width_, sampleStride_); }
}

/** A callback-scoped row view of a validated affine plane. */
struct RasterPlaneRow(T)
{
private:
    const(T)* base_;
    size_t length_;
    ptrdiff_t sampleStride_;

    this(const(T)* base, size_t length, ptrdiff_t sampleStride)
    @safe pure nothrow @nogc
    { base_ = base; length_ = length; sampleStride_ = sampleStride; }

public:
    @property size_t length() const @safe pure nothrow @nogc { return length_; }
    /**
        Returns the first sample of this callback-scoped row.

        Consumers may use `data[x * sampleStride]` in a hot loop.  The
        returned pointer is tied to the row borrow and must not escape the
        enclosing data-plane callback.
    */
    const(T)* data() const return scope @safe pure nothrow @nogc
    { return base_; }
    @property ptrdiff_t sampleStride() const @safe pure nothrow @nogc
    { return sampleStride_; }
    T load(size_t x) const @safe nothrow @nogc
    { return loadUnchecked(base_, x, 0, 0, sampleStride_); }
}

/// Example referring to the scoped read-window load operation.
@safe unittest
{
    import raster;
    RasterPlaneWindow!ubyte window;
    static assert(is(typeof(window.load(0, 0)) == ubyte));
}

/// Example declaring a scoped read window value.
@safe unittest
{
    import raster;
    RasterPlaneWindow!ubyte window;
    assert(window.width == 0);
    assert(window.height == 0);
}

/// A strided row exposes its validated data pointer and element stride.
@trusted unittest
{
    import raster;
    ubyte[4] values = [1, 2, 3, 4];
    auto row = RasterPlaneRow!ubyte(cast(const(ubyte)*) values.ptr, 2, 2);
    assert(row.length == 2);
    assert(row.sampleStride == 2);
    assert(row.data[0] == 1);
    assert(row.data[row.sampleStride] == 3);
}

/** A validated, writable affine plane window valid only inside one callback. */
struct WritableRasterPlaneWindow(T)
{
private:
    T* base_;
    size_t width_;
    size_t height_;
    ptrdiff_t rowStride_;
    ptrdiff_t sampleStride_;

    this(T* base, size_t width, size_t height,
        ptrdiff_t rowStride, ptrdiff_t sampleStride)
    @safe pure nothrow @nogc
    {
        base_ = base;
        width_ = width;
        height_ = height;
        rowStride_ = rowStride;
        sampleStride_ = sampleStride;
    }

public:
    @property size_t width() const @safe pure nothrow @nogc { return width_; }
    @property size_t height() const @safe pure nothrow @nogc { return height_; }
    @property ptrdiff_t rowStride() const @safe pure nothrow @nogc { return rowStride_; }
    @property ptrdiff_t sampleStride() const @safe pure nothrow @nogc { return sampleStride_; }

    /**
        Loads a previously validated logical coordinate; no bounds check.

        Example:
        ---
        auto sample = window.load(x, y);
        ---
    */
    T load(size_t x, size_t y) const @safe nothrow @nogc
    {
        return loadUnchecked(base_, x, y, rowStride_, sampleStride_);
    }

    /**
        Stores a previously validated logical coordinate; no bounds check.

        Example:
        ---
        window.store(x, y, value);
        ---
    */
    void store(size_t x, size_t y, T value) @safe nothrow @nogc
    {
        storeUnchecked(base_, x, y, rowStride_, sampleStride_, value);
    }

    /** Returns a writable row view with the row offset hoisted out of the sample loop. */
    WritableRasterPlaneRow!T row(size_t y) @safe nothrow @nogc
    {
        return WritableRasterPlaneRow!T(rowBaseMutable(base_, y, rowStride_), width_, sampleStride_);
    }

    /**
        Returns one validated contiguous writable row as a scoped slice.
        Returns an empty slice when the row has a non-unit sample stride.
    */
    scope T[] contiguousRowSpan(size_t y) @safe nothrow @nogc
    { return makeMutableRowSpan(rowBaseMutable(base_, y, rowStride_), width_, sampleStride_); }
}

/** A callback-scoped writable row view of a validated affine plane. */
struct WritableRasterPlaneRow(T)
{
private:
    T* base_;
    size_t length_;
    ptrdiff_t sampleStride_;

    this(T* base, size_t length, ptrdiff_t sampleStride)
    @safe pure nothrow @nogc
    { base_ = base; length_ = length; sampleStride_ = sampleStride; }

public:
    @property size_t length() const @safe pure nothrow @nogc { return length_; }
    /** Returns the first sample of this callback-scoped writable row. */
    T* data() return scope @safe pure nothrow @nogc
    { return base_; }
    @property ptrdiff_t sampleStride() const @safe pure nothrow @nogc
    { return sampleStride_; }
    T load(size_t x) const @safe nothrow @nogc
    { return loadUnchecked(base_, x, 0, 0, sampleStride_); }
    void store(size_t x, T value) @safe nothrow @nogc
    { storeUnchecked(base_, x, 0, 0, sampleStride_, value); }
}

/// Example referring to the scoped writable-window operations.
@safe unittest
{
    import raster;
    WritableRasterPlaneWindow!ubyte window;
    static assert(is(typeof(window.load(0, 0)) == ubyte));
    static assert(is(typeof(window.store(0, 0, cast(ubyte) 0)) == void));
}

/// Example declaring a scoped writable window value.
@safe unittest
{
    import raster;
    WritableRasterPlaneWindow!ubyte window;
    assert(window.width == 0);
    assert(window.height == 0);
}

/// A writable strided row exposes direct callback-scoped storage access.
@trusted unittest
{
    import raster;
    ubyte[4] values = [1, 2, 3, 4];
    auto row = WritableRasterPlaneRow!ubyte(values.ptr, 2, 2);
    row.data[row.sampleStride] = 9;
    assert(values[2] == 9);
}

private struct ByteEnvelope
{
    size_t first;
    size_t end;
    bool valid;
}

/**
    Visits one flat contiguous read plane without per-sample bounds checks.

    Validation happens before the callback is entered.  The slice is scoped
    to the callback and must not be retained by the caller.  The callback is
    synchronous and must not start work that outlives the view borrow.

    Returns false when `planeIndex` is invalid or the plane is not flat
    contiguous.  Empty planes are valid and invoke the callback with an empty
    slice.
*/
bool withContiguousPlane(T)(
    scope ref const RasterView!T view,
    size_t planeIndex,
    scope void delegate(scope const(T)[] samples, size_t width, size_t height)
        @safe nothrow @nogc callback
)
@safe
nothrow
@nogc
{
    if (callback is null)
        return false;

    import raster.internal.execution_layout : PlaneExecutionTraits;

    PlaneExecutionTraits traits;
    if (!view.tryPlaneExecutionTraits(planeIndex, traits))
        return false;

    if (view.empty)
    {
        const(T)[] empty;
        callback(empty, view.width, view.height);
        return true;
    }

    if (!traits.linearContiguous1D)
        return false;

    auto base = view.executionRegionBase(planeIndex);
    auto samples = makeConstSlice(base, traits.flatElementCount);
    callback(samples, view.width, view.height);
    return true;
}

/**
    Visits several validated flat-contiguous source and destination planes in
    one synchronous callback. The callback is entered only after every plane
    has passed contiguous-layout validation; no partial execution occurs.
*/
bool withContiguousPlanesInto(Source, Destination)(
    scope ref const RasterView!Source source,
    scope const(size_t)[] sourcePlanes,
    scope ref WritableRasterView!Destination destination,
    scope const(size_t)[] destinationPlanes,
    scope const(Source)[][] sourceSlices,
    scope Destination[][] destinationSlices,
    scope void delegate(
        scope const(Source)[][] sources,
        scope Destination[][] destinations
    ) @safe nothrow @nogc kernel
)
@safe nothrow @nogc
{
    if (kernel is null || sourcePlanes.length == 0
        || sourcePlanes.length != sourceSlices.length
        || destinationPlanes.length == 0
        || destinationPlanes.length != destinationSlices.length
        || source.width != destination.width || source.height != destination.height)
        return false;

    import raster.internal.execution_layout : PlaneExecutionTraits;
    foreach (i, plane; sourcePlanes) {
        PlaneExecutionTraits traits;
        if (!source.tryPlaneExecutionTraits(plane, traits) || !traits.linearContiguous1D)
            return false;
        sourceSlices[i] = makeConstSlice(source.executionRegionBase(plane), traits.flatElementCount);
    }
    foreach (i, plane; destinationPlanes) {
        PlaneExecutionTraits traits;
        if (!destination.tryPlaneExecutionTraits(plane, traits) || !traits.linearContiguous1D)
            return false;
        destinationSlices[i] = makeMutableSlice(destination.executionRegionBase(plane), traits.flatElementCount);
    }
    kernel(sourceSlices, destinationSlices);
    return true;
}

/// Example rejecting an invalid contiguous read-plane request.
@safe unittest
{
    import raster;
    RasterView!ubyte view;
    assert(!withContiguousPlane!ubyte(view, 0, null));
}

/**
    Visits one flat contiguous writable plane without per-sample bounds checks.

    The callback receives a scoped mutable slice.  This grants write access,
    not uniqueness or non-aliasing; callers remain responsible for obeying the
    documented source/destination alias rules of their operation.
*/
bool withContiguousPlane(T)(
    scope ref WritableRasterView!T view,
    size_t planeIndex,
    scope void delegate(scope T[] samples, size_t width, size_t height)
        @safe nothrow @nogc callback
)
@safe
nothrow
@nogc
{
    if (callback is null)
        return false;

    import raster.internal.execution_layout : PlaneExecutionTraits;

    PlaneExecutionTraits traits;
    if (!view.tryPlaneExecutionTraits(planeIndex, traits))
        return false;

    if (view.empty)
    {
        T[] empty;
        callback(empty, view.width, view.height);
        return true;
    }

    if (!traits.linearContiguous1D)
        return false;

    auto base = view.executionRegionBase(planeIndex);
    auto samples = makeMutableSlice(base, traits.flatElementCount);
    callback(samples, view.width, view.height);
    return true;
}

/// Example rejecting an invalid contiguous writable-plane request.
@safe unittest
{
    import raster;
    WritableRasterView!ubyte view;
    assert(!withContiguousPlane!ubyte(view, 0, null));
}

/** Forms the scoped read slice after contiguous validation. */
private scope const(T)[] makeConstSlice(T)(
    return scope const(T)* base,
    size_t length
)
@trusted
nothrow
@nogc
{
    return base[0 .. length];
}

/** Forms the scoped writable slice after contiguous validation. */
private scope T[] makeMutableSlice(T)(
    return scope T* base,
    size_t length
)
@trusted
nothrow
@nogc
{
    return base[0 .. length];
}

/**
    Visits any validated affine read plane. The callback is synchronous and
    receives no raw pointer; `load` preserves arbitrary signed strides.
*/
bool withPlane(T)(
    scope ref const RasterView!T view,
    size_t planeIndex,
    scope void delegate(scope ref const RasterPlaneWindow!T window)
        @safe nothrow @nogc callback
)
@safe nothrow @nogc
{
    if (callback is null)
        return false;

    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
    if (!view.tryExecutionPlaneStrides(planeIndex, rowStride, sampleStride))
        return false;

    auto base = view.executionRegionBase(planeIndex);
    auto window = RasterPlaneWindow!T(
        base, view.width, view.height, rowStride, sampleStride);
    callback(window);
    return true;
}

/**
    Validates and exposes multiple source and destination planes as one
    synchronous kernel invocation.

    `sourceWindows` and `destinationWindows` are caller-owned workspace. No
    allocation is performed. Source and destination sample types may differ.
    The callback must not retain either window array or start work that
    outlives the view borrows.

    Source/source aliasing is allowed because sources are read-only. Any
    destination/destination or source/destination byte-envelope overlap is
    rejected before the callback. The check is conservative: intersecting
    envelopes are rejected even when individual samples might be disjoint.
*/
bool withPlanesInto(Source, Destination)(
    scope ref const RasterView!Source source,
    scope const(size_t)[] sourcePlanes,
    scope ref WritableRasterView!Destination destination,
    scope const(size_t)[] destinationPlanes,
    scope RasterPlaneWindow!Source[] sourceWindows,
    scope WritableRasterPlaneWindow!Destination[] destinationWindows,
    scope void delegate(
        scope const(RasterPlaneWindow!Source)[] sources,
        scope WritableRasterPlaneWindow!Destination[] destinations
    ) @safe nothrow @nogc kernel
)
@safe nothrow @nogc
{
    if (kernel is null
        || sourcePlanes.length == 0
        || sourcePlanes.length != sourceWindows.length
        || destinationPlanes.length == 0
        || destinationPlanes.length != destinationWindows.length)
    {
        return false;
    }

    if (source.width != destination.width
        || source.height != destination.height)
    {
        return false;
    }

    foreach (i, plane; sourcePlanes)
    {
        ptrdiff_t rowStride;
        ptrdiff_t sampleStride;
        if (!source.tryExecutionPlaneStrides(plane, rowStride, sampleStride))
            return false;

        sourceWindows[i] = RasterPlaneWindow!Source(
            source.executionRegionBase(plane),
            source.width,
            source.height,
            rowStride,
            sampleStride
        );
    }

    foreach (i, plane; destinationPlanes)
    {
        ptrdiff_t rowStride;
        ptrdiff_t sampleStride;
        if (!destination.tryExecutionPlaneStrides(plane, rowStride, sampleStride))
            return false;

        destinationWindows[i] = WritableRasterPlaneWindow!Destination(
            destination.executionRegionBase(plane),
            destination.width,
            destination.height,
            rowStride,
            sampleStride
        );
    }

    foreach (sourceWindow; sourceWindows)
        foreach (destinationWindow; destinationWindows)
            if (envelopesOverlap(envelope(sourceWindow), envelope(destinationWindow))
                && !provenDisjointMixed(sourceWindow, destinationWindow))
                return false;

    foreach (i, left; destinationWindows)
        foreach (right; destinationWindows[i + 1 .. $])
            if (envelopesOverlap(envelope(left), envelope(right))
                && !provenDisjointSamples(left, right))
                return false;

    kernel(sourceWindows, destinationWindows);
    return true;
}

/**
    Validates affine planes and executes a bounded row-parallel kernel.

    The callback receives the same callback-scoped windows as
    `withPlanesInto`, plus a half-open logical row range.  It must only write
    its assigned rows and must not retain any argument or start work that
    outlives this call.  All locally created workers are joined before this
    function returns.  A failed callback may leave partial destination
    writes; callers should publish temporary output only after success.

    This is a general raster primitive: it has no imagery-specific sample
    types, operation semantics, or process-global scheduler.
*/
bool withPlanesIntoParallel(Source, Destination)(
    scope ref const RasterView!Source source,
    scope const(size_t)[] sourcePlanes,
    scope ref WritableRasterView!Destination destination,
    scope const(size_t)[] destinationPlanes,
    scope RasterPlaneWindow!Source[] sourceWindows,
    scope WritableRasterPlaneWindow!Destination[] destinationWindows,
    size_t workerLimit,
    size_t minimumChunk,
    scope bool delegate(
        scope const(RasterPlaneWindow!Source)[] sources,
        scope WritableRasterPlaneWindow!Destination[] destinations,
        size_t firstRow,
        size_t endRow
    ) @safe nothrow kernel
)
@trusted
{
    if (kernel is null
        || sourcePlanes.length == 0
        || sourcePlanes.length != sourceWindows.length
        || destinationPlanes.length == 0
        || destinationPlanes.length != destinationWindows.length
        || source.width != destination.width
        || source.height != destination.height)
        return false;

    foreach (i, plane; sourcePlanes)
    {
        ptrdiff_t rowStride;
        ptrdiff_t sampleStride;
        if (!source.tryExecutionPlaneStrides(plane, rowStride, sampleStride))
            return false;
        sourceWindows[i] = RasterPlaneWindow!Source(
            source.executionRegionBase(plane), source.width, source.height,
            rowStride, sampleStride);
    }
    foreach (i, plane; destinationPlanes)
    {
        ptrdiff_t rowStride;
        ptrdiff_t sampleStride;
        if (!destination.tryExecutionPlaneStrides(plane, rowStride, sampleStride))
            return false;
        destinationWindows[i] = WritableRasterPlaneWindow!Destination(
            destination.executionRegionBase(plane), destination.width,
            destination.height, rowStride, sampleStride);
    }

    foreach (sourceWindow; sourceWindows)
        foreach (destinationWindow; destinationWindows)
            if (envelopesOverlap(envelope(sourceWindow), envelope(destinationWindow))
                && !provenDisjointMixed(sourceWindow, destinationWindow))
                return false;
    foreach (i, left; destinationWindows)
        foreach (right; destinationWindows[i + 1 .. $])
            if (envelopesOverlap(envelope(left), envelope(right))
                && !provenDisjointSamples(left, right))
                return false;

    return parallelRows(source.height, workerLimit, minimumChunk,
        (size_t firstRow, size_t endRow)
        {
            return kernel(sourceWindows[], destinationWindows[], firstRow, endRow);
        }) == ParallelRowsResult.completed;
}

/**
    Validates read-only affine planes and executes a bounded row-parallel
    kernel.  Unlike `withPlanesIntoParallel`, this source-only form does not
    require a fabricated destination.  Read-only planes may overlap.
*/
bool withPlanesParallel(Source)(
    scope ref const RasterView!Source source,
    scope const(size_t)[] sourcePlanes,
    scope RasterPlaneWindow!Source[] sourceWindows,
    size_t workerLimit,
    size_t minimumChunk,
    scope bool delegate(
        scope const(RasterPlaneWindow!Source)[] sources,
        size_t firstRow,
        size_t endRow
    ) @safe nothrow kernel
)
@trusted
{
    if (kernel is null || sourcePlanes.length == 0
        || sourcePlanes.length != sourceWindows.length)
        return false;

    foreach (i, plane; sourcePlanes)
    {
        ptrdiff_t rowStride;
        ptrdiff_t sampleStride;
        if (!source.tryExecutionPlaneStrides(plane, rowStride, sampleStride))
            return false;
        sourceWindows[i] = RasterPlaneWindow!Source(
            source.executionRegionBase(plane), source.width, source.height,
            rowStride, sampleStride);
    }

    return parallelRows(source.height, workerLimit, minimumChunk,
        (size_t firstRow, size_t endRow)
        {
            return kernel(sourceWindows[], firstRow, endRow);
        }) == ParallelRowsResult.completed;
}

/**
    Performs multiple synchronous row phases under one validated source-only
    borrow.  `phases` owns the operation barrier: every `forRows` call joins
    its callbacks before returning, so callers may reduce phase-local state
    before starting the next phase.
*/
bool withPlanesParallelPhases(Source)(
    scope ref const RasterView!Source source,
    scope const(size_t)[] sourcePlanes,
    scope RasterPlaneWindow!Source[] sourceWindows,
    size_t workerLimit,
    size_t minimumChunk,
    scope bool delegate(
        scope const(RasterPlaneWindow!Source)[] sources,
        ParallelRowsOperation operation
    ) @safe nothrow phases
)
@trusted
{
    if (phases is null || sourcePlanes.length == 0
        || sourcePlanes.length != sourceWindows.length)
        return false;
    foreach (i, plane; sourcePlanes)
    {
        ptrdiff_t rowStride;
        ptrdiff_t sampleStride;
        if (!source.tryExecutionPlaneStrides(plane, rowStride, sampleStride))
            return false;
        sourceWindows[i] = RasterPlaneWindow!Source(
            source.executionRegionBase(plane), source.width, source.height,
            rowStride, sampleStride);
    }
    auto operation = ParallelRowsOperation(source.height, workerLimit, minimumChunk);
    return phases(sourceWindows[], operation);
}

/**
    Performs multiple synchronous row phases under one validated
    source-to-destination borrow.  Destination alias checks are identical to
    `withPlanesIntoParallel`; the destination windows remain callback-scoped.
*/
bool withPlanesIntoParallelPhases(Source, Destination)(
    scope ref const RasterView!Source source,
    scope const(size_t)[] sourcePlanes,
    scope ref WritableRasterView!Destination destination,
    scope const(size_t)[] destinationPlanes,
    scope RasterPlaneWindow!Source[] sourceWindows,
    scope WritableRasterPlaneWindow!Destination[] destinationWindows,
    size_t workerLimit,
    size_t minimumChunk,
    scope bool delegate(
        scope const(RasterPlaneWindow!Source)[] sources,
        scope WritableRasterPlaneWindow!Destination[] destinations,
        ParallelRowsOperation operation
    ) @safe nothrow phases
)
@trusted
{
    if (phases is null || sourcePlanes.length == 0
        || sourcePlanes.length != sourceWindows.length
        || destinationPlanes.length == 0
        || destinationPlanes.length != destinationWindows.length
        || source.width != destination.width
        || source.height != destination.height)
        return false;
    foreach (i, plane; sourcePlanes)
    {
        ptrdiff_t rowStride;
        ptrdiff_t sampleStride;
        if (!source.tryExecutionPlaneStrides(plane, rowStride, sampleStride))
            return false;
        sourceWindows[i] = RasterPlaneWindow!Source(
            source.executionRegionBase(plane), source.width, source.height,
            rowStride, sampleStride);
    }
    foreach (i, plane; destinationPlanes)
    {
        ptrdiff_t rowStride;
        ptrdiff_t sampleStride;
        if (!destination.tryExecutionPlaneStrides(plane, rowStride, sampleStride))
            return false;
        destinationWindows[i] = WritableRasterPlaneWindow!Destination(
            destination.executionRegionBase(plane), destination.width,
            destination.height, rowStride, sampleStride);
    }
    foreach (sourceWindow; sourceWindows)
        foreach (destinationWindow; destinationWindows)
            if (envelopesOverlap(envelope(sourceWindow), envelope(destinationWindow))
                && !provenDisjointMixed(sourceWindow, destinationWindow))
                return false;
    foreach (i, left; destinationWindows)
        foreach (right; destinationWindows[i + 1 .. $])
            if (envelopesOverlap(envelope(left), envelope(right))
                && !provenDisjointSamples(left, right))
                return false;
    auto operation = ParallelRowsOperation(source.height, workerLimit, minimumChunk);
    return phases(sourceWindows[], destinationWindows[], operation);
}

@safe unittest
{
    ubyte[24] storage;
    foreach (i, ref value; storage) value = cast(ubyte) i;
    const PlaneDescriptor[1] descriptors =
        [PlaneDescriptor(storage.ptr, 6, 1)];
    auto source = makeRasterViewAssumeValidated!ubyte(
        descriptors[], Region2D(0, 0, 6, 4));
    RasterPlaneWindow!ubyte[1] windows;
    size_t covered;
    assert(withPlanesParallel(source, [size_t(0)], windows[], 3, 1,
        (scope const(RasterPlaneWindow!ubyte)[] sources,
            size_t first, size_t last) nothrow
        {
            foreach (y; first .. last)
                foreach (x; 0 .. sources[0].width)
                    assert(sources[0].load(x, y) == storage[y * 6 + x]);
            atomicFetchAdd!(MemoryOrder.rel)(covered, last - first);
            return true;
        }));
    assert(covered == 4);
}

@safe unittest
{
    ubyte[8] storage;
    const PlaneDescriptor[1] descriptors =
        [PlaneDescriptor(storage.ptr, 4, 1)];
    auto source = makeRasterViewAssumeValidated!ubyte(
        descriptors[], Region2D(0, 0, 4, 2));
    RasterPlaneWindow!ubyte[1] windows;
    size_t firstPhase;
    size_t secondPhase;
    assert(withPlanesParallelPhases(source, [size_t(0)], windows[], 1, 1,
        (scope const(RasterPlaneWindow!ubyte)[] sources,
            scope ParallelRowsOperation operation) nothrow
        {
            assert(operation.forRows(
                (size_t worker, size_t first, size_t last) nothrow
                {
                    firstPhase += last - first;
                    return true;
                }) == ParallelRowsResult.completed);
            assert(firstPhase == 2);
            assert(operation.forRows(
                (size_t worker, size_t first, size_t last) nothrow
                {
                    secondPhase += last - first;
                    return true;
                }) == ParallelRowsResult.completed);
            return true;
        }));
    assert(secondPhase == 2);
}

@trusted unittest
{
    ubyte[8] sourceStorage;
    float[8] destinationStorage;
    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, 4, 1)];
    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 4, 1)];
    const ResourceEntry[1] resources =
        [ResourceEntry(destinationStorage.ptr,
            destinationStorage.length * float.sizeof, null, null,
            ResourceAccess.readWrite)];
    auto source = makeRasterViewAssumeValidated!ubyte(
        sourceDescriptors[], Region2D(0, 0, 4, 2));
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;
    auto destination = tryMakeWritableRasterView!float(
        resources[], destinationDescriptors[], Region2D(0, 0, 4, 2),
        validation, certification);
    RasterPlaneWindow!ubyte[1] sources;
    WritableRasterPlaneWindow!float[1] destinations;
    assert(validation.ok && certification.ok);
    assert(withPlanesIntoParallelPhases(source, [size_t(0)], destination,
        [size_t(0)],
        sources[], destinations[], 1, 1,
        (scope const(RasterPlaneWindow!ubyte)[] ss,
            scope WritableRasterPlaneWindow!float[] ds,
            scope ParallelRowsOperation operation) nothrow
        {
            assert(operation.forRows(
                (size_t worker, size_t first, size_t last) nothrow
                {
                    foreach (y; first .. last)
                        foreach (x; 0 .. ss[0].width)
                            ds[0].store(x, y, cast(float) ss[0].load(x, y));
                    return true;
                }) == ParallelRowsResult.completed);
            return true;
        }));
    foreach (i, value; destinationStorage)
        assert(value == cast(float) sourceStorage[i]);
}

@trusted unittest
{
    ubyte[24] sourceStorage;
    float[24] destinationStorage;
    foreach (i, ref value; sourceStorage) value = cast(ubyte) i;

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage.ptr, 6, 1)];
    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 6, 1)];
    const ResourceEntry[1] destinationResources =
        [ResourceEntry(destinationStorage.ptr,
            destinationStorage.length * float.sizeof, null, null,
            ResourceAccess.readWrite)];

    auto source = makeRasterViewAssumeValidated!ubyte(
        sourceDescriptors[], Region2D(0, 0, 6, 4));
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;
    auto destination = tryMakeWritableRasterView!float(
        destinationResources[], destinationDescriptors[],
        Region2D(0, 0, 6, 4), validation, certification);
    assert(validation.ok && certification.ok);

    RasterPlaneWindow!ubyte[1] sources;
    WritableRasterPlaneWindow!float[1] destinations;
    size_t covered;
    auto result = withPlanesIntoParallel(
        source, [0], destination, [0], sources[], destinations[], 3, 1,
        (scope const(RasterPlaneWindow!ubyte)[] ss,
            scope WritableRasterPlaneWindow!float[] ds,
            size_t first, size_t last) nothrow
        {
            foreach (y; first .. last)
                foreach (x; 0 .. ss[0].width)
                    ds[0].store(x, y, cast(float) ss[0].load(x, y));
            atomicFetchAdd!(MemoryOrder.rel)(covered, last - first);
            return true;
        });
    assert(result && covered == 4);
    foreach (i, value; destinationStorage)
        assert(value == cast(float) sourceStorage[i]);
}

@trusted unittest
{
    ubyte[24] sourceStorage;
    float[24] destinationStorage;
    foreach (i, ref value; sourceStorage) value = cast(ubyte)(i + 1);

    // The logical first row starts at the last physical row and walks up.
    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceStorage[18 .. $].ptr, -6, 1)];
    const PlaneDescriptor[1] destinationDescriptors =
        [PlaneDescriptor(destinationStorage.ptr, 6, 1)];
    const ResourceEntry[1] resources =
        [ResourceEntry(destinationStorage.ptr,
            destinationStorage.length * float.sizeof, null, null,
            ResourceAccess.readWrite)];
    auto source = makeRasterViewAssumeValidated!ubyte(
        sourceDescriptors[], Region2D(0, 0, 6, 4));
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;
    auto destination = tryMakeWritableRasterView!float(
        resources[], destinationDescriptors[], Region2D(0, 0, 6, 4),
        validation, certification);
    assert(validation.ok && certification.ok);

    RasterPlaneWindow!ubyte[1] sources;
    WritableRasterPlaneWindow!float[1] destinations;
    assert(withPlanesIntoParallel(source, [0], destination, [0],
        sources[], destinations[], 2, 1,
        (scope const(RasterPlaneWindow!ubyte)[] ss,
            scope WritableRasterPlaneWindow!float[] ds,
            size_t first, size_t last) nothrow
        {
            foreach (y; first .. last)
                foreach (x; 0 .. ss[0].width)
                    ds[0].store(x, y, cast(float) ss[0].load(x, y));
            return true;
        }));
    foreach (y; 0 .. 4)
        foreach (x; 0 .. 6)
            assert(destinationStorage[y * 6 + x]
                == cast(float) sourceStorage[(3 - y) * 6 + x]);
}

@safe unittest
{
    ubyte[8] storage;
    const PlaneDescriptor[1] descriptors =
        [PlaneDescriptor(storage.ptr, 4, 1)];
    const ResourceEntry[1] resources =
        [ResourceEntry(storage.ptr, storage.length, null, null,
            ResourceAccess.readWrite)];
    auto source = makeRasterViewAssumeValidated!ubyte(
        descriptors[], Region2D(0, 0, 4, 2));
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;
    auto destination = tryMakeWritableRasterView!ubyte(
        resources[], descriptors[], Region2D(0, 0, 4, 2),
        validation, certification);
    assert(validation.ok && certification.ok);
    RasterPlaneWindow!ubyte[1] sources;
    WritableRasterPlaneWindow!ubyte[1] destinations;
    assert(!withPlanesIntoParallel(source, [0], destination, [0],
        sources[], destinations[], 2, 1,
        (scope const(RasterPlaneWindow!ubyte)[] ss,
            scope WritableRasterPlaneWindow!ubyte[] ds,
            size_t first, size_t last) nothrow { return true; }));
}

/// Example rejecting an invalid multi-plane request.
@safe unittest
{
    import raster;
    RasterView!ubyte source;
    WritableRasterView!float destination;
    RasterPlaneWindow!ubyte[1] sources;
    WritableRasterPlaneWindow!float[1] destinations;
    assert(!withPlanesInto(
        source, [0], destination, [0], sources[], destinations[], null));
}

/// Example rejecting an invalid affine read-plane request.
@safe unittest
{
    import raster;
    RasterView!ubyte view;
    assert(!withPlane!ubyte(view, 0, null));
}

/** Visits any validated affine writable plane without exposing a pointer. */
bool withPlane(T)(
    scope ref WritableRasterView!T view,
    size_t planeIndex,
    scope void delegate(scope ref WritableRasterPlaneWindow!T window)
        @safe nothrow @nogc callback
)
@safe nothrow @nogc
{
    if (callback is null)
        return false;

    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
    if (!view.tryExecutionPlaneStrides(planeIndex, rowStride, sampleStride))
        return false;

    auto base = view.executionRegionBase(planeIndex);
    auto window = WritableRasterPlaneWindow!T(
        base, view.width, view.height, rowStride, sampleStride);
    callback(window);
    return true;
}

/// Example rejecting an invalid affine writable-plane request.
@safe unittest
{
    import raster;
    WritableRasterView!ubyte view;
    assert(!withPlane!ubyte(view, 0, null));
}

/** Loads an affine sample after the enclosing view validated its coordinates. */
private T loadUnchecked(T)(const(T)* base, size_t x, size_t y,
    ptrdiff_t rowStride, ptrdiff_t sampleStride)
@trusted nothrow @nogc
{
    return base[cast(ptrdiff_t) y * rowStride
        + cast(ptrdiff_t) x * sampleStride];
}

/** Computes the element-based base address for one validated row. */
private const(T)* rowBase(T)(const(T)* base, size_t y, ptrdiff_t rowStride)
@trusted pure nothrow @nogc
{ return base + y * rowStride; }

/** Computes the writable element-based base address for one validated row. */
private T* rowBaseMutable(T)(T* base, size_t y, ptrdiff_t rowStride)
@trusted pure nothrow @nogc
{ return base + y * rowStride; }

/** Forms a contiguous read-only row slice after stride validation. */
private scope const(T)[] makeConstRowSpan(T)(const(T)* base, size_t length, ptrdiff_t stride)
@trusted pure nothrow @nogc
{
    if (length == 0 || stride != T.sizeof) return null;
    return base[0 .. length];
}

private scope T[] makeMutableRowSpan(T)(T* base, size_t length, ptrdiff_t stride)
@trusted pure nothrow @nogc
{
    if (length == 0 || stride != T.sizeof) return null;
    return base[0 .. length];
}

/** Stores an affine sample after the enclosing view validated its coordinates. */
private void storeUnchecked(T)(T* base, size_t x, size_t y,
    ptrdiff_t rowStride, ptrdiff_t sampleStride, T value)
@trusted nothrow @nogc
{
    base[cast(ptrdiff_t) y * rowStride
        + cast(ptrdiff_t) x * sampleStride] = value;
}

/** Computes a conservative byte envelope for one validated affine plane. */
private ByteEnvelope envelope(T)(scope const(T)* base, size_t width, size_t height,
    ptrdiff_t rowStride, ptrdiff_t sampleStride)
@trusted nothrow @nogc
{
    if (base is null || width == 0 || height == 0)
        return ByteEnvelope.init;

    const lastX = cast(ptrdiff_t)(width - 1) * sampleStride * T.sizeof;
    const lastY = cast(ptrdiff_t)(height - 1) * rowStride * T.sizeof;
    const(ubyte)* byteBase = cast(const(ubyte)*) base;
    const(ubyte)* p0 = byteBase;
    const(ubyte)* p1 = byteBase + lastX;
    const(ubyte)* p2 = byteBase + lastY;
    const(ubyte)* p3 = byteBase + lastY + lastX;

    size_t first = cast(size_t)p0;
    size_t end = first + T.sizeof;
    foreach (pointer; [p1, p2, p3])
    {
        const address = cast(size_t)pointer;
        if (address < first) first = address;
        if (address + T.sizeof > end) end = address + T.sizeof;
    }
    return ByteEnvelope(first, end, true);
}

/** Computes the envelope of a read-only public window. */
private ByteEnvelope envelope(T)(scope const RasterPlaneWindow!T window)
@safe nothrow @nogc
{
    return envelope(window.base_, window.width_, window.height_,
        window.rowStride_, window.sampleStride_);
}

/** Computes the envelope of a writable public window. */
private ByteEnvelope envelope(T)(scope const WritableRasterPlaneWindow!T window)
@safe nothrow @nogc
{
    return envelope(window.base_, window.width_, window.height_,
        window.rowStride_, window.sampleStride_);
}

/** Tests two conservative half-open byte envelopes for intersection. */
private bool envelopesOverlap(ByteEnvelope left, ByteEnvelope right)
@safe pure nothrow @nogc
{
    if (!left.valid || !right.valid)
        return false;
    return left.first < right.end && right.first < left.end;
}

/** Exact fast proof for equally shaped interleaved planes with disjoint lanes. */
private bool provenDisjointSamples(T)(
    scope const WritableRasterPlaneWindow!T left,
    scope const WritableRasterPlaneWindow!T right)
@safe pure nothrow @nogc
{
    if (left.width_ == 0 || left.height_ == 0
        || left.rowStride_ != right.rowStride_
        || left.sampleStride_ != right.sampleStride_
        || left.sampleStride_ <= 0
        || left.sampleStride_ * T.sizeof < T.sizeof)
        return false;

    const leftAddress = cast(size_t) left.base_;
    const rightAddress = cast(size_t) right.base_;
    const laneDelta = leftAddress > rightAddress
        ? leftAddress - rightAddress : rightAddress - leftAddress;
    return laneDelta > 0 && laneDelta < cast(size_t) left.sampleStride_ * T.sizeof;
}

/** Proves disjointness for one validated ubyte source and float destination. */
private bool provenDisjointMixed(Source, Destination)(
    scope const RasterPlaneWindow!Source source,
    scope const WritableRasterPlaneWindow!Destination destination)
@safe pure nothrow @nogc
{
    static if (!is(Source == ubyte) || !is(Destination == float)) {
        return false;
    } else {
        const sourceAddress = cast(size_t) source.base_;
        const destinationAddress = cast(size_t) destination.base_;
        const commonBase = sourceAddress < destinationAddress
            ? sourceAddress : destinationAddress;
        if (sourceAddress < commonBase || destinationAddress < commonBase)
            return false;

        return classifyValidatedUbyteToFloatAffine2DByteOverlap(
            source.width_, source.height_,
            sourceAddress - commonBase,
            source.rowStride_ * ubyte.sizeof, source.sampleStride_ * ubyte.sizeof,
            destinationAddress - commonBase,
            destination.rowStride_ * float.sizeof, destination.sampleStride_ * float.sizeof)
            == AffineByteOverlapRelation.disjoint;
    }
}
