module neighbourhood_alias_path_bench;

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

/*
 * Same negative-Canonical kernel as the address-shape probe.
 * LLVM may version this loop for possible source/destination overlap.
 */
private void signedKernel(const(float)* base, ptrdiff_t stride, float* dst)
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
 * Research-only range proof. It mirrors the production architectural rule:
 * overlap is invocation-local and checked before writes. It deliberately does
 * not pretend that the proof changes D's pointer alias semantics.
 */
private bool disjoint(
    const(float)* sourceLow, size_t sourceElements,
    float* target, size_t targetElements)
@trusted pure nothrow @nogc {
    const ss=cast(size_t)sourceLow;
    const ts=cast(size_t)target;
    const sb=sourceElements*float.sizeof;
    const tb=targetElements*float.sizeof;
    if(ss > size_t.max-sb || ts > size_t.max-tb) return false;
    return ss+sb <= ts || ts+tb <= ss;
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
    writefln("neighbourhood3x3_alias shape=%s median_ns=%s sink=%s",name,median(m[]),sink);
    writefln("neighbourhood3x3_alias shape=%s raw_ns=%(%s,%)",name,s);
}

int runNeighbourhoodAliasPath() {
    enum size_t pitch=4096;
    const rows=height+2;
    auto storage=new float[pitch*rows];
    auto dst=new float[width*height];
    auto reference=new float[width*height];
    fill(storage);
    const base=storage.ptr+(rows-1)*pitch;
    const stride=-cast(ptrdiff_t)pitch;

    signedKernel(base,stride,reference.ptr);
    signedKernel(base,stride,dst.ptr);
    if(dst != reference) return 1;

    const proven=disjoint(storage.ptr,storage.length,dst.ptr,dst.length);
    writefln("neighbourhood3x3_alias disjoint=%s",proven);
    if(!proven) return 1;

    report("ordinary_call", { signedKernel(base,stride,dst.ptr); }, dst);
    report("after_runtime_nonoverlap_proof", {
        // The branch records the semantic proof but cannot by itself add a
        // compiler noalias contract to signedKernel.
        if(proven) signedKernel(base,stride,dst.ptr);
    }, dst);
    return 0;
}
