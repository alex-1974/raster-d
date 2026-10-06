# raster-d v0.2 M2.4 — arithmetic wrappers over generic transforms

Status: implementation candidate for Issue #98.

Baseline:

~~~text
develop
1ec41191d048537582be82f48c3160831511225e
~~~

## 1. Decision

v0.2 adds four common same-type destination-oriented arithmetic wrappers:

~~~text
addInto
subtractInto
multiplyInto
divideInto
~~~

All four are thin semantic wrappers over zipTransformInto.

There is no arithmetic-specific pixel traversal, layout classifier, alias
checker, scheduler or allocation path.

## 2. Public shape

Representative call:

~~~d
left.addInto(
    leftPlaneIndex,
    right,
    rightPlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);
~~~

The same parameter order applies to subtractInto, multiplyInto and divideInto.

The first source remains the semantic UFCS subject.

The wrappers return bool and use RasterZipTransformError unchanged.

## 3. Supported sample types

Arithmetic convenience is intentionally narrower than isRasterSampleType.

Add/subtract/multiply support:

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

divideInto supports only:

~~~text
float
double
~~~

Excluded from the convenience family:

- bool;
- char, wchar, dchar;
- real;
- static-array pixel values;
- arbitrary POD structs;
- other representation-only raster samples.

Those types remain legal Raster sample representations where allowed by
isRasterSampleType, and consumers may still use zipTransformInto with an
explicitly defined callable.

## 4. Why real is excluded

The workspace numerical contract explicitly rejects the assumption that real is
one portable precision.

M2.4 does not create a convenience API whose observable precision varies across
targets without a deliberate policy.

A later real-specific contract could be added only with explicit portability
evidence.

## 5. Integer add/subtract semantics

For integer T, addInto and subtractInto define the result as the mathematical
integer result reduced modulo 2^N, where N is the bit width of T.

Examples:

~~~text
byte.max + 1    -> byte.min
byte.min - 1    -> byte.max
ubyte.max + 1   -> 0
0u8 - 1         -> ubyte.max
int.max + 1     -> int.min
~~~

This is an explicit raster-d contract.

The implementation uses D integer arithmetic plus explicit cast back to T so
small integer promotion does not accidentally change the public result width.

## 6. Integer multiplication semantics

For integer T, multiplyInto defines:

~~~text
result = mathematical product modulo 2^N
~~~

The rule is the same for signed and unsigned T under the two's-complement sample
representation.

This remains true for byte/short/ushort even though D promotes those operands
before evaluation.

No overflow error is reported.

This wrapper is therefore suitable only when modulo arithmetic is the intended
sample semantics.

Consumers requiring checked/saturating/clamped arithmetic must use or define a
separately specified operation rather than assume addInto/multiplyInto provide
it.

## 7. Integer division is deliberately absent

D runtime integer division has undefined cases, including:

~~~text
divisor == 0
signed minimum / -1
~~~

zipTransformInto has no per-element failure channel.

Providing integer divideInto safely would therefore require at least one of:

- a complete denominator/exception pre-scan;
- a different result carrier with per-operation failure state;
- temporary output plus commit;
- a separate checked execution kernel;
- a defined saturation/substitution policy.

Any of those would be a new semantic/execution contract, not a thin wrapper.

M2.4 therefore does not provide integer divideInto.

This preserves the requirement that arithmetic wrappers remain wrappers.

## 8. Floating semantics

For float and double, add/subtract/multiply/divide use D's IEEE-754 arithmetic
semantics and materialize the result back into T.

This includes:

- ordinary rounding in the active floating environment;
- signed zero;
- NaN propagation/generation;
- positive and negative infinity;
- overflow to infinity where required;
- underflow to subnormal or zero where required;
- floating division by signed zero producing the corresponding infinity when
  the numerator is nonzero;
- 0/0 producing NaN.

Raster-d performs no additional:

- NaN canonicalization;
- signed-zero normalization;
- clamp;
- saturation;
- finite-only validation;
- exception-flag clearing;
- alternate rounding policy;
- fast-math semantic weakening.

## 9. Delegation

The wrappers contain only a call of the form:

~~~text
zipTransformInto!(arithmetic operation)
~~~

Therefore they inherit unchanged:

- plane validation;
- shape validation;
- matching-empty success;
- destination injectivity;
- source/source alias allowance;
- source/destination overlap rejection;
- signed-stride support;
- canonical dispatch;
- universal-layout semantic traversal;
- @nogc behavior;
- pre-write structural failure.

No duplicate hot-path family is introduced.

## 10. Error semantics

Arithmetic wrappers do not define a new error enum.

They use RasterZipTransformError directly:

~~~text
none
invalidLeftPlane
invalidRightPlane
invalidDestinationPlane
shapeMismatch
nonInjectiveDestination
leftDestinationOverlap
rightDestinationOverlap
~~~

Arithmetic overflow is not represented as an error:

- integer add/sub/mul are modulo by contract;
- floating overflow follows IEEE floating semantics.

Integer division is excluded rather than exposing runtime undefined behavior.

## 11. Allocation and lifetime

All wrappers:

- allocate nothing;
- retain nothing;
- create no owner;
- launch no work;
- use no GC;
- preserve caller-controlled destination reuse.

They are convenience names for semantic operations, not allocating APIs.

## 12. Performance contract

The wrappers must not become separate optimized engines.

Optimization belongs below zipTransformInto in shared internal dispatch.

This is important for M2.4's intended role:

~~~text
arithmetic convenience
        |
        v
zipTransformInto
        |
        +-- shared validation/alias semantics
        +-- shared canonical executor
        +-- shared universal traversal
~~~

Future arithmetic-specific optimization is acceptable only when implemented as
a semantics-preserving specialization inside the generic execution machinery,
not as duplicated public loops.

## 13. Tests

The implementation directly tests:

- signed byte addition wrap;
- unsigned subtraction wrap;
- ushort multiplication wrap after integer promotion;
- full-width signed int overflow wrap;
- float division by +0, -behavior through negative numerator, 0/0 NaN and
  ordinary finite division;
- arbitrary signed row/sample strides;
- inherited shape failure without destination modification;
- compile-time rejection of integer divideInto;
- compile-time rejection of arbitrary POD arithmetic convenience.

Existing zipTransformInto tests continue to own exhaustive shape/layout/alias
behavior.

DMD and LDC Fast CI qualify the public wrappers.

## 14. D-language basis

The contract matches current D language semantics where used, but raster-d
states its own narrower API result explicitly.

Relevant D language facts:

- integer arithmetic uses two's-complement arithmetic;
- + and - wrap on integral overflow/underflow;
- integral multiplication overflow is chopped to the integral result width;
- small integer operands undergo integer promotion;
- runtime integer division has undefined exceptional cases;
- floating arithmetic follows IEEE-754.

The raster-d integer wrapper contract is intentionally phrased as modulo 2^N in
T so callers do not need to reason about intermediate promotion.

## 15. Explicit non-goals

M2.4 does not add:

- checked integer arithmetic;
- saturating arithmetic;
- clamped arithmetic;
- integer division;
- scalar-vs-raster arithmetic wrappers;
- cross-type arithmetic;
- broadcasting;
- operator overloading;
- implicit allocation;
- fused arithmetic expressions;
- expression templates;
- hidden SIMD/parallel policy.

## 16. Acceptance mapping

Issue #98 requires:

- wrappers delegate to generic transform/zip machinery;
- overflow/division/floating semantics are explicit;
- no duplicate hot-path implementation family.

The implementation satisfies those requirements directly.

The PR is ready to close #98 once DMD and LDC Fast CI are green.
