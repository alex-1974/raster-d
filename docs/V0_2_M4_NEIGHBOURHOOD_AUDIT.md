# raster-d v0.2 M4.1 — fixed 3 x 3 neighbourhood audit

Status: implementation/evidence audit for Issue #108.

Baseline:

~~~text
develop
2cf30b5aac4ab9bb1651c163d66f5febcfc82e3c
~~~

## 1. Purpose

M4.1 does not introduce a new public neighbourhood API.

It audits the qualified public
`tryApplyRasterNeighbourhood3x3!kernel()` implementation and separates:

- semantic API contract;
- generic structural machinery;
- fixed-3x3 geometry;
- compiler/layout execution specialization;
- reusable optimization evidence.

The result is the design input for:

- #109 compile-time neighbourhood shape model;
- #110 generic applyNeighbourhoodInto primitive;
- #111 border policy model;
- #112 convolution family.

## 2. Existing public semantic contract

The current fixed operation defines these caller-visible semantics:

~~~text
source                RasterView!T
source plane           runtime plane index
sourceOutputRegion     resident-relative Region2D
destination           WritableRasterView!T
destination plane      runtime plane index
kernel                 compile-time callable
kernel input           ref const(T)[9]
kernel order           row-major 3 x 3
kernel center          index 4
kernel attributes      @safe pure nothrow @nogc
output sample type     T
border policy          none
allocation             none
scheduling             none
~~~

For non-empty output the operation requires one resident source sample of halo
on all four sides of sourceOutputRegion.

Matching empty output succeeds without halo and without invoking the kernel.

All structural failures occur before the first destination write.

## 3. What is inherently 3 x 3-specific

The following production work is semantically tied to radius-one 3 x 3
geometry and must not be mistaken for generic spatial-operation machinery.

### 3.1 Halo extent

Current required source region is exactly:

~~~text
output.x      - 1
output.y      - 1
output.width  + 2
output.height + 2
~~~

The four boundary checks are therefore hard-coded radius-one checks.

A general fixed-shape model must derive left/right/top/bottom dependency margins
from shape/anchor semantics rather than retaining these constants.

### 3.2 Kernel value carrier

The current callable receives:

~~~d
ref const(T)[9]
~~~

This fixes:

- sample count = 9;
- row-major flattening;
- 3 columns;
- 3 rows;
- center index = 4.

A generalized shape cannot reuse this public carrier unchanged.

### 3.3 Canonical load graph

The Canonical executor explicitly forms three source rows and nine loads:

~~~text
row0[x + 0..2]
row1[x + 0..2]
row2[x + 0..2]
~~~

This is a real fixed-shape specialization.

The source form contains no runtime loops over neighbourhood width/height.

### 3.4 Float negative-row specialized executor

The retained LDC/frontend-2.111 specialization has a 3-row call boundary and a
fixed 9-value float carrier.

Its exact source form is therefore 3x3-specific even though the reason for the
specialization — preserving vectorizable row-local code for negative row
strides — may generalize.

## 4. What is generic today

The following work is not inherently 3x3-specific and should form the shared
foundation of #110.

### 4.1 Source and destination plane validation

Both plane indices are validated through their existing execution-stride
capabilities.

This is independent of neighbourhood shape.

### 4.2 Destination/output shape relation

Destination width/height must equal the requested output region width/height.

That is a generic Into-operation rule.

### 4.3 Output-region containment

The requested output region must be resident-relative and contained in the
source view before dependency expansion.

This remains generic once the required halo/dependency margins are parameterized.

### 4.4 Matching-empty no-op

A zero-area output can succeed before halo validation and kernel execution.

This is shape-independent.

### 4.5 Destination injectivity

A non-empty destination must be injective.

This is a generic multi-write destination rule and should be shared by the
generic spatial family.

### 4.6 Required-source versus destination overlap

The operation rejects physical overlap between the complete required source
rectangle and destination before the first write.

The existing exact asymmetric same-type affine rectangle classifier already
accepts independently sized source and destination rectangles.

That machinery is directly reusable once the generic shape computes the
required source rectangle.

### 4.7 Defensive allocation-free overlap fallback

The fallback pairwise sample-byte classifier is also shape-independent in
semantics.

It consumes source/destination rectangle dimensions and strides.

The implementation may later be centralized with other same-type
destination-oriented consumers, but M4 does not need a weaker alias contract.

### 4.8 Signed affine layout support

The current semantic path supports every validated resident signed-affine
layout.

Generic neighbourhood must preserve this support.

A fast path may specialize only after the general semantic path remains
available.

### 4.9 Structural-failure output state

Invalid plane, shape, halo, injectivity and overlap failures are all resolved
before writing.

This strong destination-state contract generalizes directly.

### 4.10 Kernel callable attributes

The requirement that the compile-time kernel be usable as:

~~~text
@safe pure nothrow @nogc
~~~

is generic and already protected by compile-contract tests.

