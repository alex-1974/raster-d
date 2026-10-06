/++
    Internal compatibility names for raster conversion constraints.

    Public semantic traits live in raster.sample as of M3.8. These package
    aliases keep internal conversion modules narrow while #107 promotes the
    caller-visible capability surface.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.internal.conversion_policy;

import raster.sample :
    isExactConvertible,
    isNumericRasterSample;


package(raster)
template isSupportedConversionNumeric(T)
{
    enum isSupportedConversionNumeric =
        isNumericRasterSample!T;
}


package(raster)
template isUniversallyExactRasterConversion(
    From,
    To
)
{
    enum isUniversallyExactRasterConversion =
        isExactConvertible!(
            From,
            To
        );
}


version (unittest)
{

static assert(isSupportedConversionNumeric!ubyte);
static assert(isSupportedConversionNumeric!double);
static assert(!isSupportedConversionNumeric!real);

static assert(isUniversallyExactRasterConversion!(byte, short));
static assert(isUniversallyExactRasterConversion!(ubyte, float));
static assert(isUniversallyExactRasterConversion!(int, double));
static assert(isUniversallyExactRasterConversion!(float, double));

static assert(!isUniversallyExactRasterConversion!(int, float));
static assert(!isUniversallyExactRasterConversion!(long, double));
static assert(!isUniversallyExactRasterConversion!(double, float));
static assert(!isUniversallyExactRasterConversion!(float, int));
static assert(!isUniversallyExactRasterConversion!(real, double));

} // version (unittest)
