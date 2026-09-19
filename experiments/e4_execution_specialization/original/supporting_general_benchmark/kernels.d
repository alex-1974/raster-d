module e4kernels;

version (LDC)
{
    import ldc.attributes :
        fastmath,
        restrict;
}


/*
 * Unknown source/target overlap.
 */
extern(C)
pragma(inline, false)
bool copyUnknownAlias(
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
 * Caller promises source/target non-overlap.
 */
extern(C)
pragma(inline, false)
bool copyNoAlias(
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
 * Strict left-to-right reduction.
 */
extern(C)
pragma(inline, false)
double sumStrict(
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
 * Explicit fixed four-lane reduction.
 *
 * a0 = x0 + x4 + x8  + ...
 * a1 = x1 + x5 + x9  + ...
 * a2 = x2 + x6 + x10 + ...
 * a3 = x3 + x7 + x11 + ...
 *
 * result = (a0 + a1) + (a2 + a3)
 */
extern(C)
pragma(inline, false)
double sumFixedLane4(
    const(float)* source,
    size_t length
)
@system
nothrow
@nogc
{
    double a0 = 0.0;
    double a1 = 0.0;
    double a2 = 0.0;
    double a3 = 0.0;

    size_t i = 0;

    while (length - i >= 4)
    {
        a0 += source[i];
        a1 += source[i + 1];
        a2 += source[i + 2];
        a3 += source[i + 3];

        i += 4;
    }

    double total =
        (a0 + a1)
        + (a2 + a3);

    while (i < length)
    {
        total += source[i];
        ++i;
    }

    return total;
}


/*
 * Broad LLVM fast-math variant.
 *
 * Benchmark upper bound only.
 */
@fastmath
extern(C)
pragma(inline, false)
double sumFast(
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
