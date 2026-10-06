/++
    Internal compile-time relations for raster conversion policy.

    This module is package-internal deliberately. #107 owns the decision whether
    any reusable conversion capability trait belongs in the public API.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.internal.conversion_policy;


/++
    Supported numeric representations for the initial generic conversion
    family.

    real is deliberately excluded because its precision is target-dependent.
+/
package(raster)
template isSupportedConversionNumeric(T)
{
    enum isSupportedConversionNumeric =
        is(T == byte)
        || is(T == ubyte)
        || is(T == short)
        || is(T == ushort)
        || is(T == int)
        || is(T == uint)
        || is(T == long)
        || is(T == ulong)
        || is(T == float)
        || is(T == double);
}


private
template isSignedConversionInteger(T)
{
    enum isSignedConversionInteger =
        is(T == byte)
        || is(T == short)
        || is(T == int)
        || is(T == long);
}


private
template isUnsignedConversionInteger(T)
{
    enum isUnsignedConversionInteger =
        is(T == ubyte)
        || is(T == ushort)
        || is(T == uint)
        || is(T == ulong);
}


private
template isConversionInteger(T)
{
    enum isConversionInteger =
        isSignedConversionInteger!T
        || isUnsignedConversionInteger!T;
}


private
template isConversionFloating(T)
{
    enum isConversionFloating =
        is(T == float)
        || is(T == double);
}


/++
    Whether every possible From value is exactly representable in To.

    This is the exact-policy type relation for #105.

    Integer -> integer:
    the complete From mathematical range must be contained in To.

    Integer -> floating:
    the complete integer domain must fit within the destination binary
    significand precision. For the supported D types this yields:
      byte/ubyte/short/ushort -> float
      byte/ubyte/short/ushort/int/uint -> double

    Floating -> floating:
      float -> float
      float -> double
      double -> double

    Floating -> integer is never universally exact because the floating domain
    contains fractional values, infinities and NaNs.

    double -> float is not universally exact.

    real is outside the supported initial relation.
+/
package(raster)
template isUniversallyExactRasterConversion(
    From,
    To
)
{
    static if (
        !isSupportedConversionNumeric!From
        || !isSupportedConversionNumeric!To
    )
    {
        enum isUniversallyExactRasterConversion =
            false;
    }
    else static if (is(From == To))
    {
        enum isUniversallyExactRasterConversion =
            true;
    }
    else static if (
        isConversionInteger!From
        && isConversionInteger!To
    )
    {
        static if (isSignedConversionInteger!From)
        {
            enum isUniversallyExactRasterConversion =
                isSignedConversionInteger!To
                && From.sizeof <= To.sizeof;
        }
        else static if (isUnsignedConversionInteger!To)
        {
            enum isUniversallyExactRasterConversion =
                From.sizeof <= To.sizeof;
        }
        else
        {
            /*
             * unsigned -> signed requires one additional value bit.
             */
            enum isUniversallyExactRasterConversion =
                From.sizeof < To.sizeof;
        }
    }
    else static if (
        isConversionInteger!From
        && is(To == float)
    )
    {
        enum isUniversallyExactRasterConversion =
            is(From == byte)
            || is(From == ubyte)
            || is(From == short)
            || is(From == ushort);
    }
    else static if (
        isConversionInteger!From
        && is(To == double)
    )
    {
        enum isUniversallyExactRasterConversion =
            is(From == byte)
            || is(From == ubyte)
            || is(From == short)
            || is(From == ushort)
            || is(From == int)
            || is(From == uint);
    }
    else static if (
        is(From == float)
        && is(To == double)
    )
    {
        enum isUniversallyExactRasterConversion =
            true;
    }
    else
    {
        enum isUniversallyExactRasterConversion =
            false;
    }
}


version (unittest)
{

/*
 * Identity is exact for every supported initial numeric representation.
 */
static assert(isUniversallyExactRasterConversion!(byte, byte));
static assert(isUniversallyExactRasterConversion!(ulong, ulong));
static assert(isUniversallyExactRasterConversion!(float, float));
static assert(isUniversallyExactRasterConversion!(double, double));


/*
 * Integer range containment.
 */
static assert(isUniversallyExactRasterConversion!(byte, short));
static assert(isUniversallyExactRasterConversion!(ubyte, ushort));
static assert(isUniversallyExactRasterConversion!(ubyte, short));
static assert(isUniversallyExactRasterConversion!(uint, ulong));
static assert(isUniversallyExactRasterConversion!(uint, long));

static assert(!isUniversallyExactRasterConversion!(short, ubyte));
static assert(!isUniversallyExactRasterConversion!(int, uint));
static assert(!isUniversallyExactRasterConversion!(ulong, long));


/*
 * Integer -> IEEE binary floating precision boundaries.
 */
static assert(isUniversallyExactRasterConversion!(ushort, float));
static assert(!isUniversallyExactRasterConversion!(int, float));
static assert(!isUniversallyExactRasterConversion!(uint, float));

static assert(isUniversallyExactRasterConversion!(int, double));
static assert(isUniversallyExactRasterConversion!(uint, double));
static assert(!isUniversallyExactRasterConversion!(long, double));
static assert(!isUniversallyExactRasterConversion!(ulong, double));


/*
 * Floating widening and rejected narrowing/integer conversion.
 */
static assert(isUniversallyExactRasterConversion!(float, double));
static assert(!isUniversallyExactRasterConversion!(double, float));
static assert(!isUniversallyExactRasterConversion!(float, int));
static assert(!isUniversallyExactRasterConversion!(double, long));


/*
 * real is deliberately not part of the initial portable relation.
 */
static assert(!isSupportedConversionNumeric!real);
static assert(!isUniversallyExactRasterConversion!(real, double));
static assert(!isUniversallyExactRasterConversion!(double, real));

} // version (unittest)
