# R0.3 Region and Streaming Experiments

## Status

Research-only.

The authoritative higher-level contract is:

    docs/research/regions-streaming.md

Nothing in this experiment directory is a stable public API.

Production `Region2D` is not modified merely to make these experiments
convenient.

# E3.1 — Region and Dependency Algebra

## 1. Purpose

E3.1 establishes the geometric operations required by the later identity and
neighbourhood streaming experiments.

The work is deliberately split into:

    E3.1.1  primitive region algebra
    E3.1.2  request-bounded dependency expansion
    E3.1.3  decomposition validation oracle

E3.1 does not implement:

- a source abstraction;
- cache blocks;
- provider tiles;
- scheduling;
- parallelism;
- raster processing pipelines;
- border policies.

## 2. Coordinate model

All `Region2D` values used here retain their existing property:

> the owner of the value defines its coordinate space.

The experimental helpers therefore operate on geometry only.

They do not infer whether a region is:

- logical/global;
- resident;
- provider-local;
- cache-local.

Callers must only combine regions belonging to the same coordinate space.

## 3. Rectangle semantics

A representable non-empty region

    Region2D(x, y, width, height)

represents the half-open rectangle:

    [x, x + width) × [y, y + height)

Half-open semantics are required because they make:

- adjacency unambiguous;
- width and height equal to coordinate differences;
- decomposition boundaries non-overlapping;
- edge-touching intersections naturally empty.

Before an end coordinate is formed, the region must satisfy the existing
representability rule.

No helper may depend on unchecked:

    x + width
    y + height

when representability has not already been established.

## 4. Valid empty regions

A region is empty when either extent is zero.

Empty geometry is valid geometry.

Therefore:

    empty != failure

Research helpers must never use `Region2D.init` alone as a failure sentinel.

A successful operation may legitimately return an empty region.

## 5. E3.1.1 — Primitive region algebra

The first implementation slice investigates four operations.

### 5.1 Representability

The existing production operation remains authoritative:

    Region2D.hasRepresentableExtent()

The experiment does not introduce a competing definition.

### 5.2 Absolute containment

Conceptual operation:

    tryContainsAbsolute(outer, inner, contains)

Semantics:

- return failure only if either input has unrepresentable extent;
- otherwise return success and set `contains`;
- containment is tested independently on both half-open axes;
- a zero-extent child may lie at the enclosing end boundary;
- no coordinate translation is implied.

This deliberately distinguishes:

    valid geometry, not contained

from:

    invalid / unrepresentable geometry

### 5.3 Intersection

Conceptual operation:

    tryIntersection(a, b, result)

Semantics:

- fail only if an input region is unrepresentable;
- otherwise always produce a valid result;
- overlapping regions produce their normal intersection;
- disjoint regions produce a valid empty intersection;
- edge-touching regions produce a valid empty intersection.

For each axis:

    start = max(aStart, bStart)
    end   = min(aEnd, bEnd)

If:

    end > start

then:

    extent = end - start

otherwise:

    extent = 0

The result origin remains the computed `start`.

Empty intersections are therefore deterministic rather than canonicalized to
`Region2D.init`.

Example:

    A = [0, 10)
    B = [10, 20)

produces:

    intersection = [10, 10)

not a failure.

### 5.4 Translation

Translation must support movement in both directions without narrowing the
coordinate range to `ptrdiff_t`, `long` or another signed type smaller than the
full `size_t` magnitude domain.

The research representation should therefore use sign plus magnitude per axis,
conceptually:

    AxisDelta
        direction
        magnitude

    Translation2D
        x
        y

This is experimental machinery, not a proposed public type.

Semantics:

- source region must be representable;
- width and height are preserved exactly;
- zero translation is identity;
- negative translation fails on coordinate underflow;
- positive translation fails if the translated region end would become
  unrepresentable;
- translation never clips;
- translation never saturates;
- failure leaves no partially valid translated result.

A zero-magnitude delta has no directional semantic significance.

## 6. E3.1.1 edge cases

Tests must cover at least:

### Intersection

- identical regions;
- one contained in another;
- partial overlap;
- horizontal disjointness;
- vertical disjointness;
- disjoint on both axes;
- edge touching;
- corner touching;
- empty input;
- empty input anchored at another region's end;
- representable geometry near `size_t.max`;
- unrepresentable input.

### Containment

- identical region;
- strict child;
- child touching each boundary;
- child outside each boundary;
- zero-width child at right boundary;
- zero-height child at bottom boundary;
- empty parent;
- invalid parent;
- invalid child.

### Translation

- zero shift;
- positive x/y;
- negative x/y;
- mixed signs;
- exact translation to coordinate zero;
- one step beyond coordinate zero;
- exact translation to maximum representable end;
- one step beyond maximum representable end;
- empty region;
- invalid source region.

## 7. E3.1.2 — Request-bounded dependency expansion

The next slice derives the valid input required by a rectangular
request-bounded dependency.

