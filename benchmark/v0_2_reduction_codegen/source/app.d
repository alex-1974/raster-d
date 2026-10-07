module raster.benchmark_reduction_codegen;

import core.stdc.stdlib : malloc;
import core.time : MonoTime;
import std.algorithm.sorting : sort;
import std.conv : to;
import std.math : signbit;
import std.stdio : writefln;

import raster;
import raster.internal.extrema : ExtremaMode, ExtremaStatus, executeExtrema;
import raster.internal.strict_sum : StrictSumStatus, executeStrictSum;

private enum size_t warmups = 6;
private enum size_t samples = 18;

private void require(bool condition, string message) @safe
{
    if (!condition) throw new Exception(message);
}

private bool makeFloatLease(size_t width, size_t height, size_t rowPadding,
    ref RasterLease!float lease) @system
{
    const rowElements = width + rowPadding;
    if (width == 0 || height == 0 || rowElements < width
        || rowElements > size_t.max / height) return false;
    const elementCount = rowElements * height;
    if (elementCount > size_t.max / float.sizeof) return false;
    const byteLength = elementCount * float.sizeof;
    void* memory = malloc(byteLength);
    if (memory is null) return false;
    auto data = (cast(float*) memory)[0 .. elementCount];

    foreach (y; 0 .. height)
        foreach (x; 0 .. rowElements)
            data[y * rowElements + x] =
                cast(float)(cast(int)((y * 977 + x * 131 + 17) % 8191) - 4095)
                * 0.001953125f;

    OwnedByteResource resource;
    if (!tryAdoptMallocResource(memory, byteLength, resource)) return false;
    const PlaneByteLayout[1] layouts = [
        PlaneByteLayout(0,
            cast(ptrdiff_t)(rowElements * float.sizeof),
            cast(ptrdiff_t) float.sizeof)
    ];
    const imported = tryImportOwnedRaster!float(
        resource, layouts[], Region2D(0, 0, width, height), lease);
    return imported.ok;
}

private ulong floatBits(float value) @safe pure nothrow @nogc
{
    union Bits { float value; uint bits; }
    Bits bits; bits.value = value; return bits.bits;
}
private ulong doubleBits(double value) @safe pure nothrow @nogc
{
    union Bits { double value; ulong bits; }
    Bits bits; bits.value = value; return bits.bits;
}
private long median(long[samples] values)
{
    sort(values[]);
    return (values[samples / 2 - 1] + values[samples / 2]) / 2;
}

private float publicMax(scope RasterView!float source) @safe
{
    const r = source.max(0); require(r.ok, "public max failed"); return r.value;
}
private float semanticMax(scope RasterView!float source) @safe
{
    const r = executeExtrema!(ExtremaMode.maximum, float)(source, 0);
    require(r.status == ExtremaStatus.none, "semantic max failed");
    return r.maximum;
}
private void updateMaximum(ref float current, float value) @safe pure nothrow @nogc
{
    if (value > current) { current = value; return; }
    if (value == current && value == 0.0f && !signbit(value)) current = value;
}
private void updateMinimum(ref float current, float value) @safe pure nothrow @nogc
{
    if (value < current) { current = value; return; }
    if (value == current && value == 0.0f && signbit(value)) current = value;
}

private float runtimeMax(scope RasterView!float source) @trusted nothrow @nogc
{
    ptrdiff_t rs, ss;
    const ok = source.tryExecutionPlaneStrides(0, rs, ss);
    assert(ok && !source.empty);
    const(float)* row = source.executionRegionBase(0);
    float best = *row;
    if (best != best) return best;
    bool first = true;
    foreach (y; 0 .. source.height) {
        const(float)* p = row;
        foreach (x; 0 .. source.width) {
            if (first) first = false;
            else {
                const v = *p;
                if (v != v) return v;
                updateMaximum(best, v);
            }
            if (x + 1 < source.width) p += ss;
        }
        if (y + 1 < source.height) row += rs;
    }
    return best;
}
private float staticMax(scope RasterView!float source) @trusted nothrow @nogc
{
    ptrdiff_t rs, ss;
    const ok = source.tryExecutionPlaneStrides(0, rs, ss);
    assert(ok && ss == 1 && !source.empty);
    const(float)* base = source.executionRegionBase(0);
    float best = *base;
    if (best != best) return best;
    bool first = true;
    foreach (y; 0 .. source.height) {
        const(float)* row = base + cast(ptrdiff_t)y * rs;
        foreach (x; 0 .. source.width) {
            if (first) first = false;
            else {
                const v = row[x];
                if (v != v) return v;
                updateMaximum(best, v);
            }
        }
    }
    return best;
}

private struct Pair { float minimum; float maximum; }

