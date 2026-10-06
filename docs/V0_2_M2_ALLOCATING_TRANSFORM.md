# raster-d v0.2 M2.2 — allocating transform convenience

Status: implementation candidate for Issue #96.

Baseline:

~~~text
develop
5dceb29ad8d06d09d9f0fa7c4ebdbb051b60c3b0
~~~

## 1. Decision

The allocating transform convenience is justified, but it must remain visibly
secondary to the caller-controlled destination primitive.

Selected API:

~~~d
auto result =
    source.tryTransformAllocated!transform(
        sourcePlaneIndex
    );
~~~

The name deliberately contains Allocated.

The result type is:

~~~text
RasterAllocatedTransformResult!T
~~~

and exposes a retained output owner through lease().

## 2. Why RasterLease is the production payload today

M1 designed Raster!T as the final semantic owner, but Raster!T has not yet been
promoted to production code.

The existing qualified retained owner is RasterLease!T.

M2.2 therefore does not invent a placeholder Raster!T or a second ownership
architecture.

The current materialization path publishes RasterLease!T.

When Raster!T is implemented, the convenience result may change its public owner
payload in the corresponding API-promotion work while retaining the same
allocation and transform semantics.

## 3. Fundamental primitive remains transformInto

M2.2 introduces no transform executor.

Successful execution is:

~~~text
validate source plane
    |
    v
allocate compact retained destination
    |
    v
obtain WritableRasterView
    |
    v
source.transformInto!transform(...)
~~~

All pixel semantics, layout-independent source traversal, alias behavior and
callable constraints therefore remain single-sourced in transformInto /
tryTransformRasterPlane.

Caller-owned reusable destination storage remains the performance-oriented path.

## 4. Result representation

A successful result contains one independently owned logical plane:

~~~text
sample type       T
plane count       1
resident origin   0,0
width             source.width
height            source.height
sample stride     1
row layout        compact row-major
ownership         independent retained raster-d storage
writability       read-write provenance
~~~

Only the selected source plane is materialized.

The source's original plane index is not preserved as an output plane number;
the result plane is always index 0.

## 5. Allocation route

For non-empty output:

~~~text
checked width/height/sample byte arithmetic
    |
    v
malloc-compatible pixel storage
    |
    v
OwnedByteResource
    |
    v
PlaneByteLayout[1]
    |
    v
tryImportOwnedRaster!T
    |
    v
RasterLease!T
~~~

This follows the M1.2 ownership route and keeps release obligations behind the
existing transactional importer.

## 6. Zero-area result

transformInto defines matching empty shapes as successful no-op execution.

M1.2 and M1.5 also require valid zero-area owned rasters without fabricating a
pixel.

The public OwnedByteResource import intentionally represents a real physical
resource and rejects an empty ownership token.

Therefore zero-area allocation uses the already-existing lower retained
construction boundary directly:

~~~text
no physical ResourceEntry
one PlaneDescriptor with null base
empty Region2D
    |
    v
constructRetainedRaster
    |
    v
metadata-only one-plane RasterLease
~~~

This is valid under existing backing validation:

- empty regions have no reachable sample;
- no physical pixel allocation is required;
- writable certification succeeds vacuously for empty geometry;
- planeCount remains 1, unlike RasterLease.init.

This is a documented narrow exception to the ordinary
OwnedByteResource -> import route, required to preserve the established empty
raster contract.

## 7. Callable contract

The callable is unchanged from transformInto:

~~~text
@safe pure nothrow @nogc T -> T
~~~

It remains a compile-time alias.

M2.2 does not add:

- runtime callable type erasure;
- stateful transform objects;
- string mixins;
- a second generated kernel family;
- image-domain numeric policy.

## 8. Failure model

RasterAllocatedTransformError distinguishes:

~~~text
invalidSourcePlane
sizeOverflow
allocationFailed
backingConstructionFailed
writableDestinationUnavailable
transformFailed
internalFailure
~~~

For transformFailed, the underlying RasterTransformError is retained separately.

The default RasterAllocatedTransformResult state is failure.

Failure publishes no retained output owner.

## 9. Failure atomicity

Before allocation:

- invalid source plane fails immediately.

After physical allocation:

- ownership is immediately placed behind OwnedByteResource;
- import either transfers ownership to RasterLease, leaves the token armed, or
  releases after commit according to the existing transactional contract.

After retained construction:

- failure to obtain writable capability destroys the local owner normally;
- transform failure destroys the local independent output normally.

No partial output owner is published.

Source storage is never transferred or modified by the convenience layer.

## 10. Aliasing

A successful allocated result uses independent storage.

Therefore source/result physical overlap is impossible by construction.

The transformInto overlap check remains in force anyway because M2.2 delegates
to the exact same public semantic operation instead of bypassing it.

No public backing-identity query is introduced.

## 11. UFCS

The semantic source remains the first parameter.

Canonical use:

~~~d
auto result =
    source.tryTransformAllocated!op(
        planeIndex
    );
~~~

The callable is one free function; no duplicate member implementation is added.

## 12. Allocation visibility

Allocation is not hidden:

- Allocated is present in the function name;
- the operation documentation explicitly says it materializes new storage;
- the result type is allocation/materialization-specific;
- transformInto remains available for caller-controlled storage reuse.

This satisfies the workspace allocation contract without making ordinary
transformInto allocate.

## 13. Performance contract

No speedup claim is made for tryTransformAllocated.

Its cost includes:

~~~text
pixel storage allocation
retained metadata construction
writable certification
transformInto pixel traversal
owner publication
~~~

The operation is intended for convenience, not repeated hot-loop destination
reuse.

Callers concerned with allocation count, reuse or stable latency should allocate
or retain their destination separately and call transformInto.

## 14. Tests

The implementation covers:

- root-package UFCS use;
- invalid source plane before output publication;
- signed-stride source semantic preservation;
- compact origin-normalized output;
- independent writable output storage;
- zero-area one-plane retained result with no pixel allocation;
- DMD and LDC through Fast CI.

The existing transformInto suite continues to own exhaustive transform semantic
and layout qualification.

## 15. Explicit non-goals

M2.2 does not implement:

- Raster!T production owner;
- generic public allocateRaster;
- clone;
- multi-plane allocating transform;
- cross-type transform;
- configurable output layout;
- allocator policy objects;
- alignment policy;
- scheduler/worker ownership;
- SIMD selection;
- hidden parallelism.

## 16. Acceptance mapping

Issue #96:

- allocation explicit in documentation: yes;
- semantics match transformInto: execution delegates to transformInto;
- no second algorithm implementation: yes;
- caller-controlled destination path remains performance-oriented primitive:
  yes.

The implementation is ready to close #96 once DMD and LDC Fast CI are green.
