module neighbourhood_direction_matrix_bench;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln;

private enum size_t width=2048, height=512, halo=1;
private enum size_t repetitions=12, warmups=2;
private __gshared ulong sink;
private __gshared ulong invocation;

private uint bits(float v) @trusted pure nothrow @nogc {
    union U { float f; uint u; } U u; u.f=v; return u.u;
}
private void consume(scope const(float)[] dst) @trusted nothrow @nogc {
    ulong v=++invocation*0x9e3779b97f4a7c15UL;
    foreach(y;0..height) {
        const r=y*width;
        v=(v^bits(dst[r]))*0x9e3779b185ebca87UL;
        v=(v^bits(dst[r+width-1]))*0xc2b2ae3d27d4eb4fUL;
    }
    sink^=v;
}
private void fillLogical(scope float[] storage, size_t pitch) @safe nothrow @nogc {
    foreach(y;0..height+2)
        foreach(x;0..width+2)
            storage[y*pitch+x]=cast(float)(((y*(width+2)+x)*37+
                ((y*(width+2)+x)>>4)*13)%4093)*0.00025f;
}
private void reference(scope const(float)[] s,size_t pitch,scope float[] d)
@safe pure nothrow @nogc {
    foreach(y;0..height) foreach(x;0..width)
        d[y*width+x]=
            s[y*pitch+x]+s[y*pitch+x+1]+s[y*pitch+x+2]+
            s[(y+1)*pitch+x]+s[(y+1)*pitch+x+1]+s[(y+1)*pitch+x+2]+
            s[(y+2)*pitch+x]+s[(y+2)*pitch+x+1]+s[(y+2)*pitch+x+2];
}

// Direction flags change physical row traversal only. Source storage is
// initialized so every variant presents the same logical source rows.
// Destination mapping restores the same logical output array.
private void kernel(
    scope const(float)[] storage,size_t pitch,scope float[] dst,
    bool sourceReverse,bool destinationReverse)
@trusted pure nothrow @nogc {
    const sp=storage.ptr;
    auto dp=dst.ptr;
    foreach(step;0..height) {
        const logicalY=step;
        const sourceY=sourceReverse ? height-1-step : step;
        const destinationY=destinationReverse ? height-1-step : step;

        // To keep the logical computation identical, reversed source storage
        // was prepared with reversed logical rows before timing.
        const r0=sourceY*pitch;
        const r1=(sourceY+1)*pitch;
        const r2=(sourceY+2)*pitch;
        const d=destinationY*width;
        foreach(x;0..width)
            dp[d+x]=
                sp[r0+x]+sp[r0+x+1]+sp[r0+x+2]+
                sp[r1+x]+sp[r1+x+1]+sp[r1+x+2]+
                sp[r2+x]+sp[r2+x+1]+sp[r2+x+2];
    }
}

private long measure(void delegate() op) {
    const t=MonoTime.currTime; op(); return (MonoTime.currTime-t).total!"nsecs";
}
private long median(scope long[] a){sort(a);return a[a.length/2];}

private int runVariant(size_t pitch,bool srcRev,bool dstRev) {
    auto normal=new float[pitch*(height+2)];
    auto expected=new float[width*height];
    auto dst=new float[width*height];
    fillLogical(normal,pitch);
    reference(normal,pitch,expected);

    /*
     * Traverse output rows in either direction while computing the same
     * logical y. srcRev controls traversal order. dstRev is isolated by
     * storing through a reversed physical destination representation, then
     * restoring it only for the correctness check.
     */
    void run() @trusted pure nothrow @nogc {
        const sp=normal.ptr;
        auto dp=dst.ptr;
        foreach(step;0..height) {
            const y=srcRev ? height-1-step : step;
            const physicalDstY=dstRev ? height-1-y : y;
            const r0=y*pitch, r1=(y+1)*pitch, r2=(y+2)*pitch;
            const d=physicalDstY*width;
            foreach(x;0..width)
                dp[d+x]=
                    sp[r0+x]+sp[r0+x+1]+sp[r0+x+2]+
                    sp[r1+x]+sp[r1+x+1]+sp[r1+x+2]+
                    sp[r2+x]+sp[r2+x+1]+sp[r2+x+2];
        }
    }

    run();
    if(dstRev) {
        foreach(y;0..height/2) {
            const oy=height-1-y;
            foreach(x;0..width) {
                const a=y*width+x, b=oy*width+x;
                const t=dst[a]; dst[a]=dst[b]; dst[b]=t;
            }
        }
    }
    if(dst != expected) {
        writefln("neighbourhood3x3_direction correctness_failed pitch=%s src=%s dst=%s",
            pitch,srcRev?"reverse":"forward",dstRev?"reverse":"forward");
        return 1;
    }
    run();

    foreach(_;0..warmups){run();consume(dst);}
    long[repetitions] samples;
    foreach(i;0..repetitions) samples[i]=measure({run();consume(dst);});
    auto m=samples;
    writefln("neighbourhood3x3_direction pitch=%s src=%s dst=%s median_ns=%s sink=%s",
        pitch,srcRev?"reverse":"forward",dstRev?"reverse":"forward",median(m[]),sink);
    writefln("neighbourhood3x3_direction pitch=%s src=%s dst=%s raw_ns=%(%s,%)",
        pitch,srcRev?"reverse":"forward",dstRev?"reverse":"forward",samples);
    return 0;
}

int runNeighbourhoodDirectionMatrix() {
    foreach(pitch;[cast(size_t)2304,4096]) {
        foreach(srcRev;[false,true]) foreach(dstRev;[false,true])
            if(runVariant(pitch,srcRev,dstRev)!=0) return 1;
    }
    return 0;
}
