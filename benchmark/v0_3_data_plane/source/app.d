module raster.benchmark_v0_3_data_plane;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;
import std.algorithm.sorting : sort;
import std.stdio : writefln;
import raster;

enum width = 256;
enum height = 256;
enum channels = 3;
enum warmups = 3;
enum samples = 7;

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

private RasterLease!T makeLease(T)(out void* ownedMemory)
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
    require(tryImportOwnedRaster!T(resource, layouts!T(), Region2D(0, 0, width, height), lease).ok,
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

void main()
@system
{
    string compiler;
    version (DigitalMars) compiler = "dmd";
    else version (LDC) compiler = "ldc";
    else compiler = "other";

    void* sourceMemory;
    void* destinationMemory;
    auto source = makeLease!ubyte(sourceMemory);
    auto destination = makeLease!float(destinationMemory);

    foreach (_; 0 .. warmups) { checkedPath(source, destination); dataPlanePath(source, destination); }
    long[warmups + samples] checked;
    long[warmups + samples] dataPlane;
    foreach (i; 0 .. checked.length) {
        checked[i] = checkedPath(source, destination);
        dataPlane[i] = dataPlanePath(source, destination);
    }
    auto checkedMeasured = checked[warmups .. $].sort;
    auto dataMeasured = dataPlane[warmups .. $].sort;
    writefln("data_plane_benchmark compiler=%s checked_ns_per_pixel=%.3f data_plane_ns_per_pixel=%.3f checksum=%016x",
        compiler, cast(double)checkedMeasured[$ / 2] / (2 * width * height),
        cast(double)dataMeasured[$ / 2] / (2 * width * height), checksum(destination));
}
