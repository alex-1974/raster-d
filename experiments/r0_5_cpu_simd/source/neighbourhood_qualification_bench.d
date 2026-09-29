module neighbourhood_qualification_bench;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln;

import raster.internal.r0_5_neighbourhood_view_bench :
    box3CanonicalRowKernelNoInline, box3CanonicalTrusted,
    makeCanonicalNeighbourhoodFixture;

private enum size_t repetitions = 9;
private enum size_t warmups = 2;
private __gshared ulong sink;

private uint bits(float v) @trusted pure nothrow @nogc {
    union U { float f; uint u; } U u; u.f=v; return u.u;
}
private float logicalValue(size_t y,size_t x,size_t logicalWidth)
@safe pure nothrow @nogc {
    const i=y*(logicalWidth+2)+x;
    return cast(float)((i*37+(i>>4)*13)%4093)*0.00025f;
}
private void fillLogical(float[] storage,size_t width,size_t height,size_t pitch,bool negativeRows)
@safe nothrow @nogc {
    foreach(y;0..height+2) foreach(x;0..width+2) {
        const physicalY=negativeRows ? height+1-y : y;
        storage[physicalY*pitch+x]=logicalValue(y,x,width);
    }
}
private void oracle(float[] dst,size_t width,size_t height)
@safe nothrow @nogc {
    foreach(y;0..height) foreach(x;0..width)
        dst[y*width+x]=
            logicalValue(y,x,width)+logicalValue(y,x+1,width)+logicalValue(y,x+2,width)+
            logicalValue(y+1,x,width)+logicalValue(y+1,x+1,width)+logicalValue(y+1,x+2,width)+
            logicalValue(y+2,x,width)+logicalValue(y+2,x+1,width)+logicalValue(y+2,x+2,width);
}
private void consume(scope const(float)[] d,size_t width,size_t height)
@trusted nothrow @nogc {
    ulong v=sink^0x9e3779b97f4a7c15UL;
    foreach(y;0..height) {
        const r=y*width;
        v=(v^bits(d[r]))*0x9e3779b185ebca87UL;
        v=(v^bits(d[r+width-1]))*0xc2b2ae3d27d4eb4fUL;
    }
    sink=v;
}
private long median(scope long[] a){sort(a);return a[a.length/2];}

private int runOne(size_t width,size_t height,size_t pitch,bool negativeRows,bool noInline) {
    auto source=new float[pitch*(height+2)];
    auto expected=new float[width*height];
    auto dst=new float[width*height];
    fillLogical(source,width,height,pitch,negativeRows);
    oracle(expected,width,height);

    auto fixture=makeCanonicalNeighbourhoodFixture(
        source,dst,width,height,pitch,negativeRows
    );
    bool run() @safe nothrow @nogc {
        return noInline
            ? box3CanonicalRowKernelNoInline(fixture.source,fixture.target)
            : box3CanonicalTrusted(fixture.source,fixture.target);
    }

    if(!run() || dst!=expected) {
        writefln("neighbourhood3x3_qual correctness_failed width=%s height=%s pitch=%s rows=%s kernel=%s",
            width,height,pitch,negativeRows?"negative":"positive",noInline?"noinline":"trusted");
        return 1;
    }
    foreach(_;0..warmups) {
        if(!run()) return 1;
        consume(dst,width,height);
    }

    long[repetitions] samples;
    bool executionOk=true;
    foreach(i;0..repetitions) {
        const t=MonoTime.currTime;
        const ok=run();
        samples[i]=(MonoTime.currTime-t).total!"nsecs";
        executionOk=executionOk&&ok;
        consume(dst,width,height);
    }
    if(!executionOk)return 1;
    auto m=samples;
    writefln("neighbourhood3x3_qual width=%s height=%s pitch=%s rows=%s kernel=%s median_ns=%s raw_ns=%(%s,%) sink=%s",
        width,height,pitch,negativeRows?"negative":"positive",
        noInline?"noinline":"trusted",median(m[]),samples,sink);
    return 0;
}

int runNeighbourhoodQualificationMatrix() {
    struct Case { size_t width,height,pitch; }
    const cases=[
        Case(127,64,192),
        Case(128,64,192),
        Case(129,64,192),
        Case(511,256,640),
        Case(512,256,640),
        Case(513,256,640),
        Case(2047,512,2304),
        Case(2048,512,2304),
        Case(2049,512,2304),
        Case(2048,512,4096),
        Case(2048,64,4096),
        Case(2048,1024,4096)
    ];

    foreach(c;cases) foreach(negativeRows;[false,true]) foreach(noInline;[false,true])
        if(runOne(c.width,c.height,c.pitch,negativeRows,noInline)!=0)return 1;
    return 0;
}