private Pair publicMinMax(scope RasterView!float source) @safe
{
    const r = source.minMax(0); require(r.ok, "public minMax failed");
    return Pair(r.minimum, r.maximum);
}
private Pair semanticMinMax(scope RasterView!float source) @safe
{
    const r = executeExtrema!(ExtremaMode.minMax, float)(source, 0);
    require(r.status == ExtremaStatus.none, "semantic minMax failed");
    return Pair(r.minimum, r.maximum);
}
private Pair runtimeMinMax(scope RasterView!float source) @trusted nothrow @nogc
{
    ptrdiff_t rs, ss;
    const ok = source.tryExecutionPlaneStrides(0, rs, ss);
    assert(ok && !source.empty);
    const(float)* row = source.executionRegionBase(0);
    float lo = *row, hi = *row;
    if (lo != lo) return Pair(lo, lo);
    bool first = true;
    foreach (y; 0 .. source.height) {
        const(float)* p = row;
        foreach (x; 0 .. source.width) {
            if (first) first = false;
            else {
                const v = *p;
                if (v != v) return Pair(v, v);
                updateMinimum(lo, v);
                updateMaximum(hi, v);
            }
            if (x + 1 < source.width) p += ss;
        }
        if (y + 1 < source.height) row += rs;
    }
    return Pair(lo, hi);
}
private Pair staticMinMax(scope RasterView!float source) @trusted nothrow @nogc
{
    ptrdiff_t rs, ss;
    const ok = source.tryExecutionPlaneStrides(0, rs, ss);
    assert(ok && ss == 1 && !source.empty);
    const(float)* base = source.executionRegionBase(0);
    float lo = *base, hi = *base;
    if (lo != lo) return Pair(lo, lo);
    bool first = true;
    foreach (y; 0 .. source.height) {
        const(float)* row = base + cast(ptrdiff_t)y * rs;
        foreach (x; 0 .. source.width) {
            if (first) first = false;
            else {
                const v = row[x];
                if (v != v) return Pair(v, v);
                updateMinimum(lo, v);
                updateMaximum(hi, v);
            }
        }
    }
    return Pair(lo, hi);
}
private Pair staticTwoPass(scope RasterView!float source) @trusted nothrow @nogc
{
    ptrdiff_t rs, ss;
    const ok = source.tryExecutionPlaneStrides(0, rs, ss);
    assert(ok && ss == 1 && !source.empty);
    const(float)* base = source.executionRegionBase(0);
    float lo = *base;
    if (lo != lo) return Pair(lo, lo);
    bool first = true;
    foreach (y; 0 .. source.height) {
        const(float)* row = base + cast(ptrdiff_t)y * rs;
        foreach (x; 0 .. source.width) {
            if (first) first = false;
            else {
                const v = row[x];
                if (v != v) return Pair(v, v);
                updateMinimum(lo, v);
            }
        }
    }
    float hi = *base;
    first = true;
    foreach (y; 0 .. source.height) {
        const(float)* row = base + cast(ptrdiff_t)y * rs;
        foreach (x; 0 .. source.width) {
            if (first) first = false;
            else {
                const v = row[x];
                if (v != v) return Pair(v, v);
                updateMaximum(hi, v);
            }
        }
    }
    return Pair(lo, hi);
}

private double publicMean(scope RasterView!float source) @safe
{
    const r = source.mean!(double, double)(0);
    require(r.ok, "public mean failed"); return r.value;
}
private double semanticMean(scope RasterView!float source) @safe
{
    const r = executeStrictSum!(float, double)(source, 0);
    require(r.status == StrictSumStatus.none, "semantic mean failed");
    return r.value / cast(double)(source.width * source.height);
}
private double runtimeMean(scope RasterView!float source) @trusted nothrow @nogc
{
    ptrdiff_t rs, ss;
    const ok = source.tryExecutionPlaneStrides(0, rs, ss);
    assert(ok && !source.empty);
    const(float)* row = source.executionRegionBase(0);
    double total = 0.0;
    foreach (y; 0 .. source.height) {
        const(float)* p = row;
        foreach (x; 0 .. source.width) {
            total += cast(double)*p;
            if (x + 1 < source.width) p += ss;
        }
        if (y + 1 < source.height) row += rs;
    }
    return total / cast(double)(source.width * source.height);
}
private double staticMean(scope RasterView!float source) @trusted nothrow @nogc
{
    ptrdiff_t rs, ss;
    const ok = source.tryExecutionPlaneStrides(0, rs, ss);
    assert(ok && ss == 1 && !source.empty);
    const(float)* base = source.executionRegionBase(0);
    double total = 0.0;
    foreach (y; 0 .. source.height) {
        const(float)* row = base + cast(ptrdiff_t)y * rs;
        foreach (x; 0 .. source.width) total += cast(double)row[x];
    }
    return total / cast(double)(source.width * source.height);
}

