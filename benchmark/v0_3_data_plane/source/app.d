module raster.benchmark_v0_3_data_plane;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;
import core.atomic : MemoryOrder, atomicFetchAdd;
import std.algorithm.sorting : sort;
import std.stdio : writefln;
import raster;

version (raster_benchmark_1080p)
{
    enum width = 1920;
    enum height = 1080;
}
else
{
    enum width = 1024;
    enum height = 768;
}
enum channels = 3;
// The generic fixture uses integer Rec. 709-like luma weights.  The result
// is scaled to the full 16-bit histogram domain, so every input byte has a
// deterministic bin and no colour-space dependency is implied.
enum histogramBins = 65536;
enum percentile = 75;
enum warmups = 3;
enum samples = 7;
version (raster_benchmark_workers_1) enum benchmarkWorkers = 1;
else version (raster_benchmark_workers_2) enum benchmarkWorkers = 2;
else version (raster_benchmark_workers_8) enum benchmarkWorkers = 8;
else enum benchmarkWorkers = 4;
version (raster_benchmark_chunk_8) enum benchmarkChunk = 8;
else version (raster_benchmark_chunk_64) enum benchmarkChunk = 64;
else version (raster_benchmark_chunk_128) enum benchmarkChunk = 128;
else enum benchmarkChunk = 32;
private void require(bool value, string message) @safe
{
    if (!value) throw new Exception(message);
}

private auto layouts(T)()
{
    return [
        PlaneByteLayout(0, cast(ptrdiff_t)(width * T.sizeof), cast(ptrdiff_t)T.sizeof),
        PlaneByteLayout(cast(size_t)(width * height * T.sizeof), cast(ptrdiff_t)(width * T.sizeof), cast(ptrdiff_t)T.sizeof),
        PlaneByteLayout(cast(size_t)(2 * width * height * T.sizeof), cast(ptrdiff_t)(width * T.sizeof), cast(ptrdiff_t)T.sizeof)
    ];
}

private auto interleavedLayouts(T)()
{
    return [
        PlaneByteLayout(0, cast(ptrdiff_t)(width * channels * T.sizeof), cast(ptrdiff_t)(channels * T.sizeof)),
        PlaneByteLayout(cast(size_t)T.sizeof, cast(ptrdiff_t)(width * channels * T.sizeof), cast(ptrdiff_t)(channels * T.sizeof)),
        PlaneByteLayout(cast(size_t)(2 * T.sizeof), cast(ptrdiff_t)(width * channels * T.sizeof), cast(ptrdiff_t)(channels * T.sizeof))
    ];
}

private RasterLease!T makeLease(T, bool interleaved = false)(out void* ownedMemory)
@system
{
    const bytes = channels * width * height * T.sizeof;
    ownedMemory = malloc(bytes);
    require(ownedMemory !is null, "allocation failed");
    auto typed = (cast(T*) ownedMemory)[0 .. channels * width * height];
    foreach (i, ref value; typed)
        value = cast(T)((i * 13 + 7) % 251);

    OwnedByteResource resource;
    require(tryAdoptMallocResource(ownedMemory, bytes, resource), "adoption failed");
    RasterLease!T lease;
    auto layout = interleaved ? interleavedLayouts!T() : layouts!T();
    require(tryImportOwnedRaster!T(resource, layout, Region2D(0, 0, width, height), lease).ok,
        "import failed");
    return lease;
}

private ulong checksum(RasterLease!float lease)
@safe
{
    auto view = lease.view();
    ulong result = 1469598103934665603UL;
    float value;
    foreach (band; 0 .. channels)
        foreach (y; 0 .. height)
            foreach (x; 0 .. width)
            {
                require(view.trySample(band, x, y, value), "checksum read failed");
                result = (result ^ cast(ulong)(value * 1000.0f)) * 1099511628211UL;
            }
    return result;
}

private void requireEqualOutputs(RasterLease!float leftLease,
    RasterLease!float rightLease)
