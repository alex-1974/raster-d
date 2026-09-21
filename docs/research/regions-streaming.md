# R0.3 — Region, Tile and Streaming Model

## Status

Research contract.

R0.3 is not a stable public-API phase.

Initial experimental work belongs under:

```text
experiments/r0_3_regions_streaming/
```

Production types are changed only if research provides concrete evidence that
their current semantics are insufficient.

## 1. Purpose

The resident raster core can represent and operate on validated resident raster
storage.

R0.3 investigates the layer above that core:

```text
large logical image
        |
        | output request
        v
operation dependency
        |
        | required input
        v
source / cache resolution
        |
        | resident materialization
        v
RasterLease / RasterView
        |
        v
raster operation
```

The principal question is:

> What is the smallest region/dependency model that allows arbitrary portions
> of very large imagery datasets to be processed correctly with bounded
> residency, without making provider tiles, cache blocks or scheduler tasks
> part of operation semantics?

The first intended consumer remains an interactive OSM editor, but the model
must remain independent of OSM-specific data structures.

## 2. Existing architectural invariants

R0.3 inherits the following decisions.

### 2.1 Dataset size is not resident size

A logical image may be substantially larger than RAM.

Only pixels required for current work need to become resident unless an
operation is intrinsically global.

### 2.2 Global placement is not RasterView geometry

`Region2D` is a geometry value type.

Its owner determines its coordinate space.

For example, a global request:

```text
Region2D(100000, 200000, 512, 512)
```

may be materialized as resident storage whose view uses:

```text
Region2D(0, 0, 512, 512)
```

Global image placement therefore remains above `RasterView`.

### 2.3 Storage geometry is not processing geometry

These concepts remain distinct:

```text
ProviderTile != CacheBlock != Region != ProcessingTask
```

Equal dimensions do not imply semantic identity.

A provider that happens to return 256 x 256 tiles does not require processing
to occur in 256 x 256 regions.

### 2.4 Operation semantics are separate from scheduling

An operation determines what input is required to produce requested output.

A later scheduler may determine:

- task dimensions;
- traversal order;
- parallelism;
- priority;
- cancellation;
- prefetch.

Those choices must not alter the semantic result.

## 3. Terminology

### 3.1 Logical extent

The complete valid rectangular pixel domain of one logical image at one
representation or resolution level.

Logical extent is expressed in logical-image coordinates and does not imply
residency.

R0.3a does not decide whether a future logical-extent representation may carry
a non-zero origin. Initial experiments may use an origin-zero logical extent,
while output requests must also exercise non-zero logical origins.

The future production type that owns logical extent is deliberately not frozen
by R0.3a.

### 3.2 Output request

A region in logical-image coordinates requested by a downstream consumer.

For an interactive editor this will commonly be related to a viewport or part
of a viewport.

An output request is not a scheduler task.

### 3.3 Dependency

A dependency describes what an operation semantically requires from an input in
order to produce an output request.

R0.3 initially investigates at least the conceptual distinction:

```text
request-bounded spatial dependency
full-extent spatial dependency
```

A request-bounded spatial dependency derives required input geometry from the
output request and operation parameters without requiring the complete logical
input extent. Its dependency reach remains tied to the request rather than to
unrelated portions of the dataset.

A full-extent spatial dependency means that producing the requested output
semantically depends on the complete logical input extent.

This is an initial research classification, not a claim that these two cases
form an exhaustive future dependency taxonomy.

The concrete representation is deliberately not yet a production API decision.

### 3.4 Mathematical required input

For a request-bounded spatial dependency, this is the complete input geometry
mathematically required by the operation before clipping to the valid image
domain.

Examples:

```text
identity:
    required input == output request

radius-r neighbourhood:
    required input == output request expanded by r

future resampling:
    required input == transformed source footprint
```

This concept may extend outside the logical image extent.

### 3.5 Valid input region

The portion of the mathematical required input that lies inside the input
logical extent.

It is therefore an intersection, not the complete dependency.

### 3.6 Context deficit

The part of a request-bounded mathematical dependency that lies outside the
valid logical extent.

At minimum, rectangular neighbourhood research may need directional deficits:

```text
left
top
right
bottom
```

This distinction is required because current `Region2D` coordinates use
`size_t`.

For example, a radius-1 operation at logical x = 0 mathematically requires an
input column at x = -1, which cannot be represented directly by `Region2D`.

Therefore R0.3 must not silently collapse:

```text
mathematical required input
```

into:

```text
clipped valid input region
```

and thereby lose the fact that context is missing.

The concrete deficit representation remains experimental.

### 3.7 Resident coverage

The portion of logical-image space represented by one or more currently
resident resources.

Resident coverage is higher-level metadata.

It does not belong in `RasterView`.

### 3.8 Processing decomposition

A decomposition partitions an output request into smaller output regions that
may be processed separately when their dependencies can be satisfied.

A decomposition is not a scheduler policy.

### 3.9 Provider tile

A unit naturally supplied or decoded by an external source.

Provider-tile geometry is an I/O property.

### 3.10 Cache block

A unit selected by the engine for storage and reuse.

