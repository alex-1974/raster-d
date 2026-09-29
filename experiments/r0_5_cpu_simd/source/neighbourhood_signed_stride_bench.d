module neighbourhood_signed_stride_bench;

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
    U u; u.f=value; return u.u;
}

private void consume(scope const(float)[] dst, size_t width, size_t height)
@trusted nothrow @nogc
{
    ulong v=++invocation*0x9e3779b97f4a7c15UL;
    foreach(y;0..height) {
        const row=y*width;
        v=(v^bits(dst[row]))*0x9e3779b185ebca87UL;
        v=(v^bits(dst[row+width-1]))*0xc2b2ae3d27d4eb4fUL;
    }
    sink^=v;
}

private void fill(scope float[] a) @safe nothrow @nogc
{
    foreach(i;0..a.length)
        a[i]=cast(float)((i*37+(i>>4)*13)%4093)*0.00025f;
}

private void box3SignedValidated(
    scope const(float)[] storage,
    size_t origin,
    ptrdiff_t rowStride,
    scope float[] dst,
    size_t width,
    size_t height)
@safe pure nothrow @nogc
{
    if (width == 0 || height == 0)
        return;

    assert(width <= cast(size_t) ptrdiff_t.max - 2);
    assert(height <= cast(size_t) ptrdiff_t.max - 2);
    assert(origin < storage.length);
    assert(width <= size_t.max / height);
    assert(width * height <= dst.length);

    const signedOrigin=cast(ptrdiff_t)origin;
    const lastRow=cast(ptrdiff_t)(height+1);

    // Research-only validation for this fixture: prove both physical row
    // extremes plus the rightmost halo sample before entering trusted code.
    ptrdiff_t minRowOffset;
    ptrdiff_t maxRowOffset;
    if (rowStride >= 0) {
        minRowOffset=0;
        assert(lastRow == 0 || rowStride <= ptrdiff_t.max / lastRow);
        maxRowOffset=lastRow*rowStride;
    } else {
        maxRowOffset=0;
        assert(rowStride != ptrdiff_t.min);
        const magnitude=-rowStride;
        assert(lastRow == 0 || magnitude <= ptrdiff_t.max / lastRow);
        minRowOffset=-(lastRow*magnitude);
    }

    assert(signedOrigin >= -minRowOffset);
    const maxBase=signedOrigin+maxRowOffset;
    assert(maxBase >= 0);
    assert(cast(size_t)maxBase <= storage.length-(width+2));

    box3SignedUnchecked(storage, origin, rowStride, dst, width, height);
}

private void box3SignedUnchecked(
    scope const(float)[] storage,
    size_t origin,
    ptrdiff_t rowStride,
    scope float[] dst,
    size_t width,
    size_t height)
@trusted pure nothrow @nogc
{
    const base=storage.ptr+origin;
    auto dp=dst.ptr;
    foreach(y;0..height) {
        const py=cast(ptrdiff_t)y;
        const r0=py*rowStride;
        const r1=(py+1)*rowStride;
        const r2=(py+2)*rowStride;
        const d=y*width;
        foreach(x;0..width) {
            const px=cast(ptrdiff_t)x;
            dp[d+x] =
                base[r0+px] + base[r0+px+1] + base[r0+px+2] +
                base[r1+px] + base[r1+px+1] + base[r1+px+2] +
                base[r2+px] + base[r2+px+1] + base[r2+px+2];
        }
    }
}

private long measure(void delegate() op)
{
    const t=MonoTime.currTime; op();
    return (MonoTime.currTime-t).total!"nsecs";
}
private long median(scope long[] a){sort(a);return a[a.length/2];}

private int runCase(size_t pitch, bool reverse)
{
    enum size_t width=2048, height=512;
    const rows=height+2;
    auto storage=new float[pitch*rows];
    auto dst=new float[width*height];
    fill(storage);

    const origin=reverse ? (rows-1)*pitch : 0;
    const stride=reverse ? -cast(ptrdiff_t)pitch : cast(ptrdiff_t)pitch;

    box3SignedValidated(storage,origin,stride,dst,width,height);
    consume(dst,width,height);

    foreach(_;0..warmups) {
        box3SignedValidated(storage,origin,stride,dst,width,height);
        consume(dst,width,height);
    }

    long[repetitions] samples;
    foreach(i;0..repetitions)
        samples[i]=measure({
            box3SignedValidated(storage,origin,stride,dst,width,height);
            consume(dst,width,height);
        });

    auto m=samples;
    writefln(
        "neighbourhood3x3_signed width=%s height=%s halo=1 pitch=%s direction=%s validated_ns=%s sink=%s",
        width,height,pitch,reverse ? "negative" : "positive",median(m[]),sink);
    writefln(
        "neighbourhood3x3_signed pitch=%s direction=%s raw_ns=%(%s,%)",
        pitch,reverse ? "negative" : "positive",samples);
    return 0;
}

int runNeighbourhoodSignedStrideMatrix()
{
    foreach(pitch; [cast(size_t)2050,2112,2304,4096]) {
        if(runCase(pitch,false)!=0) return 1;
        if(runCase(pitch,true)!=0) return 1;
    }
    return 0;
}
