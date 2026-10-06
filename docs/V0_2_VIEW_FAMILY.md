# raster-d v0.2 M1.3 — ergonomic raster view family

Status: **design proposal for review; no production API implementation in this change**

Baseline:

~~~text
branch: develop
commit: f029333cc1a5377700c8dfdfa5116bfeb75fc3c7
~~~

Issue: #91 — M1.3 Add ergonomic raster view family

## 1. Decision

The v0.2 view family keeps the existing owner/read/write split and adds only the
smallest new semantic layer needed to remove repeated plane-index plumbing.

Accepted family:

~~~text
Raster!T
    |
    +-- view ----------------------> RasterView!T
    |
    +-- tryWritableView ----------> WritableRasterView!T
                                    (mutable owner only)

RasterView!T
    |
    +-- tryPlane(index) ----------> RasterPlaneView!T
    |
    +-- tryRoi(relative) ---------> RasterView!T
                                    (existing v0.1 contract)

WritableRasterView!T
    |
    +-- tryPlane(index) ----------> WritableRasterPlaneView!T
    |
    +-- tryRoi(relative) ---------> WritableRasterView!T
                                    (existing v0.1 contract)

RasterPlaneView!T
    |
    +-- tryRoi(relative) ---------> RasterPlaneView!T
    |
    +-- tryRow(y) ----------------> RasterPlaneView!T
                                    with height == 1

WritableRasterPlaneView!T
    |
    +-- tryRoi(relative) ---------> WritableRasterPlaneView!T
    |
    +-- tryRow(y) ----------------> WritableRasterPlaneView!T
                                    with height == 1
~~~

No new Row type is selected.

No borrowed external-storage wrap API is promoted in M1.3.

## 2. Why PlaneView is justified

The current v0.1 public operation family repeatedly carries:

~~~text
RasterView!T + planeIndex
WritableRasterView!T + planeIndex
~~~

That is correct but mechanically noisy.

A first-class plane capability removes that repeated control-plane parameter
while preserving the existing validated descriptor/backing architecture.

The new plane view does not create new storage and does not expose layout
internals.

Conceptually:

~~~text
RasterPlaneView!T
    = RasterView!T borrow
    + one validated logical plane selection
~~~

and:

~~~text
WritableRasterPlaneView!T
    = WritableRasterView!T borrow
    + one validated logical plane selection
~~~

This gives later v0.2 operations a natural subject:

~~~d
sourcePlane.copyInto(destinationPlane);
sourcePlane.transformInto(destinationPlane, transform);
sourcePlane.sum(...);
~~~

without requiring every operation to repeat a plane index.

## 3. Read and write capability remain separate

M1.3 explicitly rejects an inout-based combined plane/view abstraction.

The public capability split remains:

~~~text
RasterView!T
RasterPlaneView!T
    = read-only capability

WritableRasterView!T
WritableRasterPlaneView!T
    = certified writable capability
~~~

A read-only view cannot recover a writable plane.

A const-qualified writable-capability value cannot be used to manufacture a new
mutable child capability.

A const Raster owner may produce a read view only.

A mutable Raster owner may attempt to produce a writable view through the
existing certification path.

## 4. Canonical API style

For new v0.2 surface, the canonical form should be free functions whose first
argument is the semantic subject.

That gives UFCS naturally without creating duplicate member/free-function APIs.

Provisional examples:

~~~d
auto read = view(raster);
auto writable = tryWritableView(raster, success);

auto p = tryPlane(read, 2, success);
auto wp = tryPlane(writable, 2, success);

auto row = tryRow(p, 7, success);
~~~

Via UFCS this reads naturally as:

~~~d
auto read = raster.view();
auto writable = raster.tryWritableView(success);

auto p = read.tryPlane(2, success);
auto row = p.tryRow(7, success);
~~~

The exact spelling remains provisional until M1.6 / #94.

Existing v0.1 member functions are preserved for compatibility.

M1.3 does not add duplicate free-function wrappers for existing v0.1 methods
merely to create syntactic symmetry.

## 5. Owner -> view

The semantic operation is:

~~~text
Raster!T -> RasterView!T
~~~

Requirements:

- zero pixel allocation;
- O(1) retained-borrow work;
- borrow lifetime tied to the Raster owner used to create it;
- no writable capability created;
- Raster.init produces RasterView!T.init;
- no layout or pointer exposure.

The final implementation may delegate to the private RasterLease held by Raster.

No implicit conversion from Raster to RasterView is selected.

## 6. Owner -> writable view

The semantic operation is:

~~~text
mutable Raster!T -> attempt WritableRasterView!T
~~~

Requirements:

- mutable owner receiver;
- preserve the existing complete writable-certification path;
- no assumption that ownership implies writability;
- failure produces no writable capability;
- Raster.init fails cleanly / produces the default writable view according to
  the selected result shape;
- no const owner may recover writable access.

The current RasterLease.tryWritableView behavior is the semantic baseline.

The exact public error/result shape remains implementation work; M1.3 requires
only explicit success/failure.

## 7. RasterPlaneView!T

Provisional semantic shape:

~~~d
struct RasterPlaneView(T)
{
    // private:
    // RasterView!T parent or equivalent borrow
    // size_t planeIndex
}
~~~

Public meaning:

- exactly one logical plane;
- same resident Region2D as the parent view unless further narrowed;
- non-owning;
- read-only;
- no contiguity guarantee;
- no positive-stride guarantee;
- no pointer exposure;
- no allocation;
- same T as the parent raster.

Expected semantic properties:

~~~text
region
width
height
empty
~~~

A plane view does not need planeCount: by definition it represents one plane.

A plane view may expose checked sample access with two-dimensional coordinates:

~~~text
trySample(x, y, out value)
~~~

delegating to the already-validated parent/view semantics.

## 8. WritableRasterPlaneView!T

WritableRasterPlaneView mirrors the read-only plane abstraction but carries the
certified writable capability.

It must not imply:

- uniqueness;
- noalias;
- contiguity;
- thread exclusivity;
- exclusive ownership.

Expected semantic operations:

~~~text
region
width
height
empty
trySample(x, y, out value)
trySetSample(x, y, value)
~~~

Construction is possible only from a WritableRasterView.

No public constructor from raw PlaneDescriptor metadata is admitted.

## 9. Plane selection

Plane selection is a checked O(1) subview operation.

Failure cases:

- index >= parent planeCount.

On failure:

- success is false;
- default plane-view value is returned.

On success:

- the selected plane remains lifetime-bound to the parent borrow;
- no descriptor/resource ownership changes;
- no pixel bytes are copied;
- no descriptor data are exposed publicly.

The selected plane retains the parent's resident Region2D exactly.

## 10. ROI

The current v0.1 tryRoi contract remains authoritative until M1.4 / #92.

M1.3 does not redefine:

- relative coordinate semantics;
- containment rules;
- empty-region legality;
- failure behavior;
- signed-stride behavior;
- writable provenance.

The ergonomic view family only requires that ROI composition remain closed over
the same capability kind:

~~~text
RasterView -> RasterView
WritableRasterView -> WritableRasterView
RasterPlaneView -> RasterPlaneView
WritableRasterPlaneView -> WritableRasterPlaneView
~~~

M1.4 will freeze the detailed subregion contract.

## 11. Row

A row is not a new storage/layout concept.

For a plane view, a row is simply a child region:

~~~text
relative Region2D(0, y, width, 1)
~~~

Therefore M1.3 rejects a third public RowView type.

tryRow returns the same plane-view capability narrowed to height 1.

This preserves:

- arbitrary sample stride;
- negative sample stride where legal;
- padding;
- non-contiguous rows;
- read/write capability;
- lifetime.

Critically, row does **not** promise T[].

A D slice can represent only contiguous element spacing and would silently lose
the general affine raster contract.

If a future consumer needs a contiguous row span, that must be a separately
validated capability query rather than the meaning of row itself.

## 12. Why no T[] row API

The following is rejected as a general row contract:

~~~d
T[] row(...);
~~~

because a legal raster plane may have:

- sampleStrideElements != 1;
- negative sample stride;
- interleaved physical storage;
- other affine layouts.

Returning T[] would either reject valid raster layouts or lie about physical
spacing.

The semantic row remains layout-neutral.

## 13. Why no generic Plane type with inout

A combined form such as:

~~~text
PlaneView!(inout T)
~~~

is rejected.