@safe
{
    auto left = leftLease.view();
    auto right = rightLease.view();
    float leftValue, rightValue;
    foreach (band; 0 .. channels)
        foreach (y; 0 .. height)
            foreach (x; 0 .. width)
            {
                require(left.trySample(band, x, y, leftValue), "left output read failed");
                require(right.trySample(band, x, y, rightValue), "right output read failed");
                if (leftValue != rightValue)
                {
                    writefln("mismatch band=%s x=%s y=%s serial=%s parallel=%s",
                        band, x, y, leftValue, rightValue);
                    throw new Exception("serial and parallel output arrays differ");
                }
            }
}

private long checkedPath(RasterLease!ubyte sourceLease, RasterLease!float destinationLease)
@safe
{
    auto source = sourceLease.view();
    bool writableOk;
    auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    const start = MonoTime.currTime;
    foreach (_; 0 .. 2)
        foreach (band; 0 .. channels)
            foreach (y; 0 .. height)
                foreach (x; 0 .. width)
                {
                    ubyte value;
                    require(source.trySample(band, x, y, value), "source read failed");
                    require(destination.trySetSample(band, x, y, cast(float)value + 0.5f), "destination write failed");
                }
    return (MonoTime.currTime - start).total!"nsecs";
}

private long dataPlanePath(RasterLease!ubyte sourceLease, RasterLease!float destinationLease)
@safe
{
    auto source = sourceLease.view();
    bool writableOk;
    auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    RasterPlaneWindow!ubyte[channels] sources;
    WritableRasterPlaneWindow!float[channels] destinations;
    const start = MonoTime.currTime;
    require(withPlanesInto(source, [0, 1, 2], destination, [0, 1, 2],
        sources[], destinations[],
        (scope const(RasterPlaneWindow!ubyte)[] src,
            scope WritableRasterPlaneWindow!float[] dst)
            @safe nothrow @nogc
            {
                foreach (band; 0 .. channels)
                    foreach (y; 0 .. height)
                        foreach (x; 0 .. width)
                            dst[band].store(x, y, cast(float)src[band].load(x, y) + 0.5f);
            }), "data-plane callback failed");
    return (MonoTime.currTime - start).total!"nsecs";
}

private long rowDataPlanePath(RasterLease!ubyte sourceLease, RasterLease!float destinationLease)
@safe
{
    auto source = sourceLease.view();
    bool writableOk;
    auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    RasterPlaneWindow!ubyte[channels] sources;
    WritableRasterPlaneWindow!float[channels] destinations;
    const start = MonoTime.currTime;
    require(withPlanesInto(source, [0, 1, 2], destination, [0, 1, 2], sources[], destinations[],
        (scope const(RasterPlaneWindow!ubyte)[] src, scope WritableRasterPlaneWindow!float[] dst)
            @safe nothrow @nogc
        {
            foreach (y; 0 .. height) {
                auto r0 = src[0].row(y); auto r1 = src[1].row(y); auto r2 = src[2].row(y);
                auto w0 = dst[0].row(y); auto w1 = dst[1].row(y); auto w2 = dst[2].row(y);
                foreach (x; 0 .. width) {
                    w0.store(x, cast(float) r0.load(x) + 0.5f);
                    w1.store(x, cast(float) r1.load(x) + 0.5f);
                    w2.store(x, cast(float) r2.load(x) + 0.5f);
                }
            }
        }), "row data-plane callback failed");
    return (MonoTime.currTime - start).total!"nsecs";
}

