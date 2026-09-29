module neighbourhood_codegen_probe;

extern(C) void probeBox3Rows(
    scope const(float)[] src,
    size_t stride,
    scope float[] dst,
    size_t width,
    size_t height
)
@safe pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const r0 = y * stride;
        const r1 = (y + 1) * stride;
        const r2 = (y + 2) * stride;
        const d = y * width;

        foreach (x; 0 .. width)
        {
            dst[d + x] =
                src[r0 + x] + src[r0 + x + 1] + src[r0 + x + 2] +
                src[r1 + x] + src[r1 + x + 1] + src[r1 + x + 2] +
                src[r2 + x] + src[r2 + x + 1] + src[r2 + x + 2];
        }
    }
}

extern(C) void probeBox3Pointer(
    scope const(float)* src,
    size_t stride,
    scope float* dst,
    size_t width,
    size_t height
)
@system pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const r0 = y * stride;
        const r1 = (y + 1) * stride;
        const r2 = (y + 2) * stride;
        const d = y * width;

        foreach (x; 0 .. width)
        {
            dst[d + x] =
                src[r0 + x] + src[r0 + x + 1] + src[r0 + x + 2] +
                src[r1 + x] + src[r1 + x + 1] + src[r1 + x + 2] +
                src[r2 + x] + src[r2 + x + 1] + src[r2 + x + 2];
        }
    }
}
