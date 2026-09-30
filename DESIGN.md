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


E5.4g.5 closed the initial public-operation boundary without adding another
execution abstraction. At that checkpoint external consumers saw semantic
raster views, lease-bound writable views and the three reviewed E5.4 operations
only. Lifetime probes require writable capabilities to remain tied to their
leases; public operation probes compile through the umbrella package with named
arguments; compile-negative probes keep raw certification and all
execution/relation machinery inaccessible.

M2.1 extends that reviewed public operation surface with
`tryFillRasterPlane()`.

Fill is generic over the existing raw raster sample contract and writes one
exact `T` value into one selected writable plane. It introduces no numeric
conversion or image interpretation.

Unlike copy and conversion, fill does not require destination injectivity.
Raster strides are expressed in elements of `T`, so distinct sample starts do
not partially overlap; when several logical coordinates resolve to the same
sample start, repeated writes of the same exact value are semantically
idempotent.

The current implementation is a scalar correctness path over the semantic
WritableRasterView boundary. Compiler-specific source forms, SIMD and other
fast paths remain internal M3 concerns.

M2.2 extends the public operation surface with
`tryTransformRasterPlane!transform()`.

The fundamental point-transform contract is deliberately generic and same-type:

```text
RasterView!T source plane
        +
compile-time @safe pure nothrow @nogc T -> T transform
        +
injective, physically disjoint WritableRasterView!T destination plane
        ->
transformed destination
```

Raster-d owns structural validation, layout traversal, lifetime/write
capability and source/destination physical-relation checking. The supplied
transform owns arithmetic and value semantics, including NaN/Inf behavior,
signed zero, saturation if explicitly coded, and any fused or unfused
floating-point expression graph.

Matching empty planes succeed without transform invocation. Structural failures
are detected before the first destination write. The first M2.2 contract rejects
all source/destination overlap, including exact in-place mapping; a separately
qualified in-place operation remains deferred.

Runtime delegates, image-domain adjustment semantics, compiler-specific source
forms, SIMD and threading are not part of this semantic API.

M2.3 adds one fixed radius-one neighbourhood semantic through
`tryApplyRasterNeighbourhood3x3!kernel()`.

Its resident execution model is:

```text
already-materialized RasterView!T
        +
resident-relative sourceOutputRegion
        +
complete one-sample halo
        +
compile-time @safe pure nothrow @nogc nine-sample kernel
        +
injective physically disjoint WritableRasterView!T
        ->
same-type neighbourhood output
```

The operation does not derive logical dependencies. M1.1/M1.2 remain the
authority for logical request expansion, ContextDeficit and resident-output
planning. A caller may use a materialization plan's residentOutput as the
source-relative output region after supplying complete resident context.

M2.3 defines no clamp, mirror, wrap or constant border behavior. Missing
resident context is an explicit operation failure. A higher layer may instead
synthesize border samples according to an explicit policy before invoking the
neighbourhood operation.

The public kernel receives only a row-major nine-value snapshot; source
pointers, strides, Mir types and execution-layout machinery remain internal.
The required source rectangle is two samples wider and taller than the output,
so the internal affine-relation layer supports exact differently shaped
same-type rectangle overlap while retaining the old equal-shape relation for
existing consumers.

M3.2a adds a shared invocation-local checked byte-envelope prefilter for point
transform and neighbourhood relations (ADR 0010). Disjoint half-open envelopes
prove disjoint sample bytes. Overlapping or unrepresentable envelopes fall
through to the unchanged exact algebraic classifier, including its
`arithmeticFailure` result and each consumer's defensive enumeration fallback.
The bounds calculation dereferences no pointers and establishes no ownership,
exclusivity or persistent noalias fact. Neighbourhood uses the entire required
halo rectangle. Copy and cross-type relation consumers retain their existing
paths.

R0.5 compiler/layout-specific neighbourhood source forms remain M3 internal
optimization work.

Detailed evidence and implementation sequencing are maintained in:

```text
raster-d-research repository:
docs/research/memory-model.md
docs/research/raster-core-types.md
docs/architecture/raster-construction.md
docs/architecture/raster-execution.md
docs/architecture/raster-operations.md
ROADMAP.md
```

Source, reuse/cache and scheduling architecture is promoted incrementally.

Production now contains only the generic pieces justified by research:
request/dependency geometry, caller-owned synchronous materialization,
bounded residency accounting and the M1.5 package-internal bounded retained
store. Replacement/eviction policy, cache-block selection, concurrency and
scheduling remain experimental.

