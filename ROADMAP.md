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

Status: complete.

M2 starts from the completed E5.4 public-operation sequence rather than
reimplementing already-qualified primitives.

Implemented and counted toward M2:

- checked same-type raster-plane copy via `tryCopyRasterPlane()`;
- exact `ubyte -> float` conversion via
  `tryConvertUbyteToFloatPlane()`;
- strict row-major `float -> double` sum via
  `trySumFloatToDouble()`;
- exact same-type fill via `tryFillRasterPlane()`;
- generic compile-time point transforms via
  `tryTransformRasterPlane!transform()`;
- generic fixed radius-one neighbourhood kernels via
  `tryApplyRasterNeighbourhood3x3!kernel()`.

The M1.7 exact 3 x 3 neighbourhood kernel remains test-local qualification
machinery and is not counted as a production M2 kernel.

M2 adds only semantic processing primitives. Compiler/source-form tuning,
SIMD, multithreading and other performance work remain M3 unless a minimal
correctness implementation requires otherwise.

### M2.1 — Semantic raster-plane fill

Status: complete.

The first missing primitive is an exact same-type fill over one selected
writable raster plane.

The implemented public contract:

- is generic over every existing `isRasterSampleType!T`;
- writes one exact `T` value without conversion, clamping or image semantics;
- supports contiguous, padded, interleaved and signed-stride writable layouts;
- permits valid non-injective mappings because repeated writes of the same
  exact value are semantically idempotent;
- supports POD struct samples in addition to numeric samples;
- treats a valid empty plane as a successful no-op;
- fails only for an invalid destination plane index;
- allocates nothing and retains no operand;
- exposes only `tryFillRasterPlane()`; execution details remain internal;
- is qualified through root import and direct-internal rejection probes on DMD
  and LDC;
- introduces no scheduler, parallelism or public execution-layout API.

R0.5 fill measurements are performance evidence only. They do not select a
production SIMD or compiler-specific implementation in M2.1.

### M2.2 — Point transforms

Status: complete.

Completed M2.2 research selected a same-type compile-time point transform rather
than a built-in affine numeric operator.

The implemented production contract:

- exposes `RasterTransformError` and
  `tryTransformRasterPlane!transform()`;
- accepts a compile-time `alias transform` implementing `T -> T`;
- requires the transform to be usable as `@safe pure nothrow @nogc`;
- is generic over existing `isRasterSampleType!T`, including POD samples;
- operates out-of-place from one RasterView plane to one WritableRasterView
  plane;
- requires equal logical shape and an injective destination;
- rejects any physical source/destination sample-byte overlap before writing;
- treats matching empty planes as success without invoking the transform;
- performs no implicit conversion, clamping, saturation, FMA selection or
  image-domain interpretation;
- supports every validated signed affine resident layout;
- uses the existing exact affine relation classifier plus an allocation-free
  exact fallback for defensive relation-arithmetic failure;
- keeps execution specialization and alias-relation machinery internal;
- is qualified through root-import, named-argument and invalid-transform
  compile probes on both required compilers.

Exact in-place transforms, runtime-selected transforms, cross-type transforms
and convenience affine/LUT APIs remain deferred.

Research provenance:

    raster-d-research main bf150645c0ed6e91d43e0fbda94f7a7bf80e2a1b
    Issue #8 / PR #9
    docs/research/m2-point-transform-contract.md

### M2.3 — Basic neighbourhood kernels

Status: complete.

Completed M2.3 research selects one fixed radius-one / 3 x 3 same-type
neighbourhood primitive.

The implemented production contract:

- exposes `RasterNeighbourhood3x3Error` and
  `tryApplyRasterNeighbourhood3x3!kernel()`;
- consumes an already-materialized RasterView source;
- uses an explicit resident-relative sourceOutputRegion;
- requires one resident source sample of halo on every side for non-empty
  output;
- exposes no border policy and does not interpret ContextDeficit;
- invokes a compile-time kernel over a row-major nine-sample snapshot;
- requires the kernel to be usable as @safe pure nothrow @nogc;
- requires destination shape to equal sourceOutputRegion shape;
- requires an injective destination;
- rejects exact physical overlap between the expanded required-source rectangle
  and destination before writing;
- supports validated signed affine source/destination layouts;
- treats matching empty output as success without kernel invocation;
- preserves whole-versus-task-local-halo decomposition independence;
- is qualified through root-import, named-argument and invalid-kernel compile
  probes on both required compilers.

M1.1/M1.2 remain responsible for logical dependency planning. The M1.7
weighted kernel remains test-only evidence and is not promoted as a built-in
operation.

The production slice also generalizes the package-internal exact same-type
affine overlap relation to differently shaped source and target rectangles while
preserving the existing equal-shape wrapper for copy/point-transform consumers.

