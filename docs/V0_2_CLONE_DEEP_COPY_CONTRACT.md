# raster-d v0.2 M1.5 — explicit clone / deep-copy semantics

Status: **design contract for review; no production clone implementation in this change**

Baseline:

~~~text
branch: develop
commit: b086efd98bfa84834025b2d6139eb90d7badc9d9
~~~

Issue: #93 — M1.5 Define explicit clone/deep-copy semantics

## 1. Decision

v0.2 defines clone as an explicit materializing deep copy.

~~~text
ordinary Raster copy
    O(1)
    shared retained backing
    no pixel traversal

clone(source)
    explicit allocation
    O(pixel count)
    independent retained Raster
    semantic pixel copy
~~~

No ordinary assignment or owner copy may silently deep-copy pixels.

## 2. Canonical semantic source

The canonical semantic source is RasterView!T.

~~~text
RasterView!T -> independent Raster!T
~~~

This supports cloning:

- a complete Raster owner through its read view;
- a RasterLease view;
- an ROI;
- any later semantic view that can expose the same read contract.

A Raster!T convenience overload may later delegate to its read view.
Final spelling and overloads remain M1.6 work.

## 3. Preserved semantics

After success, clone preserves:

- sample type T;
- logical plane count;
- plane order;
- width;
- height;
- every reachable semantic sample value.

For every valid plane p and relative coordinate x,y:

~~~text
clone[p,x,y] == source[p,x,y]
~~~

The equality is semantic, not byte-layout identity.

## 4. Physical layout is not cloned

Clone deliberately does not preserve:

- row stride;
- sample stride;
- stride sign;
- row padding;
- planar/interleaved source representation;
- physical allocation count;
- resource identity;
- descriptor base addresses;
- alignment accidents;
- execution-layout classification.

Those are representation details.

## 5. Canonical destination layout

The default v0.2 clone result uses one canonical owned representation:

~~~text
T                  same as source
plane count        same as source
resident origin    0,0
width/height       same extents as source
plane layout       compact planar
sample stride      1
row stride         width
plane storage      sequential planes
ownership          independent raster-d-owned backing
~~~

No public clone-layout policy hierarchy is introduced.

## 6. Resident origin normalization

Region2D.x/y in RasterView are resident descriptor-space coordinates, not global
dataset/image coordinates.

A source ROI may therefore have a non-zero resident origin while its descriptors
still describe a larger backing.

Preserving that origin in a newly compact allocation would require undesirable
prefix allocation, invalid/outside-allocation descriptor bases, or retention of
unrelated source padding.

Therefore clone normalizes the independent destination to:

~~~text
Region2D(0, 0, source.width, source.height)
~~~

while preserving extents and semantic sample values.

Higher layers that own global image placement must preserve that metadata
outside generic Raster.

## 7. ROI clone

Cloning an ROI materializes only the ROI semantic matrix.

Example:

~~~text
source ROI region     110,220,20,10
clone region          0,0,20,10
clone sample values   equal to source ROI relative coordinates
~~~

The parent extent and descriptor-space offset are not materialized.

## 8. Ownership and lifetime

A successful clone owns independent retained backing.

Consequences:

- destroying source does not invalidate clone;
- destroying clone does not invalidate source;
- mutating clone cannot mutate source;
- mutating source after completion cannot mutate clone;
- ordinary copies of clone may share the clone new backing.

The successful result must not retain or borrow source metadata.

Source must remain alive only for the synchronous duration of clone.

## 9. Writable result

Clone allocates new raster-d-owned storage with read-write resource provenance.

A read-only source may therefore produce an independently writable clone.

Writable access still passes through the ordinary certification path.
Clone does not upgrade source authority.

## 10. Aliasing

Source and successful clone result do not alias by contract.

This is stronger than destination-oriented copy, which must handle possible
source/destination overlap.

Clone independence must be tested behaviorally rather than by exposing backing
identity:

- mutate clone, source unchanged;
- mutate source, clone unchanged.

