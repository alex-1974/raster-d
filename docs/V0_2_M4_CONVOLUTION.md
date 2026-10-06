# raster-d v0.2 M4.5 — generic fixed-kernel convolution

Status: implementation candidate for Issue #112.

Baseline:

~~~text
develop
4b76d68b78e2038f8802c376b5b291bbe2a31c45
~~~

## 1. Public family

v0.2 adds:

~~~d
FixedConvolutionKernel!(
    Shape,
    Coefficient,
    coefficients...
)
~~~

and:

~~~d
bool convolveInto!(
    Kernel,
    Accumulator
)(
    source,
    sourcePlaneIndex,
    sourceOutputRegion,
    destination,
    destinationPlaneIndex,
    error
);
~~~

The operation is destination-oriented and reuses applyNeighbourhoodInto.

## 2. Kernel representation

A FixedConvolutionKernel contains:

- one compile-time NeighbourhoodShape;
- one compile-time coefficient type;
- exactly Shape.sampleCount compile-time coefficient values.

Example:

~~~d
alias Shape =
    NeighbourhoodShape!(
        3,
        3,
        1,
        1
    );

alias Identity =
    FixedConvolutionKernel!(
        Shape,
        float,
        0.0f, 0.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, 0.0f
    );
~~~

Coefficient order is row-major and matches the neighbourhood carrier order.

The kernel type has no runtime fields.

## 3. Why fixed compile-time coefficients are the first contract

Issue #113 separately owns the question whether prepared/runtime convolution
state is worth introducing.

M4.5 therefore does not pre-empt that research with a permanent runtime kernel
object.

A fixed kernel:

- has no preparation allocation;
- has no runtime coefficient pointer/state;
- can be specialized/inlined by the compiler;
- maps directly onto the existing compile-time neighbourhood-kernel contract.

This keeps the one-shot API coherent while leaving prepared state evidence-gated.

## 4. Initial numerical domain

The first production family is deliberately floating-only.

Supported source/output sample types:

~~~text
float
double
~~~

Supported coefficient types:

~~~text
float
double
~~~

Supported accumulators:

~~~text
float
double
~~~

real remains excluded.

Integer convolution is not promoted in M4.5 because it would require an
additional contract for:

- multiply overflow;
- accumulation overflow;
- final narrowing;
- rounding;
- saturation or checked failure;
- destination state on numeric failure.

No such policy is invented implicitly.

## 5. Accumulator constraints

Source samples and coefficients must both be exactly representable in the
selected Accumulator.

Supported examples:

~~~text
float source + float coeff  -> float accumulator
float source + float coeff  -> double accumulator
float source + double coeff -> double accumulator
double source + float coeff -> double accumulator
double source + double coeff -> double accumulator
~~~

Rejected examples include:

~~~text
double source -> float accumulator
double coeff  -> float accumulator
integer source convolution
~~~

## 6. Evaluation order

For one neighbourhood, terms are visited in row-major coefficient order.

The source-level operation is:

~~~text
total = +0 in Accumulator

for i = 0 .. sampleCount:
    sample      = exact cast source[i]      -> Accumulator
    coefficient = exact cast coefficient[i] -> Accumulator
    product     = sample * coefficient
    total       = total + product
~~~

NaN and infinity participate through ordinary D/IEEE floating arithmetic.

The contract fixes coefficient order and Accumulator type.

It does not add an extra promise forbidding compiler-permitted floating
multiply/add contraction.

## 7. Final result conversion

The destination sample type equals the source sample type T.

If:

~~~text
Accumulator == T
~~~

the final conversion is identity.

For:

~~~text
T = float
Accumulator = double
~~~

one explicit binary64 -> binary32 cast occurs after the complete accumulation.

That is the only promoted narrowing case.

No hidden normalization or clamping is performed.

## 8. Spatial execution

convolveInto contains no spatial traversal.

It constructs one compile-time convolution callable and delegates to:

~~~d
applyNeighbourhoodInto!(
    Kernel.shape,
    convolutionKernel
)
~~~

