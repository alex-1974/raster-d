module neighbourhood_sliding_bench;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln;

private enum size_t width=2048, height=512, repetitions=12, warmups=2;
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

/* Exact baseline expression/order used by the preceding R0.5e probes. */
private void baseline(const(float)* base, ptrdiff_t stride, float* dst)
@system pure nothrow @nogc {
    auto p0=base, p1=base+stride, p2=base+stride+stride;
    foreach(y;0..height) {
        const d=y*width;
        foreach(x;0..width) {
            const px=cast(ptrdiff_t)x;
            dst[d+x]=
                p0[px]+p0[px+1]+p0[px+2]+
                p1[px]+p1[px+1]+p1[px+2]+
                p2[px]+p2[px+1]+p2[px+2];
        }
        p0+=stride; p1+=stride; p2+=stride;
    }
}

/*
 * Algorithmic control: form vertical column sums once, then maintain a
 * three-column horizontal window. This reduces source loads/additions but
 * changes the floating-point evaluation graph, so it is NOT a drop-in
 * implementation of the exact baseline semantic.
 */
private void sliding(const(float)* base, ptrdiff_t stride, float* dst)
@system pure nothrow @nogc {
    auto p0=base, p1=base+stride, p2=base+stride+stride;
    foreach(y;0..height) {
        float c0=p0[0]+p1[0]+p2[0];
        float c1=p0[1]+p1[1]+p2[1];
        float c2=p0[2]+p1[2]+p2[2];
        const d=y*width;
        dst[d]=c0+c1+c2;
        foreach(x;1..width) {
            c0=c1; c1=c2;
            const nx=cast(ptrdiff_t)x+2;
            c2=p0[nx]+p1[nx]+p2[nx];
            dst[d+x]=c0+c1+c2;
        }
        p0+=stride; p1+=stride; p2+=stride;
    }
}
private bool closeEnough(scope const(float)[] a, scope const(float)[] b)
@safe pure nothrow @nogc {
    if(a.length!=b.length)return false;
    foreach(i;0..a.length) {
        const da=a[i]>b[i]?a[i]-b[i]:b[i]-a[i];
        if(da>1.0e-5f)return false;
    }
    return true;
}
private long measure(void delegate() op) {
    const t=MonoTime.currTime; op(); return (MonoTime.currTime-t).total!"nsecs";
}
private long median(scope long[] a){sort(a);return a[a.length/2];}
private void report(string name, void delegate() op, scope float[] dst) {
    foreach(_;0..warmups){op();consume(dst);}
    long[repetitions] s;
    foreach(i;0..repetitions)s[i]=measure({op();consume(dst);});
    auto m=s;
    writefln("neighbourhood3x3_sliding shape=%s median_ns=%s sink=%s",name,median(m[]),sink);
    writefln("neighbourhood3x3_sliding shape=%s raw_ns=%(%s,%)",name,s);
}

int runNeighbourhoodSliding() {
    enum size_t pitch=4096;
    const rows=height+2;
    auto storage=new float[pitch*rows];
    auto exact=new float[width*height];
    auto dst=new float[width*height];
    fill(storage);
    const base=storage.ptr+(rows-1)*pitch;
    const stride=-cast(ptrdiff_t)pitch;
    baseline(base,stride,exact.ptr);
    sliding(base,stride,dst.ptr);
    if(!closeEnough(exact,dst)) {
        writefln("neighbourhood3x3_sliding correctness_failed");
        return 1;
    }
    report("baseline_exact_graph",{baseline(base,stride,dst.ptr);},dst);
    report("sliding_changed_graph",{sliding(base,stride,dst.ptr);},dst);
    return 0;
}