Research provenance:

    raster-d-research main e4e9352c2443c3fb9f27c94125b683f3e69ff1e7
    Issue #10 / PR #11
    docs/research/m2-neighbourhood-contract.md

---

## M3 — CPU Performance

Status: complete for the qualified x86-64 baseline.

Optimise proven hot paths using measured, replaceable internal execution forms
without changing public raster semantics.

### M3.1 — Canonical 3 x 3 neighbourhood fast path

Status: complete.

Completed research selects the current public M2.3 neighbourhood operation as
the first Production hot-path optimization.

The implemented execution strategy:

- preserves the complete public
  `tryApplyRasterNeighbourhood3x3!kernel()` API and error contract;
- keeps all existing structural validation before execution;
- dispatches sample-stride-one source/destination layouts to a package-internal
  check-free Canonical executor;
- retains the existing generic semantic path for Universal/sample-strided and
  otherwise unqualified layouts;
- keeps positive and negative Canonical row strides semantically supported;
- uses a centralized compiler capability for one qualified specialization:
  `float`, negative source row stride, LDC with frontend 2.111;
- keeps DMD and later LDC frontend generations on the ordinary Canonical
  executor until separate evidence justifies another source form;
- introduces no public compiler/layout switch, handwritten SIMD or hidden
  parallelism.

Stable local XPS evidence for 2048 x 512 shows roughly:

- DMD Canonical: 3.27-3.64x faster than the former public semantic loop;
- LDC Canonical: 2.10-2.46x faster;
- LDC negative-row out-of-line row kernel: a further 12-14% over integrated
  Canonical;
- DMD negative-row out-of-line form: neutral to materially worse.

Final LDC 1.41 / LLVM 19.1.7 code generation confirms that the integrated
versioning guard includes signed outer row stride and selects scalar execution
for negative rows, while the row-local boundary preserves the eight-float AVX2
loop.

Research provenance:

    raster-d-research main 5ff4f488919a3786ae0793977027e4b19081babf
    Issue #12 / PR #13
    docs/research/m3-production-hotpath-audit.md

Later M3 slices may address fill, point transform, strict reduction, additional
compiler generations, AArch64 and caller-owned parallel execution only after
their own evidence.

---

## M3.2a — Checked affine bounds prefilter

Implemented and qualified for same-type point transform and 3x3 neighbourhood
in Issue #52, with the semantic decision recorded in ADR 0010.

One package-internal wrapper proves disjointness from checked half-open physical
bounds before invoking the existing exact relation classifier. Overlap and
unrepresentable bounds preserve the exact classifier and defensive fallback.
No public API or executor specialization is introduced.

Research Gate 4 qualifies the consumer benefit on XPS i7-9750H with DMD 2.111
and LDC 1.41; its pinned source and raw logs are recorded in BENCHMARK.md.
Production adds an independent bounded oracle, integer-limit fixtures, sparse
shared-backing regressions and external visibility probes to Fast/Release CI.
Copy, cross-type relations and AArch64 performance remain separately qualified
future work. The separate point-transform executor qualification follows in M3.2b.

---

## M3.2b — Generic Canonical point-transform executor

Completed in Issue #54 / PR #55, following research Issue #14 and its
2026-10-01 XPS qualification. ADR 0011 selects one generic pointer executor
for matching validated sample strides of one, including signed padded rows.
The existing Universal traversal and all public validation/error semantics stay
in force. No compiler-specific dispatch, SIMD or threading is introduced.

Production coverage adds 48 public float/ubyte/POD layout cases, bitwise special
float identity checks, a no-access dispatch-decline test and actual-source trust
and external visibility probes in Fast/Release CI. BENCHMARK.md records measured
scope and variance; AArch64 performance remains unqualified.

---

## M3.3 — Generic Canonical fill executor

Implemented for review in Issue #56 after Research Issue #17's 2026-10-01 XPS
qualification. ADR 0012 selects one generic safe row-slice assignment executor
for sample stride one. Trust is limited to validated row/slice construction.
Legal repeated and overlapping rows remain supported without an injectivity
check; other Universal layouts retain their original logical traversal.

Production adds 30 independent float/ubyte/POD layout cases, 15 bitwise special
float fill cases and external visibility/actual-source trust controls in
Fast/Release CI. BENCHMARK.md records the consistent DMD ubyte benefit, measured
LDC tradeoffs and substantial variance. No compiler specialization, manual SIMD,
threading or AArch64 performance claim is introduced.

---

## M3.4 — Strict row-major float-to-double reduction execution

Status: complete.

The public strict reduction keeps one double accumulator and exact logical
row-major addition order.

Controlled M3.4 research and reference-XPS confirmation selected one narrow
compiler-specific execution form:

- DMD x86-64 Canonical layouts use a private pointer-based row executor;
- the existing contiguous Mir path is unchanged;
- Universal/non-Canonical traversal is unchanged;
- LDC and other compilers are unchanged;
- no reassociation, fixed-lane SIMD, fast-math, contraction or threading is
  introduced.

Six fixed-binary CPU0-pinned DMD processes on the i7-9750H reference XPS
confirmed representative public/pointer medians of roughly 1.128x to 1.131x on
large padded, negative-row and repeated-row Canonical cases, while contiguous
and LDC controls remained near 1.00x.

The decision is recorded by ADR 0015 and Production PR #63.

Research provenance:

    raster-d-research Issue #21 / PR #43
    archive raster-m3-reduction-pointer-confirm-20261005-101445.tar.gz
    SHA256 46c778441788941e35483e6279a36c05f89b94730416bd1e6f7341b5a04f3b1

---

## M3.5 — Copy / exact conversion bounds and row execution

Status: complete.

ADR 0013 first selected checked same-/cross-type physical bounds before the
original exact relation/fallback plus approved unit-sample-stride row execution.
That production slice preserved the existing flat-copy memcpy, Universal
traversal and every public validation/error/no-write/empty contract.

The follow-up compiler qualification is now also complete.

### Copy

Same-type Copy retains the qualified ADR 0013 implementation:

- checked physical-bounds prefilter;
- original exact fallback when bounds overlap or are unrepresentable;
- slice assignment for approved unit-sample-stride rows;
- existing flat-copy memcpy;
- Universal traversal unchanged.

### Exact ubyte-to-float conversion

After the ADR 0013 validation/relation boundary:

- **DMD x86-64, width >=64, unit sample stride** uses the qualified exact SSE2
  unpack/widen/`CVTDQ2PS` row kernel with scalar tail;
- **DMD x86-64, width <64** retains the ordinary scalar row conversion;
- **LDC x86-64, negative source row stride, width >=64** uses the qualified
  safe `pragma(inline, false)` row-local optimizer boundary;
- other LDC Canonical rows retain the ordinary row form;
- Universal/non-unit-sample-stride traversal remains unchanged.

The DMD SSE2 path was refreshed against the already optimized DMD pointer
Production implementation rather than against an obsolete scalar baseline.
Six fixed-binary CPU0-pinned reference-XPS processes showed pooled
Production/SSE2 medians of about 1.695x short and 1.677x long for active DMD
cases, while inactive DMD and all LDC controls remained near 1.00x.

The LDC signed-source qualification isolates source-row direction as the
optimizer boundary: negative-source and negative-both cases gain materially
from width 64 upward, while positive-source, negative-target-only,
repeated-source, Universal and DMD controls stay near parity.

ADR 0014 records the final compiler-qualified conversion strategy.

Production sequence:

- PR #61 — checked bounds + approved Copy/conversion row execution;
- PR #62 — DMD bounded pointer conversion, later superseded for width >=64;
- PR #64 — LDC negative-source no-inline row boundary;
- PR #65 — exact DMD SSE2 conversion, superseding the pointer kernel for the
  active DMD width>=64 path.

Research provenance includes Issues #22, #39, #41, #44 and #46 and their
stacked qualification PRs.

No public compiler/layout switch, fast-math, reassociation, hidden threading or
scheduler policy is introduced.

---

### M3 completion boundary

The x86-64 M3 production baseline is complete for the currently exposed
fundamental operations:

- 3x3 neighbourhood;
- checked affine relation prefilter;
- generic point transform;
- fill;
- strict reduction;
- same-type Copy;
- exact ubyte-to-float conversion.

Remaining work is explicitly **not** an unfinished M3 requirement:

- AArch64/NEON performance qualification;
- later compiler/frontend generations where codegen differs;
- caller-owned parallel execution and scheduling research;
- GPU execution;
- higher-level image-domain kernels.

Those require their own measured research and must not be inferred from the
qualified x86-64 results.

---


## M5 — v0.2 Performance Qualification

Status: active.

M5 treats performance as a layered property of the supported v0.2 operation
families. It does not expose execution-layout or compiler choices through the
public API.

### M5.1 — Establish v0.2 benchmark families

Status: complete.

Issue #115 owns the benchmark coverage matrix.

The first M5.1 slice establishes:

- six representative processing families;
- an explicit distinction between public semantic latency, preflight,
  approved hot-executor, layout-specialization and numeric-kernel cost;
- a machine-readable family inventory;
- CI validation of that inventory;
- DMD/LDC release compile smoke for every retained v0.2 benchmark harness;
- a qualification metadata contract covering compiler, build flags, platform,
  workload, warm-up, samples/distribution, semantic preflight and baseline
  commit.

