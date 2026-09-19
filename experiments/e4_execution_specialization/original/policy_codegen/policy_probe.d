module imagery.raster.internal.policy_codegen_probe;

version (LDC)
{
    import ldc.attributes :
        fastmath,
        restrict;
}


/*
 * Baseline: same forward-copy semantics as E3c.
 */
extern(C)
bool copy_unknown_alias(
    const(ubyte)* source,
    ubyte* target,
    size_t length
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. length)
        target[i] = source[i];

    return true;
}


/*
 * Candidate policy:
 *
 * source and target are promised not to alias.
 *
 * This is NOT equivalent to the unknown-alias E3c contract and must only
 * ever be selected when non-overlap is established by a higher layer.
 */
extern(C)
bool copy_restrict(
    @restrict const(ubyte)* source,
    @restrict ubyte* target,
    size_t length
)
@system
nothrow
@nogc
{
    foreach (i; 0 .. length)
        target[i] = source[i];

    return true;
}


/*
 * Strict floating reduction:
 *
 * preserves ordinary D/IEEE expression semantics.
 */
extern(C)
double sum_f32_f64_strict(
    const(float)* source,
    size_t length
)
@system
nothrow
@nogc
{
    double total = 0.0;

    foreach (i; 0 .. length)
        total += source[i];

    return total;
}


/*
 * Experimental relaxed floating reduction.
 *
 * This exists ONLY to measure the optimization opportunity. It must not
 * become the default d-imagery reduction semantics merely because it is fast.
 */
@fastmath
extern(C)
double sum_f32_f64_fastmath(
    const(float)* source,
    size_t length
)
@system
nothrow
@nogc
{
    double total = 0.0;

    foreach (i; 0 .. length)
        total += source[i];

    return total;
}
