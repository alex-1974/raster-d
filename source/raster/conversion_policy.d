/++
    Public raster conversion policy model.

    v0.2 initially promotes only the policy whose behavior is fully specified
    and already has production evidence: exact representation conversion.

    Additional candidate policies remain unpromoted until their integer,
    floating, NaN/infinity, overflow and rounding semantics are complete.

    Authors: Alexander Bernardi
    Copyright: Copyright © 2026, Alexander Bernardi
    License: MIT
    Date: 2026-10-06
+/
module raster.conversion_policy;


/++
    Semantic policy selecting how one raster sample representation may be
    converted to another.

    Only exact is currently part of the public contract.

    exact means:

    - every legal source value is representable in the destination type without
      numerical information loss;
    - no rounding, truncation, saturation, clamping or overflow policy is
      involved;
    - NaN/infinity behavior is admitted only when the complete source floating
      domain is exactly preserved by the destination representation;
    - unsupported source/destination type pairs are rejected by the conversion
      API at compile time rather than becoming per-sample runtime failures.

    Future enum members, if any, require their own fully specified semantics and
    qualification before promotion.
+/
enum RasterConversionPolicy : ubyte
{
    exact
}


static assert(
    RasterConversionPolicy.init
    == RasterConversionPolicy.exact
);


/// Example selecting the only promoted v0.2 conversion policy.
@safe unittest
{
    import raster;

    const policy =
        RasterConversionPolicy.exact;

    assert(
        policy
        == RasterConversionPolicy.exact
    );
}