private long stridedRowDataPlanePath(RasterLease!ubyte sourceLease, RasterLease!float destinationLease)
@safe
{
    auto source = sourceLease.view();
    bool writableOk;
    auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    RasterPlaneWindow!ubyte[channels] sources;
    WritableRasterPlaneWindow!float[channels] destinations;
    const start = MonoTime.currTime;
    require(withPlanesInto(source, [0, 1, 2], destination, [0, 1, 2], sources[], destinations[],
        (scope const(RasterPlaneWindow!ubyte)[] src, scope WritableRasterPlaneWindow!float[] dst)
            @trusted nothrow @nogc
        {
            foreach (y; 0 .. height) {
                auto r0 = src[0].row(y); auto r1 = src[1].row(y); auto r2 = src[2].row(y);
                auto w0 = dst[0].row(y); auto w1 = dst[1].row(y); auto w2 = dst[2].row(y);
                auto s0 = r0.data; auto s1 = r1.data; auto s2 = r2.data;
                auto d0 = w0.data; auto d1 = w1.data; auto d2 = w2.data;
                const ss0 = r0.sampleStride; const ss1 = r1.sampleStride; const ss2 = r2.sampleStride;
                const ds0 = w0.sampleStride; const ds1 = w1.sampleStride; const ds2 = w2.sampleStride;
                foreach (x; 0 .. width) {
                    d0[x * ds0] = cast(float) s0[x * ss0] + 0.5f;
                    d1[x * ds1] = cast(float) s1[x * ss1] + 0.5f;
                    d2[x * ds2] = cast(float) s2[x * ss2] + 0.5f;
                }
            }
        }), "strided row data-plane callback failed");
    return (MonoTime.currTime - start).total!"nsecs";
}

private long parallelRowDataPlanePath(RasterLease!ubyte sourceLease, RasterLease!float destinationLease)
@safe
{
    auto source = sourceLease.view();
    bool writableOk;
    auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    RasterPlaneWindow!ubyte[channels] sources;
    WritableRasterPlaneWindow!float[channels] destinations;
    const start = MonoTime.currTime;
    require(withPlanesIntoParallel(source, [0, 1, 2], destination, [0, 1, 2],
        sources[], destinations[], benchmarkWorkers, benchmarkChunk,
        (scope const(RasterPlaneWindow!ubyte)[] src,
            scope WritableRasterPlaneWindow!float[] dst,
            size_t firstRow, size_t endRow) nothrow
        {
            foreach (y; firstRow .. endRow)
                foreach (band; 0 .. channels)
                    foreach (x; 0 .. width)
                        dst[band].store(x, y, cast(float)src[band].load(x, y) + 0.5f);
            return true;
        }), "parallel row data-plane callback failed");
    return (MonoTime.currTime - start).total!"nsecs";
}

private long parallelTwoPhasePath(RasterLease!ubyte sourceLease, RasterLease!float destinationLease)
@safe
{
    auto source = sourceLease.view();
    bool writableOk;
    auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    RasterPlaneWindow!ubyte[channels] sources;
    WritableRasterPlaneWindow!float[channels] destinations;
    shared ulong selected;
    const start = MonoTime.currTime;
    require(withPlanesIntoParallelPhases(source,
        [size_t(0), size_t(1), size_t(2)], destination,
        [size_t(0), size_t(1), size_t(2)], sources[], destinations[],
        benchmarkWorkers, benchmarkChunk,
        (scope const(RasterPlaneWindow!ubyte)[] src,
            scope WritableRasterPlaneWindow!float[] dst,
            scope ParallelRowsOperation operation) @safe nothrow
        {
            assert(operation.forRows(
                (size_t worker, size_t firstRow, size_t endRow) nothrow
                {
                    ulong local;
                    foreach (y; firstRow .. endRow)
                        foreach (x; 0 .. width)
                            local += src[0].load(x, y) != 0;
                    atomicFetchAdd!(MemoryOrder.rel)(selected, local);
                    return true;
                }) == ParallelRowsResult.completed);
            return operation.forRows(
                (size_t worker, size_t firstRow, size_t endRow) nothrow
                {
                    foreach (y; firstRow .. endRow)
                        foreach (band; 0 .. channels)
                            foreach (x; 0 .. width)
                                dst[band].store(x, y,
                                    cast(float)src[band].load(x, y) + 0.5f);
                    return true;
                }) == ParallelRowsResult.completed;
        }), "two-phase data-plane callback failed");
    return (MonoTime.currTime - start).total!"nsecs";
}

private long imageryShapedTwoPhasePath(RasterLease!ubyte rgbLease,
    RasterLease!ubyte maskLease, RasterLease!float destinationLease)
