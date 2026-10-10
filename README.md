# raster-d

`raster-d` is a high-performance generic raster library for D.

**New to raster data?** A raster is a grid of values: heights, temperatures,
measurements or image samples. `raster-d` helps programs work with their
shape, storage, regions and processing without making every application
implement that machinery itself. Start with
[What is a raster, and what can raster-d do?](https://github.com/alex-1974/raster-d/blob/release/0.2/docs/understanding-rasters.md).

It represents large resident or streamed raster data without forcing image,
colour, radiometric, or geospatial-image semantics on every consumer.

```text
imagery-d
    |
    v
 raster-d
```

Scientific grids, elevation data, GDAL-backed windows, and application-specific
raster systems can also use `raster-d` directly.

## Status

v0.1.0 is released. Its public source contract is frozen at
`freeze/api-0.1.0`.

The release passed the supported compiler and platform matrices, compiler-floor
checks, public-only DDox, external archive consumers, and the reference XPS
performance gate. The signed `v0.1.0` tag, GitHub Release, stable/versioned
documentation, and DUB publication were verified after release.

v0.2.0 is a release candidate undergoing stabilization on `release/0.2`.
Its feature set is frozen at `freeze/feature-0.2.0`, and its public API
is frozen at `freeze/api-0.2.0`. **v0.2.0 is not yet published**; v0.1.0
remains the latest published stable version until the release checks,
GitHub Release, documentation publication and DUB verification complete.

Because raster-d is pre-1.0, a later minor release may deliberately evolve the
API. Published release contracts stay fixed.

The DUB package is `raster-d`. The public D namespace is `raster` and
`raster.*`.

## Quick start

This example adopts four bytes, describes them as a 2 x 2 `ubyte` plane, and
reads one sample.

```d
import core.stdc.stdlib : malloc;
import raster;

void main()
@system
{
    void* memory = malloc(4);
    assert(memory !is null);

    auto samples = (cast(ubyte*) memory)[0 .. 4];
    samples[] = [1, 2, 3, 4];

    OwnedByteResource resource;
    assert(tryAdoptMallocResource(memory, 4, resource));

    const PlaneByteLayout[1] layout =
    [
        PlaneByteLayout(0, 2, 1)
    ];

    RasterLease!ubyte lease;

    assert(
        tryImportOwnedRaster!ubyte(
            resource,
            layout[],
            Region2D(0, 0, 2, 2),
            lease
        ).ok
    );

    scope auto view = lease.view();

    ubyte value;
    assert(view.trySample(0, 1, 1, value));
    assert(value == 4);
}
```

A successful import transfers the adopted resource into retained raster
ownership. `RasterLease` keeps that storage alive. `RasterView` borrows from
the retained lifetime and does not own storage.

See [docs/README.md](https://github.com/alex-1974/raster-d/blob/release/0.2/docs/README.md) for the user documentation path.

## What raster-d provides

The current raster foundation includes:

- retained ownership of one or more physical resources;
- validated multi-plane backing with signed row and sample strides;
- logical regions and zero-copy subregions;
- lease-bound read-only `RasterView`;
- lease-bound `WritableRasterView`;
- checked copy, fill, transform, conversion, reduction, neighbourhood, and
  convolution families;
- bounded request residency and retained reuse;
- exact multi-block dependency assembly for streamed requests;
- synchronous caller-owned materialization;
- internal layout and compiler specialization without public ISA switches.

Execution layouts, raw execution pointers, Mir adapters, affine proofs,
compiler-specific kernels, cache replacement policy, and scheduling remain
implementation details.

## Design goals

raster-d aims to:

- handle logical rasters larger than available RAM;
- keep residency bounded and explicit;
- support signed-stride, multi-plane, planar, and interleaved layouts;
- make regions, windows, neighbourhoods, and halo processing efficient;
- avoid unnecessary copies and hidden allocation;
- preserve decomposition-independent results;
- expose semantic raster contracts without exposing execution policy;
- leave thread scheduling to the caller;
- keep a path open for future CPU and GPU execution;
- remain independent of codecs, providers, and image-domain semantics.

## What raster-d does not own

raster-d is not a full image-processing library.

Image and pixel-format semantics, colour, radiometric normalization,
image-quality analysis, mosaics, pyramids, enhancement, segmentation, and
imagery-specific geospatial metadata belong above this layer, primarily in
`imagery-d`.

A higher-level need enters raster-d only when it proves a reusable raster-domain
requirement.

## Repository and package boundary

The Git repository contains more than the consumer package.

```text
source/raster/        production library
tests/                correctness and external-consumer tests
benchmark/            maintained production qualification harnesses
tools/                verification and release tooling
docs/                 user, API, architecture, and decision documentation
```

Experimental prototypes, raw benchmark runs, compiler investigations, and
large retained evidence live in the separate
`alex-1974/raster-d-research` repository.

The consumer archive excludes repository-only tests, benchmarks, tools,
engineering documentation, and CI files. Release CI verifies that boundary.

## Build

```bash
dub build
dub test
```

Normal integration tests DMD and LDC. LDC/LLVM is the primary optimized/codegen
compiler; DMD is also a required correctness and development baseline.

## Compiler support

The source/frontend compatibility floor is DMD/Phobos 2.101. The corresponding
LDC generation is LDC 1.31.0.

Concrete package floors vary by platform because older macOS compiler packages
do not support current macOS 15 runners:

| Platform | DMD | LDC |
| --- | --- | --- |
| Linux x86-64 | 2.101.2 | 1.31.0 |
| Linux ARM64 | — | 1.31.0 |
| Windows x86-64 | 2.101.2 | 1.31.0 |
| macOS x86-64 | 2.112.1 | 1.41.0 |
| macOS ARM64 | — | 1.41.0 |
| Windows ARM64 | experimental | experimental |

Normal `develop` integration uses:

- DMD 2.111.0;
- LDC 1.41.0.

Release qualification also exercises DMD 2.111.0 / 2.112.1 / 2.113.0 and
LDC 1.41.0 / 1.42.0 / 1.43.0, the supported platform matrix, and the minimum
compiler-package floor.

## Documentation

Start with:

- [user documentation](https://github.com/alex-1974/raster-d/blob/release/0.2/docs/README.md);
- [v0.2 public API audit](https://github.com/alex-1974/raster-d/blob/release/0.2/docs/API_0_2.md);
- [v0.1 public API baseline](https://github.com/alex-1974/raster-d/blob/release/0.2/docs/API.md);
- [changelog](CHANGELOG.md).

Maintainer context lives in `ROADMAP.md`, `DESIGN.md`, `BENCHMARK.md`,
ADRs, and architecture documents.

## Workspace context

Inside `d-geospatial-workspace`, shared engineering rules are available under
`.workspace/`.

That directory is local workspace context. It is ignored by Git and is not part
of the raster-d package.
