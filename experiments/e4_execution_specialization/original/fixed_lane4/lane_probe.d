module imagery.raster.internal.fixed_lane_probe;

version (LDC)
{
    import ldc.attributes :
        fastmath;
}


/*
 * Existing strict semantic reference.
 */
extern(C)
double sum_strict(
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
 * Semantic order:
 *
 *   a0 = x0 + x4 + x8  + ...
 *   a1 = x1 + x5 + x9  + ...
 *   a2 = x2 + x6 + x10 + ...
 *   a3 = x3 + x7 + x11 + ...
 *
 *   total = (a0 + a1) + (a2 + a3)
 *
 * Remaining tail samples are then appended in increasing index order.
 *
 * No fast-math flags are used.
 */
extern(C)
double sum_fixed_lane4(
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
 * Broad fast-math variant retained only as a codegen upper bound.
 */
@fastmath
extern(C)
double sum_fast(
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