private long timeFloat(alias op)(scope RasterView!float source, size_t iterations,
    out ulong checksum) @safe
{
    checksum = 0; const start = MonoTime.currTime;
    foreach (i; 0 .. iterations) checksum ^= floatBits(op(source)) + cast(ulong)i;
    return (MonoTime.currTime - start).total!"nsecs";
}
private long timePair(alias op)(scope RasterView!float source, size_t iterations,
    out ulong checksum) @safe
{
    checksum = 0; const start = MonoTime.currTime;
    foreach (i; 0 .. iterations) {
        const v = op(source);
        checksum ^= floatBits(v.minimum) ^ (floatBits(v.maximum) << 1) ^ cast(ulong)i;
    }
    return (MonoTime.currTime - start).total!"nsecs";
}
private long timeDouble(alias op)(scope RasterView!float source, size_t iterations,
    out ulong checksum) @safe
{
    checksum = 0; const start = MonoTime.currTime;
    foreach (i; 0 .. iterations) checksum ^= doubleBits(op(source)) + cast(ulong)i;
    return (MonoTime.currTime - start).total!"nsecs";
}
private string compilerName()
{
    version (DigitalMars) return "dmd";
    else version (LDC) return "ldc";
    else return "other";
}
private void printPath(string operation, string path, size_t width, size_t height,
    size_t iterations, long medianNs, ulong checksum)
{
    const n = cast(double)(width * height * iterations);
    writefln("reduction_codegen compiler=%s operation=%s path=%s width=%s height=%s iterations=%s samples=%s median_ns=%s ns_per_sample=%.6f checksum=%016x",
        compilerName(), operation, path, width, height, iterations, samples,
        medianNs, cast(double)medianNs / n, checksum);
}

void main(string[] args) @system
{
    const width = args.length >= 2 ? args[1].to!size_t : 2048;
    const height = args.length >= 3 ? args[2].to!size_t : 512;
    const iterations = args.length >= 4 ? args[3].to!size_t : 16;
    RasterLease!float lease;
    require(makeFloatLease(width, height, 32, lease), "source construction failed");
    scope auto source = lease.view();

    require(floatBits(publicMax(source)) == floatBits(semanticMax(source)), "max public/semantic mismatch");
    require(floatBits(publicMax(source)) == floatBits(runtimeMax(source)), "max runtime mismatch");
    require(floatBits(publicMax(source)) == floatBits(staticMax(source)), "max static mismatch");
    const expectedPair = publicMinMax(source);
    foreach (candidate; [semanticMinMax(source), runtimeMinMax(source), staticMinMax(source), staticTwoPass(source)])
        require(floatBits(candidate.minimum) == floatBits(expectedPair.minimum)
            && floatBits(candidate.maximum) == floatBits(expectedPair.maximum), "minMax mismatch");
    require(doubleBits(publicMean(source)) == doubleBits(semanticMean(source)), "mean semantic mismatch");
    require(doubleBits(publicMean(source)) == doubleBits(runtimeMean(source)), "mean runtime mismatch");
    require(doubleBits(publicMean(source)) == doubleBits(staticMean(source)), "mean static mismatch");

    ulong ignored;
    foreach (_; 0 .. warmups) {
        timeFloat!publicMax(source, 1, ignored); timeFloat!semanticMax(source, 1, ignored);
        timeFloat!runtimeMax(source, 1, ignored); timeFloat!staticMax(source, 1, ignored);
        timePair!publicMinMax(source, 1, ignored); timePair!semanticMinMax(source, 1, ignored);
        timePair!runtimeMinMax(source, 1, ignored); timePair!staticMinMax(source, 1, ignored);
        timePair!staticTwoPass(source, 1, ignored);
        timeDouble!publicMean(source, 1, ignored); timeDouble!semanticMean(source, 1, ignored);
        timeDouble!runtimeMean(source, 1, ignored); timeDouble!staticMean(source, 1, ignored);
    }

    long[samples][13] times;
    ulong[13] checksums;
    foreach (s; 0 .. samples) {
        ulong c;
        times[0][s]=timeFloat!publicMax(source,iterations,c); checksums[0]^=c;
        times[1][s]=timeFloat!semanticMax(source,iterations,c); checksums[1]^=c;
        times[2][s]=timeFloat!runtimeMax(source,iterations,c); checksums[2]^=c;
        times[3][s]=timeFloat!staticMax(source,iterations,c); checksums[3]^=c;
        times[4][s]=timePair!publicMinMax(source,iterations,c); checksums[4]^=c;
        times[5][s]=timePair!semanticMinMax(source,iterations,c); checksums[5]^=c;
        times[6][s]=timePair!runtimeMinMax(source,iterations,c); checksums[6]^=c;
        times[7][s]=timePair!staticMinMax(source,iterations,c); checksums[7]^=c;
        times[8][s]=timePair!staticTwoPass(source,iterations,c); checksums[8]^=c;
        times[9][s]=timeDouble!publicMean(source,iterations,c); checksums[9]^=c;
        times[10][s]=timeDouble!semanticMean(source,iterations,c); checksums[10]^=c;
        times[11][s]=timeDouble!runtimeMean(source,iterations,c); checksums[11]^=c;
        times[12][s]=timeDouble!staticMean(source,iterations,c); checksums[12]^=c;
    }

    enum ops=["max","max","max","max","minmax","minmax","minmax","minmax","minmax","mean","mean","mean","mean"];
    enum paths=["public","semantic","runtime_stride","static_stride1","public","semantic","runtime_stride","static_stride1","static_two_pass","public","semantic_strict","runtime_stride","static_stride1"];
    foreach (i; 0 .. 13) printPath(ops[i],paths[i],width,height,iterations,median(times[i]),checksums[i]);
}
