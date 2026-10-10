# raster-d v0.2 M1.4 — ROI and subregion semantics

Status: **contract freeze for v0.2 subregions**

Baseline:

~~~text
branch: develop
commit: b1084de2694a5b8c25f07aa779ad0d77056934d2
~~~

Issue: #92 — M1.4 Define ROI and subregion semantics

## 1. Scope

This contract applies to semantic subregions produced from:

- `RasterView!T`;
- `WritableRasterView!T`;
- the M1.3 `RasterPlaneView!T` design;
- the M1.3 `WritableRasterPlaneView!T` design;
- row subviews, which are defined as height-1 plane ROIs.

It freezes caller-visible geometry and lifetime semantics.

It does not expose or freeze physical execution layout.

## 2. Coordinate model

A `Region2D` has:

~~~text
x, y      origin in an enclosing coordinate space
width     horizontal extent
height    vertical extent
~~~

`Region2D` itself remains coordinate-space neutral.

For a raster/view ROI call, the argument is interpreted **relative to the
current parent view origin**.

Given:

~~~text
parent.region = (px, py, pw, ph)
relative      = (rx, ry, rw, rh)
~~~

a successful child has:

~~~text
child.region = (px + rx, py + ry, rw, rh)
~~~

in the same resident descriptor-space coordinate system as the parent.

ROI coordinates are not global dataset/image coordinates.

## 3. Containment

A relative child is contained iff all of these hold without overflow:

~~~text
rx <= pw
ry <= ph
rw <= pw - rx
rh <= ph - ry
~~~

This subtraction form is normative.

Unchecked expressions such as:

~~~text
rx + rw <= pw
~~~

must not be used as the semantic definition because they may overflow.

The parent itself must also have a representable translated extent.

## 4. Empty regions

A region is empty iff:

~~~text
width == 0 || height == 0
~~~

Empty ROIs are valid when geometrically contained.

This includes one-past boundary positions.

For a parent width 4 and height 3:

~~~text
Region2D(4, 3, 0, 0)
~~~

is valid.

But:

~~~text
Region2D(5, 3, 0, 0)
Region2D(4, 4, 0, 0)
~~~

are not contained.

An empty ROI contains no readable or writable sample and must not require
forming a pixel pointer.

## 5. Empty parent regions

An empty parent is still valid geometry.

Containment is determined by the same rules, not by a special "all children
fail" rule.

Example:

~~~text
parent = Region2D(size_t.max, 7, 0, 2)
~~~

may validly contain:

~~~text
relative = Region2D(0, 0, 0, 2)
~~~

because no x sample is reachable and the translated extent remains
representable.

But relative x > 0 is outside that zero-width parent.

## 6. Representability

ROI resolution must reject:

- an unrepresentable parent translated extent;
- a child outside the parent;
- x translation overflow;
- y translation overflow;
- an unrepresentable resolved child extent.

On failure, resolved geometry is reset to `Region2D.init`.

## 7. Nested ROI composition

ROI is compositional.

If:

~~~text
A = root.roi(r1)
B = A.roi(r2)
~~~

and both operations succeed, then B is semantically equivalent to a direct
root ROI whose relative origin is the composed offset and whose extent is r2.

No new storage or descriptor table is created by composition.

Nested ROI operations accumulate resident coordinates while preserving the same
underlying storage interpretation.

## 8. Failure state

For current `tryRoi` APIs:

~~~text
success = false
return  = ViewType.init
~~~

on failure.

A failed ROI operation:

- does not publish a partially valid view;
- does not mutate parent geometry;
- does not mutate pixel data;
- does not alter ownership;
- does not alter writable certification.

This deterministic failure state is part of the public contract.

## 9. Storage ownership

ROI is always non-owning.

It:

- allocates no pixel storage;
- copies no pixel data;
- creates no release obligation;
- does not retain an independent backing owner.

A child view remains a borrow.

## 10. Descriptor and backing relation

ROI preserves the existing validated descriptor/backing relationship.

It may narrow the represented region, but it does not reinterpret or rebuild
the physical layout.

The child therefore continues to use the same logical plane descriptors and
retained physical resources as its parent.

This identity is an implementation invariant; raw descriptor identity remains
non-public.

## 11. Signed and negative strides

ROI semantics are independent of stride sign.

Valid parent layouts may use:

- positive row stride;
- negative row stride;
- positive sample stride;
- negative sample stride;
- combinations thereof where validated.

ROI does not normalize these layouts.

Instead it changes only the logical/resident region.

For a sample in a child ROI, the physical address is still derived from the
parent descriptor's signed strides using the resolved resident coordinates.

## 12. Layout neutrality

Creating a subregion does not imply:

- contiguity;
- canonical row layout;
- positive strides;
- unit sample stride;
- alignment suitable for SIMD;
- no padding.

A narrower ROI may change internal execution classification, but that
classification is not part of ROI semantics.

For example, a full parent may be flat contiguous while a narrow multi-row ROI
is only canonical/strided.

## 13. Aliasing

ROI creation establishes **no uniqueness or noalias guarantee**.

Two valid ROIs may:

- be disjoint;
- partially overlap;
- be identical;
- have one contain the other.

If their logical coordinates resolve to the same physical sample bytes, they
alias those bytes.

Read-only overlapping views observe the same underlying values.

Writable overlapping views observe each other's writes according to ordinary
program order.

No concurrency or race guarantee is implied.

## 14. Writable provenance

