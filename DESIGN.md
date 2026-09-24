# raster-d Design

## 1. Purpose

`raster-d` is a high-performance generic raster foundation for D.

It owns reusable semantics for raster storage, ownership, layout, views,
regions, generic operations and execution without defining what the raster
means as an image, elevation model, scientific grid or application-specific
dataset.

The principal architectural relationship is:

```text
    imagery-d
        |
        v
     raster-d
```

The higher-level image library can therefore reuse raster ownership, layout,
streaming and execution machinery without making image-domain semantics
mandatory for other raster consumers.

The architecture must support both interactive and throughput-oriented
consumers while remaining independent of OSM-specific data structures, UI
code, concrete file formats and source providers.

## 2. Fundamental constraints

### 2.1 RAM is a budget, not a dataset-size limit

The library must not require an entire logical raster dataset to reside in
memory.

Memory consumption must be bounded and configurable.

The working set may include:

- decoded source data;
- source/cache blocks;
- processing regions;
- temporary buffers;
- output buffers;
- metadata;
- later, GPU-resident resources.

The total dataset may be substantially larger than physical RAM.

No operation should silently require a complete-image copy.

### 2.2 Dataset dimensions

Internal coordinate and size types must not introduce avoidable 32-bit limits.

The raster model must support:

- large single-plane and multi-plane rasters;
- planar and interleaved storage;
- arbitrary valid signed strides;
- subregions and non-contiguous views;
- streamed logical datasets;
- neighbouring/context regions required by generic operations.

Image mosaics, image pyramids and other image-domain structures may be built
above this raster representation but are not primitive raster semantics.

### 2.3 Performance

The library must serve both interactive consumers and throughput-oriented batch workloads.

The architecture must therefore permit:

- prioritisation of visible data;
- cancellation of obsolete work;
- asynchronous source loading;
- prefetching;
- reuse of decoded data;
- progressive refinement;
- parallel execution.

Performance is measured rather than inferred from abstraction choice.

### 2.4 Allocation behaviour

Hot processing loops should not repeatedly allocate.

Operations should permit engine-managed or caller-managed reusable destination
and workspace storage where appropriate.

### 2.5 Correctness before optimisation

Optimised implementations require a simple reference implementation or another
clear correctness oracle.

Whole-image and streamed/region processing must produce equivalent results
within explicitly defined tolerances when sufficient neighbourhood context is
available.

## 3. Terminology

These concepts must remain distinct.

### Provider tile

A unit delivered by an external source such as XYZ, TMS or WMTS.

It is an I/O concept.

### Cache block

A unit selected by the engine for storing reusable data.

It is a storage concept.

### Region

An arbitrary rectangular area requested from a raster or processing stage.

It is expected to become a fundamental processing concept, subject to R0
research.

### Window

A view into a raster or region.

A window should normally avoid copying pixel data.

### Processing tile

A possible unit of scheduled work.

It must not be assumed to equal a provider tile or cache block.

### Halo / context

Input pixels outside the requested output region that are required by an
operation.

Neighbourhood requirements should eventually be expressible by the operation
rather than being globally hard-coded.

## 4. Memory and view model

The initial R0.2/R0.3 research has been completed far enough to select the
resident raster/view architecture now used by the core implementation.

The current model separates:

```text
retained physical resources
        |
        v
RasterBacking
        |
        | retained ownership
        v
RasterLease
        |
        +---- lease-bound read borrow ----> RasterView
        |
        `---- lease-bound writable borrow
                                      |
                                      v
                              WritableRasterView
                                      |
                                      | when one current plane is
                                      | flat contiguous
                                      v
                              RasterTargetPlane
```

`RasterView` remains a cheap non-owning semantic read view.

`WritableRasterView` is its public lease-bound writable semantic peer. It
certifies permission to write represented samples but does not imply:

```text
uniqueness
non-aliasing
contiguity
single-plane storage
thread exclusivity
```

Physical raster geometry is described using validated plane descriptors with
signed row and sample strides. Multi-plane storage does not require one common
base allocation.

Mir `ndslice` has been selected as an internal execution substrate where useful,
not as part of the public semantic API.

The current execution architecture therefore separates:

```text
raster-d semantics
        |
        v
validated RasterView / WritableRasterView
        |
        v
package-internal execution classification/adapters
        |
        +-- generic strided path
        |
        `-- specialized proven fast paths
```

The public API must not expose Mir implementation types.

Ownership/lifetime and read/write capability remain separate concepts.

The lease-bound writable borrow, writable execution primitives and first
flat-contiguous `WritableRasterView -> RasterTargetPlane` execution bridge are
now implemented.

E5.4g.1 exposes `WritableRasterView` and the mutable
`RasterLease.tryWritableView()` borrow as semantic public capabilities.
Certification factories, execution-layout metadata, mutable execution pointers,
`RasterTargetPlane` and current operation dispatchers remain internal.

Integration with the existing checked copy and exact conversion consumers is
verified, and the E5.4f public-operation contract review remains the authority
for E5.4g operation exposure.