Final qualified family coverage:

- reduction: qualified;
- unary transform: qualified;
- fill/copy: qualified;
- binary transform/arithmetic: qualified;
- conversion: qualified;
- neighbourhood/convolution: qualified.

Issue #115 is closed. Retained reference-XPS evidence, DMD/LDC separation,
semantic preflight, public/hot layering and Fast-CI compile smoke are recorded
in BENCHMARK.md and docs/V0_2_M5_BENCHMARK_FAMILIES.md.

The M4.6 prepared-convolution isolation also creates an explicit M5 signal:
public `convolveInto` and the validation-free direct-fixed execution shape are
roughly an order of magnitude apart on both baseline compilers. M5 investigates
that as public/preflight/dispatch/execution cost, not as a prepared-state
benefit.

### M5.2 — Internal layout specialization framework

Status: complete.

Issue #116 evaluated whether the internal execution-layout model should grow
from the existing Universal/Canonical/Contiguous capability lattice into a
larger physical-layout taxonomy.

Decision:

- retain PlaneExecutionLayout2D and PlaneExecutionTraits as the shared storage
  capability classifier;
- do not introduce separate generic classes for padded rows, negative row
  stride, interleaved storage or general affine storage merely because those
  physical descriptions differ;
- keep signed row stride as a Canonical parameter whenever sample stride is one;
- keep arbitrary sample-strided/interleaved/general affine traversal under
  Universal until a concrete operation demonstrates a material benefit from a
  stronger capability;
- combine shared storage capabilities with operation-local facts such as
  alias/non-overlap proof, numeric semantics, compiler capability, kernel/shape,
  type pair and measured thresholds.

The original M5.1 generic 5x3 sample-strided/Canonical timing was later found
to have been collected under the release-only neighbourhood stride-
initialization bug fixed by PR #168. The nominal Canonical path had therefore
fallen through to Universal execution.

Post-#168 evidence initially showed a material generic-neighbourhood
sample-strided penalty. M5.2 therefore added one private operation-specific
signed-affine pointer/stride executor without expanding the shared layout enum.

Post-change reference-XPS evidence shows:

- DMD sample-strided/Canonical: 0.875674x;
- LDC sample-strided/Canonical: 6.217490x.

This is sufficient to close the structural/layout part of M5.2: the shared
Universal -> Canonical -> Contiguous capability model remains appropriate and
the expensive public-view sampling fallback has been removed. The remaining
LDC-only gap is retained for M5.3 code-generation analysis rather than encoded
as another global layout class.

The full decision and evidence mapping are recorded in
docs/V0_2_M5_LAYOUT_SPECIALIZATION.md.

### M5.3 — DMD/LDC code-generation audit

Status: active; neighbourhood root cause fixed and post-fix qualified.

Issue #117 owns compiler/code-generation investigation for the retained M5.1
signals. The centered 3x3 neighbourhood public/hot signal has been root-caused and
fixed. A release-only stride query had been placed inside assert(...), so the
query vanished from optimized builds and Canonical dispatch was disabled.

Post-fix public/hot reference-XPS ratios:

- DMD 2.111.0: 0.999172x;
- LDC 1.41.0: 0.968592x.

M5.3 should now proceed to the remaining compiler/code-generation signals.

The second M5.3 diagnostic is retained at `benchmark/v0_2_affine_codegen`.
It targets the LDC-only signed-affine 5x3 gap by separating runtime versus
compile-time sample strides and source-side versus destination-side stride
effects while retaining DMD/LDC disassembly.

The third M5.3 diagnostic is retained at
`benchmark/v0_2_affine_multiversion`. It tests whether a small runtime
dispatcher into template-static stride 2/3/4 executors recovers LDC codegen
while leaving the general signed-affine runtime executor as fallback.

The first M5.3 diagnostic is retained at
`benchmark/v0_2_neighbourhood_codegen`. It compares the production public path,
the approved hot executor, a benchmark-local noinline executor boundary, a
diagnostic preflight-plus-noinline path and preflight-only cost, while retaining
DMD/LDC disassembly.


The fifth M5.3 diagnostic is retained at
`benchmark/v0_2_reduction_codegen`. It decomposes the remaining mean/max/minMax
compiler split into public/semantic cost, runtime sample-stride induction and
Canonical static-stride execution while retaining exact reduction semantics and
DMD/LDC disassembly. No production optimization is selected until reference-XPS
evidence is retained and inspected.

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


The fourth M5.3 diagnostic is retained at
`benchmark/v0_2_convolution_codegen`. It decomposes the remaining DMD-only
fixed-convolution one-shot/direct-fixed gap into wrapper, neighbourhood
preflight, kernel source-form and executor/materialization components.
