module neighbourhood_outer_address_bench;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln;

private enum size_t width=2048, height=512, pitch=4096, repetitions=12, warmups=2;
private __gshared ulong sink;
private __gshared ulong invocation;

private uint bits(float v) @trusted pure nothrow @nogc {
    union U { float f; uint u; } U u; u.f=v; return u.u;
}
private void consume(scope const(float)[] d) @trusted nothrow @nogc {
    ulong v=++invocation*0x9e3779b97f4a7c15UL;
    foreach(y;0..height) {
        const r=y*width;
        v=(v^bits(d[r]))*0x9e3779b185ebca87UL;
        v=(v^bits(d[r+width-1]))*0xc2b2ae3d27d4eb4fUL;
    }
    sink^=v;
}
private void fill(scope float[] a) @safe nothrow @nogc {
    foreach(i;0..a.length)
        a[i]=cast(float)((i*37+(i>>4)*13)%4093)*0.00025f;
}
private void body(const(float)* p0,const(float)* p1,const(float)* p2,float* d)
@system pure nothrow @nogc {
    foreach(x;0..width) {
        const px=cast(ptrdiff_t)x;
        d[x]=p0[px]+p0[px+1]+p0[px+2]+
             p1[px]+p1[px+1]+p1[px+2]+
             p2[px]+p2[px+1]+p2[px+2];
    }
}
private void signedRecurrence(const(float)* base,ptrdiff_t stride,float* dst)
@system pure nothrow @nogc {
    auto p0=base,p1=base+stride,p2=base+stride+stride;
    foreach(y;0..height) {
        body(p0,p1,p2,dst+y*width);
        p0+=stride;p1+=stride;p2+=stride;
    }
}
private void magnitudeRecurrence(const(float)* base,size_t rowPitch,float* dst)
@system pure nothrow @nogc {
    auto p0=base,p1=base-rowPitch,p2=base-rowPitch-rowPitch;
    foreach(y;0..height) {
        body(p0,p1,p2,dst+y*width);
        p0-=rowPitch;p1-=rowPitch;p2-=rowPitch;
    }
}
private void indexedMagnitude(const(float)* base,size_t rowPitch,float* dst)
@system pure nothrow @nogc {
    foreach(y;0..height) {
        const off=cast(ptrdiff_t)(y*rowPitch);
        body(base-off,base-off-cast(ptrdiff_t)rowPitch,
             base-off-cast(ptrdiff_t)(rowPitch*2),dst+y*width);
    }
}
private long measure(void delegate() op) {
    const t=MonoTime.currTime;op();return (MonoTime.currTime-t).total!"nsecs";
}
private long median(scope long[] a){sort(a);return a[a.length/2];}
private void report(string name,void delegate() op,scope float[] dst) {
    foreach(_;0..warmups){op();consume(dst);}
    long[repetitions] s;
    foreach(i;0..repetitions)s[i]=measure({op();consume(dst);});
    auto m=s;
    writefln("neighbourhood3x3_outer shape=%s median_ns=%s sink=%s",name,median(m[]),sink);
    writefln("neighbourhood3x3_outer shape=%s raw_ns=%(%s,%)",name,s);
}
int runNeighbourhoodOuterAddress() {
    enum size_t rows=height+2;
    auto storage=new float[pitch*rows];
    auto reference=new float[width*height];
    auto dst=new float[width*height];
    fill(storage);
    const base=storage.ptr+(rows-1)*pitch;
    const stride=-cast(ptrdiff_t)pitch;

    signedRecurrence(base,stride,reference.ptr);

    void checkAndReport(string name,void delegate() op) {
        op();
        if(dst!=reference) {
            writefln("neighbourhood3x3_outer correctness_failed shape=%s",name);
            return;
        }
        report(name,op,dst);
    }
    checkAndReport("signed_recurrence",{signedRecurrence(base,stride,dst.ptr);});
    checkAndReport("magnitude_recurrence",{magnitudeRecurrence(base,pitch,dst.ptr);});
    checkAndReport("indexed_magnitude",{indexedMagnitude(base,pitch,dst.ptr);});
    return 0;
}