Image-domain APIs belong to the separate `imagery-d` project.

## 5. Region-first processing

The engine should be able to request and compute only the area actually needed.

ADR 0004 promotes the R0.3 request-bounded dependency semantics into
production architecture without introducing a new public API.

The production model is:

    logical output request
             |
             v
    operation dependency margins
             |
             v
    valid logical input region
             +
    directional context deficit

Logical/global request and dependency geometry remains separate from resident
RasterView descriptor geometry.

A context deficit records required logical context outside the valid extent.
It does not select a border policy.

Processing-task boundaries are not logical-image boundaries. Tasks may
materialize overlapping halo input while producing disjoint output regions.

Dependency margins, context deficit and dependency-derivation helpers remain
package-internal initially. Region2D remains the public rectangular geometry
value.

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
- another processing operation;
- a scientific grid or other non-image raster source.

R0.6 source-boundary research is complete.

ADR 0006 selects the first production boundary as package-internal,
synchronous and caller-owned:

    RequestMaterializationPlan
        + source callable/capability
        + WritableRasterView
        -> materialization result

The generic orchestration layer receives no provider-tile, cache-block,
scheduler, image-domain or geospatial metadata.

The caller owns destination storage and lifetime. A source receives the exact
logical valid-input region and the resident writable destination.

Retained/adopted source output is proven viable by R0.6 as a secondary path,
but is not part of the first orchestration contract.

A public RasterSource inheritance hierarchy is deliberately not introduced.

### 6.1 Bounded retained reuse

ADR 0007 and ADR 0008 promote only the storage-neutral parts of reusable
retained raster data.

The production model keeps three concerns separate:

```text
caller-owned semantic Key
        |
        v
package-internal retained lookup/store
        |
        v
typed RasterLease ownership
```

and independently:

```text
request / operation residency admission
!=
store-retained byte budget
```

The M1.5 retained store:

- is generic over caller-owned Key;
- does not define source, generation, schema or provider identity;
- uses compile-time hash/equality specialization;
- owns a fixed entry capacity and a separate retained physical-byte limit;
- measures retained payload through the M1.4 backing-resource byte accounting;
- returns independently retained RasterLease copies;
- fails explicitly when duplicate, full, invalid or over its retained-byte
  limit;
- performs no automatic eviction.

Provider tiles, cache-block geometry, replacement policy, concurrency and
scheduling remain outside this contract.

A public RasterCache or public key hierarchy is deliberately not introduced.

### 6.2 Multi-block dependency resolution

ADR 0009 adds the first production bridge from one logical dependency to
multiple reusable retained/source blocks.

The caller owns block selection and supplies:

- semantic block keys;
- logical block regions;
- a retained store;
- a retained-materialization source capability;
- the caller-owned resident destination.

The resolver validates that the block/request intersections exactly and
pairwise-disjointly cover the requested logical dependency before any source
call or destination write.

Resolution then follows:

```text
caller-described block
        |
        +-- retained hit --------+
        |                        |
        `-- source miss ---------+
                                 |
                                 v
                         intersection transfer
                                 |
                                 v
                      rebased resident destination
```

A successfully materialized miss may satisfy the current request even when the
retained store cannot keep that value because of entry or byte limits.

Therefore:

```text
request resolution success
!=
store retention success
```

M1.6 defines no cache-block size, block-selection policy, provider mapping,
eviction/replacement rule or scheduler.

The current transfer loop is a correctness reference path. Later ROI/copy
specialisation may replace it without changing the semantic contract.

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

M3.1 promotes the first measured public-operation fast path while preserving
this separation.

For `tryApplyRasterNeighbourhood3x3!kernel()`, the public M2.3 validation and
error semantics remain authoritative. After successful validation:

```text
sampleStride == 1 for source and destination
        -> package-internal Canonical executor

otherwise
        -> existing generic semantic executor
```

The Canonical executor uses already-approved pointers/row strides and performs
no repeated per-sample view validation.

Compiler-specific source-form selection is centralized. The first qualified
specialization is deliberately narrow:

```text
T == float
AND LDC
AND D frontend == 2.111
AND source row stride < 0
        -> preserved out-of-line row-kernel boundary
```

Stable local benchmark and code-generation evidence shows that this boundary
restores row-local vector execution for the qualified LDC generation while the
same source form is not beneficial on DMD. Later LDC frontend generations do
not inherit the specialization automatically.

Universal/sample-strided layouts remain fully supported through the existing
generic path. No public execution-layout, compiler, pointer or SIMD vocabulary
is introduced.

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
