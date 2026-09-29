module neighbourhood_address_shape_bench;

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

private void multiplyKernel(const(float)* base, ptrdiff_t stride, float* dp)
@system pure nothrow @nogc {
    foreach(y;0..height) {
        const py=cast(ptrdiff_t)y;
        const r0=py*stride, r1=(py+1)*stride, r2=(py+2)*stride;
        const d=y*width;
        foreach(x;0..width) {
            const px=cast(ptrdiff_t)x;
            dp[d+x]=
                base[r0+px]+base[r0+px+1]+base[r0+px+2]+
                base[r1+px]+base[r1+px+1]+base[r1+px+2]+
                base[r2+px]+base[r2+px+1]+base[r2+px+2];
        }
    }
}

private void rowPointerKernel(const(float)* base, ptrdiff_t stride, float* dp)
@system pure nothrow @nogc {
    auto p0=base, p1=base+stride, p2=base+stride+stride;
    foreach(y;0..height) {
        const d=y*width;
        foreach(x;0..width) {
            const px=cast(ptrdiff_t)x;
            dp[d+x]=
                p0[px]+p0[px+1]+p0[px+2]+
                p1[px]+p1[px+1]+p1[px+2]+
                p2[px]+p2[px+1]+p2[px+2];
        }
        p0+=stride; p1+=stride; p2+=stride;
    }
}

private void magnitudeKernel(const(float)* base, size_t pitch, float* dp)
@system pure nothrow @nogc {
    foreach(y;0..height) {
        const r0=y*pitch, r1=(y+1)*pitch, r2=(y+2)*pitch;
        const d=y*width;
        foreach(x;0..width) {
            // base is the high physical row; subtract positive magnitudes.
            dp[d+x]=
                base[-cast(ptrdiff_t)r0+cast(ptrdiff_t)x]+
                base[-cast(ptrdiff_t)r0+cast(ptrdiff_t)x+1]+
                base[-cast(ptrdiff_t)r0+cast(ptrdiff_t)x+2]+
                base[-cast(ptrdiff_t)r1+cast(ptrdiff_t)x]+
                base[-cast(ptrdiff_t)r1+cast(ptrdiff_t)x+1]+
                base[-cast(ptrdiff_t)r1+cast(ptrdiff_t)x+2]+
                base[-cast(ptrdiff_t)r2+cast(ptrdiff_t)x]+
                base[-cast(ptrdiff_t)r2+cast(ptrdiff_t)x+1]+
                base[-cast(ptrdiff_t)r2+cast(ptrdiff_t)x+2];
        }
    }
}

private long measure(void delegate() op) {
    const t=MonoTime.currTime; op(); return (MonoTime.currTime-t).total!"nsecs";
}
private long median(scope long[] a){sort(a);return a[a.length/2];}

private int runCase(size_t pitch) {
    const rows=height+2;
    auto storage=new float[pitch*rows];
    auto reference=new float[width*height];
    auto dst=new float[width*height];
    fill(storage);
    const origin=(rows-1)*pitch;
    const base=storage.ptr+origin;
    const stride=-cast(ptrdiff_t)pitch;

    multiplyKernel(base,stride,reference.ptr);

    void runOne(string name, void delegate() op) {
        op();
        if(dst != reference) {
            writefln("neighbourhood3x3_address correctness_failed pitch=%s shape=%s",pitch,name);
            return;
        }
        foreach(_;0..warmups){op();consume(dst);}
        long[repetitions] samples;
        foreach(i;0..repetitions) samples[i]=measure({op();consume(dst);});
        auto m=samples;
        writefln("neighbourhood3x3_address pitch=%s shape=%s median_ns=%s sink=%s",
            pitch,name,median(m[]),sink);
        writefln("neighbourhood3x3_address pitch=%s shape=%s raw_ns=%(%s,%)",
            pitch,name,samples);
    }

    runOne("signed_multiply", { multiplyKernel(base,stride,dst.ptr); });
    runOne("row_pointers", { rowPointerKernel(base,stride,dst.ptr); });
    runOne("positive_magnitude", { magnitudeKernel(base,pitch,dst.ptr); });
    return 0;
}

int runNeighbourhoodAddressShapeMatrix() {
    foreach(pitch;[cast(size_t)2304,4096])
        if(runCase(pitch)!=0) return 1;
    return 0;
}
