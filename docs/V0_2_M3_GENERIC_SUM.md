# raster-d v0.2 M3.2 — generic strict sum

Status: implementation candidate for Issue #101.

Baseline:

~~~text
develop
945275ea8317d35c8f8bb1d1ab3ca0187a3a6946
~~~

## 1. Public family

v0.2 adds:

~~~d
RasterSumResult!Accumulator sum(Accumulator, Sample)(
    scope RasterView!Sample source,
    size_t planeIndex
);
~~~

UFCS:

~~~d
auto result = source.sum!double(planeIndex);
~~~

Accumulator is mandatory. There is no implicit default.

The root package exports:

~~~text
RasterSumError
RasterSumResult
sum
~~~

The frozen v0.1 operation remains exported unchanged:

~~~text
trySumFloatToDouble
~~~

## 2. Failure model

~~~d
enum RasterSumError : ubyte
{
    none,
    invalidPlane,
    accumulatorOverflow
}
~~~

A RasterSumResult is successful only when error == none.

Failed results expose the additive identity in value rather than a partial sum.

Floating overflow is not RasterSumError.accumulatorOverflow. IEEE infinity/NaN
remain successful floating numerical results.

## 3. Legal Sample -> Accumulator matrix

The rule is semantic, not an arbitrary list:

> Every possible Sample value must be exactly representable in Accumulator, and
> Sample/Accumulator must belong to the same integer or floating family.

Supported integer types:

~~~text
byte ubyte short ushort int uint long ulong
~~~

Supported floating types:

~~~text
float double
~~~

real is excluded.

### Integer pairs

Signed Sample -> signed Accumulator:

~~~text
Accumulator width >= Sample width
~~~

Unsigned Sample -> unsigned Accumulator:

~~~text
Accumulator width >= Sample width
~~~

Unsigned Sample -> signed Accumulator:

~~~text
Accumulator width > Sample width
~~~

Signed Sample -> unsigned Accumulator:

~~~text
rejected
~~~

Examples:

~~~text
ubyte  -> ushort    legal
ushort -> int       legal
uint   -> ulong     legal
uint   -> long      legal
int    -> long      legal
long   -> long      legal

long   -> ulong     rejected
ulong  -> long      rejected
int    -> uint      rejected
~~~

Same-width integer accumulation is legal because every individual Sample value
fits; the accumulated mathematical sum may still overflow and then fails at
runtime.

### Floating pairs

~~~text
float  -> float     legal
float  -> double    legal
double -> double    legal
double -> float     rejected
~~~

Integer/floating cross-family accumulation is rejected.

## 4. Integer numerical semantics

Accumulation starts at zero in Accumulator.

For each logical sample in row-major order:

1. convert Sample exactly to Accumulator;
2. prove that total + value is representable;
3. only then evaluate and commit the addition.

If representability fails:

~~~text
error = accumulatorOverflow
value = 0
~~~

No overflowing expression is evaluated first and classified afterwards.

No wrap, saturation, clamp, wider hidden type or floating fallback occurs.

## 5. Floating numerical semantics

Floating accumulation is exactly:

~~~text
Accumulator total = +0;

for y
    for x
        total = total + cast(Accumulator) sample;
~~~

No reassociation.

No fixed-lane tree.

No pairwise/Kahan/Neumaier substitution.

No hidden parallel partial sums.

NaN and infinities participate through ordinary D/IEEE arithmetic.

## 6. Layout semantics

Logical traversal is row-major regardless of physical layout.

The generic executor consumes:

~~~text
executionRegionBase
rowStrideElements
sampleStrideElements
width
height
~~~

and walks the logical coordinates directly.

This supports validated:

- compact;
- padded;
- negative-row;
- negative-sample;
- interleaved/universal;
- ROI;

layouts without routing every sample through the public accessor.

## 7. float -> double compatibility specialization

The generic call:

~~~d
source.sum!double(planeIndex)
~~~

for Sample == float intentionally delegates to the existing qualified
tryStrictFloatToDoubleSum internal engine.

Therefore it inherits the already-qualified v0.1:

- strict row-major graph;
- all validated layouts;
- DMD x86-64 canonical pointer specialization;
- LDC behavior;
- empty identity;
- NaN/Inf semantics.

The public v0.1 trySumFloatToDouble function itself remains unchanged.

## 8. Other pairs

All other legal pairs use one shared generic strict pointer executor.

It is not a second semantic family.

The executor differs only in mechanism:

~~~text
validated base + signed strides
+
strict row-major loop
+
checked integer add OR strict floating add
~~~

Future performance specialization may replace mechanism only if it preserves the
same result/error semantics.

## 9. Empty and invalid input

Valid empty selected plane:

~~~text
success
value = 0 in Accumulator
~~~

Invalid plane:

~~~text
failure
error = invalidPlane
value = 0
~~~

Zero is therefore not used as a success sentinel.

## 10. Attributes and ownership

sum is:

~~~text
@safe
nothrow
@nogc
~~~

It:

- allocates nothing;
- retains nothing;
- creates no owner;
- launches no tasks/workers;
- uses no hidden scheduler.

## 11. Compile-contract coverage

Positive instantiation coverage includes representative:

~~~text
ubyte -> ushort
ushort -> int
uint -> ulong
int -> long
float -> float
float -> double
double -> double
~~~

Negative coverage includes:

~~~text
long -> ulong
ulong -> long
double -> float
int -> double
real -> real
~~~

These constraints are public source-compatibility behavior even though the
helper trait implementing them remains private until #107 determines whether a
public reusable semantic trait is justified.

## 12. C++ comparison

The repository includes:

~~~text
benchmark/v0_2_sum/
~~~

The benchmark compares:

~~~text
D public generic float -> double strict sum
C++ strict scalar float -> double reference
~~~

on the same generated padded-row workload and logical row-major order.

The C++ reference is compiled without fast-math/reassociation and with explicit
vectorization disabled for the strict scalar comparison.

Important difference:

The C++ reference is a small kernel-level semantic reference, not a complete
RasterView/backing-validation implementation.

Therefore the benchmark record reports it as a representative C++ performance
reference rather than claiming identical library abstraction overhead.

The comparison aligns:

- float input;
- double accumulator;
- row-major association;
- row padding;
- sample count;
- no allocation inside the timed reduction;
- no exceptions/failure on the valid hot path.

## 13. Qualification direction

GitHub Fast CI qualifies:

- DMD 2.111 correctness;
- LDC 1.41 correctness;
- template instantiation matrix;
- integer overflow failures;
- layout independence;
- v0.1 float->double equivalence.

Reference-XPS performance qualification is run separately because hosted CI is
not a stable performance environment.

The benchmark runner records:

- compiler versions;
- CPU/environment;
- pinned process runs;
- DMD generic timings;
- LDC generic timings;
- C++ timings;
- exact result/checksum agreement;
- SHA256 manifest/archive.

## 14. Acceptance mapping

Issue #101:

### legal sample/accumulator combinations explicitly constrained

Satisfied by the exact-representability same-family compile-time matrix.

### deterministic/numerical behavior documented

Strict row-major order, checked integer accumulation, IEEE floating behavior and
failure semantics are explicit.

### representative C++ comparison included

A reproducible strict C++ reference benchmark is included under
benchmark/v0_2_sum.

The PR is ready to close #101 after DMD/LDC Fast CI is green and the benchmark
harness at least builds/validates structurally. Reference-XPS timing evidence
may be recorded separately if required for the milestone performance record.
