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

The initial oracle uses an explicitly bounded coverage bitmap.

If a geometrically valid target exceeds that research-only bitmap capacity,
the oracle reports an oracle-capacity condition rather than invalid geometry.

Empty decomposition members produce no pixels. They are therefore ignored for
coverage and containment after their own geometry has been verified as
representable.

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

# E3.2 — Identity Streamed Equivalence

## 18. Purpose

E3.2 is the first integration experiment above the E3.1 geometry layer.

It must prove that one logical output request produces exactly the same pixel
result whether it is processed:

- as one whole request;
- as horizontal strips;
- as vertical strips;
- as regular rectangular tiles;
- as irregular rectangular regions;
- as individual pixels for a deliberately small fixture.

The experiment tests identity only:

    output = input

No neighbourhood operation, cache, provider tiling or scheduler is introduced.

## 19. Existing production raster core is the resident execution layer

E3.2 must consume the existing public raster API rather than reproduce it inside
the experiment.

Resident materializations should use the public path:

    malloc-compatible storage
        ->
    OwnedByteResource
        ->
    tryImportOwnedRaster()
        ->
    RasterLease!ubyte
        ->
    RasterView!ubyte

Writable resident destinations should use:

    mutable RasterLease!ubyte
        ->
    tryWritableView()
        ->
    WritableRasterView!ubyte

Identity execution should use the stable public operation:

    tryCopyRasterPlane()

Correctness inspection may use:

    RasterView.trySample()

or the equivalent read operation on a writable view.

E3.2 must not access package-internal raster execution APIs.

## 20. Logical versus resident coordinates

Every source request belongs to logical-image coordinates.

For example:

    logical extent:
        Region2D(0, 0, 8192, 6144)

    requested output:
        Region2D(1733, 911, 1021, 769)

A decomposed logical task such as:

    Region2D(1800, 950, 128, 64)

must be materialized into a resident raster whose descriptor-space region is:

    Region2D(0, 0, 128, 64)

The logical placement must remain separate metadata owned by the experiment.

E3.2 must explicitly assert that resident `RasterView.region` does not carry
the logical/global origin.

## 21. Procedural source

The initial E3.2 source is procedural.

It represents a logical image without allocating storage for the complete
logical extent.

A requested logical region is materialized on demand.

Every generated sample must depend on its logical coordinates.

A suitable conceptual pattern is:

    value(x, y) =
        deterministicFunction(x, y)

The implementation should first reduce coordinates to small bounded values
before multiplication or addition so the pattern generator itself remains
overflow-safe for large `size_t` coordinates.

For example, a pattern may be based on:

    x % 251
    y % 251

combined using bounded arithmetic and finally converted to `ubyte`.

Two equal local resident coordinates originating from different logical
locations must therefore be capable of containing different values.

The experiment must include an explicit non-zero-origin case whose resident
sample `(0, 0)` differs from `value(0, 0)` and equals the value at the actual
logical request origin.

This prevents an implementation that accidentally resets each logical task to
global `(0, 0)` from passing the equivalence test.

## 22. Source request validity

The procedural source accepts only:

- representable logical extent;
- representable non-empty request;
- request contained in the logical extent.

Invalid requests are rejected.

They are not clipped.

The initial resident materialization experiment does not materialize an empty
request.

Empty dependency/output semantics were already established by E3.1 and remain
a no-op at this layer.

## 23. Resident materialization

For one non-empty logical request:

1. compute checked sample/byte count;
2. allocate exactly enough storage for one single-plane `ubyte` raster;
3. transfer ownership through the public retained-import API;
4. expose a writable borrow from the resulting lease;
5. fill resident samples using the procedural value derived from the
   corresponding logical coordinates;
6. release the writable borrow;
7. expose the ordinary read-only `RasterView`.

The imported resident region is always:

    Region2D(
        0,
        0,
        logicalRequest.width,
        logicalRequest.height
    )

The resulting materialization therefore contains two deliberately separate
pieces of information:

    logical request placement

and:

    resident RasterLease / RasterView

No production raster type is extended with logical/global placement metadata.

## 24. Identity execution

Identity processing uses two distinct resident rasters:

    materialized source
    materialized destination

The destination has the same resident shape as the source.

The operation is:

    tryCopyRasterPlane(
        source.view(),
        0,
        destinationWritable,
        0,
        error
    )

The operation must succeed with:

    RasterCopyError.none

