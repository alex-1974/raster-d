# raster-d v0.2 M3.1 — generic reduction semantics

Status: design contract for Issue #100.

Baseline:

~~~text
develop
583af6f57827a23c3203e1c00c9f37e8ab650983
~~~

## 1. Purpose

M3.1 freezes the common numerical and structural semantics for the v0.2
reduction family before broad public reduction APIs are implemented.

Covered operation families:

~~~text
sum
min
max
minMax
count
mean
~~~

Later statistical operations such as variance and standard deviation are not
defined here.

The existing v0.1 operation:

~~~d
trySumFloatToDouble(...)
~~~

remains frozen compatibility/evidence and is not weakened or silently
reinterpreted by this design.

## 2. Governing rule

A reduction semantic is not an execution hint.

If two evaluation graphs can produce observably different numerical results,
they are different reduction semantics.

Therefore raster-d does not silently replace a requested strict reduction with:

- reassociated arithmetic;
- a fixed-lane reduction tree;
- SIMD horizontal trees with different association;
- parallel partial reductions;
- compensated summation;
- pairwise summation;
- wider intermediate precision;
- narrower intermediate precision.

Such alternatives may later exist only as separately specified semantics or as
an implementation proven to preserve the exact requested observable result.

This preserves the distinction already established by the v0.1 strict
float-to-double reduction work.

## 3. Logical traversal order

For every order-sensitive reduction the canonical semantic order is logical
row-major order:

~~~text
for y = 0 .. height
    for x = 0 .. width
        consume sample(x, y)
~~~

Physical layout does not change this order.

Therefore the result must be semantically identical for:

- compact storage;
- padded rows;
- positive or negative row stride;
- positive or negative sample stride;
- interleaved/shared backing where the selected logical plane is valid;
- ROI views with non-zero resident origin.

The reduction observes logical sample order, not physical address order.

## 4. Plane selection and validity

A reduction operates on one explicitly selected logical plane until production
RasterPlaneView removes that compatibility plumbing.

An invalid plane selection is a request failure.

No reduction reads any sample before plane selection has been validated.

Read-only RasterView mappings may be non-injective. That is not a reduction
error: if multiple logical coordinates resolve to the same physical sample,
each logical coordinate still participates independently in the reduction.

## 5. Empty-input semantics

The operations divide into identity-bearing and non-identity families.

### 5.1 sum

A valid empty plane succeeds with the additive identity:

~~~text
0 in the selected accumulator type
~~~

This preserves the existing v0.1 strict-sum behavior.

### 5.2 count

A valid empty plane succeeds with:

~~~text
0
~~~

### 5.3 min / max / minMax

A valid empty plane has no extrema.

Therefore min, max and minMax fail with an explicit empty-input condition.

No fabricated sentinel such as:

~~~text
T.max
T.min
NaN
T.init
~~~

is published as a successful extrema result.

### 5.4 mean

A valid empty plane has no arithmetic mean.

Mean therefore fails with an explicit empty-input condition.

It does not return zero, NaN or T.init as a successful result.

## 6. Reduction result/failure direction

New v0.2 reductions should prefer result carriers whose default state is
unsuccessful rather than relying on output-value sentinels.

The exact public carrier names and fields belong to #101-#103, but the common
failure vocabulary must be able to represent, where applicable:

~~~text
invalid plane
empty input
count overflow
accumulator overflow
~~~

A failure result must not make a partial reduction value appear successful.

The v0.1 trySumFloatToDouble output-reset contract remains unchanged for
compatibility.

## 7. Sample-domain boundary

isRasterSampleType describes representation safety, not numerical capability.

The generic reduction family must therefore not assume that every legal raster
sample can be added, ordered or averaged.

M3.1 establishes these semantic capability groups.

### 7.1 count

count requires no numerical interpretation of T.

It may therefore apply to every legal RasterView!T sample representation.

### 7.2 numeric reductions

