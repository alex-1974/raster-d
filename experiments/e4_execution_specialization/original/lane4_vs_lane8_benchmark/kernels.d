module kernels;

version (LDC)
{
    import ldc.attributes :
        fastmath;
}


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


extern(C)
pragma(inline, false)
double sumLane4(
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


extern(C)
pragma(inline, false)
double sumLane8(
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
    double a4 = 0.0;
    double a5 = 0.0;
    double a6 = 0.0;
    double a7 = 0.0;

    size_t i = 0;

    while (length - i >= 8)
    {
        a0 += source[i];
        a1 += source[i + 1];
        a2 += source[i + 2];
        a3 += source[i + 3];

        a4 += source[i + 4];
        a5 += source[i + 5];
        a6 += source[i + 6];
        a7 += source[i + 7];

        i += 8;
    }

    const double p01 = a0 + a1;
    const double p23 = a2 + a3;
    const double p45 = a4 + a5;
    const double p67 = a6 + a7;

    const double q03 =
        p01 + p23;

    const double q47 =
        p45 + p67;

    double total =
        q03 + q47;

    while (i < length)
    {
        total += source[i];
        ++i;
    }

    return total;
}


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