Cache-block geometry is a cache/storage policy.

### 3.11 Processing task

A future scheduler work unit.

A processing task may refer to a processing region, multiple resident
resources and execution state.

R0.3 does not define that scheduler.

## 4. Dependency model

For a request-bounded spatial dependency:

```text
output request
      |
      v
operation dependency
      |
      v
mathematical required input
      |
      +----> valid input region
      |
      `----> context deficit
```

These concepts remain distinct:

```text
operation dependency
        !=
valid image intersection
        !=
border policy
```

Clipping a dependency to the image extent is therefore not itself a border
policy.

How missing context is interpreted belongs to the operation contract or an
explicit later policy.

## 5. Spatial dependency and execution strategy

R0.3 must not equate spatial dependency reach with memory residency or execution
strategy.

A dependency describes which logical input pixels can affect requested output.

It does not by itself determine:

- whether all required pixels must be resident simultaneously;
- whether execution is one-pass or multi-pass;
- whether an incremental aggregate is sufficient;
- whether intermediate state can be bounded;
- whether complete materialization is required.

Streamability is therefore treated as a separate execution property. R0.3 must
establish whether an operation or pipeline can satisfy its semantic dependencies
without simultaneously materializing complete logical inputs or intermediates;
it must not infer that property solely from spatial dependency reach.

### 5.1 Request-bounded spatial dependency

A finite output request produces required input geometry derived from that
request and the operation parameters without requiring the complete logical
input extent.

Identity and local neighbourhood operations are representative examples.

This is the primary case investigated by the initial region and later halo
experiments.

### 5.2 Full-extent spatial dependency

Producing requested output semantically depends on the complete logical input
extent.

This fact must be visible before execution.

However, full-extent dependency does not by itself imply simultaneous
whole-image residency.

For example, some full-extent computations may be implemented through bounded
streaming reductions, multiple passes or other incremental algorithms.

Whether a particular operation requires full materialization is therefore a
separate execution/property question that later R0.3 research must make
explicit rather than infer from dependency reach alone.

## 6. Central correctness invariant

The central R0.3 invariant is decomposition independence.

For operation `F`, logical input `I`, output request `R`, and any legal
decomposition of `R`:

```text
F(I)[R]
```

must equal the reassembled result of processing the decomposed output regions
with all required input context available.

For exact operations, equality must be exact.

For future numerically approximate operations, any accepted tolerance must be
part of the operation contract rather than a property of streaming.

Processing boundaries must not create image seams.

## 7. R0.3a scope

The first research slice is:

```text
R0.3a
Region dependency algebra + identity streamed equivalence
```

Its purpose is to establish geometric semantics before adding cache or
scheduler complexity.

Included:

```text
overflow-safe region algebra
dependency representation
logical-to-resident materialization
output decomposition
identity whole/decomposed equivalence
basic residency instrumentation
```

Excluded:

```text
stable production pipeline API
production cache
worker pools
parallel scheduling
work stealing
priority
cancellation
network I/O
GDAL integration
XYZ / TMS / WMTS / WMS
manual SIMD
advanced image processing
```

## 8. R0.3a region algebra

Research helpers must be overflow-safe.

At minimum investigate:

- representability;
- absolute containment;
- intersection;
- translation;
- request-bounded dependency derivation and expansion;
- clipping to logical extent;
- context deficit;
- partition validation.

Existing production `Region2D` must not gain methods merely because they make
the experiment convenient.

Promotion requires a concrete production consumer and a separately reviewed
semantic contract.

## 9. Empty regions

Empty regions are valid geometry.

Research code must distinguish:

```text
valid empty result
```

from:

```text
invalid or unrepresentable geometry
```

`Region2D.init` must not serve as an ambiguous failure sentinel where that same
value may also denote a valid empty region.

The semantics of empty intersection and empty decomposition results must be
defined explicitly before any corresponding helper is promoted.

## 10. Overflow requirements

Unchecked arithmetic such as:

```text
x + width
x - halo
x + width + halo
```

must not be used when overflow or underflow is possible.

Tests must cover geometry near both:

```text
0
size_t.max
```

including:

- zero expansion;
- expansion larger than the request;
- requests touching every image edge;
- complete-extent requests;
- empty requests;
- maximum representable origins and extents;
- unrepresentable translated extents.

Invalid geometry must be rejected before it can influence allocation or pointer
arithmetic.

## 11. Identity streamed-equivalence experiment

The first executable operation is identity:

```text
output = input
```

Identity has:

```text
required input == requested output
```

and therefore isolates region, decomposition and materialization semantics from
neighbourhood processing.

Compare at minimum:

- one whole output request;
- horizontal strips;
- vertical strips;
- regular rectangular tiles;
- irregular rectangular partitions;
- single-pixel regions.

The reassembled output must be byte-identical to the reference output.

For R0.3a, a legal decomposition of output request `R` must satisfy at least:

- every non-empty member lies completely inside `R`;
- non-empty members are pairwise disjoint;
- the union of the members is exactly `R`;
- no pixel in `R` is omitted;
- no pixel outside `R` is produced.

The initial identity experiment should deliberately use one simple sample type
and plane, preferably single-plane `ubyte`, so that decomposition and
coordinate semantics are tested without unrelated format complexity.

## 12. Non-zero logical origins

At least one principal experiment must use a requested region whose logical
origin is not `(0, 0)`.

Example:

```text
logical extent:
    width  = 8192
    height = 6144