sum, min, max, minMax and mean are numeric families.

Initial v0.2 numeric reduction work should be limited to explicitly supported
numeric sample types.

The exact reusable public trait, if one is justified, belongs to #107 after the
actual #101-#106 constraints have demonstrated the common capability.

Do not introduce a trait merely to shorten implementation code.

## 8. real is not an implicit default

D real is not one portable precision or storage representation across targets.

Therefore M3 does not assume:

~~~text
real is always wider than double
real is the universal reduction accumulator
~~~

Any later API accepting or producing real must validate and document the
supported target representations explicitly.

The first generic reduction implementations may deliberately exclude real.

## 9. Accumulator type is part of semantics

The accumulator type is caller-visible numerical semantics, not an internal
optimization detail.

For sum and mean, the implementation must have one explicitly defined
accumulator type Acc.

The legal Sample -> Acc combinations are specified by #101 and #103 and are
part of source compatibility.

M3.1 does not freeze one universal automatic promotion table before those
combinations are audited.

However every accepted combination must obey the rules below.

## 10. Integer accumulation

Integer sum accumulation is checked.

For each logical sample, the mathematical addition must be proven representable
in Acc before the new accumulator value is committed.

If the next mathematical sum is not representable in Acc:

~~~text
the reduction fails with accumulator overflow
~~~

It must not:

- wrap modulo the accumulator width;
- saturate;
- clamp;
- silently switch to floating point;
- silently switch to a wider runtime type.

This differs intentionally from M2 arithmetic wrappers, whose integer
add/subtract/multiply APIs explicitly define modulo-2^N sample results.

Reduction accumulation is a different semantic problem.

## 11. Floating accumulation

Floating sum accumulation uses the explicitly selected floating Acc type.

The strict semantic graph is:

~~~text
acc = +0 in Acc

for each logical sample in row-major order:
    acc = acc + cast(Acc) sample
~~~

No reassociation is permitted under the strict semantic.

No compensated summation is implied.

No implicit wider temporary precision is part of the public contract beyond
what the supported compiler/target combination guarantees for an Acc operation;
release qualification must test materially relevant compiler/target behavior.

## 12. Floating NaN semantics — sum and mean

NaN is not treated as missing data.

Every logical sample participates.

For strict floating sum:

~~~text
NaN participates in the ordinary Acc addition sequence
~~~

Therefore a NaN sample makes the accumulated result NaN under ordinary IEEE
arithmetic.

Mean inherits the same participation rule.

Raster-d does not:

- skip NaNs;
- count only finite samples;
- replace NaN with zero;
- interpret NaN as NoData;
- canonicalize NaN payload/sign as an image-domain policy.

The public contract promises NaN-ness where applicable, not preservation of a
particular NaN payload.

## 13. Floating infinities

Positive and negative infinity participate as ordinary floating values.

Sum/mean follow the strict floating arithmetic graph.

Examples include:

~~~text
finite + +Inf  -> +Inf
finite + -Inf  -> -Inf
+Inf + -Inf    -> NaN
~~~

according to the selected Acc floating semantics and the fixed logical order.

Extrema treat infinities as ordered floating values below/above finite values.

## 14. min and max accumulator/result

min and max do not use an arithmetic accumulator.

Their semantic candidate/result type is the selected sample type T.

For non-empty integer inputs:

~~~text
min = mathematically smallest sample
max = mathematically largest sample
~~~

No arithmetic overflow is possible.

For non-empty floating inputs, the NaN and signed-zero rules below apply.

## 15. Floating NaN semantics — extrema

min, max and minMax use **NaN propagation**, not NaN omission.

If any logical sample is NaN:

~~~text
min result    is NaN
max result    is NaN
minMax.min    is NaN
minMax.max    is NaN
~~~

The operation itself is still a successful non-empty reduction.

No promise is made about preserving a particular NaN payload or NaN sign.

