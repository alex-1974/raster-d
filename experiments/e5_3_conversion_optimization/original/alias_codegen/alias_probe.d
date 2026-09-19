module alias_probe;

import ldc.attributes :
    restrict;


/*
 * Deliberately no alias promise.
 *
 * This models what LLVM sees at the current scalar conversion kernel boundary:
 * two ordinary pointers whose relation is not represented in the function
 * signature.
 */
pragma(inline, false)
extern(C)
void rawConvertUnknown(
    const(ubyte)* source,
    float* target,
    size_t elementCount
)
@system
pure
nothrow
@nogc
{
    foreach (i; 0 .. elementCount)
    {
        target[i] =
            cast(float)
                source[i];
    }
}


/*
 * Same computation, but with a C-like no-alias contract supplied explicitly
 * to LDC/LLVM.
 *
 * This is an experiment only. Calling it with overlapping ranges would violate
 * the restrict contract.
 */
pragma(inline, false)
extern(C)
void rawConvertRestrict(
    @restrict const(ubyte)* source,
    @restrict float* target,
    size_t elementCount
)
@system
pure
nothrow
@nogc
{
    foreach (i; 0 .. elementCount)
    {
        target[i] =
            cast(float)
                source[i];
    }
}