A writable child ROI may be created only from an already certified writable
parent capability.

Writable certification is inherited because the child reachable sample set is
a subset of the parent's certified reachable sample set.

ROI does not perform a weaker "const cast" or qualifier-based recovery of write
access.

A read-only parent can never produce a writable ROI.

A const-qualified writable capability cannot be used to manufacture a new
mutable child capability.

## 15. Read/write symmetry

The geometry rules are identical for read and writable views.

The capability result differs only in authority:

~~~text
RasterView!T
    -> RasterView!T

WritableRasterView!T
    -> WritableRasterView!T

RasterPlaneView!T
    -> RasterPlaneView!T

WritableRasterPlaneView!T
    -> WritableRasterPlaneView!T
~~~

No operation upgrades authority.

## 16. Plane subregions

A plane ROI uses the same relative geometry rules as a full raster view.

The logical plane selection is preserved.

A plane ROI does not regain access to any other plane.

No plane index is reintroduced into the subregion operation.

## 17. Row semantics

Per M1.3, a row is exactly a plane ROI:

~~~text
Region2D(
    0,
    y,
    plane.width,
    1
)
~~~

Therefore:

- row index must satisfy `y < height`;
- a row has height 1;
- width equals the current plane width;
- arbitrary sample stride remains valid;
- no `T[]` contiguity guarantee follows.

An empty plane has no valid row index.

## 18. Sample coordinates inside a child

Sample coordinates passed to a child view are relative to the child origin.

For child region:

~~~text
Region2D(cx, cy, cw, ch)
~~~

a child sample coordinate:

~~~text
(x, y)
~~~

resolves to resident descriptor coordinates:

~~~text
(cx + x, cy + y)
~~~

subject to:

~~~text
x < cw
y < ch
~~~

This is independent of the physical stride representation.

## 19. Lifetime

A child ROI remains transitively bound to the lifetime of the backing owner from
which the parent borrow originates.

Conceptually:

~~~text
Raster / RasterLease owner
    -> view
        -> ROI
            -> nested ROI / plane / row
~~~

A child cannot outlive that borrow chain.

Creating another owner copy that happens to retain the same backing does not
retroactively detach an existing child borrow from the owner variable from
which it was derived.

The existing DIP1000 compile-negative ROI probes remain normative evidence for
this relation.

## 20. Safety

ROI/subregion creation should remain:

~~~text
@safe
pure
nothrow
@nogc
~~~

where the current view APIs already establish these attributes.

Unsafe pointer arithmetic is not part of the public ROI operation.

Any eventual plane-view implementation must preserve the same small trusted
boundary model.

## 21. Complexity and allocation

Successful or failed ROI creation is control-plane work.

Expected complexity:

~~~text
time:       O(1)
pixel copy: O(0)
heap pixel allocation: none
~~~

No child creation may traverse pixel samples merely to establish the subregion.

## 22. Executable invariants

M1.4 adds explicit `dub test` coverage for:

- nested ROI composition equivalence;
- valid one-past empty child;
- rejection beyond one-past boundary;
- empty-parent containment;
- deterministic `Region2D.init` on geometry failure;
- negative row + sample stride preservation;
- overlapping read-only aliasing;
- overlapping writable aliasing;
- inherited writable certification;
- deterministic default view on ROI failure;
- no mutation caused by failed ROI creation.

Existing tests additionally cover:

- basic ROI translation;
- interleaved ROI behavior;
- descriptor-block reuse;
- empty ROI sample failure;
- execution-layout reclassification after ROI;
- writable ROI mutation;
- negative row stride;
- negative sample stride.

Existing compile-negative probes cover transitive borrow escape and writable
const restrictions.

## 23. What M1.4 does not add

M1.4 does not introduce:

- clipping ROI requests automatically to bounds;
- wraparound coordinates;
- negative logical x/y coordinates;
- global dataset coordinates;
- border synthesis;
- clamp/mirror/wrap edge policy;
- copy-on-subregion;
- independent retained subregion ownership;
- noalias claims;
- thread-safety claims;
- public physical stride properties.

Those require separate semantics.

## 24. Relationship to neighbourhood/border work

ROI containment is strict.

A request that needs samples outside the current valid region is not silently
expanded or clamped by ROI.

Neighbourhood dependency expansion and border policy remain separate concerns.

This keeps:

~~~text
subregion geometry
!=
halo/dependency derivation
!=
border synthesis
~~~

## 25. Compatibility

M1.4 freezes the semantics already implemented by the v0.1:

- `Region2D.containsRelative`;
- `Region2D.tryResolveRelative`;
- `RasterView.tryRoi`;
- `WritableRasterView.tryRoi`.

It does not change their signatures.

The M1.3 plane-view family must implement the same rules when promoted.

## 26. M1.4 acceptance checklist

- [x] coordinate model is explicit;
- [x] relative vs resident coordinates are explicit;
- [x] empty-region boundary behavior is explicit;
- [x] bounds and overflow behavior are explicit;
- [x] nested ROI composition is explicit;
- [x] failure state is deterministic;
- [x] signed/negative strides remain valid and unchanged;
- [x] aliasing is allowed and does not imply noalias;
- [x] writable certification is inherited only from writable parents;
- [x] lifetime remains transitively tied to retained backing;
- [x] O(1)/zero-copy semantics are explicit;
- [x] applicable invariants have executable tests;
- [x] existing DIP1000 lifetime probes remain applicable;
- [x] no new production API is introduced by this contract freeze.
