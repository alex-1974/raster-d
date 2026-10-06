# raster-d v0.2 M4.3 — generic applyNeighbourhoodInto

Status: implementation candidate for Issue #110.

Baseline:

~~~text
develop
6dfe745889a323ff962a9ae1622e704cf964cd75
~~~

## 1. Public API

v0.2 adds:

~~~d
bool applyNeighbourhoodInto(
    alias Shape,
    alias kernel,
    T
)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out RasterNeighbourhoodError error
);
~~~

UFCS:

~~~d
source.applyNeighbourhoodInto!(
    Shape,
    kernel
)(
    sourcePlaneIndex,
    sourceOutputRegion,
    destination,
    destinationPlaneIndex,
    error
);
~~~

Shape is a compile-time fixed neighbourhood geometry such as
NeighbourhoodShape!(5, 3, 2, 1).

## 2. Error model

~~~d
enum RasterNeighbourhoodError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    destinationShapeMismatch,
    unsatisfiedNeighbourhood,
    nonInjectiveDestination,
    sourceDestinationOverlap
}
~~~

The generic error model preserves the same structural categories as the
qualified fixed 3x3 operation.

## 3. Layout and halo semantics

sourceOutputRegion is resident-relative to the supplied source view.

For a non-empty output, the source must contain the full margins derived from
Shape:

~~~text
left   = Shape.left
right  = Shape.right
top    = Shape.top
bottom = Shape.bottom
~~~

The required source rectangle is:

~~~text
x      = output.x - left
y      = output.y - top
width  = left + output.width  + right
height = top  + output.height + bottom
~~~

This operation defines no border policy.

If the complete resident neighbourhood is unavailable the result is:

~~~text
RasterNeighbourhoodError.unsatisfiedNeighbourhood
~~~

Matching empty output succeeds without requiring halo and without invoking the
kernel.

## 4. Kernel contract

The kernel is selected at compile time.

It receives:

~~~d
ref const(T)[Shape.sampleCount]
~~~

in row-major neighbourhood order.

The sample at:

~~~text
(Shape.anchorX, Shape.anchorY)
~~~

is the logical output anchor.

The kernel must be usable as:

~~~text
@safe pure nothrow @nogc
~~~

and return T.

External compile probes reject:

- wrong fixed carrier length;
- impure kernels;
- throwing kernels;
- allocating kernels;
- @system kernels.

## 5. Destination contract

Destination width and height must equal sourceOutputRegion width and height.

For non-empty output the destination mapping must be injective.

The complete required source sample-byte rectangle must be physically disjoint
from destination sample bytes.

All structural failures occur before the first destination write.

No snapshot or in-place semantics are implied.

## 6. No hidden allocation

applyNeighbourhoodInto is:

~~~text
@safe
nothrow
@nogc
~~~

It allocates no output storage, no scratch raster and no heap neighbourhood
buffer.

Each per-output neighbourhood carrier is a fixed-size stack/local value whose
size is Shape.sampleCount * T.sizeof.

The caller owns and may reuse destination storage.

## 7. Layout independence

Every validated resident signed-affine layout remains semantically supported.

The implementation has two execution forms:

### Canonical

When required-source and destination sample strides are one:

~~~text
requiredSourceSampleStride == 1
destinationSampleStride    == 1
~~~

execution uses validated pointers and row strides directly.

### General signed-affine fallback

All other valid layouts use semantic sample access through the already
validated required-source ROI and writable destination.

Negative row strides, negative sample strides and interleaved/universal layouts
therefore remain valid.

The fast path does not weaken layout support.

## 8. Compile-time geometry use

Shape is used at compile time for:

- required margins;
- sample count;
- fixed local carrier type;
- neighbourhood width/height loop bounds;
- 3x3 specialization selection.

No runtime shape descriptor exists.

This is the M4.2-justified state removal.

The generic Canonical executor does not manually unroll arbitrary shapes merely
because they are template constants. Optimizers may use the fixed bounds.