The initial requirement representation is conceptually:

    DependencyMargins
        left
        top
        right
        bottom

Each value is a non-negative `size_t` magnitude.

The values describe required context around an output request.

They do not describe:

- allocation padding;
- provider overlap;
- cache overlap;
- a border policy.

## 8. Expanded dependency result

The research result is conceptually:

    ExpandedDependency
        validInput
        contextDeficit

where:

    validInput

is the portion of the mathematical dependency contained in the logical extent,

and:

    contextDeficit

records required context that lies beyond the logical extent.

For the initial rectangular experiment, context deficit can be represented as
four directional magnitudes:

    left
    top
    right
    bottom

The exact D type remains experimental.

## 9. Dependency-expansion preconditions

The operation receives:

- a representable logical extent;
- a representable output request;
- dependency margins.

The output request must be contained in the logical extent according to the
same absolute-containment semantics established by E3.1.1.

An output request outside the logical extent is invalid input to this
experiment.

It is not silently clipped.

## 10. Dependency-expansion semantics

For a non-empty output request:

1. determine how much valid logical-image space is available on each side;
2. satisfy as much requested context as possible from that space;
3. form `validInput` from the output plus the satisfiable context;
4. record any unsatisfied remainder in `contextDeficit`.

Conceptually, for the left side:

    availableLeft =
        output.x - logicalExtent.x

    usedLeft =
        min(requiredLeft, availableLeft)

    deficitLeft =
        requiredLeft - usedLeft

Equivalent subtraction-based logic applies to the other sides.

The implementation must not construct an unrepresentable mathematical
rectangle merely to clip it afterwards.

In particular, a margin of:

    size_t.max

is a valid research input and must not itself cause arithmetic wrapping.

## 11. Empty-output dependency

An empty output request produces no output samples.

Therefore the initial R0.3 dependency rule is:

    empty output
        -> empty required input
        -> zero context deficit

regardless of the configured dependency margins.

The returned empty input is anchored at the output-request origin:

    Region2D(output.x, output.y, 0, 0)

This remains a successful empty result rather than a failure sentinel.

This rule may be revisited only if a concrete future operation demonstrates
that producing no output can semantically require input work.

## 12. Context deficit is not border handling

A context deficit means only:

> the mathematical dependency asks for context outside the valid logical
> extent.

It does not specify what should happen next.

In particular it does not imply:

- clamp;
- mirror;
- wrap;
- constant fill;
- zero fill;
- failure.

Those are later operation or border-policy semantics.

The dependency layer only preserves the information.

## 13. E3.1.2 edge cases

Tests must cover at least:

- zero margins;
- centered output with all context available;
- left edge;
- top edge;
- right edge;
- bottom edge;
- all four corners;
- whole logical extent as output;
- margin larger than output dimensions;
- margin larger than logical dimensions;
- `size_t.max` margin;
- empty output;
- invalid logical extent;
- invalid output extent;
- output not contained in logical extent.

For successful cases verify independently:

    valid input geometry
    left deficit
    top deficit
    right deficit
    bottom deficit

## 14. E3.1.3 — Decomposition validation oracle

R0.3a requires legal output decompositions, but E3.1 does not yet have evidence
for a general production partition-validation abstraction.

Therefore E3.1.3 will initially provide only a research/test oracle for the
bounded output sizes used by E3.2.

The oracle must detect:

- member outside target;
- overlap;
- omitted pixels;
- duplicate coverage;
- produced pixels outside target.

A simple coverage bitmap is acceptable for the deliberately bounded E3.2 test
requests.

This is preferable at this stage to introducing a generic area-accounting or
sweep-line API whose production consumer is not yet known.

Large-coordinate arithmetic continues to be tested independently by E3.1.1
and E3.1.2.

## 15. Initial module split

If the semantics above survive review, the intended experiment structure is:

    experiments/r0_3_regions_streaming/
        README.md
        dub.sdl
        region_algebra.d
        dependency.d
        decomposition_oracle.d

The exact files may change if implementation evidence suggests a smaller
structure.

No module under this directory is part of the `imagery-d` public package.

## 16. D engineering requirements

Experimental geometry helpers should, where their semantics permit, remain:

    @safe
    pure
    nothrow
    @nogc

Tests should use explicit runtime values near arithmetic boundaries rather than
assuming ordinary small coordinates are sufficient evidence.

`assert` is appropriate for unittests.

It is not a substitute for runtime validation inside helpers whose contract
accepts potentially invalid research input.

## 17. E3.1 completion gate

E3.1 is complete only when:

1. primitive geometry has deterministic semantics;
2. valid empty results remain distinguishable from failure;
3. intersection and translation are overflow-safe;
4. dependency expansion never requires constructing an overflowing expanded
   rectangle;
5. context outside logical extent remains observable;
6. `size_t.max` edge cases are tested;
7. E3.2 can consume the resulting geometry without changing its semantics;
8. no Production `Region2D` change was required merely for convenience.

Only then does R0.3a proceed to the identity streamed-equivalence harness.
