module pointer_probe;

version (LDC)
{
    import ldc.attributes :
        restrict;
}


/*
 * Unknown aliasing.
 */
extern(C)
pragma(inline, false)
void e43CopyPointerUnknown(
    const(ubyte)* source,
    ubyte* target,
    size_t length
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. length)
    {
        target[i] =
            source[i];
    }
}


/*
 * Caller promises C-like non-aliasing for both pointer parameters.
 */
extern(C)
pragma(inline, false)
void e43CopyPointerRestrict(
    @restrict const(ubyte)* source,
    @restrict ubyte* target,
    size_t length
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. length)
    {
        target[i] =
            source[i];
    }
}
