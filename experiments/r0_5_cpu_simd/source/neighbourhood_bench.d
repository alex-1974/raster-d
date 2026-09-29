module neighbourhood_bench;

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

private void box3Rows(scope const(float)[] src, size_t stride,
                      scope float[] dst, size_t width, size_t height)
@safe pure nothrow @nogc
{
    foreach(y;0..height) {
        const r0=y*stride;
        const r1=(y+1)*stride;
        const r2=(y+2)*stride;
        const d=y*width;
        foreach(x;0..width) {
            dst[d+x] =
                src[r0+x] + src[r0+x+1] + src[r0+x+2] +
                src[r1+x] + src[r1+x+1] + src[r1+x+2] +
                src[r2+x] + src[r2+x+1] + src[r2+x+2];
        }
    }
}

private void box3Pointer(scope const(float)[] src, size_t stride,
                         scope float[] dst, size_t width, size_t height)
@trusted pure nothrow @nogc
{
    const sp=src.ptr; auto dp=dst.ptr;
    foreach(y;0..height) {
        const r0=y*stride, r1=(y+1)*stride, r2=(y+2)*stride, d=y*width;
        foreach(x;0..width) {
            dp[d+x] =
                sp[r0+x] + sp[r0+x+1] + sp[r0+x+2] +
                sp[r1+x] + sp[r1+x+1] + sp[r1+x+2] +
                sp[r2+x] + sp[r2+x+1] + sp[r2+x+2];
        }
    }
}

private void fill(scope float[] a) @safe nothrow @nogc
{
    foreach(i;0..a.length) a[i]=cast(float)((i*37+(i>>4)*13)%4093)*0.00025f;
}
private long measure(void delegate() op) { const t=MonoTime.currTime;op();return (MonoTime.currTime-t).total!"nsecs"; }
private long median(scope long[] a){sort(a);return a[a.length/2];}
private void raw(string name,size_t stride,scope const(long)[] a){
    import std.array:join; import std.conv:to;
    auto p=new string[a.length]; foreach(i,v;a)p[i]=v.to!string;
    writefln("neighbourhood3x3 width=2048 height=512 halo=1 stride=%s %s_raw_ns=%s",stride,name,p.join(","));
}

private int runCase(size_t stride)
{
    enum width=2048, height=512;
    auto src=new float[stride*(height+2)];
    auto dst=new float[width*height];
    auto ref=new float[width*height];
    fill(src);
    box3Rows(src,stride,ref,width,height);
    box3Pointer(src,stride,dst,width,height);
    if(ref!=dst) return 1;

    foreach(_;0..warmups){
        box3Rows(src,stride,dst,width,height);consume(dst,width,height);
        box3Pointer(src,stride,dst,width,height);consume(dst,width,height);
    }
    long[repetitions] rows,pointer,control;
    foreach(r;0..repetitions){
        const rot=r%3;
        foreach(step;0..3) final switch((rot+step)%3){
            case 0:rows[r]=measure({box3Rows(src,stride,dst,width,height);consume(dst,width,height);});break;
            case 1:pointer[r]=measure({box3Pointer(src,stride,dst,width,height);consume(dst,width,height);});break;
            case 2:control[r]=measure({box3Pointer(src,stride,dst,width,height);consume(dst,width,height);});break;
        }
    }
    auto a=rows,b=pointer,c=control;
    writefln("neighbourhood3x3 width=%s height=%s halo=1 stride=%s rows_ns=%s pointer_ns=%s pointer_control_ns=%s sink=%s",
        width,height,stride,median(a[]),median(b[]),median(c[]),sink);
    raw("rows",stride,rows[]);raw("pointer",stride,pointer[]);raw("pointer_control",stride,control[]);
    return 0;
}

int runNeighbourhoodMatrix()
{
    // Input includes one halo sample on each horizontal side: minimum stride W+2.
    foreach(stride;[2050UL,2112UL,2304UL,4096UL])
        if(runCase(cast(size_t)stride)) return 1;
    return 0;
}