The identity experiment must not implement its own pixel-copy loop as the
operation under test.

A loop is permitted only for:

- procedural source generation;
- reference/output inspection;
- decomposition construction;
- reassembly into the test oracle.

## 25. E3.1 dependency integration

Identity has zero dependency margins.

For every output task E3.2 must derive its required input through the E3.1.2
dependency logic using:

    DependencyMargins.init

and verify:

    validInput == outputTask
    contextDeficit == ContextDeficit.init

The materialized source request is this derived `validInput`.

This ensures E3.2 consumes the dependency layer rather than bypassing it.

## 26. E3.1 decomposition integration

Before decomposed execution begins, the complete decomposition must be checked
with the E3.1.3 decomposition oracle.

Execution proceeds only if:

    tryValidateDecomposition(...) == true
    issue == DecompositionIssue.none

This makes decomposition correctness independent of the identity comparison.

A broken partition must not be able to masquerade as an image-processing bug.

## 27. Reassembly

The decomposed result is reassembled into one ordinary test buffer whose
coordinate system is relative to the complete requested output region.

For a processed logical task:

    relativeX =
        task.x - requestedOutput.x

    relativeY =
        task.y - requestedOutput.y

Each resident destination sample `(localX, localY)` is written to:

    output[
        relativeX + localX,
        relativeY + localY
    ]

The task result should be read through the public semantic raster accessor.

The reassembly buffer is test-oracle state.

It is not a cache block, resident raster resource or proposed production
output representation.

## 28. Reference execution

For a modest requested region, E3.2 first executes identity once as a single
whole request.

That produces the reference output.

Each legal decomposition is then processed independently and reassembled.

Every decomposed result must be byte-identical to the whole-request reference.

The whole-request reference is a correctness oracle.

It is not evidence that production processing should materialize a complete
logical image or complete future viewport result at once.

## 29. Required decompositions

At minimum E3.2 must test:

### Whole request

One task equal to the requested output.

### Horizontal strips

Multiple complete-width tasks.

At least one decomposition must contain a final strip smaller than the nominal
strip height.

### Vertical strips

Multiple complete-height tasks.

At least one decomposition must contain a final strip smaller than the nominal
strip width.

### Regular rectangular tiles

A regular task grid whose dimensions do not evenly divide the requested output.

This forces smaller right and bottom edge tasks.

### Irregular rectangles

A manually defined legal decomposition with unequal rectangles and boundaries
that do not follow one regular grid.

### Single-pixel decomposition

A deliberately small requested region is partitioned into one task per pixel.

The large principal fixture must not use a single-pixel decomposition merely
to create hundreds of thousands of allocations.

## 30. Principal non-zero-origin fixture

The principal exact-equivalence fixture should use:

    logical extent:
        Region2D(0, 0, 8192, 6144)

    requested output:
        Region2D(1733, 911, 1021, 769)

The dimensions are deliberately not convenient multiples of common strip or
tile dimensions.

All decomposition forms except the dedicated small single-pixel fixture should
be exercised against this request.

## 31. Large-logical-image fixture

E3.2 must also demonstrate that the procedural source can represent a logical
image much larger than any resident task without allocating the whole image.

The logical extent should therefore be deliberately much larger than the
principal resident request.

For example, subject to representability on the test platform:

    logical extent:
        1,000,000 x 1,000,000

with a modest non-zero-origin requested region.

The experiment must demonstrate:

    logical image bytes
        >>
    maximum simultaneously resident task raster bytes

No allocation proportional to the complete logical image is permitted.

## 32. Residency accounting

E3.2 should distinguish at least:

    logical image size
    requested output size
    source materialization bytes
    destination materialization bytes
    current resident raster bytes
    peak resident raster bytes
    number of source materializations
    total materialized source pixels

Test-oracle memory such as:

- the whole-request reference buffer;
- the reassembled comparison buffer;
- decomposition metadata;

must be reported separately from resident raster materialization.

E3.2 must not claim that total process memory is bounded by task size while a
whole requested-output oracle buffer is deliberately retained for testing.

The required claim is narrower:

> raster residency is independent of complete logical-image size and can be
> bounded by the currently processed materialization.

## 33. Materialization lifetime

Decomposed execution should process tasks sequentially in E3.2.

For each task:

    derive dependency
        ->
    materialize source
        ->
    allocate destination
        ->
    identity copy
        ->
    reassemble result
        ->
    release task source/destination
        ->
    process next task

