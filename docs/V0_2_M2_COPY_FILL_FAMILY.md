# raster-d v0.2 M2.5 — copy/fill API family reconciliation

Status: implementation candidate for Issue #99.

Baseline:

~~~text
develop
e69acd27e14ef6fb273e8058596bade9de2b02a9
~~~

## 1. Decision

The existing copy and fill implementations are already generic, layout-aware,
allocation-free and semantically complete.

M2.5 therefore does **not** replace or rewrite their execution machinery.

v0.2 adds only the reconciled destination-oriented names:

~~~text
copyInto
fill
~~~

The frozen v0.1 names remain public and source-compatible:

~~~text
tryCopyRasterPlane
tryFillRasterPlane
~~~

## 2. v0.2 copy family

Canonical form while plane views are not yet production types:

~~~d
copyInto(
    source,
    sourcePlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);
~~~

UFCS:

~~~d
source.copyInto(
    sourcePlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);
~~~

The eventual plane-view form remains conceptually:

~~~d
sourcePlane.copyInto(destinationPlane);
~~~

The current plane indices are compatibility plumbing, not semantic names to
preserve forever.

## 3. copyInto semantics

copyInto delegates directly to tryCopyRasterPlane.

Therefore the existing RasterCopyError remains authoritative:

~~~text
none
invalidSourcePlane
invalidDestinationPlane
shapeMismatch
nonInjectiveDestination
sourceDestinationOverlap
~~~

Inherited guarantees:

- source and destination must have matching logical shape;
- matching empty geometry succeeds as a no-op;
- destination must be injective;
- exact source/destination sample-byte overlap is rejected before writing;
- shared backing is valid when reachable sample bytes are disjoint;
- every already-valid signed affine layout is supported;
- no allocation;
- no retention;
- no hidden scheduling;
- all semantic request failure occurs before destination modification.

No new error enum is introduced.

## 4. v0.2 fill family

Canonical form while WritableRasterPlaneView is not yet production:

~~~d
fill(
    destination,
    planeIndex,
    value
);
~~~

UFCS:

~~~d
destination.fill(
    planeIndex,
    value
);
~~~

The eventual plane-view form remains conceptually:

~~~d
destinationPlane.fill(value);
~~~

## 5. fill semantics

fill delegates directly to tryFillRasterPlane.

Inherited guarantees:

- planeIndex must select a logical destination plane;
- valid empty geometry succeeds as a no-op;
- every valid signed affine writable layout is supported;
- non-injective mappings are allowed because repeated writes of the same exact
  T value are idempotent;
- no allocation;
- no retention;
- no scheduler or execution-policy surface.

The existing bool result completely represents the one request failure category:
invalid plane selection.

A second error enum would weaken rather than improve the contract, so none is
introduced.

## 6. Compatibility

M2.5 preserves v0.1 source compatibility exactly.

Still root-exported:

~~~text
tryCopyRasterPlane
tryFillRasterPlane
RasterCopyError
~~~

New additive v0.2 root exports:

~~~text
copyInto
fill
~~~

No parameter order, error value, attribute, overlap rule, empty behavior or
layout support is changed on the v0.1 names.

## 7. Specialized-name policy

The names tryCopyRasterPlane and tryFillRasterPlane are retained because they
are frozen v0.1 API.

They are **not** retained as the preferred v0.2 naming model.

The word RasterPlane in those names reflects the pre-plane-view compatibility
surface, not a distinct algorithm family.

No new names such as:

~~~text
copyRasterPlaneInto
fillRasterPlane
copyPlaneInto
fillPlaneInto
~~~

are added.

Specialized naming remains justified only when it carries a real semantic
distinction. Copy and fill do not need such additional variants here.

## 8. Implementation sharing

The v0.2 wrappers contain no execution logic.

~~~text
copyInto
    -> tryCopyRasterPlane
        -> existing copy dispatch

fill
    -> tryFillRasterPlane
        -> existing fill dispatch
~~~

This preserves all already-qualified copy/fill specialization and avoids
creating parallel hot paths.

Any future performance work belongs below the existing dispatch layers, where
both v0.1 and v0.2 names benefit automatically.

## 9. Why copy is not reimplemented through transformInto

Semantically, identity transform could appear similar to copy.

M2.5 deliberately does **not** route copy through transformInto because the
existing copy engine has copy-specific optimized semantics and dispatch,
including established memcpy/layout specialization and its own qualified error
mapping.

Replacing it with a point-transform identity callable would be implementation
churn, could regress code generation, and would erase a real semantic
distinction: copy is a primitive storage-preserving semantic operation, not a
user-defined transform.

Implementation sharing is maximized where contracts are actually shared
without forcing unrelated hot paths through one abstraction.

## 10. Why fill is not reimplemented through transformInto

Fill has no source.

Its destination may also be validly non-injective because writing the same exact
value repeatedly is idempotent.

That differs materially from transformInto/copy destination semantics.

Therefore fill retains its own established semantic primitive and internal
dispatcher.

The v0.2 reconciliation is naming/UFCS only.

## 11. UFCS

M1.6 rules are followed:

Copy has a natural source subject:

~~~text
source.copyInto(...)
~~~

Fill has no source, so destination is the semantic subject:

~~~text
destination.fill(...)
~~~

No duplicate member implementations are added.

Both are ordinary free functions.

## 12. Attributes and allocation

Both v0.2 names preserve:

~~~text
@safe
nothrow
@nogc
~~~

They allocate no storage and retain no operands.

No policy object is introduced because neither operation has an unresolved
policy dimension in its current semantics.

## 13. Testing

The implementation adds direct root-import compile/execution evidence for both
ordinary-call and UFCS forms:

~~~text
copyInto(...)
source.copyInto(...)

fill(...)
destination.fill(...)
~~~

Existing copy/fill unit tests remain authoritative for successful layout,
overlap, non-injective and empty behavior because the new names delegate
directly to those implementations.

DMD and LDC Fast CI qualify both surfaces together.

## 14. Acceptance mapping

Issue #99 requires:

- v0.1 compatibility impact explicit:
  yes, additive only; frozen names remain unchanged;

- specialized names retained only where real semantic distinctions exist:
  legacy specialized names remain only for compatibility; no new specialized
  v0.2 variants are introduced;

- implementation sharing maximized without weakening contracts:
  yes, v0.2 names directly delegate to the existing qualified copy/fill
  primitives and retain their distinct semantics.

The PR is ready to close #99 once DMD and LDC Fast CI are green.