@safe
{
    auto rgb = rgbLease.view();
    auto mask = maskLease.view();
    bool writableOk;
    auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    RasterView!ubyte[2] views = [rgb, mask];
    const(size_t)[][] planes = [[size_t(0), size_t(1), size_t(2)], [size_t(0)]];
    RasterPlaneWindow!ubyte[][] windows = [
        new RasterPlaneWindow!ubyte[channels], new RasterPlaneWindow!ubyte[1]];
    WritableRasterPlaneWindow!float[channels] destinations;
    ulong[][benchmarkWorkers] histograms;
    ulong[benchmarkWorkers] selected;
    foreach (ref histogram; histograms) histogram = new ulong[histogramBins];
    const start = MonoTime.currTime;
    const completed = withViewsIntoParallelPhases(views[], planes, windows,
        destination, [size_t(0), size_t(1), size_t(2)], destinations[],
        benchmarkWorkers, benchmarkChunk,
        (scope RasterPlaneWindow!ubyte[][] src,
            scope WritableRasterPlaneWindow!float[] dst,
            scope ParallelRowsOperation operation) @safe nothrow
        {
            if (operation.forRows(
                (size_t worker, size_t firstRow, size_t endRow) nothrow
                {
                    auto histogram = histograms[worker];
                    ulong localSelected;
                    foreach (y; firstRow .. endRow)
                    {
                        foreach (x; 0 .. width)
                        {
                            if (src[1][0].load(x, y) != 0) {
                                const value = lumaBin(src[0][0].load(x, y),
                                    src[0][1].load(x, y), src[0][2].load(x, y));
                                ++histogram[value];
                                ++localSelected;
                            }
                        }
                    }
                    selected[worker] += localSelected;
                    return true;
                }) != ParallelRowsResult.completed)
                return false;
            ulong selectedTotal;
            ulong histogramTotal;
            foreach (worker; 0 .. benchmarkWorkers)
            {
                selectedTotal += selected[worker];
                foreach (count; histograms[worker]) histogramTotal += count;
            }
            const threshold = nearestRank(histograms, histogramTotal, percentile);
            try
            {
                if (parallelRows(height, benchmarkWorkers, benchmarkChunk,
                    (size_t firstRow, size_t endRow) nothrow
                    {
                        foreach (y; firstRow .. endRow)
                            foreach (x; 0 .. width)
                            {
                                const value = lumaBin(src[0][0].load(x, y),
                                    src[0][1].load(x, y), src[0][2].load(x, y));
                                const offset = cast(float)(value >= threshold ? 1 : 0);
                                foreach (band; 0 .. channels)
                                    dst[band].store(x, y,
                                        cast(float)src[0][band].load(x, y) + offset);
                            }
                        return true;
                    }) != ParallelRowsResult.completed)
                    return false;
            }
            catch (Exception)
                return false;
            return true;
        });
    require(completed, "imagery-shaped two-phase callback failed");
    return (MonoTime.currTime - start).total!"nsecs";
}

private ushort lumaBin(ubyte r, ubyte g, ubyte b) @safe nothrow @nogc
{
    // 77 + 150 + 29 = 256; scaling by 257 maps 0..255 to 0..65535.
    return cast(ushort)((cast(uint)(77 * r + 150 * g + 29 * b) * 257) / 256);
}

private ushort nearestRank(ulong[][benchmarkWorkers] histograms,
    ulong total, uint percentileValue) @safe nothrow @nogc
{
    if (total == 0) return 0;
    const rank = ((total * percentileValue) + 99) / 100; // one-based rank
    ulong cumulative;
    foreach (bin; 0 .. histogramBins) {
        foreach (worker; 0 .. benchmarkWorkers) cumulative += histograms[worker][bin];
        if (cumulative >= rank) return cast(ushort)bin;
    }
    return cast(ushort)(histogramBins - 1);
}