## 11. Concurrency

Clone is synchronous.

It introduces no hidden scheduler, worker pool, future or background copy.

No snapshot guarantee is made against concurrent unsynchronized source mutation.
Callers that require a stable snapshot provide synchronization.

## 12. Failure model

Clone is fallible because it allocates and because output-size arithmetic may be
unrepresentable.

M1.5 follows the M1.2 result-carrier direction.

Provisional semantic errors:

~~~text
none
invalidSource
sizeOverflow
allocationFailed
backingConstructionFailed
copyFailed
internalFailure
~~~

Exact names and accessors remain M1.6 work.

Failure publishes no Raster owner.

## 13. Failure atomicity

On failure:

- source remains unchanged;
- no partial Raster is published;
- no destination view is published;
- any allocated destination resource is released exactly once;
- no source ownership is transferred;
- result retains no destination backing.

Caller cleanup of partial pixel storage must never be required.

## 14. Default versus valid empty source

RasterView!T.init has zero planes and is not a valid raster representation for
clone. Cloning it fails explicitly.

A valid raster with one or more planes and zero width and/or height is clonable.

The successful empty clone preserves plane count and zero extents, normalizes
origin to 0,0, and requires no pixel-byte copy.

Implementation must not fabricate a readable pixel solely to satisfy an
allocation helper.

## 15. Checked allocation arithmetic

For non-empty input:

~~~text
samplesPerPlane = width * height
bytesPerPlane   = samplesPerPlane * T.sizeof
totalBytes      = bytesPerPlane * planeCount
~~~

Every multiplication is checked before allocation.

The canonical strides must also be representable in the existing signed stride
types.

No wrapping or truncated allocation is allowed.

## 16. Multi-plane clone

Clone preserves homogeneous plane count and order.

The destination uses compact planar sequential storage:

~~~text
plane 0
plane 1
...
plane N-1
~~~

No RGB, alpha, channel-role, heterogeneous sample type or per-plane geometry
semantics are added.

## 17. Legal source layouts

Clone must preserve semantic pixels from every already-valid source layout:

- compact contiguous;
- padded rows;
- sample-strided;
- planar;
- interleaved;
- negative row stride;
- negative sample stride;
- accepted affine combinations;
- ROI views with non-zero resident origin.

Source contiguity is not a precondition.

## 18. Reuse the existing copy engine

Clone should not create a second semantic copy engine.

Implementation direction:

~~~text
validate semantic source
    -> checked canonical allocation
    -> retained writable destination backing
    -> for each plane use existing same-type copy machinery
    -> publish Raster only after every plane succeeds
~~~

Because destination storage is newly independent, overlap rejection should be
impossible in a correct clone implementation. If observed, it is an internal
invariant failure.

## 19. Post-allocation failure

If destination ownership has already been established and a later plane copy or
backing step fails:

- destination remains internal;
- it is destroyed before returning;
- resources release exactly once;
- no partial clone escapes.

Failure injection should test this only through a real internal seam; public
copy semantics must not be weakened merely to manufacture a test.

## 20. Initialization

Successful clone publication occurs only after every reachable destination
sample has been written from source.

Thus no uninitialized destination sample becomes publicly reachable.

Empty rasters have no reachable samples and require no fill pass.

## 21. Cost model

For P planes and W x H semantic extent:

~~~text
time             O(P * W * H)
metadata work    O(P)
pixel allocation explicit
pixel copy       explicit
~~~

Clone is not a no-allocation operation and does not promise @nogc.

Internal fast paths may use:

- flat bulk copy;
- row-wise canonical copy;
- general affine copy.

Those remain implementation details.

## 22. Clone versus copyInto

~~~text
clone
    allocates destination
    produces independent owner

copyInto
    caller provides destination
    no pixel-storage allocation
~~~

Clone may internally reuse copyInto/copy-plane machinery, but the public cost
models stay distinct.

## 23. Clone versus adopt

~~~text
adopt
    transfers an existing release obligation
    need not copy pixels