The input carrier changes with geometry; the attribute contract need not.

### 4.11 Whole-vs-streamed decomposition independence

The public operation is already tested against independently materialized
task-local halo regions and exact reassembly.

This property is generic: the same logical output coordinate with the same
required source neighbourhood must produce the same result regardless of task
decomposition.

## 5. Semantic API versus execution specialization

The generic M4 family must preserve a strict boundary:

~~~text
SEMANTIC LAYER

validate source/destination
validate output region
derive required halo region
validate destination shape/injectivity
validate exact source/destination disjointness
define kernel sample order
define empty/failure semantics

        ↓ approved operation

EXECUTION LAYER

choose Canonical vs general signed-affine traversal
choose compiler-qualified source form
choose fixed-shape load graph
choose later SIMD/codegen specialization
~~~

Compiler, ISA and layout decisions remain package-internal.

No public API may expose:

- Canonical/Universal layout selectors;
- LDC/DMD switches;
- frontend-version switches;
- SIMD switches;
- negative-row implementation variants.

## 6. Existing optimization evidence

The retained production history for M3.1 records local XPS evidence for a
2048 x 512 workload:

~~~text
DMD Canonical:
    3.27x to 3.64x faster than the former public semantic loop

LDC Canonical:
    2.10x to 2.46x faster

LDC negative-row out-of-line row kernel:
    additional 12% to 14% over integrated Canonical

DMD negative-row out-of-line form:
    neutral to materially worse
~~~

The qualified LDC case is narrowly gated to:

~~~text
LDC
D frontend 2.111
float sample type
negative Canonical source row stride
~~~

Later frontend generations deliberately do not inherit that specialization
without measurement.

## 7. What the measurements actually justify

The evidence supports these conclusions.

### 7.1 Canonical sample-stride-one execution is reusable

This is the strongest reusable optimization.

The large improvement came from removing per-sample public semantic access and
using already-approved pointer/row execution for Canonical layouts.

A generic neighbourhood family should retain:

~~~text
sampleStride == 1 source
and
sampleStride == 1 destination
    -> candidate Canonical executor
else
    -> generic signed-affine semantic executor
~~~

The exact executor must still depend on neighbourhood shape.

### 7.2 Compiler-specific row boundaries are evidence-gated

The LDC negative-row source form is reusable as an optimization pattern, not as
a universal implementation rule.

The reusable rule is:

> A compiler/version-specific source form may be selected only for the exact
> qualified compiler/capability combination and must preserve the same semantic
> contract.

It must not be generalized to:

- DMD;
- later LDC frontends;
- all sample types;
- all neighbourhood shapes

without separate measurement/codegen evidence.

### 7.3 Fixed unrolled loads are plausible but not yet generalized evidence

The 3x3 Canonical executor benefits from a statically fixed nine-load graph.

However the existing benchmark does not isolate:

~~~text
benefit from Canonical pointer execution
versus
benefit from compile-time 3x3 unrolling
~~~

Therefore #109 must not conclude that arbitrary
`Neighbourhood!(W,H)` templates are justified merely because 3x3 is fast.

## 8. What #109 must measure

The compile-time shape issue should compare at least:

### A. runtime shape loop

One generic Canonical executor with runtime width/height/anchor.

### B. compile-time shape loops

Width/height known at compile time, but ordinary nested loops remain in source.

### C. fixed/unrolled specialization

Compile-time shape allows the compiler or implementation to remove shape loops
and construct a fixed neighbourhood carrier/load graph.

Relevant measurements:

- ns/output sample;
- instruction count where practical;
- generated loop/branch structure;
- stack/local carrier size;
- code size;
- DMD and LDC separately;
- positive and negative row stride;
- at least 3x3 and one larger shape such as 5x5.

Acceptance for public compile-time shape should require measurable removal of:

- runtime shape state;
- loop bounds/branches;
- indexing work;
- or material performance cost.

Template constants alone are not sufficient evidence.

## 9. Shape model requirements derived from 3 x 3

If #109 promotes a fixed-shape model, it must encode or derive at least:

~~~text
width
height
anchorX
anchorY
left margin
right margin
top margin
bottom margin
sample count
row-major flattening
~~~

For the current 3x3 centered case:

~~~text
width       = 3
height      = 3
anchorX     = 1
anchorY     = 1
left        = 1
right       = 1
top         = 1
bottom      = 1
sampleCount = 9
center      = flattened index 4
~~~

The audit does not yet approve final public names.

## 10. Anchor semantics must not be hidden

3x3 has an obvious center.

Generic fixed shapes do not always have one unique center:

- 2x2;
- 4x4;
- 3x4;
- asymmetric kernels.

Therefore generic geometry must not silently infer an anchor from integer
division unless that rule is explicitly selected and documented.

A shape type may eventually require an explicit anchor or restrict the first
promoted family to shapes whose anchor semantics are unambiguous.

This is a #109 design decision.

## 11. Border policy remains separate

