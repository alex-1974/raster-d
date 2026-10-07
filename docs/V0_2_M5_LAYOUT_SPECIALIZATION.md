# raster-d v0.2 M5.2 — internal layout specialization decision

Status: complete evaluation for Issue #116.

Baseline:

~~~text
develop
e7c0c29beb90a12cc6f03e398cfd431ce727ae79
~~~

## 1. Question

M5.2 evaluates whether raster-d should generalize its internal execution-layout
specialization into a wider reusable framework.

The candidate physical classes named by Issue #116 were:

- canonical contiguous;
- padded;
- negative stride;
- interleaved;
- general affine.

The governing rule is stronger than taxonomy completeness:

> A specialization is justified only if it removes real work, state or
> branches, or produces a material code-generation/performance benefit.

The result is therefore allowed to be "do not add another abstraction".

## 2. Existing shared classifier

Production already has a package-internal storage capability classifier:

~~~text
PlaneExecutionLayout2D

    universal
        arbitrary validated signed-affine row/sample traversal

    canonical
        sampleStrideElements == 1
        row stride remains explicit and may be:
            positive
            negative
            padded
            inherited from a wider parent

    contiguous
        canonical
        plus no logical row gap for the current view
~~~

PlaneExecutionTraits additionally records:

~~~text
linearContiguous1D
flatElementCount
~~~

This is deliberately a capability lattice rather than a physical-layout label
catalog. Empty views remain conservative and do not claim reachable execution
capabilities.

## 3. Mapping the M5.2 candidate classes

| Candidate description | Existing classification | Reason |
| --- | --- | --- |
| canonical contiguous | contiguous | unit sample stride plus no row gap |
| padded unit-stride rows | canonical | same x traversal; explicit row stride already carries padding |
| negative row stride with unit x stride | canonical | x traversal remains forward/unit-stride; signed row stride is already explicit |
| negative sample stride | universal | logical x traversal is not forward unit-stride |
| interleaved/sample-strided | universal | requires arbitrary sample stride |
| general signed affine | universal | arbitrary row/sample stride is already supported |

Creating separate enum values for padded, negative-row, interleaved and general
affine would therefore encode physical descriptions that do not automatically
correspond to distinct profitable execution kernels.

## 4. Evidence from current production operations

### 4.1 Point transforms and binary transforms

Point and zip transforms use one approved Canonical pointer/row executor when
all participating sample strides are one. Row strides remain explicit.

This means contiguous, padded, positive-row Canonical and negative-row
Canonical storage can share one execution form when the compiler/toolchain
permits it. No independent padded executor is required merely because rows
contain gaps.

### 4.2 Fill

Fill selects a Canonical unit-sample-stride row path and otherwise retains the
general semantic traversal. Row padding and signed row stride are data to the
Canonical executor, not separate semantic classes.

### 4.3 Copy

Copy demonstrates why layout alone is insufficient. Its strongest
specialization is not selected merely by contiguous storage. It also requires
a concrete invocation-local proof that source and target are physically
non-overlapping. Only after both facts exist does production use memcpy.

~~~text
flat contiguous capability
+ matching operation semantics
+ checked source/target non-overlap
= memcpy specialization
~~~

A wider physical-layout enum would not replace this operation-specific relation.

### 4.4 Strict and fixed-lane reduction

Reduction demonstrates a second independent dimension. The explicit
fixed-lane4 graph requires flat contiguous execution, but it is also a
different floating-point operation graph from strict row-major summation.

~~~text
storage capability
+ requested numeric semantics
= compatible reduction kernel
~~~

Storage layout must not silently substitute one numeric graph for another.

### 4.5 Exact conversion

Exact conversion has retained compiler-qualified source forms whose benefit
depends on sample type pair, row direction, compiler/frontend generation and
width/source form. Those facts are more specific than one generic layout class.

The existing compiler-capability boundary is therefore more accurate than a
global negative-stride executor label.

