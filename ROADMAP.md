# raster-d Roadmap

## Current implementation checkpoint — 2026-09-24

The generic raster foundation is now implemented far enough that the former
`imagery-d` repository has passed the extraction gate defined by ADR 0003.

The technical package/namespace pivot is complete:

```text
DUB package:       raster-d
public namespace: raster / raster.*
production source: source/raster/**
```

The current production foundation includes:

- retained raster-resource ownership;
- validated multi-plane raster backing;
- signed row and sample strides;
- zero-copy resident ROIs;
- read-only `RasterView!T`;
- lease-bound `WritableRasterView!T`;
- retained read/write provenance and writable-backing certification;
- internal execution-layout classification and Mir adapters;
- checked affine alias/overlap analysis;
- strict row-major `float -> double` reduction;
- checked same-type raster-plane copy;
- exact `ubyte -> float` raster-plane conversion.

The E5.4 public-operation sequence is complete. Internal execution,
certification, physical-range, affine-relation and checked-wide-arithmetic
machinery remains non-public.

R0.3a and R0.3b are also complete as research evidence. They demonstrate
decomposition-independent identity processing and neighbourhood/halo processing
with bounded raster residency without forcing premature promotion of the
research types into production.

The repository-pivot sequence is complete:

```text
P1  package / namespace / replay migration       complete
P2  repository documentation                    complete
P3  full technical migration gate               complete
P4  PR and merge under existing GitHub identity complete
P5  GitHub/local repository rename to raster-d  complete
P6  shared workspace-context migration          complete
P7  separate higher-level imagery-d bootstrap   complete
```

P7 closes only the repository/bootstrap handoff. Development milestones of the
separate `imagery-d` project remain independent of the `raster-d` roadmap.

## R0 — Constraints, Research and Architecture

The first phase determines the architecture before the core API is stabilized.

### R0.0 — Operational constraints

Define measurable limits and workload classes for:

- RAM;
- cache memory;
- temporary memory;
- dataset dimensions;
- allocations;
- I/O;
- CPU throughput;
- interactive latency;
- concurrency;
- cancellation;
- numerical correctness;
- portability.

Establish benchmark metrics before optimising implementation.

Deliverable:

    raster-d-research: docs/research/constraints.md

### R0.1 — Reference architecture research

Study architecture and implementation strategies used by:

- libvips;
- Halide;
- GDAL;
- Orfeo ToolBox;
- OpenCV;
- GEGL;
- Mir / `mir.ndslice`.

Focus on:

- views and strides;
- ownership;
- regions/windows;
- streaming;
- requested-region propagation;
- caching;
- tiling;
- SIMD;
- scheduling;
- large-image processing.

Deliverable:

    raster-d-research: docs/research/reference-engines.md

### R0.2 — Memory-model research

Compare experimentally:

- custom pointer/shape/stride views;
- `mir.ndslice`;
- packed pixel types;
- planar layout;
- interleaved layout;
- HWC and CHW;
- aligned allocation;
- arbitrary-stride views;
- externally owned buffers.

Prototype:

- raster;
- ROI;
- channel view;
- non-contiguous view;
- expanded region/halo.

Deliverable:

    raster-d-research: docs/research/memory-model.md

### R0.3 — Region, dependency and streaming model

**Status (2026-09-22): complete as research evidence.**

R0.3 established and validated:

- logical/global versus resident-coordinate separation;
- checked region/dependency algebra;
- decomposition validation;
- horizontal, vertical, regular-tile and irregular decompositions;
- dedicated one-pixel-task decomposition;
- decomposition-independent identity execution;
- explicit halo/context dependency derivation;
- whole/decomposed neighbourhood equivalence;
- bounded sequential raster residency;
- huge logical extents without whole-image allocation;
- separate raster/oracle/metadata accounting;
- DMD and LDC equivalence.

The extraction gate following R0.3 is resolved by ADR 0003: the generic raster
domain is independently useful and the existing repository lineage becomes
`raster-d`.

R0.3 types remain research types until a separate production-API promotion
decision is justified.

### R0.4 — Execution and scheduling research

Research:

- synchronous baseline execution;
- region-level tasks;
- worker pools;
- pipeline parallelism;
- work stealing;
- I/O/decode/compute separation;
- priority;
- cancellation;
- prefetch.

Deliverable:

    raster-d-research: docs/research/execution.md

### R0.5 — CPU and SIMD research

Use deliberately simple kernels:

- copy;
- fill;
- plane extraction;
- numeric point conversion;
- LUT-style scalar transforms;
- min/max reduction;
- histogram/reduction workloads;
- small generic neighbourhood kernels.

Compare:

- DMD;
- LDC;
- generic strided loops;
- contiguous specialised loops;
- LLVM auto-vectorisation;
- explicit SIMD where justified;
- single-threaded and parallel execution.

Deliverable:

    raster-d-research: docs/research/cpu-performance.md

### R0.6 — Raster-source and adapter boundary research

**Status (2026-09-30): complete as research evidence.**

Research the boundary between `raster-d` and external raster producers.

Reference systems may include:

- GDAL;
- local codecs;
- GeoTIFF / COG readers;
- XYZ/TMS/WMTS/WMS consumers;
- procedural sources;
- scientific-grid or elevation sources.

The goal is not to make every source backend a `raster-d` dependency. The goal
is to determine the smallest generic contract needed to import, retain,
materialize or stream raster data while keeping provider- and image-specific
policy outside the core library.

Deliverable:

    raster-d-research: docs/research/io-sources.md

### R0.7 — Representative raster workload corpus

Define reproducible workloads that exercise generic raster behaviour:

- contiguous and non-contiguous layouts;
- planar and interleaved storage;
- signed strides;
- large logical extents;
- region boundaries;
- neighbourhood halos;
- streaming and bounded residency;
- multiple sample types;
- externally supplied memory.

Synthetic fixtures should be preferred when they isolate a semantic or
performance property.

Real imagery may be retained as consumer-derived stress-test input, but the
full aerial/satellite imagery corpus and imagery-specific provenance policy
belong to the separate `imagery-d` project.

### R0.8 — Prototype bake-off

Implement disposable competing prototypes.

At minimum compare:

- `mir.ndslice` versus custom views;
- planar versus interleaved layouts;
- fixed tiles versus arbitrary regions;
- generic versus contiguous fast paths;
- whole-image versus streamed execution;
- sequential versus parallel processing.

Production compatibility is not required.

### R0.9 — Architecture synthesis

Consolidate the research into:

- terminology;
- ownership model;
- raster/view representation;
- region/window API;
- dependency/halo model;
- cache model;
- source model;
- execution model;
- CPU fast-path strategy;
- GPU boundary.

Update `DESIGN.md` and record major decisions as ADRs.

### R0 exit criteria

R0 is complete when:

1. reference engines have been studied;
2. operational constraints are documented;
3. representative raster workloads are reproducibly obtainable;
4. memory-layout alternatives have been benchmarked;
5. Region/Tile/Halo semantics are defined;
6. streaming correctness rules are defined;
7. CPU performance behaviour has been measured;
8. `mir.ndslice` has been evaluated experimentally;
9. major architecture choices have ADRs.

---

## M0 — Core Raster and View Model

Implement the architecture selected during R0.

Initial focus:

- storage ownership;
- raster shape;
- strides;
- views;
- regions/windows;
- pixel/band representation;
- correctness tests.

---

## M1 — Regions, Streaming and Cache

**Status (2026-09-30): complete.**

Implemented and qualified:

- requested regions;
- halo/context propagation;
- caller-described reusable retained/source blocks;
- bounded request/working-set residency accounting;
- separately bounded retained-store memory;
- neighbouring multi-block source access;
- sequential streamed processing qualification;
- whole-request/streamed equivalence tests.

M1 deliberately does **not** define engine-selected cache-block geometry,
automatic replacement/eviction, a unified total-process memory manager,
scheduler ownership, worker pools or public cache/source abstractions. Those
are deferred policy/execution concerns, not incomplete M1 requirements.

The completion audit closes M1 against the contracts accepted by ADR 0004
through ADR 0009 and the M1.7 production-stack equivalence qualification.

### M1.1 — Request/dependency geometry

Status: complete.

ADR 0004 defines the first production promotion from R0.3:

- Region2D remains the shared public rectangular geometry value;
- request-bounded dependency margins and context deficit are production
  semantics;
- dependency-specific types and helpers remain package-internal initially;
- logical/global dependency geometry remains separate from resident RasterView
  geometry;
- border policy remains outside dependency derivation.

The package-internal checked dependency module and its DMD/LDC/public-surface
coverage are implemented.

### M1.2 — Request-to-resident materialization planning

Status: complete.

ADR 0005 defines the metadata-only bridge from logical dependency geometry to
resident descriptor geometry.

The package-internal planner:

- consumes M1.1 dependency derivation;
- retains logical valid-input and context-deficit information;
- rebases resident input geometry to descriptor origin (0, 0);
- derives the output ROI inside resident storage from logical region
  differences;
- keeps large logical coordinates out of resident pointer geometry;
- performs no allocation and introduces no source, cache, provider or scheduler
  API.

M1.3 uses this plan as the stable input to the concrete synchronous
materialization/source boundary selected by the completed R0.6 source-adapter
research.

### M1.3 — Synchronous caller-owned materialization

Status: complete.

ADR 0006 promotes the completed R0.6 source-boundary research into the first
production materialization orchestration slice.

The package-internal synchronous helper:

- combines RequestMaterializationPlan with a compile-time/callable source and
  caller-owned WritableRasterView destination;
- forwards exactly the planned logical valid-input region;
- requires the resident destination region to match the planned resident input;
- treats empty valid input as successful without invoking the source;
- keeps context deficit separate from border policy;
- distinguishes destination mismatch from source failure;
- performs no allocation and introduces no public source interface.

Provider tiles, cache blocks, scheduling, async/cancellation, resampling and
public source metadata remain outside this slice.

### M1.4 — Bounded residency accounting

Status: complete.

The completed cache-boundary research in `raster-d-research` establishes that
cache retention and total/request residency are separate accounting domains.

The first production promotion is therefore deliberately narrower than a
cache.

The implemented package-internal contract:

- counts physical retained raster-resource payload from the backing's
  authoritative ResourceEntry byte lengths;
- counts shared/interleaved physical allocations once regardless of logical
  plane count;
- provides a residency byte budget that admits and releases working-set
  obligations without overflow or underflow;
- rejects over-budget working sets explicitly without mutating accounting;
- treats zero-byte work as valid and budget-neutral;
- protects both root and direct-internal surfaces with compile-negative probes.

Cache identity, block geometry, replacement policy, provider identity,
concurrency and scheduling remain outside this slice.

Research provenance:

    raster-d-research main ae4dec5d9de4f8d8831d6e50954a851743fcaa4c
    Issue #3 / PR #4

### M1.5 — Bounded generic retained store

Status: complete.

The completed cache-identity research establishes caller-owned semantic identity
as the generic reuse boundary.

The implemented production retained-store slice:

- is generic over caller-owned Key;
- stores typed RasterLease values;
- specializes hash/equality at compile time;
- has fixed entry capacity;
- has a separate store-retained physical-byte limit;
- rejects duplicate/full/invalid/over-budget insertion explicitly;
- leaves rejected insertion state unchanged;
- returns independently retained lease copies on lookup;
- supports explicit clear of store-owned entries and accounting;
- protects root and direct-internal surfaces with compile-negative probes;
- defines no automatic eviction or replacement policy.

The M1.4 ResidencyBudget remains a separate request/working-set admission
contract and is not repurposed as a retained-store cache budget.

Provider/source/schema identity types, cache-block geometry, concurrency and
scheduling remain outside this slice.

Research provenance:

    raster-d-research main 3371e2f6474d5f3adee49d1741392598b30e81c9
    Issue #5 / PR #6

### M1.6 — Multi-block dependency resolution

Status: complete.

The next production bridge resolves one logical dependency from multiple
caller-described retained/source blocks.

The implemented package-internal resolver:

- accepts caller-owned block keys and logical block regions;
- validates exact, pairwise-disjoint coverage before any source call or write;
- performs retained-store lookup first;
- materializes misses through a caller-supplied retained-source capability;
- assembles only block/request intersections into one rebased caller-owned
  resident destination;
- supports multi-plane retained values and huge logical origins;
- treats retained-store insertion rejection as non-fatal to the current request;
- records hit/miss/store-retention control-flow statistics;
- leaves M1.4 request-residency admission caller/orchestrator-owned;
- protects root and direct-internal surfaces with compile-negative probes;
- introduces no block-size or block-selection policy.

Provider geometry, cache replacement, scheduling, border policy and public
source/cache APIs remain outside this slice.

Research provenance:

    R0.3b / E3.3 neighbourhood-halo equivalence
    cache-boundary E7.3 / E7.4
    cache-identity E8.1-E8.5

### M1.7 — Whole-vs-streamed production-stack equivalence

Status: complete.

This is a qualification slice rather than a new execution abstraction.

The test harness drives the existing M1.1-M1.6 production machinery through:

- whole-request execution;
- horizontal strips;
- vertical strips;
- regular rectangular tasks;
- deliberately irregular/T-junction tasks;
- one-pixel tasks on a small fixture.

Each task derives a one-pixel neighbourhood dependency, admits bounded
task-local residency through M1.4, assembles the resident dependency through
M1.6 using M1.5 retained reuse, executes an exact test-local 3 x 3 kernel, and
reassembles only the requested output.

The completed qualification proves exact byte equality between whole and
streamed output while preserving:

- logical/resident coordinate separation;
- explicit ContextDeficit at logical-image boundaries;
- caller-owned block geometry;
- separate request-residency and retained-store accounting;
- no production ProcessingTask/Decomposition type;
- no scheduler, worker pool or border policy.

The qualification also covers non-zero and near-size_t.max logical origins,
retained hit/miss reuse, task-local residency lower than whole-request
residency for streamed decompositions, explicit logical-edge ContextDeficit,
and empty-output zero-work planning on both DMD and LDC.

Research provenance:

    R0.3b / E3.3 exact neighbourhood / halo equivalence

---

## M2 — Fundamental Processing Primitives

Status: in progress.

M2 starts from the completed E5.4 public-operation sequence rather than
reimplementing already-qualified primitives.

Already present and counted toward M2:

- checked same-type raster-plane copy via `tryCopyRasterPlane()`;
- exact `ubyte -> float` conversion via
  `tryConvertUbyteToFloatPlane()`;
- strict row-major `float -> double` sum via
  `trySumFloatToDouble()`.

Still required to complete the milestone:

- fill;
- point transforms;
- basic neighbourhood kernels.

The M1.7 exact 3 x 3 neighbourhood kernel remains test-local qualification
machinery and is not counted as a production M2 kernel.

M2 adds only semantic processing primitives. Compiler/source-form tuning,
SIMD, multithreading and other performance work remain M3 unless a minimal
correctness implementation requires otherwise.

### M2.1 — Semantic raster-plane fill

Status: implementation in progress.

The first missing primitive is an exact same-type fill over one selected
writable raster plane.

The intended public contract:

- is generic over every existing `isRasterSampleType!T`;
- writes one exact `T` value without conversion, clamping or image semantics;
- supports every validated writable resident layout;
- permits valid non-injective mappings because repeated writes of the same
  exact value are semantically idempotent;
- treats a valid empty plane as a successful no-op;
- fails only for an invalid destination plane index;
- allocates nothing and retains no operand;
- introduces no scheduler, parallelism or public execution-layout API.

R0.5 fill measurements are performance evidence only. They do not select a
production SIMD or compiler-specific implementation in M2.1.

### M2.2 — Point transforms

Status: not started.

Promote only a narrowly defined generic point-transform semantic after
reviewing the existing R0.5 affine-transform evidence and the numerical/public
API contract separately.

### M2.3 — Basic neighbourhood kernels

Status: not started.

Promote a minimal reusable neighbourhood operation only after M2.2. Reuse the
M1 dependency/halo/streaming contracts; do not promote the M1.7 test oracle or
invent border policy implicitly.

---

## M3 — CPU Performance

Optimise proven hot paths using:

- LDC/LLVM;
- SIMD-friendly loops;
- layout specialisation;
- multithreading;
- reusable workspaces.

---

## Higher-level consumer — imagery-d

Image-domain work no longer defines later milestones of `raster-d`.

The separate higher-level `imagery-d` project now exists. Its production
package/API, when admitted by that project, is intended to depend on `raster-d`
and own work such as:

### Image and pixel semantics

- image/pixel-format models;
- colour semantics;
- alpha/mask interpretation;
- display-oriented transforms.

### Image I/O and imagery sources

- image codecs;
- GeoTIFF/COG imagery policy;
- XYZ/TMS/WMTS/WMS imagery integration;
- imagery-specific caching;
- image pyramids and mosaics;
- acquisition/provenance metadata.

Generic GDAL/raster adapters may instead live in focused integration libraries
when that boundary proves independently useful.

### Image-processing research

- resampling;
- sharpening and blur;
- local contrast;
- colour processing;
- quality metrics;
- radiometric normalization;
- shadow and illumination analysis;
- feature extraction;
- segmentation;
- ML-assisted interpretation.

### Relationship to raster-d

Higher-level image requirements may motivate additions to `raster-d` only when
they reveal a coherent, reusable raster-domain need.

They must not cause image semantics, provider policy or application-specific
behaviour to leak into the generic raster API.