E5.4g.2 exposes `trySumFloatToDouble()` as the first stable public operation.
The public callable represents only strict row-major reduction semantics;
execution-layout classification, Mir adaptation and the fixed-lane graph remain
internal.

E5.4g.3 exposes `tryCopyRasterPlane()` plus the operation-specific
`RasterCopyError`. The public copy contract is layout-independent: matching
empty operands succeed, destination mapping must be injective, actual reachable
source/destination sample-byte overlap is rejected before the first write, and
shared backing is otherwise permitted. Contiguous memcpy and affine scalar
execution remain replaceable internal paths.

E5.4g.4 exposes `tryConvertUbyteToFloatPlane()` plus the operation-specific
`UbyteToFloatConversionError`. The public conversion contract is exact and
layout-independent: each ubyte maps to exactly representable binary32,
matching empty operands succeed, destination injectivity is required, and
actual reachable source/destination sample-byte overlap is rejected before the
first write. Mir adapters, contiguous targets, affine relation machinery and
defensive wide-arithmetic fallback remain replaceable internals.


E5.4g.5 closes the public-operation boundary without adding another execution
abstraction. External consumers see semantic raster views, lease-bound writable
views and the three reviewed operations only. Lifetime probes require writable
capabilities to remain tied to their leases; public operation probes compile
through the umbrella package with named arguments; compile-negative probes keep
raw certification and all execution/relation machinery inaccessible.

Detailed evidence and implementation sequencing are maintained in:

```text
docs/research/memory-model.md
docs/research/raster-core-types.md
docs/architecture/raster-construction.md
docs/architecture/raster-execution.md
docs/architecture/raster-operations.md
ROADMAP.md
```

The wider source/cache/scheduling architecture remains experimental. Image-domain APIs belong to the separate `imagery-d` project.

## 5. Region-first processing

The engine should be able to request and compute only the area actually needed.

A desired model is:

    consumer requests output region
                 ↓
        operation determines dependencies
                 ↓
        required input region + halo
                 ↓
           source/cache request

Whether this becomes a demand-driven graph, an explicit region pipeline or
another architecture will be decided during R0.

Fixed tiles must not become an accidental limitation of the processing API.

## 6. Source independence

Generic raster operations must not care whether their samples originated from:

- an in-memory image;
- GeoTIFF;
- Cloud Optimized GeoTIFF;
- GDAL;
- XYZ/TMS;
- WMTS;
- WMS;
- a cached mosaic;
- another processing operation.

A source/backend abstraction will be researched before implementation.

## 7. CPU optimisation strategy

The engine should support both:

1. generic correctness paths for arbitrary valid views;
2. specialised fast paths for common layouts.

Likely optimisation dimensions include:

- contiguous versus strided memory;
- interleaved versus planar data;
- alignment;
- SIMD;
- cache blocking;
- multithreading;
- compile-time specialisation;
- runtime hardware dispatch where justified.

LDC/LLVM auto-vectorisation should be evaluated before explicit SIMD is used.

## 8. Parallel execution

Raster operations should not each invent their own threading model.

Scheduling, task granularity, cancellation and priority should belong to an
engine execution layer.

The public raster model should not be tied to one scheduler.

## 9. GPU boundary

GPU implementation is not an initial requirement.

The CPU architecture must nevertheless avoid assumptions that make future
device-backed raster storage or compute backends impractical.

Any future GPU integration must preserve the semantic distinction between:

```text
public raster contract
        |
        v
execution/storage backend
```

Image-display transforms such as brightness, contrast, gamma, saturation and
opacity are image-domain operations for `imagery-d`; they are not reasons to
place display semantics in the generic raster API.

## 10. Metadata and geospatial boundary

`raster-d` does not require a raster to be georeferenced.

Ground extent, geotransforms, CRS, GSD, acquisition metadata and imagery
provenance therefore remain outside the generic raster semantic core.

Focused adapters or higher-level consumers may associate such metadata with
raster resources without changing ownership, layout, region or execution
semantics.

The separate `imagery-d` project owns or researches imagery-specific
geospatial integration. A focused GDAL integration library may expose generic
raster transfer where that boundary is independently useful.

## 11. Consumer-derived test corpora

`raster-d` requires reproducible correctness and performance fixtures, but it
does not require a permanent aerial/satellite imagery corpus as part of its
identity.

Synthetic fixtures should cover layout, ownership, regions, halos, aliasing,
sample conversion and bounded-residency behaviour directly.

Real imagery remains useful as downstream stress-test data. ADR 0002 records
the historical non-versioned imagery policy. Management of a full imagery
corpus belongs to the separate `imagery-d` project.

## 12. imagery-d responsibilities

Image enhancement and interpretation are deliberately outside the generic
`raster-d` contract.

The higher-level `imagery-d` project researches and may implement:

- blur and sharpening;
- colour and exposure normalization;
- radiometric normalization;
- image-quality assessment;
- shadow detection and correction;
- feature extraction;
- segmentation;
- ML-assisted interpretation;
- image pyramids and mosaics;
- imagery-specific source/cache behaviour.

Those topics may reveal requirements for reusable raster primitives. Such
requirements should enter `raster-d` only when they are demonstrably generic
rather than because one image consumer needs them.
