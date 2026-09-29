module lut_codegen_probe;

enum size_t lutSize = 256;

private void validatedExecution(
    scope const(ubyte)* source,
    scope const(float)* lut,
    scope float* target,
    size_t elementCount
)
@system pure nothrow @nogc
{
    foreach (i; 0 .. elementCount)
        target[i] = lut[source[i]];
}

private void pointerDiagnostic(
    scope const(ubyte)[] source,
    scope const(float)[] lut,
    scope float[] target
)
@trusted pure nothrow @nogc
{
    assert(lut.length == lutSize);
    assert(source.length == target.length);

    foreach (i; 0 .. target.length)
        target.ptr[i] = lut.ptr[source.ptr[i]];
}

extern(C):

void probeLutValidated(
    const(ubyte)* source,
    const(float)* lut,
    float* target,
    size_t elementCount
)
@system pure nothrow @nogc
{
    validatedExecution(source, lut, target, elementCount);
}

void probeLutPointer(
    const(ubyte)[] source,
    const(float)[] lut,
    float[] target
)
@trusted pure nothrow @nogc
{
    pointerDiagnostic(source, lut, target);
}
