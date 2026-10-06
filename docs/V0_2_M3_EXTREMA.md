# raster-d v0.2 M3.3 — extrema reductions

Status: implementation candidate for Issue #102.

Baseline:

~~~text
develop
24135516b3dc3f24763fd55cdfbb57561ffbca59
~~~

## 1. Public family

v0.2 adds:

~~~d
min
max
minMax
~~~

with root-exported result types:

~~~text
RasterExtremaError
RasterExtremaResult!T
RasterMinMaxResult!T
~~~

UFCS examples:

~~~d
auto lo = source.min(planeIndex);
auto hi = source.max(planeIndex);
auto pair = source.minMax(planeIndex);
~~~

## 2. Failure model

~~~d
enum RasterExtremaError : ubyte
{
    none,
    invalidPlane,
    emptyInput
}
~~~

NaN is not an error.

A non-empty floating input containing any NaN succeeds with a NaN extrema
result according to the frozen M3.1 contract.

## 3. Supported sample types

Initial extrema support is deliberately numeric-only:

~~~text
byte
ubyte
short
ushort
int
uint
long
ulong
float
double
~~~

Excluded:

- real;
- bool;
- character types;
- static-array pixel values;
- arbitrary POD structs.

isRasterSampleType remains broader. It describes representation safety, not
ordering semantics.

The reusable public numeric trait question remains owned by #107.

## 4. Integer semantics

For non-empty integer input:

~~~text
min = mathematically smallest logical sample
max = mathematically largest logical sample
~~~

No arithmetic accumulation occurs, so there is no integer overflow policy.

minMax returns both values from one logical pass.

## 5. Floating NaN semantics

NaN propagates.

If any logical sample is NaN:

~~~text
min.value        is NaN
max.value        is NaN
minMax.minimum   is NaN
minMax.maximum   is NaN
~~~

The reduction is still successful.

Raster-d deliberately does not skip NaNs because doing so would introduce an
implicit missing-data/NoData interpretation.

No promise is made about preserving a particular NaN payload or sign.

## 6. Floating signed-zero semantics

Equal signed zeros have deterministic extrema semantics independent of encounter
order:

~~~text
min(-0,+0) -> -0
min(+0,-0) -> -0

max(-0,+0) -> +0
max(+0,-0) -> +0
~~~

minMax applies both rules.

## 7. Infinities

Positive and negative infinity participate as ordinary ordered floating values.

They are not errors and are not filtered.

## 8. Empty input

A valid empty selected plane has no extrema.

Therefore all three operations fail with:

~~~text
RasterExtremaError.emptyInput
~~~

No T.init, T.min, T.max or NaN sentinel is presented as a successful extrema
value.

Invalid plane remains separately:

~~~text
RasterExtremaError.invalidPlane
~~~

## 9. Result carriers

Single extrema:

~~~text
RasterExtremaResult!T
    error
    value
    ok
~~~

Combined extrema:

~~~text
RasterMinMaxResult!T
    error
    minimum
    maximum
    ok
~~~

Values are meaningful only when ok is true.

The default state is deliberately unsuccessful.

## 10. minMax equivalence

For every valid non-empty input:

~~~text
minMax.minimum == semantic result of min
minMax.maximum == semantic result of max
~~~

including:

- NaN propagation;
- infinities;
- signed-zero tie handling.

minMax executes one logical pass.

## 11. Shared implementation family

The internal implementation is one compile-time-selected executor:

~~~text
executeExtrema!(minimum)
executeExtrema!(maximum)
executeExtrema!(minMax)
~~~

This shares:

- plane validation;
- pointer formation;
- signed row/sample stride traversal;
- NaN handling;
- signed-zero handling;
- empty behavior.

Compile-time mode selection avoids making min calculate max or max calculate
min.

minMax performs both comparisons in the same pass.

## 12. Layout independence

The executor walks:

~~~text
executionRegionBase
rowStrideElements
sampleStrideElements
width
height
~~~

in logical row-major coordinate order.

Every validated resident signed affine layout is supported:

- compact;
- padded;
- negative row stride;
- negative sample stride;
- interleaved/universal;
- ROI.

Read-only non-injective mappings are valid. Each logical coordinate participates
even when multiple coordinates reach the same physical sample.

## 13. Allocation / ownership / scheduling

All extrema operations are:

~~~text
@safe
nothrow
@nogc
~~~

They:

- allocate no pixel/data storage;
- retain no source;
- create no destination;
- launch no task/worker;
- expose no scheduler.

Small by-value result carriers are ordinary result values, not hidden
materialization.

## 14. Tests

Coverage includes:

- integer min/max/minMax agreement;
- one-pass minMax semantics;
- signed row/sample strides;
- empty vs invalid-plane distinction;
- NaN propagation;
- signed-zero tie behavior;
- infinity ordering;
- positive compile contracts;
- compile rejection of real and arbitrary POD samples.

DMD and LDC Fast CI qualify the same public root-import surface.

## 15. Acceptance mapping

Issue #102 requires:

### one-pass minMax where appropriate

Satisfied by one shared minMax traversal.

### empty input semantics

Explicit emptyInput failure.

### NaN semantics

Any NaN propagates to successful NaN extrema.

### layout independence

All validated signed affine layouts use the same logical semantics.

### destination/allocation irrelevant unless a result carrier requires it

No destination is used. Results are small by-value carriers only.

The PR is ready to close #102 once DMD and LDC Fast CI are green.
