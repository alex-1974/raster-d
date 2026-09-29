module neighbourhood_view_bench;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln;
import neighbourhood_versioning_guard_probe : reportVersioningGeometry;

import raster.internal.r0_5_neighbourhood_view_bench :
    box3CanonicalNegativePhysicalForward, box3CanonicalTrusted, box3CanonicalView,
    makeCanonicalNeighbourhoodFixture;

private enum size_t width=2048, height=512, pitch=4096;
private enum size_t repetitions=12, warmups=2;
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
private float logicalValue(size_t y,size_t x) @safe pure nothrow @nogc {
    const i=y*(width+2)+x;
    return cast(float)((i*37+(i>>4)*13)%4093)*0.00025f;
}
private void fillLogical(float[] storage,bool negativeRows) @safe nothrow @nogc {
    foreach(y;0..height+2) foreach(x;0..width+2) {
        const physicalY=negativeRows ? height+1-y : y;
        storage[physicalY*pitch+x]=logicalValue(y,x);
    }
}
private void oracle(float[] dst) @safe nothrow @nogc {
    foreach(y;0..height) foreach(x;0..width)
        dst[y*width+x]=
            logicalValue(y,x)+logicalValue(y,x+1)+logicalValue(y,x+2)+
            logicalValue(y+1,x)+logicalValue(y+1,x+1)+logicalValue(y+1,x+2)+
            logicalValue(y+2,x)+logicalValue(y+2,x+1)+logicalValue(y+2,x+2);
}
private long measure(void delegate() op) {
    const t=MonoTime.currTime;op();return (MonoTime.currTime-t).total!"nsecs";
}
private long median(scope long[] a){sort(a);return a[a.length/2];}

private int runCase(bool negativeRows) {
    auto source=new float[pitch*(height+2)];
    auto expected=new float[width*height];
    auto dst=new float[width*height];
    fillLogical(source,negativeRows);
    oracle(expected);

    auto fixture=makeCanonicalNeighbourhoodFixture(
        source,dst,width,height,pitch,negativeRows
    );
    bool run() @safe nothrow @nogc {
        return box3CanonicalView(fixture.source,fixture.target);
    }

    if(!run() || dst!=expected) {
        writefln("neighbourhood3x3_view correctness_failed rows=%s",
            negativeRows?"negative":"positive");
        return 1;
    }
    foreach(_;0..warmups) {
        if(!run()) {
            writefln("neighbourhood3x3_view execution_failed rows=%s",
                negativeRows?"negative":"positive");
            return 1;
        }
        consume(dst);
    }
    long[repetitions] samples;
    bool executionOk=true;
    foreach(i;0..repetitions)
        samples[i]=measure({
            const ok=run();
            executionOk = executionOk && ok;
            consume(dst);
        });
    if(!executionOk) {
        writefln("neighbourhood3x3_view execution_failed rows=%s",
            negativeRows?"negative":"positive");
        return 1;
    }
    auto m=samples;
    writefln("neighbourhood3x3_view rows=%s median_ns=%s sink=%s",
        negativeRows?"negative":"positive",median(m[]),sink);
    writefln("neighbourhood3x3_view rows=%s raw_ns=%(%s,%)",
        negativeRows?"negative":"positive",samples);
    return 0;
}

private int runTrustedCase(bool negativeRows) {
    auto source=new float[pitch*(height+2)];
    auto expected=new float[width*height];
    auto dst=new float[width*height];
    fillLogical(source,negativeRows);
    oracle(expected);

    reportVersioningGeometry(source, dst, pitch);

    auto fixture=makeCanonicalNeighbourhoodFixture(
        source,dst,width,height,pitch,negativeRows
    );
    bool run() @safe nothrow @nogc {
        return box3CanonicalTrusted(fixture.source,fixture.target);
    }

    if(!run() || dst!=expected) {
        writefln("neighbourhood3x3_trusted correctness_failed rows=%s",
            negativeRows?"negative":"positive");
        return 1;
    }
    foreach(_;0..warmups) {
        if(!run()) return 1;
        consume(dst);
    }
    long[repetitions] samples;
    bool executionOk=true;
    foreach(i;0..repetitions)
        samples[i]=measure({
            const ok=run();
            executionOk = executionOk && ok;
            consume(dst);
        });
    if(!executionOk) return 1;
    auto m=samples;
    writefln("neighbourhood3x3_trusted rows=%s median_ns=%s sink=%s",
        negativeRows?"negative":"positive",median(m[]),sink);
    writefln("neighbourhood3x3_trusted rows=%s raw_ns=%(%s,%)",
        negativeRows?"negative":"positive",samples);
    return 0;
}


private int runPhysicalForwardCase() {
    enum negativeRows=true;
    auto source=new float[pitch*(height+2)];
    auto expected=new float[width*height];
    auto dst=new float[width*height];
    fillLogical(source,negativeRows);
    oracle(expected);

    auto fixture=makeCanonicalNeighbourhoodFixture(
        source,dst,width,height,pitch,negativeRows
    );
    bool run() @safe nothrow @nogc {
        return box3CanonicalNegativePhysicalForward(fixture.source,fixture.target);
    }

    if(!run() || dst!=expected) {
        writefln("neighbourhood3x3_physical_forward correctness_failed");
        return 1;
    }
    foreach(_;0..warmups) {
        if(!run()) return 1;
        consume(dst);
    }
    long[repetitions] samples;
    bool executionOk=true;
    foreach(i;0..repetitions)
        samples[i]=measure({
            const ok=run();
            executionOk = executionOk && ok;
            consume(dst);
        });
    if(!executionOk) return 1;
    auto m=samples;
    writefln("neighbourhood3x3_physical_forward rows=negative median_ns=%s sink=%s",
        median(m[]),sink);
    writefln("neighbourhood3x3_physical_forward rows=negative raw_ns=%(%s,%)",
        samples);
    return 0;
}

int runNeighbourhoodViewMatrix() {
    if(runCase(false)!=0)return 1;
    if(runCase(true)!=0)return 1;
    if(runTrustedCase(false)!=0)return 1;
    if(runTrustedCase(true)!=0)return 1;
    if(runPhysicalForwardCase()!=0)return 1;
    return 0;
}
