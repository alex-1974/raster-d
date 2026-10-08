# raster-d 0.2 public API audit

**Status:** public API frozen for the v0.2.0 release candidate  
**Feature freeze:** `freeze/feature-0.2.0`  
**API freeze:** `freeze/api-0.2.0` (`1ea67cb6ffb2c887f78d160249a293ad74ba5cda`)  
**Release line:** `release/0.2`

This document records the audited public source contract frozen for
`raster-d 0.2.0`. The immutable `freeze/api-0.2.0` checkpoint was created
on 2026-10-08, after PR #203 completed the audit. This is an engineering
checkpoint, not the published `v0.2.0` release.

## Supported import surface

The supported aggregate import is:

~~~d
import raster;
~~~

The compatibility contract freezes declarations re-exported by
`source/raster/package.d`.

Direct imports of implementation submodules are not an additional compatibility
promise merely because a module is physically present in the package. Public
Ddoc is generated from the modules that own root-exported declarations, but the
aggregate root remains the supported import surface.

Package/internal declarations and `raster.internal.*` modules are excluded
from the public contract.

## Compatibility with v0.1

Compared with `freeze/api-0.1.0`:

- all 23 v0.1 root exports remain;
- v0.2 adds 43 root exports;
- no v0.1 root export is removed.

The v0.1 compatibility bridges remain supported in v0.2 alongside the newer
destination-oriented and generic families.

## Complete v0.2 root export inventory

### Sample policy

~~~text
isRasterSampleType
isNumericRasterSample
isExactConvertible
~~~

`isRasterSampleType!T` remains the fundamental representation-policy trait.

`isNumericRasterSample!T` identifies the numeric subset used by arithmetic
and reduction families.

`isExactConvertible!(From, To)` is a compile-time representability trait. It
does not perform conversion.

### Ownership and retained import

~~~text
OwnedByteResource
tryAdoptMallocResource

PlaneByteLayout
PlaneDescriptor
Region2D

OwnedRasterImportError
OwnedRasterImportResult
OwnedRasterResourceDisposition
tryImportOwnedRaster

RasterLease
RasterView
WritableRasterView
~~~

`tryAdoptMallocResource` is the explicit `@system` ownership boundary for a
malloc-compatible allocation.

`tryImportOwnedRaster` is the `@safe` ownership-transfer boundary from an
armed `OwnedByteResource` plus byte-oriented plane layouts into a
`RasterLease!T`.

Ownership disposition is explicit:

~~~text
unchanged
transferredToLease
releasedAfterCommit
~~~

`RasterLease!T` is the retained owner in the v0.2 contract. Copying a lease
retains the same backing. `RasterLease!T.init` is inert and safe to destroy,
assign, inspect through the public borrow operations, or replace.

`RasterView!T` and `WritableRasterView!T` are non-owning borrows. They must
not outlive the retained lifetime that produced them.

A writable view proves permission to mutate represented samples. It does not
promise uniqueness, exclusivity, no-alias, contiguity, or thread exclusivity.

### Region and view semantics

`Region2D` stores unsigned origin and extent only. The owner of the value
defines the coordinate system.

Its public operations are:

~~~text
empty
hasRepresentableExtent
containsRelative
tryResolveRelative
~~~

`RasterView!T` and `WritableRasterView!T` expose:

~~~text
planeCount
region
width
height
empty
tryRoi
trySample
~~~

`WritableRasterView!T` additionally exposes:

~~~text
trySetSample
~~~

ROI coordinates are relative to the current view. A child retains the same
descriptor/storage lifetime and owns no storage.

### Reduction family

~~~text
RasterSumError
RasterSumResult
sum

RasterMeanError
RasterMeanResult
mean

RasterExtremaError
RasterExtremaResult
RasterMinMaxResult
min
max
minMax

trySumFloatToDouble
~~~

All reductions operate on logical row-major sample order.

`sum!Accumulator` supports the explicitly documented exact
sample/accumulator pairs. Integer accumulation reports
`accumulatorOverflow`; floating accumulation preserves the documented strict
encounter order.

`mean!(Accumulator, Result)` reuses the sum contract. Empty input is a checked
failure.

`min`, `max`, and `minMax` use the documented NaN and signed-zero
selection semantics.

`trySumFloatToDouble` remains the v0.1 compatibility entry point for strict
`float -> double` sum.