Additional unrolling/code-generation specialization remains evidence-gated.

## 9. Preserving the qualified 3x3 hot path

For exactly:

~~~text
width       = 3
height      = 3
anchorX     = 1
anchorY     = 1
sampleCount = 9
~~~

applyNeighbourhoodInto delegates directly to:

~~~d
tryApplyRasterNeighbourhood3x3!kernel(...)
~~~

Therefore the existing qualified production machinery remains intact:

- Canonical 3x3 executor;
- generic signed-affine fallback;
- exact overlap behavior;
- LDC frontend-2.111 negative-row float specialization;
- existing DMD/LDC qualification.

The generic family does not replace the measured 3x3 engine with a weaker
implementation.

## 10. Generic Canonical executor

For other shapes, the approved Canonical path receives:

- top-left required-source pointer;
- signed row stride;
- output width/height;
- destination pointer/row stride.

Each output coordinate gathers one Shape.width x Shape.height row-major
neighbourhood and invokes the compile-time kernel.

The executor performs no structural validation itself.

This keeps semantic validation separate from execution specialization.

## 11. Generic signed-affine executor

The fallback reads from the already-derived required-source ROI.

For output coordinate (x,y), neighbourhood coordinate (dx,dy) is simply:

~~~text
requiredSource(x + dx, y + dy)
~~~

This avoids signed/underflow-prone coordinate subtraction inside the hot loop.

The destination is written at (x,y).

## 12. Overlap behavior

The generic operation reuses:

~~~text
classifyValidatedSameTypeAffine2DRectanglesByteOverlap
~~~

for the halo-expanded required-source rectangle versus destination rectangle.

If the checked-wide classifier reports arithmetic failure, the existing
allocation-free exact pairwise fallback concept is used.

This preserves the no-write-before-failure contract.

## 13. Whole-vs-streamed equivalence

Tests include a 5x3 neighbourhood executed:

- once as a whole output;
- once as independently materialized task-local halo blocks;
- reassembled into the same output.

The two outputs must compare byte-for-byte equal.

This extends the decomposition-independence evidence beyond 3x3.

## 14. 5x3 reference case

The generic production tests exercise:

~~~text
Shape = NeighbourhoodShape!(5, 3, 2, 1)
sampleCount = 15
left/right  = 2/2
top/bottom  = 1/1
~~~

Coverage includes:

- contiguous Canonical execution;
- signed-stride layout;
- missing-halo failure before write;
- whole-vs-streamed equivalence.

## 15. Border separation

applyNeighbourhoodInto is the resident-halo primitive.

It does not:

- synthesize missing samples;
- clamp;
- mirror;
- wrap;
- inject a constant;
- interpret ContextDeficit;
- inspect logical dataset boundaries;
- interpret imagery NoData.

Issue #111 owns generic border semantics.

## 16. Convolution reuse

Issue #112 must build on this family.

A convolution wrapper may define coefficient/accumulator semantics and supply a
kernel to applyNeighbourhoodInto.

It should not introduce a second spatial traversal/halo/alias engine.

## 17. Compile-contract qualification

Fast CI runs external compile-only probes for DMD and LDC.

Expected compile:

- 5x3 generic kernel;
- centered 3x3 kernel through the generic spelling.

Expected rejection:

- mismatched carrier size;
- impure kernel;
- throwing kernel;
- allocating kernel;
- @system kernel.

## 18. Acceptance mapping

Issue #110 requires no hidden allocation.

Satisfied by the @nogc destination-oriented API with fixed local carrier only.

It requires explicit layout and halo semantics.

Recorded in sections 3 and 7.

It requires compile-time geometry only where justified.

Shape removes runtime geometry state; arbitrary manual unrolling is not added.
The already-qualified 3x3 specialization is preserved.

It requires whole-vs-streamed equivalence to remain testable.

A 5x3 decomposition-equivalence production test is included.

It requires DMD and LDC qualification.

Fast CI and external compile contracts run on both required compilers.
