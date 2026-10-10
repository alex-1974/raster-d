# raster-d v0.2 M3.8 — reusable raster sample traits

Status: implementation candidate for Issue #107.

## Promoted traits

Root-exported:

~~~text
isRasterSampleType
isNumericRasterSample
isExactConvertible
~~~

`isRasterSampleType` already existed and remains the representation-safety trait.
No duplicate `isRasterSample` alias is added.

`isNumericRasterSample!T` describes the portable scalar numeric domain used by
generic reductions and exact conversion:

~~~text
byte ubyte short ushort int uint long ulong float double
~~~

`real`, static arrays, POD pixel structs and pointer-bearing types are excluded.

`isExactConvertible!(From, To)` is a universal type relation: every possible
`From` value must be exactly representable in `To` under
`RasterConversionPolicy.exact`.

## Why these traits are public

`isNumericRasterSample` now supplies real production constraints for the
reduction family rather than duplicating the numeric type list.

`isExactConvertible` is the semantic source for the conversion-policy relation
used by `convertRasterInto` and `tryConvertAllocated`.

Therefore both traits describe caller-visible capability and are not exposed
merely to shorten implementation code.

## Rejected candidate

`isRasterSample` is not added because `isRasterSampleType` already expresses
that capability. Adding an alias would create redundant source-compatibility
surface without new semantics.

## Compatibility

Trait truth values are public source-compatibility surface. Widening or
narrowing them later is an API change and requires deliberate review.

## Tests

Positive/negative static instantiation coverage includes numeric vs nonnumeric
raw sample types and exact/non-exact conversion boundaries.

Issue #107 is ready to close once DMD/LDC Fast CI are green.