private void validateHistogramReference() @safe
{
    // Independent scalar fixture: the excluded high sample must not enter the
    // histogram, and ceil(75% of four selected samples) is the third sample.
    const ushort[5] values = [10, 20, 30, 40, 250];
    const bool[5] selected = [true, true, true, true, false];
    ulong[histogramBins] histogram;
    ulong selectedTotal;
    foreach (i, value; values)
        if (selected[i]) { ++histogram[lumaBin(cast(ubyte)value, cast(ubyte)value, cast(ubyte)value)]; ++selectedTotal; }
    require(histogram[lumaBin(250, 250, 250)] == 0, "reference mask leaked into histogram");
    ulong[][benchmarkWorkers] reduced;
    foreach (ref h; reduced) h = new ulong[histogramBins];
    foreach (bin; 0 .. histogramBins) reduced[0][bin] = histogram[bin];
    require(nearestRank(reduced, selectedTotal, percentile) == lumaBin(30, 30, 30),
        "reference percentile mismatch");

    // The excluded high sample still receives the threshold-derived transform.
    const threshold = lumaBin(30, 30, 30);
    require(cast(float)250 + (lumaBin(250, 250, 250) >= threshold ? 1 : 0) == 251,
        "excluded reference sample was not transformed");
    require(cast(float)10 + (lumaBin(10, 10, 10) >= threshold ? 1 : 0) == 10,
        "below-threshold reference sample was transformed incorrectly");
}

private long serialImageryPath(RasterLease!ubyte rgbLease,
    RasterLease!ubyte maskLease, RasterLease!float destinationLease)
@safe
{
    auto rgb = rgbLease.view(); auto mask = maskLease.view();
    bool writableOk; auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    ulong[histogramBins] histogram; ulong selectedTotal;
    const start = MonoTime.currTime;
    foreach (y; 0 .. height) foreach (x; 0 .. width) {
        ubyte maskValue;
        require(mask.trySample(0, x, y, maskValue), "mask read failed");
        if (maskValue != 0) {
            ubyte r, g, b; require(rgb.trySample(0, x, y, r) && rgb.trySample(1, x, y, g)
                && rgb.trySample(2, x, y, b), "source read failed");
            ++histogram[lumaBin(r, g, b)]; ++selectedTotal;
        }
    }
    ulong[][benchmarkWorkers] reduced;
    foreach (ref h; reduced) h = new ulong[histogramBins];
    foreach (bin; 0 .. histogramBins) reduced[0][bin] = histogram[bin];
    const threshold = nearestRank(reduced, selectedTotal, percentile);
    RasterPlaneWindow!ubyte[channels] sourceWindows;
    WritableRasterPlaneWindow!float[channels] destinationWindows;
    require(withPlanesInto(rgb, [size_t(0), size_t(1), size_t(2)], destination,
        [size_t(0), size_t(1), size_t(2)], sourceWindows[], destinationWindows[],
        (scope const(RasterPlaneWindow!ubyte)[] src,
            scope WritableRasterPlaneWindow!float[] dst) @safe nothrow @nogc
        {
            foreach (y; 0 .. height)
                foreach (x; 0 .. width)
                {
                    const value = lumaBin(src[0].load(x, y), src[1].load(x, y), src[2].load(x, y));
                    const offset = cast(float)(value >= threshold ? 1 : 0);
                    foreach (band; 0 .. channels)
                        dst[band].store(x, y, cast(float)src[band].load(x, y) + offset);
                }
        }), "serial transform window failed");
    return (MonoTime.currTime - start).total!"nsecs";
}

private long multiPlaneSlicePath(RasterLease!ubyte sourceLease, RasterLease!float destinationLease)
@safe
{
    auto source = sourceLease.view();
    bool writableOk;
    auto destination = destinationLease.tryWritableView(writableOk);
    require(writableOk, "writable view failed");
    const(ubyte)[][channels] sources;
    float[][channels] destinations;
    const start = MonoTime.currTime;
    auto ok = withContiguousPlanesInto!(ubyte, float)(source, [0, 1, 2], destination, [0, 1, 2],
        sources[], destinations[],
        (scope const(ubyte)[][] src, scope float[][] dst)
            @safe nothrow @nogc
        {
            foreach (band; 0 .. channels)
                foreach (i; 0 .. src[band].length)
                    dst[band][i] = cast(float)src[band][i] + 0.5f;
        });
    require(ok, "multi-plane contiguous validation failed");
    return (MonoTime.currTime - start).total!"nsecs";
}