output request:
    x      = 1733
    y      = 911
    width  = 1021
    height = 769
```

A decomposed logical request may still be materialized into resident storage
whose corresponding `RasterView.region` begins at:

```text
Region2D(0, 0, taskWidth, taskHeight)
```

The experiment must therefore prove that global placement is not accidentally
derived from resident descriptor coordinates.

## 13. Research source

R0.3a does not require a real imagery backend.

A deterministic in-memory or procedural source is sufficient.

It must support arbitrary valid logical regions rather than only source-native
tile coordinates.

Pixel values must depend deterministically on their logical/global coordinates,
not merely on coordinates local to each materialized region.

This is essential: if every materialized region accidentally restarted its
content pattern at local `(0, 0)`, a poorly designed identity test could still
pass while global placement was wrong.

The test pattern should therefore make requests at different logical locations
observably different while remaining exactly reproducible.

The source should record enough information to measure or verify:

- requested logical regions;
- materialization count;
- logical pixel count;
- resident byte count;
- peak resident bytes where practical.

This instrumentation is experimental and does not define a production cache or
source API.

## 14. Partial-residency evidence

At least one test must demonstrate:

```text
logical image size >> maximum resident processing region
```

without materializing the complete logical image.

The reassembled identity result must remain correct.

This provides direct evidence that logical image dimensions are independent of
the resident raster working set.

## 15. R0.3a correctness gates

R0.3a is complete only when the experiments demonstrate all of the following.

### Decomposition equivalence

All tested legal decompositions reproduce the reference output exactly.

### Coordinate-space separation

No experiment requires global coordinates inside `RasterView`.

### Bounded residency

Decomposed execution does not require complete logical-image residency.

### Overflow safety

Region operations reject invalid or unrepresentable geometry rather than
wrapping coordinates or extents.

### Empty-region semantics

Valid empty results remain distinguishable from failure.

### Tile independence

Identity processing does not depend on provider-tile or cache-block geometry.

## 16. Later R0.3 slices

After R0.3a succeeds, later research may proceed approximately as:

```text
R0.3b  neighbourhood / halo equivalence
R0.3c  dependency composition
R0.3d  provider/cache misalignment
R0.3e  full-extent dependency and materialization semantics
R0.3f  working-set accounting
```

The split may change if experimental evidence justifies a better sequence.

## 17. R0.3b preview

The first neighbourhood experiment should use a deliberately simple exact
kernel, for example a 3 x 3 integer operation.

It should compare whole and decomposed execution across arbitrary processing
boundaries.

The intended invariant is:

```text
sufficient context
    -> identical output, no seam
```

while missing context must result in either:

```text
explicitly defined border behaviour
```

or:

```text
a detectable unsatisfied dependency
```

It must not silently produce a task-boundary-dependent result.

## 18. Questions deliberately left open

R0.3 does not yet freeze answers to:

- Which type owns `LogicalImage` identity?
- Does a request include resolution or pyramid level?
- How is source identity represented?
- How are multi-input dependencies represented?
- What exact type represents request-bounded versus full-extent dependency?
- What exact type represents context deficit?
- How is border policy represented?
- How is resident coverage mapped to multiple `RasterLease`s?
- When should multiple source/cache blocks be assembled into one resident
  raster?
- How accurate can pre-execution working-set estimation become?

These questions require evidence from later experiments.

## 19. Promotion rule

No experimental type becomes public merely because it is convenient.

Promotion into `source/imagery/` requires:

1. a concrete consumer;
2. stable semantics supported by R0.3 evidence;
3. compatibility with the raster coordinate model;
4. explicit ownership/lifetime review where relevant;
5. compiler-floor verification;
6. public-surface review.

Until then, R0.3 helpers and types remain disposable research code.

## 20. Current status and immediate next experiment

R0.3a has completed its initial region/streaming correctness sequence.

E3.1 established the overflow-safe region, dependency-expansion and
decomposition-validation foundations.

E3.2 then demonstrated identity streamed equivalence across:

- whole-request execution;
- horizontal strips;
- vertical strips;
- regular rectangular tiles;
- manually irregular rectangles;
- one-pixel tasks on a small fixture;
- a logical image much larger than any resident processing task.

The experiments preserve logical/global placement outside resident
`RasterView.region`, which remains rebased to `(0, 0)` for each materialized
task.

Resident-raster accounting is separated from output/reference oracle state,
decomposition coverage-oracle payload and decomposition metadata.

No production API change was required merely to support E3.2.

DMD and LDC both pass the completed experiment suite.

The next implementation slice is:

```text
R0.3b — neighbourhood / halo equivalence
```

The first neighbourhood experiment should use a deliberately simple exact
kernel, such as a 3 x 3 integer operation, and prove that sufficient context
produces byte-identical whole and decomposed output with no task-boundary seam.
