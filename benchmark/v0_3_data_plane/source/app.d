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
            scope ParallelRowsOperation operation) nothrow
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
    string compiler;
    version (DigitalMars) compiler = "dmd";
    else version (LDC) compiler = "ldc";
    else compiler = "other";

    void* sourceMemory;
    void* destinationMemory;
    auto source = makeLease!(ubyte, true)(sourceMemory);
    auto destination = makeLease!(float, true)(destinationMemory);

    foreach (_; 0 .. warmups) { checkedPath(source, destination); dataPlanePath(source, destination); rowDataPlanePath(source, destination); stridedRowDataPlanePath(source, destination); parallelRowDataPlanePath(source, destination); parallelTwoPhasePath(source, destination); }
    long[warmups + samples] checked;
    long[warmups + samples] dataPlane;
    long[warmups + samples] rows;
    long[warmups + samples] stridedRows;
    long[warmups + samples] parallelRows;
    long[warmups + samples] twoPhase;
    foreach (i; 0 .. checked.length) {
        checked[i] = checkedPath(source, destination);
        dataPlane[i] = dataPlanePath(source, destination);
        rows[i] = rowDataPlanePath(source, destination);
        stridedRows[i] = stridedRowDataPlanePath(source, destination);
        parallelRows[i] = parallelRowDataPlanePath(source, destination);
        twoPhase[i] = parallelTwoPhasePath(source, destination);
    }
    auto checkedMeasured = checked[warmups .. $].sort;
    auto dataMeasured = dataPlane[warmups .. $].sort;
    auto rowMeasured = rows[warmups .. $].sort;
    auto stridedMeasured = stridedRows[warmups .. $].sort;
    auto parallelMeasured = parallelRows[warmups .. $].sort;
    auto twoPhaseMeasured = twoPhase[warmups .. $].sort;
    writefln("data_plane_benchmark compiler=%s checked_ns_per_pixel=%.3f data_plane_ns_per_pixel=%.3f row_ns_per_pixel=%.3f strided_row_ns_per_pixel=%.3f parallel_row_ns_per_pixel=%.3f two_phase_ns_per_pixel=%.3f workers=%s minimum_chunk=%s checksum=%016x",
        compiler, cast(double)checkedMeasured[$ / 2] / (2 * width * height),
        cast(double)dataMeasured[$ / 2] / (2 * width * height),
        cast(double)rowMeasured[$ / 2] / (2 * width * height),
        cast(double)stridedMeasured[$ / 2] / (2 * width * height),
        cast(double)parallelMeasured[$ / 2] / (2 * width * height),
        cast(double)twoPhaseMeasured[$ / 2] / (2 * width * height),
        benchmarkWorkers, benchmarkChunk, checksum(destination));
}