### 4.6 Neighbourhood

M5.1 produced direct reference-XPS evidence for a generic 5x3 neighbourhood:

~~~text
DMD 2.111.0
    strided / Canonical median = 1.007901
    range = 0.997348 .. 1.019196

LDC 1.41.0
    strided / Canonical median = 1.001187
    range = 0.992973 .. 1.027238
~~~

Evidence:

~~~text
archive:
    raster-v0.2-neighbourhood-family-20261007-113929.tar.gz

SHA256:
    ff9ca09cefdbe3e39d22e13e4cc1a0ff02279660f2dc0014b501b03838aa62c0

head:
    a4923a71e5c2df88caefe16e89e43deba27aa829
~~~

For this representative non-3x3 kernel, the sample-strided Universal fallback
does not show a material performance penalty relative to the public Canonical
path. That is direct evidence against introducing an additional generic
interleaved or sample-strided specialization merely because the physical
layout differs.

## 5. Negative-stride policy

Negative stride is not one execution class.

~~~text
negative row stride + sample stride 1
    -> Canonical capability remains valid

negative sample stride
    -> Universal
~~~

A compiler-specific negative-row workaround may still be justified for one
operation when measured evidence shows code-generation pathology. The existing
3x3 neighbourhood LDC/frontend-2.111 negative-row boundary is an example.

That exception belongs to compiler/operation policy, not to a new shared
storage-layout category.

## 6. Decision

M5.2 does not introduce a new generalized five-class execution framework.

The production decision is:

1. retain PlaneExecutionLayout2D and PlaneExecutionTraits as the shared
   storage-capability classifier;
2. keep the shared capability ordering Universal -> Canonical -> Contiguous;
3. treat signed row stride as an ordinary Canonical parameter when sample
   stride is one;
4. keep arbitrary sample-strided/interleaved/general-affine layouts under
   Universal unless a measured operation justifies a narrower capability;
5. keep operation-specific facts outside the storage classifier, including
   alias/non-overlap proofs, numeric semantics, compiler capability/workaround
   gates, coefficient/kernel semantics, width/shape thresholds and type pairs;
6. add a new execution specialization only when retained evidence proves that
   the stronger condition removes real work or materially improves generated
   code/performance.

No public API changes are introduced. No executor visibility is widened. No
speculative SIMD, scheduler or compiler switch is added.

## 7. Why this is still a reusable framework

The reusable framework is the composition of two layers:

~~~text
shared storage capabilities
    PlaneExecutionTraits

        +

operation-local qualification facts
    numeric semantics
    alias relation
    compiler capability
    kernel/shape
    type pair
    other proven preconditions

        -> operation-specific executor selection
~~~

This is more reusable than forcing every operation through one larger physical
layout enum because it preserves only facts that actually transfer between
operations.

## 8. Consequences for later M5 work

### M5.3

The largest current performance signal is not a missing layout class.

~~~text
DMD: public 3x3 / hot executor = 16.575960x
LDC: public 3x3 / hot executor = 22.032183x
~~~

while generic and legacy public spellings remain at parity. M5.3 should
therefore prioritize structural preflight, inlining and generated code around
that public/hot boundary.

### M5.4

SIMD qualification may consume PlaneExecutionTraits, but SIMD availability
must remain an internal implementation decision and may require additional
operation-specific facts such as alignment, type and numeric policy.

### M5.7

Comparable C++ qualification must compare equivalent storage capabilities and
operation semantics rather than simply labeling a benchmark contiguous or
strided.

## 9. Acceptance

M5.2 is complete when:

- [x] candidate physical layout classes are mapped to current production capabilities;
- [x] retained evidence is used instead of speculative specialization;
- [x] operation-specific facts are kept separate from storage classification;
- [x] no unnecessary new execution-layout enum/API is introduced;
- [x] the architecture records when a future specialization is justified;
- [x] the public API remains unchanged.
