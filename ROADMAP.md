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

    docs/research/constraints.md

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

    docs/research/reference-engines.md

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

    docs/research/memory-model.md

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

    docs/research/execution.md

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

    docs/research/cpu-performance.md

### R0.6 — Raster-source and adapter boundary research

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

    docs/research/io-sources.md

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

Implement:

- requested regions;
- halo/context propagation;
- cache blocks;
- bounded memory;
- neighbouring source access;
- streamed processing;
- whole-image/streamed equivalence tests.

---

## M2 — Fundamental Processing Primitives

Implement only the operations required to validate the engine:

- copy/fill;
- conversions;
- point transforms;
- simple reductions;
- basic neighbourhood kernels.

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
