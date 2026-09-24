# raster-d

`raster-d` is an experimental high-performance generic raster library written
in D.

It provides the reusable raster foundation for large resident and streamed
datasets without imposing image, colour, radiometric or geospatial-image
semantics on every consumer.

The intended dependency boundary is:

```text
    imagery-d
        |
        v
     raster-d
```

Other consumers such as scientific grids, elevation data, GDAL-backed windows
or application-specific raster systems may use `raster-d` directly.

## Status

Active generic raster-core implementation.

The production DUB package is `raster-d` and the public D namespace is
`raster` / `raster.*`.

The retained raster foundation includes:

- retained ownership of one or more physical resources;
- validated multi-plane backing and signed row/sample strides;
- descriptor-space regions;
- lease-bound read-only `RasterView`;
- lease-bound public `WritableRasterView`;
- read/write provenance and writable-backing certification;
- internal execution-layout classification and Mir adapters;
- checked physical-range and affine-overlap analysis;
- strict `trySumFloatToDouble()`;
- checked `tryCopyRasterPlane()`;
- exact `tryConvertUbyteToFloatPlane()`.

Execution layouts, mutable raw execution pointers, `RasterTargetPlane`, Mir
types, affine-relation machinery, checked-wide arithmetic and operation
dispatch internals remain non-public.

R0.3 research has additionally demonstrated decomposition-independent streamed
identity and neighbourhood/halo execution with bounded raster residency.
Those research types are not promoted into the stable production API merely by
the repository pivot.

The public API remains experimental. Performance-sensitive implementation is
developed from measured evidence and validated with both DMD and LDC.

## Primary goals

- support logical rasters substantially larger than available RAM;
- bounded and configurable raster residency;
- efficient regions, windows and neighbourhood access;
- low-copy and zero-copy semantic views where appropriate;
- correct signed-stride and multi-plane layouts;
- generic planar and interleaved raster representation;
- decomposition-independent streamed processing;
- predictable halo/context handling;
- SIMD-friendly CPU execution;
- scalable future scheduling and parallel execution;
- clear separation between semantic raster contracts and execution strategy;
- retain a path toward future GPU-backed execution without exposing GPU
  assumptions in the public raster model;
- remain independent of a particular codec, file format, provider, geospatial
  stack or image-domain interpretation.

## Non-goals of the initial phase

`raster-d` is not intended to become a comprehensive image-processing library.

Image-domain responsibilities belong above the generic raster layer. The
separate `imagery-d` project owns or researches, among other things:

- image and pixel-format semantics;
- colour semantics;
- radiometric normalization;
- image enhancement and filters;
- imagery mosaics and pyramids;
- imagery-specific source/cache policy;
- image-quality analysis;
- shadow and illumination processing;
- feature extraction and segmentation;
- ML-assisted image interpretation;
- imagery-specific geospatial metadata integration.

Those higher-level requirements may inform `raster-d` abstractions when they
produce a demonstrated generic raster need, but they do not define the raster
API by default.

## Repository layout

```text
source/raster/        production library
tests/                correctness and external-consumer tests
tools/                maintained verification/probe tooling
experiments/          research and reproducible experiment evidence
docs/adr/             architecture decision records
docs/architecture/    current architecture contracts
docs/research/        research results and retained technical evidence
```

Historical research artifacts retain their original naming where changing them
would weaken reproducibility.

## Benchmark and test data

`raster-d` should use deterministic synthetic fixtures and reproducible real
raster workloads where each is appropriate.

ADR 0002 records the historical policy that large benchmark imagery is not
stored in Git. That decision remains repository history, but management of a
full aerial/satellite imagery corpus is a responsibility of the future
`imagery-d`, not a defining responsibility of the generic raster library.

Consumer-derived imagery may still be useful as raster stress-test input when
its provenance and reproducibility are controlled.

## Build

    dub build
    dub test

Performance-sensitive work will be tested with both DMD and LDC. LDC/LLVM is
expected to become the primary performance compiler.

See `ROADMAP.md`, `DESIGN.md` and `BENCHMARK.md`.

## Compiler support

The source/frontend compatibility floor is DMD/Phobos 2.101. The corresponding
LDC generation is LDC 1.31.0.

Concrete compiler-package floors vary by platform because older macOS compiler
packages are not compatible with current macOS 15 runners:

| Platform | DMD | LDC |
| --- | --- | --- |
| Linux x86-64 | 2.101.2 | 1.31.0 |
| Linux ARM64 | — | 1.31.0 |
| Windows x86-64 | 2.101.2 | 1.31.0 |
| macOS x86-64 | 2.112.1 | 1.41.0 |
| macOS ARM64 | — | 1.41.0 |
| Windows ARM64 | experimental | experimental |

Current DMD and LDC releases remain part of the normal CI matrix. See
`docs/research/compiler-floor-audit.md` for the evidence and boundary tests.

## Workspace context

When developed inside `d-geospatial-workspace`, shared architecture and
research context is available locally under:

```text
.workspace/
```

That directory is local workspace context and is not part of the `raster-d`
repository or DUB package.

Repository-root documentation describes `raster-d`. Shared workspace
documentation is migrated separately because those files are hard-linked across
multiple workspace repositories.
