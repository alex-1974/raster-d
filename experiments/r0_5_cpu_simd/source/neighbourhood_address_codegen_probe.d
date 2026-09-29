module neighbourhood_address_codegen_probe;

enum size_t width=2048;
enum size_t height=512;

extern(C) void box3ReverseIndex(
    const(float)* src, size_t pitch, float* dst)
@system pure nothrow @nogc
{
    foreach(step; 0 .. height) {
        const y=height-1-step;
        const r0=y*pitch;
        const r1=(y+1)*pitch;
        const r2=(y+2)*pitch;
        const d=y*width;
        foreach(x; 0 .. width)
            dst[d+x]=
                src[r0+x]+src[r0+x+1]+src[r0+x+2]+
                src[r1+x]+src[r1+x+1]+src[r1+x+2]+
                src[r2+x]+src[r2+x+1]+src[r2+x+2];
    }
}

extern(C) void box3SignedMultiply(
    const(float)* base, ptrdiff_t stride, float* dst)
@system pure nothrow @nogc
{
    foreach(y; 0 .. height) {
        const py=cast(ptrdiff_t)y;
        const r0=py*stride;
        const r1=(py+1)*stride;
        const r2=(py+2)*stride;
        const d=y*width;
        foreach(x; 0 .. width) {
            const px=cast(ptrdiff_t)x;
            dst[d+x]=
                base[r0+px]+base[r0+px+1]+base[r0+px+2]+
                base[r1+px]+base[r1+px+1]+base[r1+px+2]+
                base[r2+px]+base[r2+px+1]+base[r2+px+2];
        }
    }
}

extern(C) void box3RowPointers(
    const(float)* base, ptrdiff_t stride, float* dst)
@system pure nothrow @nogc
{
    auto p0=base;
    auto p1=base+stride;
    auto p2=base+stride+stride;
    foreach(y; 0 .. height) {
        const d=y*width;
        foreach(x; 0 .. width) {
            const px=cast(ptrdiff_t)x;
            dst[d+x]=
                p0[px]+p0[px+1]+p0[px+2]+
                p1[px]+p1[px+1]+p1[px+2]+
                p2[px]+p2[px+1]+p2[px+2];
        }
        p0+=stride;
        p1+=stride;
        p2+=stride;
    }
}

extern(C) void box3PositiveMagnitude(
    const(float)* base, size_t pitch, float* dst)
@system pure nothrow @nogc
{
    foreach(y; 0 .. height) {
        const r0=y*pitch;
        const r1=(y+1)*pitch;
        const r2=(y+2)*pitch;
        const d=y*width;
        foreach(x; 0 .. width) {
            const px=cast(ptrdiff_t)x;
            dst[d+x]=
                base[-cast(ptrdiff_t)r0+px]+base[-cast(ptrdiff_t)r0+px+1]+base[-cast(ptrdiff_t)r0+px+2]+
                base[-cast(ptrdiff_t)r1+px]+base[-cast(ptrdiff_t)r1+px+1]+base[-cast(ptrdiff_t)r1+px+2]+
                base[-cast(ptrdiff_t)r2+px]+base[-cast(ptrdiff_t)r2+px+1]+base[-cast(ptrdiff_t)r2+px+2];
        }
    }
}
