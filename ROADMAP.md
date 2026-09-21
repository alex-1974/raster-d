# imagery-d Roadmap

## Current implementation checkpoint — 2026-09-20

The repository has progressed beyond the initial architecture-only stage while
the long-term milestone structure below remains valid.

The resident raster foundation now includes:

- retained raster-resource ownership;
- validated multi-plane raster backing;
- signed row and sample strides;
- zero-copy resident ROIs;
- read-only `RasterView!T`;
- public lease-bound `WritableRasterView!T`;
- retained read/write provenance and writable-backing certification;
- internal execution-layout classification and Mir adapters;
- checked affine alias/overlap analysis;
- strict row-major `float -> double` reduction;
- checked same-type raster-plane copy;
- exact `ubyte -> float` raster-plane conversion.

The current raster-operations sequence is:

```text
E5.4a       public-surface audit                         complete
E5.4b       writable prerequisites audit                complete
E5.4c       retained write-access provenance design     complete
E5.4c.1     retained ResourceAccess implementation      complete
E5.4d       semantic writable-view contract             complete
E5.4d.1a    writable backing certification              complete
E5.4d.1b    semantic WritableRasterView implementation  complete
E5.4d.1c    RasterLease -> writable borrow              complete
E5.4e       writable execution capabilities             complete
E5.4e.1     writable execution primitives               complete
E5.4e.2     WritableRasterView -> RasterTargetPlane     complete
E5.4e.3     existing consumer integration               complete
E5.4f       public operation contract redesign          complete
E5.4f.0     initial contract audit                      complete
E5.4f.1     public contract matrix audit                complete
E5.4f.2     writable affine execution-gap audit         complete
E5.4f.3     bulk-write alias contract                   complete
E5.4f.4     exact affine overlap research               complete
E5.4f.5a    checked-arithmetic carrier audit            complete
E5.4f.5b.1  sign+magnitude wide arithmetic              complete
E5.4f.5b.2a bounded wide Diophantine solver             complete
E5.4f.5b.2b affine-overlap equivalence                  complete
E5.4f.5c    production mapping audit                    complete
E5.4f.5c.1  writable execution stride query             complete
E5.4f.5c.2  affine relation + concrete consumer mapping complete
E5.4g       stable public operation exposure            complete
E5.4g.0     public exposure sequencing                  complete
E5.4g.1     semantic writable-borrow exposure           complete
E5.4g.2     strict float-to-double sum exposure         complete
E5.4g.3     same-type raster copy exposure              complete
E5.4g.4     exact ubyte-to-float conversion exposure    complete
E5.4g.5     public-surface/lifetime closeout            complete
```

The stable public raster-operation surface now consists of:

- the semantic lease-bound writable borrow;
- strict `trySumFloatToDouble()`;
- checked `tryCopyRasterPlane()`;
- exact `tryConvertUbyteToFloatPlane()`.

Execution layouts, Mir adapters, mutable execution pointers,
`RasterTargetPlane`, physical-range classification, affine relation machinery,
checked-wide arithmetic and operation dispatch internals remain non-public.

The next research milestone is R0.3: define the region, dependency and streaming
model above the resident raster core without collapsing provider tiles, cache
blocks, logical regions or future processing tasks into one tile abstraction.

R0.3 begins as research under `experiments/r0_3_regions_streaming/`. No new
stable production API is implied by starting this phase.

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

### R0.3 — Region, tile and streaming model

**Status (2026-09-21):** R0.3a / E3.2 identity streamed-equivalence complete.

Validated:

- whole/decomposed exact identity equivalence;
- horizontal, vertical, regular-tile and irregular decompositions;
- dedicated one-pixel-task decomposition;
- logical/global versus resident-coordinate separation;
- bounded sequential raster residency;
- huge logical extent without whole-image allocation;
- separate raster/oracle/metadata accounting;
- DMD and LDC;
- no E3.2-driven production API change.

**Next:** R0.3b — neighbourhood / halo equivalence.


Define and separate:

- provider tiles;
- cache blocks;
- regions;
- windows;
- processing tiles;
- halo/context;
- output regions.

Compare fixed-tile processing with arbitrary requested regions.

Test neighbouring tiles and cross-boundary processing.

Deliverable:

    docs/research/regions-streaming.md

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
- RGB channel extraction;
- RGB to grayscale;
- point transform;
- LUT;
- min/max reduction;
- histogram;
- small convolution.

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

### R0.6 — I/O and raster-source architecture

Research boundaries for:

- GDAL;
- local codecs;
- GeoTIFF;
- COG;
- XYZ/TMS;
- WMTS;
- WMS.

Define requirements for a generic raster/imagery source abstraction.

Deliverable:

    docs/research/io-sources.md

### R0.7 — Reproducible imagery corpus

Define test scenes covering:

- multiple latitudes;
- Northern and Southern Hemisphere;
- low and high elevation;
- flat and mountainous terrain;
- urban and rural areas;
- multiple providers;
- multiple quality levels;
- neighbouring tiles;
- mosaic seams.

Imagery is downloaded locally and is not committed.

Version:

- scene definitions;
- source definitions;
- retrieval parameters;
- provenance;
- hashes.

Deliverable:

    docs/research/test-corpus.md
    benchmark/scenes/
    benchmark/sources/

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
3. representative imagery is reproducibly obtainable;
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

## M4 — Image I/O and Geospatial Sources

Integrate source backends and geospatial metadata.

---

## R1 — Image Processing Research

Only after the engine foundation is stable, research:

- resampling;
- sharpening and blur;
- local contrast;
- colour processing;
- quality metrics;
- radiometric normalization.

---

## R2 — Illumination and Shadow Research

Research:

- cast shadows;
- terrain shadows;
- vegetation shadows;
- sun direction;
- acquisition metadata;
- shadow confidence;
- illumination correction.

---

## M5+ — Advanced Processing

Later milestones may include:

- editor display pipelines;
- GPU processing;
- feature extraction;
- segmentation;
- ML inference;
- mapping assistance.