The result-carrier `.init` states are deliberately unsuccessful even though
the corresponding error enums have `.none` as their enum `.init`.

### Fill

~~~text
tryFillRasterPlane
fill
~~~

`fill` is the v0.2 destination-oriented spelling. Both names share the same
semantics.

Fill requires a valid selected destination plane and an injective destination
mapping. Matching empty output succeeds as a no-op.

The operation allocates nothing and retains nothing.

### Unary point transform

~~~text
RasterTransformError
tryTransformRasterPlane
transformInto

RasterAllocatedTransformError
RasterAllocatedTransformResult
tryTransformAllocated
~~~

The transform alias must satisfy the documented same-type compile-time callable
contract.

`transformInto` is the destination-oriented v0.2 spelling of the existing
operation.

`tryTransformAllocated` explicitly allocates a new compact one-plane retained
result. Its result carrier has a deliberately failing `.init` state and
returns `RasterLease!T.init` from `lease()` on failure.

Destination-oriented transform performs no hidden allocation.

### Binary pointwise transform and arithmetic

~~~text
RasterZipTransformError
zipTransformInto

addInto
subtractInto
multiplyInto
divideInto
~~~

`zipTransformInto!transform` applies one compile-time same-type two-input
point transform.

Both read-only inputs may overlap each other. Each input must be physically
disjoint from the writable destination sample set.

The arithmetic wrappers use the same zip-transform failure model and do not
introduce a second traversal engine.

Integer arithmetic follows the operation-specific documented D semantics.
Floating arithmetic uses ordinary D/IEEE arithmetic. No saturation, clamping,
image-domain policy, or hidden wider arithmetic is implied.

### Same-type copy

~~~text
RasterCopyError
tryCopyRasterPlane
copyInto
~~~

`tryCopyRasterPlane` remains the v0.1 compatibility entry point.
`copyInto` is the v0.2 destination-oriented spelling.

Source and destination use the same sample type and must have matching logical
shape. Matching empty shapes succeed as a no-op.

The destination mapping must be injective. Source self-aliasing is permitted,
but actual source/destination sample-byte overlap is rejected before the first
write. The operation does not promise snapshot or memmove semantics.

Both spellings allocate nothing, retain neither operand, and share
`RasterCopyError`.

### Exact conversion

~~~text
RasterConversionPolicy

RasterConversionError
convertRasterInto

UbyteToFloatConversionError
tryConvertUbyteToFloatPlane

RasterAllocatedConversionError
RasterAllocatedConversionResult
tryConvertAllocated
~~~

The only v0.2 conversion policy is:

~~~text
RasterConversionPolicy.exact
~~~

Unsupported `From -> To` pairs fail to instantiate rather than becoming
per-sample runtime failures.

`convertRasterInto` is destination-oriented and allocation-free.

`tryConvertAllocated` explicitly allocates a compact one-plane retained
result.

`tryConvertUbyteToFloatPlane` remains the v0.1 exact-conversion compatibility
entry point.

### Fixed neighbourhood geometry

~~~text
NeighbourhoodShape
~~~

`NeighbourhoodShape!(Width, Height, AnchorX, AnchorY)` is compile-time
geometry. It stores no runtime fields.

The public compile-time members are:

~~~text
width
height
anchorX
anchorY
left
right
top
bottom
sampleCount
~~~

Width and height must be non-zero. The anchor must lie inside the shape.

### Border policy model

~~~text
RasterBorderKind
RasterValidBorder
RasterConstantBorder
RasterClampBorder
RasterMirrorBorder
RasterWrapBorder
~~~

These are semantic policy value/type models.

The v0.2 neighbourhood and convolution operations currently execute valid
resident-halo semantics only. They do **not** accept these policy objects as an
argument and do not synthesize constant/clamp/mirror/wrap samples.

The border types are nevertheless part of the v0.2 root contract as stable
semantic vocabulary. Callers must not infer an execution capability that is not
present in an operation signature.

Mirror means edge-inclusive symmetric reflection. Wrap uses Euclidean modulo.
Clamp, mirror, and wrap require a non-zero source extent when an operation
eventually consumes those policies.

### Neighbourhood family

~~~text
RasterNeighbourhood3x3Error
tryApplyRasterNeighbourhood3x3

RasterNeighbourhoodError
applyNeighbourhoodInto
~~~

The v0.1 centered 3 x 3 family remains supported.