This policy is deliberate because silently ignoring NaNs would create an
implicit missing-data/validity interpretation that raster-d does not own.

A future explicit skip-NaN/statistical policy would be a distinct semantic
operation.

## 16. Floating signed-zero extrema

Floating extrema must be independent of encounter order for equal zeros.

When the compared numeric values are zero:

~~~text
min(-0, +0) -> -0
min(+0, -0) -> -0

max(-0, +0) -> +0
max(+0, -0) -> +0
~~~

This rule applies to minMax as well.

It prevents physical layout or equivalent logical traversal implementations from
changing the sign of a zero extrema result.

## 17. minMax equivalence

For every valid non-empty input:

~~~text
minMax.min
~~~

must be semantically identical to running the separately specified min
reduction over the same logical samples, and:

~~~text
minMax.max
~~~

must be semantically identical to max.

This includes:

- NaN propagation;
- infinities;
- signed-zero tie handling.

The implementation should use one pass where appropriate, but one-pass
execution must not change semantics.

## 18. count semantics

count returns the number of logical sample coordinates in the selected plane:

~~~text
width * height
~~~

It does not count:

- unique physical addresses;
- finite values only;
- nonzero values;
- non-NaN values;
- valid imagery pixels;
- backing bytes.

Because width and height are size_t, multiplication must be checked.

If the mathematical logical sample count is not representable in the public
count result type:

~~~text
count fails with count overflow
~~~

It must not wrap.

The initial count result type is expected to be size_t unless #101-#103 expose a
stronger reason to choose another type.

## 19. mean semantics

Mean is conceptually:

~~~text
sum / count
~~~

over all logical samples.

For empty input, mean fails.

Mean must not use integer division as its public numeric result semantics.

The concrete legal Sample -> Acc -> Result combinations are owned by #103.

For an integer sample family, #103 must select a result type capable of
representing fractional means and must use checked accumulation or another
explicitly equivalent numerical contract.

For a floating sample family, mean inherits strict sum order and floating NaN /
infinity participation.

No online-mean, pairwise-mean or compensated algorithm may silently replace the
selected sum/count semantic merely because it has different overflow or
stability characteristics.

If a different mean algorithm is desired, its equivalence or distinct semantic
must be documented and qualified.

## 20. Precision contract

Precision is explicit at the reduction family boundary.

### sum

Precision is determined by:

~~~text
sample conversion to Acc
+
strict accumulation in Acc
~~~

### extrema

Precision is exactly the sample representation T. Values are selected, not
numerically converted.

### count

Count is exact or fails.

### mean

Precision is determined by the selected accumulator and result types plus the
specified final division.

No reduction may silently reduce precision.

No reduction may silently increase precision in a way that changes public
results or materially changes cost without that precision being part of the
documented contract.

## 21. Determinism

For identical logical sample values, selected operation semantics, compiler
contract and supported target floating environment, reductions must be
deterministic.

Strict order-sensitive reductions must preserve the same logical operation
graph independent of physical layout.

Internal performance specialization may change:

- pointer formation;
- row access mechanism;
- bounds-check elimination;
- layout dispatch;
- compiler-specific source shape;

but not the reduction graph when that graph affects observable numerical
results.

Parallel/tree reductions are therefore not silent optimizations of strict sum or
mean.

## 22. Masks, validity and NoData

M3.1 introduces no implicit mask, validity or NoData association.

Every logical sample participates.

A separate mask raster is currently just another raster; raster-d has not
promoted a universal data+validity composite contract.

Imagery-specific NoData meaning remains above raster-d.

Therefore the first generic reductions do not accept hidden or ambient validity
state.

If a future generic masked reduction is justified, it must explicitly define:

- mask operand and shape relationship;
- valid/invalid convention;
- empty-after-mask behavior;
- count meaning;
- NaN interaction;
- performance/layout rules.

It is a separate semantic extension, not an implementation option of the
unmasked reductions.

