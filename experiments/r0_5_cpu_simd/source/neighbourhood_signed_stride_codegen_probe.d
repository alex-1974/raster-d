module neighbourhood_signed_stride_codegen_probe;

// Code-generation probe for the R0.5e signed Canonical neighbourhood kernel.
// Compile to assembly with the same release flags as the benchmark.

extern(C) void box3SignedPositive(
    const(float)* base, size_t pitch, float* dst, size_t width, size_t height)
@system pure nothrow @nogc
{
    foreach(y; 0 .. height) {
        const r0=y*pitch, r1=(y+1)*pitch, r2=(y+2)*pitch, d=y*width;
        foreach(x; 0 .. width) {
            dst[d+x] =
                base[r0+x] + base[r0+x+1] + base[r0+x+2] +
                base[r1+x] + base[r1+x+1] + base[r1+x+2] +
                base[r2+x] + base[r2+x+1] + base[r2+x+2];
        }
    }
}

extern(C) void box3SignedRuntime(
    const(float)* base, ptrdiff_t rowStride, float* dst, size_t width, size_t height)
@system pure nothrow @nogc
{
    foreach(y; 0 .. height) {
        const py=cast(ptrdiff_t)y;
        const r0=py*rowStride, r1=(py+1)*rowStride, r2=(py+2)*rowStride;
        const d=y*width;
        foreach(x; 0 .. width) {
            const px=cast(ptrdiff_t)x;
            dst[d+x] =
                base[r0+px] + base[r0+px+1] + base[r0+px+2] +
                base[r1+px] + base[r1+px+1] + base[r1+px+2] +
                base[r2+px] + base[r2+px+1] + base[r2+px+2];
        }
    }
}

extern(C) void box3SignedNegativeMagnitude(
    const(float)* base, size_t pitch, float* dst, size_t width, size_t height)
@system pure nothrow @nogc
{
    foreach(y; 0 .. height) {
        const py=cast(ptrdiff_t)y;
        const stride=-cast(ptrdiff_t)pitch;
        const r0=py*stride, r1=(py+1)*stride, r2=(py+2)*stride;
        const d=y*width;
        foreach(x; 0 .. width) {
            const px=cast(ptrdiff_t)x;
            dst[d+x] =
                base[r0+px] + base[r0+px+1] + base[r0+px+2] +
                base[r1+px] + base[r1+px+1] + base[r1+px+2] +
                base[r2+px] + base[r2+px+1] + base[r2+px+2];
        }
    }
}
