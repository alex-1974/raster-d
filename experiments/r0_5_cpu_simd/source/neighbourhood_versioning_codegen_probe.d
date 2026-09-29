module neighbourhood_versioning_codegen_probe;

private enum size_t width = 2048;
private enum size_t height = 512;

private void body(
    const(float)* r0,
    const(float)* r1,
    const(float)* r2,
    float* dstRow
)
@system pure nothrow @nogc
{
    foreach (x; 0 .. width)
        dstRow[x] =
            r0[x] + r0[x + 1] + r0[x + 2] +
            r1[x] + r1[x + 1] + r1[x + 2] +
            r2[x] + r2[x + 1] + r2[x + 2];
}

extern(C) void box3VersioningPositive(
    const(float)* src,
    size_t pitch,
    float* dst
)
@system pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const r0 = src + y * pitch;
        const r1 = r0 + pitch;
        const r2 = r1 + pitch;
        body(r0, r1, r2, dst + y * width);
    }
}

extern(C) void box3VersioningNegative(
    const(float)* src,
    size_t pitch,
    float* dst
)
@system pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const r0 = src - y * pitch;
        const r1 = r0 - pitch;
        const r2 = r1 - pitch;
        body(r0, r1, r2, dst + y * width);
    }
}

extern(C) void box3VersioningNegativePhysicalForward(
    const(float)* src,
    size_t pitch,
    float* dst
)
@system pure nothrow @nogc
{
    foreach_reverse (y; 0 .. height)
    {
        const r0 = src - y * pitch;
        const r1 = r0 - pitch;
        const r2 = r1 - pitch;
        body(r0, r1, r2, dst + y * width);
    }
}
