# raster-d v0.2 M0.3 — current public API inventory

Status: **M0.3 inventory of the frozen v0.1 contract**

Baseline:

```text
branch: develop
commit: 910a2e587693f6e68c00f6c1df9bb3f52b351b50
```

Purpose:

- inventory the existing caller-visible raster-d contract before v0.2 family design;
- separate public semantic API from package/internal execution machinery;
- record root re-exports, templates, constraints, legal instantiations, attributes and UFCS shape;
- make no production API change.

Normative source for the current contract remains the implementation plus the
v0.1 API freeze evidence in `docs/V0_1_API_AUDIT.md` and
`tests/external/raster_api_freeze`.

## 1. Supported aggregate import surface

The supported aggregate consumer entry point is:

```d
import raster;
```

`source/raster/package.d` currently re-exports exactly:

| Family | Root export |
| --- | --- |
| sample constraint | `isRasterSampleType` |
| ownership | `OwnedByteResource`, `tryAdoptMallocResource` |
| external byte layout | `PlaneByteLayout` |
| retained import | `OwnedRasterImportError`, `OwnedRasterImportResult`, `OwnedRasterResourceDisposition`, `tryImportOwnedRaster` |
| physical descriptor | `PlaneDescriptor` |
| region geometry | `Region2D` |
| read view | `RasterView` |
| writable view | `WritableRasterView` |
| reduction | `trySumFloatToDouble` |
| fill | `tryFillRasterPlane` |
| point transform | `RasterTransformError`, `tryTransformRasterPlane` |
| 3x3 neighbourhood | `RasterNeighbourhood3x3Error`, `tryApplyRasterNeighbourhood3x3` |
| copy | `RasterCopyError`, `tryCopyRasterPlane` |
| conversion | `UbyteToFloatConversionError`, `tryConvertUbyteToFloatPlane` |
| retained lifetime | `RasterLease` |

Individual implementation modules are not an alternative compatibility surface.
The supported public package boundary is the aggregate `raster` import.

## 2. Sample-type constraint

```d
template isRasterSampleType(T)
```

Accepted representation family:

- unqualified POD value types;
- no pointer/reference-like indirections;
- primitive numeric types;
- static arrays whose representation satisfies the same rule;
- POD structs without indirections.

Rejected examples include:

- `void`;
- `const`, `immutable` or `shared` qualified sample types;
- pointers;
- dynamic arrays;
- classes/references;
- structs with indirections;
- non-POD/destructible value types.

The trait is public and is the common legality constraint for
`RasterView!T`, `WritableRasterView!T`, `RasterLease!T`, retained import
and generic same-type operations.

## 3. Region and layout metadata

### 3.1 `Region2D`

Public fields:

```d
size_t x;
size_t y;
size_t width;
size_t height;
```

Public methods:

```d
bool empty() const
bool hasRepresentableExtent() const
bool containsRelative(Region2D relative) const
bool tryResolveRelative(Region2D relative, out Region2D resolved) const
```

All four methods are:

```text
@safe pure nothrow @nogc
```

The v0.1 contract explicitly exercises region geometry at CTFE.

### 3.2 `PlaneDescriptor`

Public fields:

```d
const(void)* base;
ptrdiff_t rowStrideElements;
ptrdiff_t sampleStrideElements;
```

It is access-neutral metadata. Signed element strides are part of the
representation contract. Ownership and write authority are deliberately not
encoded in this type.

### 3.3 `PlaneByteLayout`

Public fields:

```d
size_t byteOffset;
ptrdiff_t rowStrideBytes;
ptrdiff_t sampleStrideBytes;
```

This is the byte-oriented external import representation. Conversion to
`PlaneDescriptor` is package-internal.

## 4. Ownership and retained backing

### 4.1 `OwnedByteResource`

Move-only:

```d
@disable this(this);
```

Public observations:

```d
@property bool ownsResource() const
@property size_t byteLength() const
```

Both are `@safe pure nothrow @nogc`.

Public adoption boundary:

```d
bool tryAdoptMallocResource(
    void* base,
    size_t byteLength,
    ref OwnedByteResource owned
)
@system nothrow @nogc;
```

The successful call transfers one malloc/free-compatible release obligation.
Failure does not replace an already armed destination token.

### 4.2 retained owned-raster import

Public enums:

```d
enum OwnedRasterImportError : ubyte
{
    none,
    emptyResource,
    outputLeaseNotEmpty,
    noPlanes,
    temporaryMetadataAllocationFailed,
    invalidPlaneLayout,
    invalidBackingLayout,
    backingAllocationFailed,
    internalConstructionFailure
}

enum OwnedRasterResourceDisposition : ubyte
{
    unchanged,
    transferredToLease,
    releasedAfterCommit
}
```

Public result:

```d
struct OwnedRasterImportResult
```

with read-only properties:

```d
@property OwnedRasterImportError error() const
@property size_t planeIndex() const
@property bool ok() const
@property OwnedRasterResourceDisposition resourceDisposition() const
```

These properties are `@safe pure nothrow @nogc`.

Default state is deliberately failure:

- `error == internalConstructionFailure`;
- `planeIndex == size_t.max`;
- `resourceDisposition == unchanged`;
- `ok == false`.

Import:

```d
OwnedRasterImportResult tryImportOwnedRaster(T)(
    ref OwnedByteResource resource,
    scope const(PlaneByteLayout)[] planes,
    Region2D residentRegion,
    ref RasterLease!T lease
)
@safe;
```

`T` must satisfy `isRasterSampleType!T`.

Ownership transition is transactional relative to the documented commit point:
pre-commit failure preserves caller ownership; success transfers ownership to
the lease; post-commit failure reports that the resource was released after
commit.

## 5. Retained lifetime and semantic views

### 5.1 `RasterLease!T`

`T` must satisfy `isRasterSampleType!T`.

Public methods:

```d
RasterView!T view()
    return
    @trusted nothrow @nogc;

WritableRasterView!T tryWritableView(out bool success)
    return
    @trusted nothrow @nogc;
```

The lease is copyable retained ownership. `.init` is an inert valid lifetime
capability. A view borrows from the lease and must not outlive it. A const lease
cannot recover writable capability.

The following lease members are package-internal, not public API:

- `hasBacking`;
- `tryPhysicalResourceBytes`;
- raw retained-owner construction.

### 5.2 `RasterView!T`

Public semantic members:

```d
@property size_t planeCount() const
@property Region2D region() const
@property size_t width() const
@property size_t height() const
@property bool empty() const

RasterView!T tryRoi(Region2D relative, out bool success) const
    return scope
    @safe pure nothrow @nogc;

bool trySample(
    size_t band,
    size_t x,
    size_t y,
    out T value
) const
@trusted nothrow @nogc;
```

The five properties are `@safe pure nothrow @nogc`.

`.init` is an inert empty view. Failed `trySample` resets `value` to
`T.init`.

Execution-layout/stride/pointer queries and raw factories are package-internal.

### 5.3 `WritableRasterView!T`

Public semantic members:

```d
@property size_t planeCount() const
@property Region2D region() const
@property size_t width() const
@property size_t height() const
@property bool empty() const

WritableRasterView!T tryRoi(Region2D relative, out bool success)
    return scope
    @safe pure nothrow @nogc;

bool trySample(
    size_t band,
    size_t x,
    size_t y,
    out T value
) const scope
@safe nothrow @nogc;

bool trySetSample(
    size_t band,
    size_t x,
    size_t y,
    T value
)
@trusted nothrow @nogc;
```

Writable views are non-owning capabilities. They do not imply uniqueness,
noalias, exclusivity, contiguity or thread exclusivity.

## 6. Public operation families

### 6.1 strict reduction

```d
bool trySumFloatToDouble(
    scope RasterView!float source,
    size_t planeIndex,
    out double sum
)
@safe nothrow @nogc;
```

Semantics:

- strict logical row-major accumulation;
- one double accumulator;
- valid empty plane succeeds with `sum == 0.0`;
- invalid plane is the only public false result and resets `sum`.

### 6.2 fill

```d
bool tryFillRasterPlane(T)(
    scope ref WritableRasterView!T destination,
    size_t planeIndex,
    T value
)
@safe nothrow @nogc;
```

Legal for every `isRasterSampleType!T`.
A valid empty plane succeeds. Non-injective mappings are semantically legal
because every reachable destination receives the same exact value.

### 6.3 point transform

```d
enum RasterTransformError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    shapeMismatch,
    nonInjectiveDestination,
    sourceDestinationOverlap
}

bool tryTransformRasterPlane(alias transform, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterTransformError error
)
@safe nothrow @nogc;
```

`T` must be a legal raster sample type. The alias must be usable as the
same-type callable:

```text
@safe pure nothrow @nogc T -> T
```

No implicit numeric/image-domain policy is applied.

### 6.4 fixed 3x3 neighbourhood

```d
enum RasterNeighbourhood3x3Error : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    destinationShapeMismatch,
    unsatisfiedNeighbourhood,
    nonInjectiveDestination,
    sourceDestinationOverlap
}

bool tryApplyRasterNeighbourhood3x3(alias kernel, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterNeighbourhood3x3Error error
)
@safe nothrow @nogc;
```

Kernel contract is same-type and compile-time selected:

```text
@safe pure nothrow @nogc
T kernel(ref const(T)[9])
```

Neighbourhood order is row-major, with center at index 4.

### 6.5 same-type copy

```d
enum RasterCopyError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    shapeMismatch,
    nonInjectiveDestination,
    sourceDestinationOverlap
}

bool tryCopyRasterPlane(T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterCopyError error
)
@safe nothrow @nogc;
```

The source and destination use the same legal sample representation.
Observable semantics are exact sample preservation. Actual reachable-byte
overlap is rejected before writing.

### 6.6 exact ubyte-to-float conversion

```d
enum UbyteToFloatConversionError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    shapeMismatch,
    nonInjectiveDestination,
    sourceDestinationOverlap
}

bool tryConvertUbyteToFloatPlane(
    scope RasterView!ubyte source,
    size_t sourcePlaneIndex,
    scope ref WritableRasterView!float destination,
    size_t destinationPlaneIndex,
    out UbyteToFloatConversionError error
)
@safe nothrow @nogc;
```

Each destination sample is exactly `cast(float) sourceSample`.
There is no rounding/clamping/overflow policy because all 256 `ubyte` values
are exactly representable as binary32.

## 7. UFCS shape of the frozen signatures

The existing signatures are UFCS-compatible where the first parameter is the
semantic subject. This inventory records the current mechanical call shape; it
does not create an additional compatibility promise beyond the frozen
underlying signatures.

Examples:

```d
source.trySumFloatToDouble(planeIndex, sum);
destination.tryFillRasterPlane(planeIndex, value);

source.tryCopyRasterPlane(
    sourcePlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);

source.tryConvertUbyteToFloatPlane(
    sourcePlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);

source.tryTransformRasterPlane!transform(
    sourcePlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);

source.tryApplyRasterNeighbourhood3x3!kernel(
    sourcePlaneIndex,
    sourceOutputRegion,
    destination,
    destinationPlaneIndex,
    error
);

resource.tryImportOwnedRaster!T(
    planes,
    residentRegion,
    lease
);
```

`tryAdoptMallocResource` begins with a raw pointer and is not an ergonomic
semantic-object UFCS family.

Member geometry/view operations already use member syntax and therefore need no
separate UFCS family.

## 8. Package/internal surfaces — explicitly not public

### 8.1 construction, validation and raw import

Not part of the external API:

- `raster.resource`;
- `raster.validation`;
- `raster.construction`;
- `raster.import_single_resource`;
- raw `RasterBacking` construction;
- raw `RasterView` / `WritableRasterView` factories;
- byte-layout conversion errors/results.

### 8.2 execution layout and dispatch

Package-internal:

- `PlaneExecutionLayout2D`;
- `PlaneExecutionTraits`;
- execution stride/base queries;
- `RasterTargetPlane`;
- Mir adapters;
- scalar and fixed-lane kernels;
- compiler capability helpers;
- affine relation / physical-range helpers;
- transform, fill, copy, conversion, reduction and neighbourhood dispatch.

These select execution mechanisms only; they do not extend public semantics.

### 8.3 dependency and streaming/materialization contracts

Current request/dependency machinery is package-internal:

```text
DependencyMargins
ContextDeficit
ExpandedDependency
tryExpandDependency

RequestMaterializationPlan
tryPlanRequestMaterialization

RequestMaterializationError
tryMaterializeRequest
```

The materialization source concept is structural/internal: a source must provide
a compatible `materializeInto(Region2D, WritableRasterView!T)` operation.
There is no public source/provider/scheduler interface in v0.1.

### 8.4 residency and retained-store machinery

Package-internal:

```text
ResidencyBudget

RetainedStoreInsertResult
RetainedRasterStore!(T, Key, EntryCapacity, hashKey, sameKey)

RetainedBlockDescriptor!Key
DependencyBlockResolveError
DependencyBlockResolveStats
```

These are control-plane mechanisms and do not define public cache replacement,
worker, scheduler or persistence policy.

## 9. Scheduling and concurrency contract

The v0.1 public API exposes no:

- worker count;
- task/future/fiber abstraction;
- scheduler;
- affinity policy;
- SMT policy;
- cache replacement policy;
- hidden parallel execution contract.

Public operations are synchronous semantic operations. Internal execution-path
selection must preserve that caller-visible model.

## 10. Attribute and CTFE inventory

Explicitly frozen/verified claims include:

- public operation families compile from `@safe nothrow @nogc` callers where
  documented;
- `Region2D` geometry is `@safe pure nothrow @nogc` and CTFE-capable;
- public view/region properties are `pure` where declared;
- `tryAdoptMallocResource` is intentionally `@system nothrow @nogc`;
- `tryImportOwnedRaster` is `@safe` but does not claim `nothrow/@nogc`;
- transform and neighbourhood callables carry compile-time
  `@safe pure nothrow @nogc` requirements;
- DIP1000 lifetime behavior is part of the external compile-contract probes.

No stronger CTFE or purity claim is inferred for operations that do not declare
it.

## 11. v0.2 design implications from the inventory

This section records observations only; it does not select the v0.2 API.

1. The current public API is operation-by-operation rather than a fully
   normalized family.
2. Ownership, retained lifetime, read view and writable view are already
   distinct semantic capabilities and should not be collapsed accidentally.
3. The generic sample constraint is already broader than numeric-only raster
   data.
4. Copy/transform/neighbourhood share a closely related validation/error shape.
5. Conversion is currently one concrete `ubyte -> float` operation, not yet a
   general conversion family.
6. Reduction is currently one concrete strict `float -> double` sum.
7. Streaming/dependency/residency mechanisms exist internally but no public
   provider/scheduler abstraction is frozen.
8. Internal layout/dispatch specialization is intentionally hidden and remains
   free to evolve behind observable semantics.
9. Existing source-before-destination ordering and named parameters are frozen
   v0.1 compatibility facts that v0.2 family design must treat explicitly.
10. Any v0.2 family unification must preserve or deliberately version the
    root-import, lifetime, error, named-argument, attribute and template
    contracts recorded above.

## 12. M0.3 completion checklist

- [x] public and package/internal surfaces separated;
- [x] complete current package-root re-export list recorded;
- [x] sample/template legality recorded;
- [x] retained ownership/lifetime/view surfaces recorded;
- [x] region/layout surfaces recorded;
- [x] copy/fill/transform/conversion/reduction/neighbourhood surfaces recorded;
- [x] internal streaming/dependency/residency contracts recorded;
- [x] current mechanical UFCS forms recorded;
- [x] CTFE/attribute claims recorded without strengthening them;
- [x] no production API change made.