void main()
@system
{
    validateHistogramReference();
    string compiler;
    version (DigitalMars) compiler = "dmd";
    else version (LDC) compiler = "ldc";
    else compiler = "other";

    void* sourceMemory;
    void* destinationMemory;
    void* maskMemory;
    auto source = makeLease!(ubyte, true)(sourceMemory);
    auto mask = makeLease!(ubyte)(maskMemory);
    auto destination = makeLease!(float, true)(destinationMemory);
    void* serialDestinationMemory;
    auto serialDestination = makeLease!(float, true)(serialDestinationMemory);
    void* imageryDestinationMemory;
    auto imageryDestination = makeLease!(float, true)(imageryDestinationMemory);

    foreach (_; 0 .. warmups) { checkedPath(source, destination); dataPlanePath(source, destination); rowDataPlanePath(source, destination); stridedRowDataPlanePath(source, destination); parallelRowDataPlanePath(source, destination); parallelTwoPhasePath(source, destination); serialImageryPath(source, mask, serialDestination); imageryShapedTwoPhasePath(source, mask, imageryDestination); }
    long[warmups + samples] checked;
    long[warmups + samples] dataPlane;
    long[warmups + samples] rows;
    long[warmups + samples] stridedRows;
    long[warmups + samples] parallelRows;
    long[warmups + samples] twoPhase;
    long[warmups + samples] imageryTwoPhase;
    long[warmups + samples] imagerySerial;
    foreach (i; 0 .. checked.length) {
        checked[i] = checkedPath(source, destination);
        dataPlane[i] = dataPlanePath(source, destination);
        rows[i] = rowDataPlanePath(source, destination);
        stridedRows[i] = stridedRowDataPlanePath(source, destination);
        parallelRows[i] = parallelRowDataPlanePath(source, destination);
        twoPhase[i] = parallelTwoPhasePath(source, destination);
        imagerySerial[i] = serialImageryPath(source, mask, serialDestination);
        imageryTwoPhase[i] = imageryShapedTwoPhasePath(source, mask, imageryDestination);
        requireEqualOutputs(serialDestination, imageryDestination);
    }
    auto checkedMeasured = checked[warmups .. $].sort;
    auto dataMeasured = dataPlane[warmups .. $].sort;
    auto rowMeasured = rows[warmups .. $].sort;
    auto stridedMeasured = stridedRows[warmups .. $].sort;
    auto parallelMeasured = parallelRows[warmups .. $].sort;
    auto twoPhaseMeasured = twoPhase[warmups .. $].sort;
    auto imageryTwoPhaseMeasured = imageryTwoPhase[warmups .. $].sort;
    auto imagerySerialMeasured = imagerySerial[warmups .. $].sort;
    writefln("data_plane_benchmark compiler=%s checked_ns_per_pixel=%.3f data_plane_ns_per_pixel=%.3f row_ns_per_pixel=%.3f strided_row_ns_per_pixel=%.3f parallel_row_ns_per_pixel=%.3f two_phase_ns_per_pixel=%.3f imagery_serial_ns_per_pixel=%.3f imagery_two_phase_ns_per_pixel=%.3f workers=%s minimum_chunk=%s checksum=%016x",
        compiler, cast(double)checkedMeasured[$ / 2] / (2 * width * height),
        cast(double)dataMeasured[$ / 2] / (2 * width * height),
        cast(double)rowMeasured[$ / 2] / (2 * width * height),
        cast(double)stridedMeasured[$ / 2] / (2 * width * height),
        cast(double)parallelMeasured[$ / 2] / (2 * width * height),
        cast(double)twoPhaseMeasured[$ / 2] / (2 * width * height),
        cast(double)imagerySerialMeasured[$ / 2] / (2 * width * height),
        cast(double)imageryTwoPhaseMeasured[$ / 2] / (2 * width * height),
        benchmarkWorkers, benchmarkChunk, checksum(destination));
}