`applyNeighbourhoodInto!(Shape, kernel)` generalizes fixed-shape
neighbourhood execution. The kernel receives samples in row-major
neighbourhood order.

`sourceOutputRegion` is resident-relative. The complete required source
context must already be resident.

Missing context is
`RasterNeighbourhoodError.unsatisfiedNeighbourhood`; no border synthesis is
implied.

Matching empty output succeeds without invoking the kernel.

The destination must be injective. Required-source/destination overlap is
rejected before writes.

No allocation or hidden scheduling occurs.

### Fixed convolution family

~~~text
FixedConvolutionKernel
convolveInto
~~~

`FixedConvolutionKernel` stores no runtime fields. Shape and coefficients are
compile-time data.

v0.2 supports float/double source/output samples and the documented
float/double coefficient/accumulator combinations.

Terms are evaluated in row-major coefficient order. The accumulator type is
explicit. When the supported contract uses a `double` accumulator and
`float` output, one final binary64-to-binary32 cast occurs.

`convolveInto` inherits spatial/failure semantics from
`applyNeighbourhoodInto`. It allocates nothing and performs no hidden
scheduling.

## Failure and no-write model

Destination-oriented operations validate structural conditions before the first
destination write.

Where an operation returns `bool` plus an error enum, the error output is
initialized on entry and identifies the documented structural failure on
`false`.

Result-carrier APIs expose an explicit `ok` property and stable error
category.

Allocation failure is exposed only by APIs whose names/contracts explicitly
allocate. Lower-level destination-oriented primitives remain allocation-free.

## Numerical contract

The v0.2 public numerical contract includes:

- exact same-type copy;
- exact promoted conversion pairs only;
- strict logical row-major sum;
- mean derived from the selected strict sum accumulator;
- documented extrema NaN/signed-zero behavior;
- pointwise unary/binary transform semantics;
- explicit fixed-neighbourhood order;
- explicit fixed-convolution coefficient order and accumulator type.

Compiler-specific vectorization, source-form specialization, SIMD, and layout
dispatch may change only when these results remain within the frozen contract.

## Scheduling and execution policy

The public API exposes no:

- worker count;
- thread pool;
- scheduler;
- affinity;
- SMT policy;
- ISA selector;
- compiler selector;
- cache replacement selector.

Public operations perform no hidden parallel scheduling.

Caller-owned scheduling may divide independent work at a higher layer.

## Attributes

The destination-oriented non-allocating operation families are
`@safe nothrow @nogc` under their documented template constraints.

Borrowing/accessor operations preserve their documented `scope`/`return`
lifetime relations.

Allocating convenience functions are `@safe` but do not claim `@nogc` or
`nothrow`.

The raw malloc adoption boundary is `@system`.

The API-freeze compile probes validate these source-level contracts under both
ordinary source mode and explicit DIP1000 mode.

## Named arguments

D parameter names can participate in source compatibility.

The v0.2 external API probe compiles representative named-argument calls across
the public families under baseline DMD and LDC, in ordinary and DIP1000 modes.

Parameter names exercised by those probes are frozen source contract for v0.2.

## Deliberately non-public machinery

The v0.2 contract excludes:

- `raster.resource` storage entries and release callbacks;
- backing validators and writable certification;
- raw view factories;
- retained backing implementation types;
- construction/import transaction internals;
- execution-layout classifiers;
- raw execution pointers;
- affine relation/proof helpers;
- Mir adapters;
- dispatch selectors;
- scalar/SIMD/fixed-lane kernels;
- block-resolution/dependency/materialization internals;
- residency/retained-store implementation;
- compiler-specific capability helpers;
- scheduler/worker policy.

The release API audit compiles negative external probes for representative
members of this set.

## API-freeze decision

The API freeze was accepted after the following checks:

1. DMD and LDC package tests pass in ordinary and explicit DIP1000 modes;
2. the external positive v0.2 source-contract probe passes;
3. the external negative surface probes reject internal machinery;
4. ownership/lifetime negative compile probes pass;
5. retained-import separate-link probes pass;
6. public-only DDox generation is complete;
7. every public DDox symbol page required by the documentation standard has a
   compiler-checked Example;
8. no release-blocking contract contradiction remains.

After `freeze/api-0.2.0`, implementation, tests, benchmarks, comments,
documentation, CI, and packaging may continue only while preserving this
public contract.