Therefore convolution inherits exactly:

- resident-relative sourceOutputRegion;
- complete halo requirement;
- destination shape contract;
- destination injectivity;
- exact source/destination overlap rejection;
- matching-empty no-op;
- signed-affine layout support;
- Canonical fast path;
- 3x3 qualified specialization;
- whole-vs-streamed decomposition behavior;
- no hidden raster allocation.

## 9. 3x3 performance preservation

When Kernel.shape is:

~~~text
3 x 3
anchor 1,1
~~~

applyNeighbourhoodInto delegates to the existing qualified
tryApplyRasterNeighbourhood3x3 path.

Therefore a fixed 3x3 convolution can still use the measured production:

- Canonical executor;
- LDC frontend-2.111 negative-row float specialization;
- generic signed-affine fallback.

M4.5 does not introduce a separate convolution loop that bypasses these paths.

## 10. Fixed-kernel specialization

Shape and every coefficient are compile-time values.

This gives the compiler visibility into:

- sample count;
- coefficient values;
- zero coefficients;
- identity coefficients;
- fixed neighbourhood geometry;
- accumulator type.

The implementation does not manually generate string-mixin code or public
compiler/ISA variants.

Further explicit unrolling/SIMD remains measurement-gated.

## 11. Border semantics

The initial convolveInto operation uses the valid/resident-halo semantics of
applyNeighbourhoodInto.

It does not synthesize edge samples.

The generic border policy types introduced in M4.4 remain separate semantic
building blocks.

M4.5 does not silently select constant/clamp/mirror/wrap or introduce image
edge meaning.

Future border-aware spatial execution can reuse the same policy types rather
than defining convolution-specific edge modes.

## 12. No image/radiometric semantics

Convolution coefficients are applied literally.

Raster-d does not infer:

- normalization to coefficient sum;
- brightness preservation;
- sharpening meaning;
- blur meaning;
- gamma behavior;
- colour-space interpretation;
- alpha handling;
- NoData handling;
- radiometric scale/offset.

Higher layers choose coefficients and interpretation.

## 13. Attributes and allocation

convolveInto is:

~~~text
@safe
nothrow
@nogc
~~~

The fixed kernel stores no runtime fields.

No coefficient heap storage, scratch raster, output allocation, worker or
scheduler is created.

The caller owns destination storage.

## 14. Tests

Production tests cover:

- centered 3x3 float identity convolution;
- 5x3 generic fixed kernel;
- explicit double accumulation with one final float narrowing;
- NaN/infinity floating behavior;
- kernel type having no runtime fields;
- coefficient-count validation;
- supported/rejected source/coefficient/accumulator combinations.

Fast CI adds external compile-only consumer probes for DMD and LDC.

## 15. Compile-contract boundaries

Expected compile:

~~~text
float source + float coefficients + float accumulator
float source + double coefficients + double accumulator
~~~

Expected rejection:

~~~text
integer source convolution
double source + float accumulator
coefficient count != Shape.sampleCount
~~~

These constraints are caller-visible source-compatibility surface.

## 16. Prepared state remains #113

M4.5 deliberately does not add:

- mutable runtime convolution kernels;
- prepared coefficient storage;
- transformed/reordered coefficient buffers;
- cached plans.

Issue #113 must first measure:

- one-shot repeated cost;
- preparation cost;
- prepared repeated cost;
- break-even reuse count.

Only measured benefit may justify a prepared production type.

## 17. Acceptance mapping

Issue #112 requires explicit kernel representation.

Satisfied by FixedConvolutionKernel with compile-time Shape/type/coefficients.

It requires explicit numerical semantics.

Satisfied by the floating-only type matrix, explicit Accumulator, row-major term
order and documented final cast.

It requires a destination-oriented path.

Satisfied by convolveInto over caller-owned WritableRasterView.

It requires fixed-kernel cases to remain compiler-specializable.

All geometry and coefficients are compile-time, and the operation reuses the
existing specialized neighbourhood path.

It requires no image, colour or radiometric semantics to leak into raster-d.

No such interpretation is present.
