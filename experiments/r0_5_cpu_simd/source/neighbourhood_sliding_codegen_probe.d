module neighbourhood_sliding_codegen_probe;

private enum size_t width=2048, height=512;

extern(C) void box3Exact(const(float)* base, ptrdiff_t stride, float* dst)
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

extern(C) void box3Sliding(const(float)* base, ptrdiff_t stride, float* dst)
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

extern(C) void box3ReverseControl(const(float)* src, size_t pitch, float* dst)
@system pure nothrow @nogc {
    foreach(step;0..height) {
        const y=height-1-step;
        const r0=y*pitch, r1=(y+1)*pitch, r2=(y+2)*pitch;
        const d=step*width;
        foreach(x;0..width)
            dst[d+x]=
                src[r0+x]+src[r0+x+1]+src[r0+x+2]+
                src[r1+x]+src[r1+x+1]+src[r1+x+2]+
                src[r2+x]+src[r2+x+1]+src[r2+x+2];
    }
}
