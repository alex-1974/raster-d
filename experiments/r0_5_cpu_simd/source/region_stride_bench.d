module region_stride_bench;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln;

private enum size_t repetitions = 12;
private enum size_t warmups = 2;
private __gshared ulong sink;
private __gshared ulong invocation;

private uint bits(float value) @trusted pure nothrow @nogc
{
    union U { float f; uint u; }
    U u; u.f = value; return u.u;
}

private void consume(scope const(float)[] storage, size_t rowStride, size_t width, size_t height)
@trusted nothrow @nogc
{
    ulong v = ++invocation * 0x9e3779b97f4a7c15UL;
    foreach (y; 0 .. height)
    {
        const row = y * rowStride;
        v = (v ^ bits(storage[row])) * 0x9e3779b185ebca87UL;
        v = (v ^ bits(storage[row + width - 1])) * 0xc2b2ae3d27d4eb4fUL;
    }
    sink ^= v;
}

private void affineContiguous(scope const(float)[] src, scope float[] dst, float gain, float bias)
@safe pure nothrow @nogc
{
    assert(src.length == dst.length);
    foreach (i; 0 .. src.length)
        dst[i] = src[i] * gain + bias;
}

private void affineRows(
    scope const(float)[] src, size_t srcStride,
    scope float[] dst, size_t dstStride,
    size_t width, size_t height, float gain, float bias)
@safe pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const s = y * srcStride;
        const d = y * dstStride;
        foreach (x; 0 .. width)
            dst[d + x] = src[s + x] * gain + bias;
    }
}

private void affineRowsPointer(
    scope const(float)[] src, size_t srcStride,
    scope float[] dst, size_t dstStride,
    size_t width, size_t height, float gain, float bias)
@trusted pure nothrow @nogc
{
    const sp = src.ptr;
    auto dp = dst.ptr;
    foreach (y; 0 .. height)
    {
        const s = y * srcStride;
        const d = y * dstStride;
        foreach (x; 0 .. width)
            dp[d + x] = sp[s + x] * gain + bias;
    }
}

private void fill(scope float[] data) @safe nothrow @nogc
{
    foreach (i; 0 .. data.length)
        data[i] = cast(float)((i * 37 + (i >> 5) * 11) % 10007) * 0.001f;
}

private long measure(void delegate() op)
{
    const t = MonoTime.currTime; op(); return (MonoTime.currTime - t).total!"nsecs";
}

private long median(scope long[] a) { sort(a); return a[a.length / 2]; }

private void raw(string name, size_t width, size_t height, size_t stride, scope const(long)[] a)
{
    import std.array : join;
    import std.conv : to;
    auto p = new string[a.length];
    foreach (i,v; a) p[i] = v.to!string;
    writefln("region_stride width=%s height=%s stride=%s %s_raw_ns=%s", width,height,stride,name,p.join(","));
}

private int runCase(size_t width, size_t height, size_t stride)
{
    const count = stride * height;
    auto src = new float[count];
    auto dst = new float[count];
    fill(src);

    const gain = 1.125f, bias = -0.25f;

    affineRows(src, stride, dst, stride, width, height, gain, bias);
    foreach (y; 0 .. height)
        foreach (x; 0 .. width)
            if (dst[y*stride+x] != src[y*stride+x]*gain+bias) return 1;

    long[repetitions] rows, pointer, control;
    foreach (_; 0 .. warmups) {
        affineRows(src,stride,dst,stride,width,height,gain,bias); consume(dst,stride,width,height);
        affineRowsPointer(src,stride,dst,stride,width,height,gain,bias); consume(dst,stride,width,height);
    }
    foreach (r; 0 .. repetitions) {
        const rot=r%3;
        foreach(step;0..3) final switch((rot+step)%3) {
            case 0: rows[r]=measure({affineRows(src,stride,dst,stride,width,height,gain,bias);consume(dst,stride,width,height);}); break;
            case 1: pointer[r]=measure({affineRowsPointer(src,stride,dst,stride,width,height,gain,bias);consume(dst,stride,width,height);}); break;
            case 2: control[r]=measure({affineRowsPointer(src,stride,dst,stride,width,height,gain,bias);consume(dst,stride,width,height);}); break;
        }
    }
    auto a=rows,b=pointer,c=control;
    writefln("region_stride width=%s height=%s stride=%s rows_ns=%s pointer_ns=%s pointer_control_ns=%s sink=%s",
        width,height,stride,median(a[]),median(b[]),median(c[]),sink);
    raw("rows",width,height,stride,rows[]);
    raw("pointer",width,height,stride,pointer[]);
    raw("pointer_control",width,height,stride,control[]);
    return 0;
}

int runRegionStrideMatrix()
{
    // Same logical 2048x512 region; physical row padding increases progressively.
    foreach (stride; [2048UL, 2112UL, 2304UL, 4096UL])
        if (runCase(2048, 512, cast(size_t)stride)) return 1;
    return 0;
}
