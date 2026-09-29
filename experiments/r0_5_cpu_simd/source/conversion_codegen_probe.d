module raster.internal.r0_5_conversion_codegen_probe;

import mir.ndslice.slice : Contiguous, Slice;
import raster.internal.scalar_conversion : scalarConvertUbyteToFloatContiguous1D;

extern(C) void probeConvertSlice(
    const(ubyte)* source,
    float* target,
    size_t length
)
@trusted pure nothrow @nogc
{
    const(ubyte)[] input = source[0 .. length];
    float[] output = target[0 .. length];

    foreach (i; 0 .. length)
        output[i] = cast(float) input[i];
}

extern(C) void probeConvertPointer(
    const(ubyte)* source,
    float* target,
    size_t length
)
@trusted pure nothrow @nogc
{
    foreach (i; 0 .. length)
        target[i] = cast(float) source[i];
}

extern(C) void probeConvertMir(
    const(ubyte)* source,
    float* target,
    size_t length
)
@trusted nothrow @nogc
{
    auto input = Slice!(const(ubyte)*, 1, Contiguous)([length], source);
    auto output = Slice!(float*, 1, Contiguous)([length], target);

    const ok = scalarConvertUbyteToFloatContiguous1D(input, output);
    assert(ok);
}
