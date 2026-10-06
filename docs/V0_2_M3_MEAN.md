# raster-d v0.2 M3.4 — mean reduction

Status: implementation candidate for Issue #103.

Baseline:

~~~text
develop
8248b9bf8cbbf2b2638639a6480f146296033111
~~~

## 1. Public family

v0.2 adds:

~~~d
RasterMeanResult!Result mean(Accumulator, Result, Sample)(
    scope RasterView!Sample source,
    size_t planeIndex
);
~~~

UFCS:

~~~d
auto result = source.mean!(Accumulator, Result)(planeIndex);
~~~

Both accumulator and result precision are explicit. There is no implicit default.

Root exports:

~~~text
RasterMeanError
RasterMeanResult
mean
~~~

## 2. Failure model

~~~d
enum RasterMeanError : ubyte
{
    none,
    invalidPlane,
    emptyInput,
    countOverflow,
    accumulatorOverflow
}
~~~

Failure priority is deterministic:

~~~text
invalid plane
empty input
count overflow
accumulator overflow
~~~

Failed results expose +0 in Result and never a partial mean.

Floating NaN/infinity are successful numerical results, not failures.

## 3. Governing numerical model

Mean is built over the generic strict sum family:

~~~text
checked/strict sum in Accumulator
+
exact logical count in size_t
+
explicit conversion to Result
+
one final Result division
~~~

No separate raster traversal or alternate reduction graph is introduced.

The operation therefore inherits M3.2 strict logical row-major order, checked
integer accumulation, floating NaN/infinity behavior, signed-stride/layout
independence, and the qualified float-to-double production path.

## 4. Legal Sample -> Accumulator -> Result matrix

Accumulation legality is exactly the M3.2 sum contract.

### Integer samples

Accumulator must be a legal integer accumulator accepted by sum.

Result is double only.

Examples:

~~~text
ubyte  -> ushort -> double
ushort -> int    -> double
int    -> long   -> double
uint   -> ulong  -> double
long   -> long   -> double
~~~

Rejected examples:

~~~text
int -> long   -> float
int -> double -> double
~~~

Integer samples are never accumulated in floating point by mean.

### Floating samples

Supported:

~~~text
float  -> float  -> float
float  -> float  -> double
float  -> double -> double
double -> double -> double
~~~

Rejected:

~~~text
double -> double -> float
~~~

Result may preserve or widen floating accumulator precision, never narrow it.

real remains excluded because it is not one portable precision contract.

## 5. Integer mean precision

For integer samples:

1. each Sample is converted exactly to the integer Accumulator;
2. the mathematical sum is accumulated with checked integer addition;
3. the complete Accumulator value is converted once to double;
4. the exact logical count is converted once to double;
5. binary64 division produces the result.

Therefore integer accumulation itself is exact unless it overflows. Large
integer sum values above binary64 exact-integer range may round at the documented
Accumulator-to-double conversion boundary. Large size_t counts may likewise
round when converted to double. No hidden real or wider floating temporary is
part of the public contract.

This rounding is part of the mean semantic and is not treated as an error.

## 6. Floating mean precision

For floating Sample/Accumulator pairs, accumulation precision is exactly the
selected Accumulator.

The final value is:

~~~text
cast(Result)(accumulated_sum)
/
cast(Result)(count)
~~~

If Result equals Accumulator, the final division is in that precision.

If float Accumulator -> double Result is selected, the already-rounded float
sum is widened before the final division. Widening the result does not recover
precision lost during float accumulation.

## 7. Accumulator precision example

For samples:

~~~text
16777216f, 1f, -16777216f, 1f
~~~

strict float accumulation yields 1 and therefore mean 0.25.

Strict double accumulation after exact float-to-double conversion yields 2 and
therefore mean 0.5.

This is why Accumulator is mandatory public syntax rather than a hidden
implementation choice.

## 8. Empty input

A valid empty selected plane has no arithmetic mean and fails with:

~~~text
RasterMeanError.emptyInput
~~~

No successful zero or NaN sentinel is returned.

## 9. Count overflow

Mean uses logical count width * height.

The multiplication is checked in size_t before any sum traversal. If it is not
representable, the result is:

~~~text
RasterMeanError.countOverflow
~~~

The operation does not begin accumulation.

## 10. Integer accumulator overflow

If sum detects integer overflow, mean returns:

~~~text
RasterMeanError.accumulatorOverflow
~~~

Mean does not wrap, saturate, retry with a wider type, switch to floating
accumulation, or divide an incomplete sum.

## 11. NaN semantics

NaN is not interpreted as missing data.

A floating NaN sample participates in strict sum, makes the accumulated result
NaN under ordinary IEEE arithmetic, remains NaN after division, and the mean
operation succeeds.

No hidden mask/NoData policy is introduced.

## 12. Infinity semantics

Infinity participates normally.

Examples:

~~~text
(+Inf + finite) / count -> +Inf
(-Inf + finite) / count -> -Inf
(+Inf + -Inf) / count   -> NaN
~~~

These are successful floating results.

## 13. Layout independence

Mean delegates raster traversal to sum.

Therefore all validated resident signed affine layouts remain semantically
equivalent: compact, padded, negative row/sample stride, interleaved/universal,
ROI, and read-only non-injective views.

Physical address order does not change logical row-major reduction order.

## 14. Allocation / lifetime / scheduling

mean is:

~~~text
@safe
nothrow
@nogc
~~~

It allocates no raster/data storage, retains no source, creates no
owner/destination, launches no tasks/workers, and exposes no scheduler.

The by-value RasterMeanResult is ordinary result state only.

## 15. Performance position

Mean intentionally reuses the qualified generic sum path and adds only plane,
empty and count preflight, one count computation, two conversions, and one
floating division.

No second O(N) mean kernel exists.

Therefore M3.2 strict-sum D/C++ benchmark remains the representative hot-loop
performance evidence for the reduction traversal family. A separate mean
microbenchmark is not introduced unless profiling later shows material
mean-specific overhead.

## 16. Tests

Coverage includes fractional integer mean, signed-stride layout, observable
float-vs-double accumulator precision, empty vs invalid-plane failure,
count-overflow preflight, checked integer accumulator overflow, NaN propagation,
infinity behavior, and positive/negative Sample/Accumulator/Result matrix
assertions.

## 17. Acceptance mapping

Issue #103 requires accumulator precision documented, empty input behavior
explicit, and overflow/NaN rules tested.

This implementation provides explicit Accumulator and Result types, emptyInput
failure, countOverflow, accumulatorOverflow, successful NaN propagation and
successful infinity behavior.

The PR is ready to close #103 once DMD and LDC Fast CI are green.