The current fixed operation deliberately requires a complete resident halo and
defines no border behavior.

That separation should remain in #110.

Generic neighbourhood execution should first support a valid/resident-halo form
whose required source is present.

#111 may then layer or specialize border handling without contaminating:

- source materialization;
- logical dataset extent;
- ContextDeficit;
- provider tile edges;
- imagery-specific NoData meaning.

## 12. Generic applyNeighbourhoodInto direction

M4.1 supports this family direction conceptually:

~~~text
source
    .applyNeighbourhoodInto!shape(
        sourcePlane,
        sourceOutputRegion,
        destination,
        destinationPlane,
        kernel,
        ...
    )
~~~

Exact spelling remains #109/#110 work.

Required properties:

- source is semantic subject;
- destination-oriented;
- no hidden allocation;
- runtime output region/plane indices;
- compile-time kernel callable;
- compile-time shape only if #109 proves it removes real work;
- border policy independent;
- structural failures before write;
- signed-affine fallback always retained.

## 13. Convolution reuse

#112 must use the same spatial executor.

Convolution is not justification for a second neighbourhood traversal.

A convolution layer should supply:

- kernel coefficient representation;
- accumulator/result semantics;
- convolution callable/evaluation logic

to the generic neighbourhood machinery.

Prepared convolution state remains evidence-gated.

## 14. Existing code that should be reused directly

The following existing production mechanisms are reusable without weakening
contracts:

~~~text
RasterView/WritableRasterView stride validation
Region2D resident-relative containment
affine2DMappingIsInjective
classifyValidatedSameTypeAffine2DRectanglesByteOverlap
allocation-free exact overlap fallback concept
matching-empty no-op
pre-write structural validation
compile-time kernel attribute contract
Canonical sample-stride-one dispatch criterion
generic signed-affine fallback
whole-vs-streamed equivalence testing pattern
central compiler-capability gating
~~~

## 15. Existing code that should not be copied mechanically

Do not mechanically generalize these source forms:

~~~text
T[9]
ref const(T)[9]
index 4 center
dx/dy 0..3
+/- 1 halo arithmetic
three explicit source rows
nine explicit loads
float negative-row three-row helper
frontend-2.111 specialization
~~~

They are evidence for a design, not the generic design itself.

## 16. Safety contract

Generalization must preserve:

- @safe public operation;
- @nogc destination-oriented execution;
- no hidden ownership;
- no hidden allocation;
- no pointer escape from views;
- exact overlap rejection before writes;
- writable destination certification;
- no scheduler ownership;
- no compiler/layout public switch.

Trusted pointer execution remains allowed only behind already validated
view/layout relations.

## 17. Performance contract

The M4 generic family must not regress the qualified 3x3 production case merely
for API generality.

Therefore #110 should retain a path by which the existing 3x3 Canonical
executor can remain specialized or be generated equivalently.

A generic abstraction is acceptable only if:

- the existing 3x3 semantic behavior remains exact;
- Canonical 3x3 performance remains within the later qualification tolerance;
- Universal/signed-affine support is not weakened;
- compiler-specific specializations remain replaceable internal policy.

Performance comparison belongs to measured qualification, not public naming.

## 18. M4.1 decisions

### Decision A — semantic core

PROMOTE AS GENERIC CONCEPT:

- output-region contract;
- required-source dependency rectangle;
- destination shape/injectivity;
- exact overlap/no-write guarantee;
- empty semantics;
- kernel callable contract;
- layout independence;
- decomposition independence.

### Decision B — Canonical fast path

REUSE:

- sample-stride-one Canonical dispatch is justified and should generalize.

### Decision C — compile-time shape

RESEARCH/MEASURE IN #109:

- 3x3 proves fixed geometry can support excellent generated code;
- current evidence does not isolate whether arbitrary compile-time shape itself
  provides material benefit.

### Decision D — LDC negative-row specialization

RETAIN NARROWLY:

- preserve existing compiler-capability gate for the qualified 3x3 case;
- do not infer wider applicability.

### Decision E — border handling

KEEP SEPARATE:

- complete resident halo remains the baseline semantic;
- border policy belongs to #111.

### Decision F — convolution

BUILD ON GENERIC NEIGHBOURHOOD:

- no second spatial executor.

## 19. Acceptance mapping

Issue #108 asks which work is inherently 3x3-specific.

Recorded in sections 3 and 15.

It asks which work is generic.

Recorded in sections 4, 12 and 14.

It asks which compile-time specializations measurably help.

Recorded evidence shows:

- Canonical execution materially helps;
- one narrow LDC negative-row row-boundary specialization materially helps;
- arbitrary compile-time shape remains unproven and is assigned to #109.

It asks which layout fast paths generalize safely.

The sample-stride-one Canonical path generalizes safely as an internal
execution class while the signed-affine fallback remains mandatory.

The audit therefore distinguishes semantic API from execution specialization
and records which existing optimizations may be reused without weakening layout
or safety contracts.