The distinction between read capability and certified writable capability is
semantic, not cosmetic constness.

Writable provenance is earned through validation/certification and must not be
recoverable merely through qualifier manipulation.

## 14. External borrowed storage wrap

M1.2 deliberately deferred borrowed external storage to M1.3.

M1.3 audits it and does **not** promote a public wrap API yet.

Reason: the current RasterView representation borrows both:

- pixel storage;
- stable PlaneDescriptor metadata.

A convenience wrapper around caller slices would need a durable, testable answer
for descriptor metadata lifetime.

For example, this cannot be added safely merely as syntax:

~~~d
auto view = wrap(samples[], width, height);
~~~

unless the returned view can prove that both the sample bytes and descriptor
metadata outlive it.

Potential future solutions include:

- a separate stack/local wrapper object that owns descriptor metadata but not
  pixels;
- caller-provided stable descriptor storage;
- a revised inline single-plane view representation;
- another explicitly lifetime-bound adapter type.

None is justified yet by a concrete consumer.

Therefore:

~~~text
borrowed external storage wrap
    = deferred / not public in M1.3
~~~

This preserves the M1.2 rule that borrowed storage must never masquerade as a
Raster owner.

## 15. Default-state semantics

All new view capability types must have useful inert .init behavior.

### RasterPlaneView!T.init

Conceptually:

~~~text
region == Region2D.init
width == 0
height == 0
empty == true
no sample is readable
owns nothing
~~~

### WritableRasterPlaneView!T.init

Same geometry/default behavior, with no writable sample reachable.

Destroying either default value performs no resource action.

## 16. Layout neutrality

Plane and row views remain semantic views over the existing raster layout.

They do not expose or promise:

- rowStrideElements;
- sampleStrideElements;
- base pointers;
- execution layout class;
- contiguous memory;
- alignment;
- SIMD suitability.

Those remain internal execution concerns.

Later internal execution adapters may derive fast-path capability from a plane
view without making that metadata public.

## 17. Performance contract

All accepted M1.3 view transformations are control-plane operations.

Expected cost:

~~~text
Raster -> read view             O(1)
Raster -> writable view         O(1) plus existing certification work
RasterView -> plane             O(1)
WritableRasterView -> plane     O(1)
Plane -> ROI                    O(1)
WritablePlane -> ROI            O(1)
Plane -> row                    O(1)
WritablePlane -> row            O(1)
~~~

None copies pixel samples.

None allocates pixel storage.

Ordinary read-plane and row creation should require no heap allocation.

## 18. Later operation-family interaction

The plane view family is specifically intended to simplify M2-M4 APIs.

Current v0.1 shape:

~~~d
tryCopyRasterPlane(
    source,
    sourcePlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);
~~~

Possible v0.2 family shape:

~~~d
sourcePlane.copyInto(destinationPlane);
~~~

Likewise:

~~~d
sourcePlane.transformInto(destinationPlane, transform);
sourcePlane.sum(...);
sourcePlane.convertInto(destinationPlane, policy);
sourcePlane.applyNeighbourhoodInto(destinationPlane, ...);
~~~

This audit does not freeze those later operation signatures.

It establishes only that plane selection can become an explicit semantic
capability rather than a repeated integer parameter.

## 19. Safety and DIP1000

Implementation must preserve the existing borrow graph.

Conceptually:

~~~text
Raster owner
    -> RasterView
        -> RasterPlaneView
            -> row/ROI plane subview
~~~

and:

~~~text
mutable Raster owner
    -> WritableRasterView
        -> WritableRasterPlaneView
            -> writable row/ROI plane subview
~~~

No child may outlive the borrow from which it was derived.

Compile-negative tests must prove escape rejection where DIP1000 can express the
relationship.

No raw pointer needs to enter the public API.

## 20. Attribute direction

View/subview construction should retain the strongest attributes supported by
the existing implementation:

- @safe where no raw capability claim is needed;
- pure for geometry-only subview transformation where valid;
- nothrow;
- @nogc.

Sample access may continue to rely on narrow internal @trusted boundaries just
as the current RasterView/WritableRasterView accessors do.

M1.3 does not strengthen attributes beyond what implementation can prove.

## 21. Root export direction

When implemented, the intended new root-visible semantic types are:

~~~text
RasterPlaneView
WritableRasterPlaneView
~~~

The existing root exports remain:

~~~text
RasterView
WritableRasterView
RasterLease
~~~

Raster itself will be added by its implementation slice.

No internal PlaneDescriptor, execution-layout or certification type becomes a
root export.

## 22. Naming direction

Provisional family vocabulary:

~~~text
view
tryWritableView
tryPlane
tryRoi
tryRow
~~~

Rules:

- use try* where ordinary bounds/capability failure is expected;
- do not use unsafe-sounding names for safe semantic views;
- do not encode physical layout in names;
- do not create readPlane/writePlane duplicate names when type capability
  already distinguishes them;
- final parameter order and UFCS are owned by M1.6.

## 23. Compatibility with v0.1

M1.3 does not remove or alter:

- RasterView;
- WritableRasterView;
- RasterLease.view;
- RasterLease.tryWritableView;
- RasterView.tryRoi;
- WritableRasterView.tryRoi;
- trySample;
- trySetSample.

Those remain frozen v0.1 source surface.

The v0.2 plane family layers above them.

No existing v0.1 member is duplicated by a new free-function synonym merely for
symmetry in this design slice.

## 24. Test obligations for implementation

Positive tests:

- read plane selection from planar layout;
- read plane selection from interleaved layout;
- writable plane selection;
- plane sample read/write;
- plane ROI;
- row subview;
- empty parent;
- empty child;
- signed row stride;
- signed sample stride where legal;
- default .init plane views;
- UFCS form for new free functions;
- root package import.

Negative / failure tests:

- plane index out of range;
- row index out of range;
- writable plane cannot be obtained from read-only view;
- writable plane cannot be recovered from const writable parent;
- child borrow cannot escape parent lifetime;
- no public raw PlaneDescriptor construction path;
- no row operation returns T[] for arbitrary affine layouts.

Compiler coverage:

- DMD;
- LDC;
- DIP1000 modes where relevant.

## 25. Explicit rejections

M1.3 rejects adding now:

- inout-unified read/write view type;
- implicit Raster -> RasterView conversion;
- implicit read -> writable conversion;
- general T[] row access;
- public stride/base-pointer properties;
- public execution-layout enums;
- arbitrary caller-storage wrap;
- a new RowView type without demonstrated need;
- new image/channel semantics;
- plane names or channel roles;
- hidden allocation in view/subview construction.

## 26. Interaction with later M1 issues

M1.4 / #92:

- freezes ROI/subregion coordinate and failure semantics.

M1.5 / #93:

- defines explicit clone/deep copy.

M1.6 / #94:

- audits final free-function spelling, parameter order and UFCS.

Later M2-M4 issues may consume RasterPlaneView/WritableRasterPlaneView as the
semantic operation subjects if implementation evidence confirms the design.

## 27. Decision summary

Accepted:

~~~text
Raster!T
    -> RasterView!T
    -> WritableRasterView!T only through mutable certified path

RasterView!T
    -> RasterPlaneView!T

WritableRasterView!T
    -> WritableRasterPlaneView!T

PlaneView
    -> ROI as same PlaneView type
    -> row as same PlaneView type with height 1
~~~

Deferred:

~~~text
borrowed external storage wrap
~~~

Rejected:

~~~text
inout unified capability
general row T[]
new RowView type without evidence
implicit owner/view conversion
public layout/pointer leakage
~~~

## 28. M1.3 acceptance checklist

- [x] read-only and certified-writable capability families remain separate;
- [x] Raster owner -> view direction is explicit;
- [x] writable view requires mutable owner and certification;
- [x] dedicated plane-view pair removes repeated plane-index plumbing;
- [x] row needs no additional public type;
- [x] row preserves arbitrary affine layout and makes no contiguity promise;
- [x] ROI composition remains closed over capability kind;
- [x] existing v0.1 ROI semantics remain authoritative until M1.4;
- [x] new v0.2 operations prefer one canonical free-function API with UFCS;
- [x] existing v0.1 members are not duplicated merely for syntax;
- [x] external borrowed-storage wrap remains deferred because metadata lifetime
      is not yet safely expressed;
- [x] no hidden allocation or pixel copy is introduced;
- [x] no production API implementation is promoted by this design change.
