# raster-d v0.2 M4.2 — compile-time neighbourhood shape model

Status: implementation candidate for Issue #109.

Baseline:

~~~text
develop
c667c7b2649fc1d818db4f33356ab4de204ea7f3
~~~

## 1. Public model

v0.2 adds:

~~~d
NeighbourhoodShape!(
    Width,
    Height,
    AnchorX,
    AnchorY
)
~~~

The model is structural and compile-time only.

Example:

~~~d
alias Shape =
    NeighbourhoodShape!(
        3,
        3,
        1,
        1
    );
~~~

## 2. Why anchor is explicit

The M4.1 audit rejected a hidden center rule for generic fixed shapes.

3x3 has an obvious center, but shapes such as:

~~~text
2x2
4x4
3x4
5x3 with asymmetric semantics
~~~

do not have one uniquely correct anchor.

Therefore M4.2 does not infer:

~~~text
AnchorX = Width / 2
AnchorY = Height / 2
~~~

as a universal semantic.

Consumers must state the anchor explicitly.

## 3. Shape invariants

The template requires:

~~~text
Width  > 0
Height > 0

AnchorX < Width
AnchorY < Height

Width * Height fits size_t
~~~

Invalid shapes fail at compile time.

## 4. Derived geometry

The model exposes compile-time enum members:

~~~text
width
height
anchorX
anchorY

left
right
top
bottom

sampleCount
~~~

Margins are derived as:

~~~text
left   = anchorX
right  = width  - anchorX - 1
top    = anchorY
bottom = height - anchorY - 1
~~~

For the existing fixed 3x3 operation:

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
~~~

## 5. Runtime-state removal

NeighbourhoodShape contains no instance fields.

Its geometry is available only as compile-time enum members.

The intended generic spatial call therefore receives Shape as a template
argument rather than a runtime descriptor.

This removes runtime neighbourhood state such as:

~~~text
width
height
anchorX
anchorY
~~~

from every operation invocation.

That directly satisfies the M4.2 acceptance requirement that compile-time shape
remove real state rather than merely relocate constants.

The implementation tests:

~~~d
static assert(Shape.tupleof.length == 0);
~~~

for representative shapes.

No runtime shape object is required.

## 6. What this does not claim

M4.2 does not claim that compile-time shape alone makes every neighbourhood
kernel faster.

The M4.1 audit showed that the measured 3x3 speedup combines:

- Canonical pointer/row execution;
- fixed nine-sample geometry;
- compiler-generated code;
- one narrow LDC negative-row specialization.

The existing evidence does not isolate arbitrary template shape as the sole
performance cause.

Therefore M4.2 promotes compile-time shape because it removes runtime geometry
state and enables specialization. Performance qualification of generated
executors remains separate.

## 7. Why a runtime shape object is not the default

Fixed-shape operations are expected to use the same geometry repeatedly across
many output samples.

Passing runtime width/height/anchor through every call would introduce state
that is invariant for the complete operation.

Using the shape as a template argument lets generic execution access:

~~~d
Shape.width
Shape.height
Shape.anchorX
Shape.anchorY
Shape.left
Shape.right
Shape.top
Shape.bottom
Shape.sampleCount
~~~

as compile-time constants.

This is a direct use of D templates for real capability/state elimination.

## 8. Why the model is not only 3x3

The model supports asymmetric fixed shapes.

Example:

~~~d
alias Shape =
    NeighbourhoodShape!(
        5,
        3,
        1,
        2
    );
~~~

This yields:

~~~text
left   = 1
right  = 3
top    = 2
bottom = 0
sampleCount = 15
~~~

No centered-only assumption leaks into the generic model.

## 9. Shape versus border policy

NeighbourhoodShape describes only local geometry.

It does not define:

- border handling;
- missing-neighbour values;
- logical dataset extent;
- ContextDeficit interpretation;
- provider tile edges;
- imagery NoData semantics.

Those remain separate.

#111 owns generic border policy.

## 10. Shape versus kernel semantics

NeighbourhoodShape also does not define the kernel result or numeric behavior.

It describes where samples are taken relative to the anchor.

#110 will define the generic destination-oriented neighbourhood primitive.

#112 will layer convolution numerical semantics over the same shape/execution
family.

## 11. Expected #110 use

The intended direction is structurally:

~~~text
alias Shape = NeighbourhoodShape!(...);

source.applyNeighbourhoodInto!(Shape, kernel)(...)
~~~

Exact #110 spelling is still allowed to specialize.

The important frozen requirement is that Shape is compile-time structural
geometry and not runtime request data.

## 12. Compile-contract tests

Fast CI runs external compile-only probes on both DMD and LDC.

Expected compile:

~~~text
3x3 anchor 1,1
5x3 anchor 1,2
~~~

Expected rejection:

~~~text
zero width
zero height
anchor outside width
anchor outside height
sample-count overflow
~~~

The tests use the root import surface.

## 13. Source-compatibility position

NeighbourhoodShape template parameter meaning and derived enum semantics are
public source-compatibility surface.

Changing:

- anchor interpretation;
- margin equations;
- sample flattening assumptions introduced by later operations;
- validity constraints

requires deliberate API review.

## 14. Performance position

The shape model itself introduces no runtime dispatch.

Later executors may use Shape to specialize:

- required-source expansion;
- neighbourhood sample loops;
- fixed-size local carriers;
- unrolled loads;
- compiler-specific execution forms.

Such specialization must still satisfy the workspace rule:

~~~text
measure optimized behavior instead of guessing it
~~~

A larger generated binary or more template instantiations are not by
themselves evidence of a useful optimization.

## 15. Acceptance mapping

Issue #109 asks for fixed neighbourhood geometry represented structurally at
compile time where this removes runtime work.

Satisfied:

- width/height/anchor are template semantics;
- no runtime shape fields exist;
- margins and sample count are compile-time constants.

Acceptance requires generated specialization to remove measurable work, state or
branches rather than only moving constants into templates.

M4.2 demonstrates removal of runtime shape state directly and leaves
hot-path performance qualification to the generic executor work rather than
making an unsupported speed claim.