## 23. Allocation, ownership and scheduling

Reductions are synchronous read-only semantic operations.

They:

- allocate no pixel output;
- do not retain the source;
- do not create an owning raster;
- do not launch background work;
- do not own a scheduler, worker pool, task or fiber.

A small by-value result carrier is not considered hidden pixel/data
materialization.

## 24. Relationship to v0.1 strict float-to-double sum

The v0.1 operation remains:

~~~d
trySumFloatToDouble(
    RasterView!float,
    planeIndex,
    out double
)
~~~

with its frozen semantics:

- float samples;
- double accumulator/result;
- strict logical row-major accumulation;
- empty success with 0.0;
- invalid plane as the only public false result;
- failure resets output to 0.0.

M3.1 adopts that strict order as the baseline generic floating-sum semantic.

#101 must preserve this operation unchanged and demonstrate how the generic sum
family relates to it.

No generic API may silently route the v0.1 operation to a numerically different
fixed-lane or reassociated graph.

## 25. Performance position

Strict semantics do not excuse avoidable overhead.

Once #101-#103 implement the family, raster-d should still pursue performance
comparable to high-quality C++ for materially equivalent work.

Fair comparison must align:

- logical order/reassociation rules;
- accumulator/result precision;
- overflow behavior;
- NaN behavior;
- validation;
- allocation;
- failure semantics.

Existing DMD/LDC evidence already shows that compiler-specific pointer execution
can improve performance while preserving one strict double accumulator and exact
row-major order.

That is the preferred optimization model: preserve semantics and optimize the
mechanism underneath them.

## 26. Deferred decisions owned by later issues

M3.1 intentionally does **not** freeze:

### #101 generic sum

- final public function name/signature;
- exact result-carrier shape;
- exact legal Sample -> Acc matrix;
- whether a convenience default accumulator is justified;
- C++ benchmark implementation and gate.

### #102 extrema

- final public function names/signatures;
- exact extrema result carrier shape.

### #103 mean

- exact legal Sample -> Acc -> Result matrix;
- final result carrier;
- whether any convenience default result type is justified.

### #107 reusable traits

- trait names;
- whether one shared numeric-sample trait is actually useful;
- exact-conversion capability traits.

Those later choices must conform to the common semantics frozen here.

## 27. Explicit non-goals

M3.1 does not define:

- variance;
- standard deviation;
- median/quantiles;
- histograms;
- compensated/Kahan/Neumaier sum;
- pairwise/tree sum;
- fast/reassociated sum;
- parallel reduction;
- masked reduction;
- skip-NaN reduction;
- NoData-aware reduction;
- complex-number reductions;
- arbitrary user-defined monoids;
- GPU reduction;
- hidden temporary materialization.

## 28. Acceptance mapping

Issue #100 requires definition of:

### empty raster behavior

Defined per operation:

- sum -> zero success;
- count -> zero success;
- min/max/minMax -> explicit empty failure;
- mean -> explicit empty failure.

### integer overflow

- count multiplication checked;
- integer sum/mean accumulation checked;
- no silent wrap/saturation/type-switch.

### floating NaN

- sum/mean: ordinary strict floating participation;
- extrema: propagate NaN rather than skip;
- no NaN-as-NoData interpretation.

### accumulator type

- accumulator is explicit semantic surface;
- no universal automatic promotion table is frozen in M3.1;
- legal Sample -> Acc pairs are owned by #101/#103 and source-compatible once
  introduced;
- extrema retain T; count is exact size/count type.

### precision

Explicitly tied to Sample -> Acc -> Result and strict operation graph.

### deterministic evaluation order

Strict row-major logical order is frozen for order-sensitive reductions.

### masks/validity

No implicit mask/validity/NoData in the initial generic family; all logical
samples participate.

This completes the M3.1 semantic gate without prematurely implementing the
public M3.2-M3.4 APIs.