clone
    creates a new release obligation
    copies semantic pixels
~~~

## 24. Clone versus view

~~~text
view
    borrowed
    zero-copy
    lifetime-bound to source

clone
    owning
    materializing
    lifetime-independent after success
~~~

## 25. Safety and attributes

Target direction:

- public @safe where ownership/result-carrier design permits;
- narrow @trusted boundaries for raw allocation and pointer-backed construction;
- not pure;
- no blanket @nogc promise;
- no blanket nothrow promise unless implementation can prove it.

## 26. Test obligations

Implementation must cover semantic preservation for:

- contiguous source;
- padded rows;
- interleaved source;
- negative row stride;
- negative sample stride;
- ROI/non-zero resident origin;
- multiple planes;
- representative legal sample types.

Result-layout tests must prove:

- origin normalized to 0,0;
- width/height preserved;
- plane count/order preserved;
- semantic values preserved;
- destination is canonical compact planar.

Independence tests must prove:

- source can die after clone;
- clone can die without affecting source;
- mutate clone leaves source unchanged;
- mutate source leaves clone unchanged.

Failure tests must cover:

- invalid/default no-plane source;
- width-height overflow;
- byte-count overflow;
- total multi-plane overflow;
- allocation failure;
- backing-construction failure where injectable;
- post-allocation failure where a real seam exists;
- exact-once cleanup.

Lifetime/compile tests must prove:

- successful owner does not borrow source;
- illegal source-borrow escape remains rejected;
- root-import surface when implementation is promoted;
- DMD and LDC.

## 27. Existing evidence

The v0.1 same-type copy engine already tests:

- contiguous copy;
- shared-backing disjoint copy;
- overlap rejection;
- negative-stride destination;
- empty matching shapes.

M1.5 reuses that engine. Clone-specific tests focus on allocation,
normalization, independence, multi-plane publication and failure cleanup.

## 28. Explicit rejections

M1.5 does not introduce:

- implicit deep copy on assignment;
- copy-on-write;
- lazy clone;
- shared backing masquerading as clone;
- hidden background execution;
- physical-layout cloning by default;
- public layout-policy hierarchy;
- global image-coordinate semantics;
- image/channel metadata copying;
- sample conversion;
- resampling;
- border handling;
- heterogeneous plane types.

## 29. M1.6 handoff

M1.6 / #94 owns final API spelling, including:

- exact free-function name;
- owner convenience overload;
- result-carrier access pattern;
- UFCS readability;
- named-argument implications;
- root exports.

M1.5 freezes semantics and cost, not final spelling.

## 30. Decision summary

Accepted:

~~~text
clone
    explicit deep copy
    independent Raster!T
    same T
    same plane count/order
    same width/height
    same semantic sample values
    normalized origin 0,0
    compact planar destination
    no alias with source after success
    synchronous
    fallible explicit allocation
~~~

Preserved:

~~~text
ordinary Raster copy     O(1), shared retained backing
copyInto/copy-plane      destination-oriented, non-allocating
ROI                      borrowed zero-copy view
~~~

Rejected:

~~~text
implicit deep copy
physical-layout cloning
copy-on-write
lazy/background clone
global-coordinate semantics inside generic Raster clone
~~~

## 31. M1.5 acceptance checklist

- [x] deep copy is explicit and distinct from ordinary Raster copy;
- [x] allocation and ownership are explicit;
- [x] semantic pixels are preserved across legal layouts;
- [x] destination layout is canonical rather than copied;
- [x] non-zero resident source origin normalizes to 0,0;
- [x] source and result are independent and non-aliasing;
- [x] result lifetime is independent after success;
- [x] failure is atomic with exact-once cleanup;
- [x] checked multi-plane allocation arithmetic is required;
- [x] valid empty raster is distinct from invalid/default no-plane input;
- [x] existing copy machinery is reused rather than duplicated;
- [x] no hidden scheduling is introduced;
- [x] no production API implementation is promoted by this design change.