The initial experiment therefore requires no worker pool or scheduler.

Peak resident-raster accounting should make this sequential lifetime visible.

## 34. Exact comparison

Identity on `ubyte` data is exact.

Therefore the correctness condition is:

    reference.length == streamed.length

and every corresponding byte is exactly equal.

No numerical tolerance is permitted.

When a mismatch occurs, diagnostics should identify at least:

    output-relative x
    output-relative y
    logical x
    logical y
    expected value
    actual value

This makes coordinate-space mistakes directly diagnosable.

## 35. E3.2 failure separation

The experiment should keep failures attributable to distinct layers.

At minimum distinguish:

    invalid logical/source request
    dependency derivation failure
    invalid decomposition
    allocation/adoption/import failure
    writable-borrow failure
    raster-copy failure
    sample-read failure
    reassembly mismatch

This is experimental diagnostics, not a proposed production error hierarchy.

## 36. E3.2 module direction

If the contract survives implementation, a minimal split is expected to be:

    experiments/r0_3_regions_streaming/
        procedural_source.d
        identity_streaming.d

Existing E3.1 modules remain:

        region_algebra.d
        dependency.d
        decomposition_oracle.d

A separate scheduler, provider or cache module is not justified by E3.2.

## 37. E3.2 completion gate

E3.2 is complete only when all of the following hold:

1. procedural pixels depend on logical/global coordinates;
2. source requests may begin at non-zero logical coordinates;
3. every materialized resident raster begins at resident `(0, 0)`;
4. identity dependency is derived through E3.1.2;
5. every decomposition is validated through E3.1.3;
6. identity execution uses the public `tryCopyRasterPlane()` operation;
7. whole-request and decomposed outputs are byte-identical;
8. horizontal, vertical, regular-tile and irregular decompositions pass;
9. a small single-pixel decomposition passes;
10. a logical image substantially larger than resident task storage is
    demonstrated without whole-image allocation;
11. resident-raster peak accounting is separated from test-oracle memory;
12. DMD and LDC pass;
13. no production API change was required merely to support the experiment.

Only after these gates pass should R0.3 proceed to the first neighbourhood /
halo equivalence experiment.

### E3.2 completion result — PASS

E3.2 completed on 2026-09-21 on branch
`research/r0_3-regions-streaming`.

All 13 completion gates above pass.

Implementation evidence includes:

- deterministic procedural pixels derived from logical/global coordinates;
- non-zero logical request origins with resident rasters rebased to `(0, 0)`;
- zero-margin dependency derivation through E3.1.2;
- exact decomposition validation through E3.1.3;
- identity execution through public `tryCopyRasterPlane()`;
- exact whole-request versus decomposed equivalence;
- horizontal strips;
- vertical strips;
- regular rectangular tiles;
- manually irregular rectangles in non-spatial task order;
- a dedicated one-task-per-pixel fixture;
- a `1,000,000 x 1,000,000` logical-image fixture without whole-image
  allocation;
- explicit separation of resident-raster, output-oracle,
  decomposition-coverage-oracle and decomposition-metadata payloads;
- first-mismatch diagnostics containing output-relative coordinates, logical
  coordinates, expected value and actual value;
- passing DMD and LDC experiment suites;
- no production `source/` changes required by E3.2.

Representative raster-residency results for the principal
`1021 x 769` requested output are:

```text
whole request peak                 1,570,298 B
horizontal strips, 128 high         261,376 B
vertical strips, 128 wide           196,864 B
regular 128 x 96 tiles               24,576 B
irregular rectangles                220,706 B
```

The dedicated `7 x 5` one-pixel-task fixture has a peak resident-raster
payload of `2 B`.

The huge-logical fixture represents:

```text
logical image                     1,000,000 x 1,000,000
logical ubyte payload             1,000,000,000,000 B
requested output                  257 x 193 = 49,601 B
nominal streamed tile             64 x 48
peak resident raster payload      6,144 B
```

These figures describe raster payload residency, not total process memory.

Output/reference buffers, decomposition coverage-oracle payload and
decomposition metadata remain explicit experiment/oracle state and are
accounted separately from resident source/destination raster storage.

E3.2 therefore supports the narrower intended conclusion:

> Raster residency is independent of complete logical-image size and can be
> bounded by the currently processed materialization.

The next R0.3 research slice is R0.3b: neighbourhood / halo equivalence.
