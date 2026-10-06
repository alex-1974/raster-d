# raster-d v0.2 M1.2 — ownership construction family

Status: **design proposal for review; no production API implementation in this change**

Baseline:

```text
branch: develop
commit: f3ad77673046abeb2d9b5418e47a67c0c0d61be5
```

Issue: `#90 — M1.2 Define allocate/adopt/wrap ownership family`

## Decision

The v0.2 construction family is separated by ownership semantics:

| Family | Produces `Raster!T` | Ownership | Allocation | Decision |
| --- | --- | --- | --- | --- |
| allocate | yes | raster-d creates and retains new storage | explicit | CORE |
| adopt | yes | caller transfers an explicit ownership token | no pixel copy required | CORE |
| wrap/borrow | no | caller retains ownership | none | defer to M1.3 view family |
| clone | yes | independent new backing | explicit deep copy | defer implementation to M1.5 |
| arbitrary foreign callback adoption | potentially | foreign release obligation transfers | none | ADAPTER-gated |

`Raster!T` remains the M1.1 semantic shared retained owner over the existing
`RasterLease!T` / `RasterBacking` architecture. No constructor may create a
second storage/lifetime system.

## 1. Allocate

Initial allocation is deliberately narrow:

```text
homogeneous T
single logical plane
resident origin (0, 0)
contiguous row-major storage
sample stride = 1
row stride = width
```

This is the smallest useful owned raster and leaves future multi-plane,
planar/interleaved, padded and aligned allocation open without changing
`Raster!T`.

The allocating path must:

- accept checked `width` and `height`;
- reject `width * height` overflow;
- reject sample-count × `T.sizeof` overflow;
- make storage allocation explicit in its API;
- publish no partially valid `Raster!T` on failure;
- use the existing retained backing/import machinery;
- make ordinary library-allocated storage writable, while preserving the
  existing writable-certification boundary.

The resulting resident region is `Region2D(0, 0, width, height)`. Global
dataset placement remains outside `Raster!T`.

A zero-area allocation is valid. It must remain distinguishable from
`Raster!T.init` when the construction contract publishes a one-plane retained
empty raster. No pixel allocation is required for zero logical area.

Provisional vocabulary only:

```d
allocateRaster!T(width, height)
```

The exact public spelling remains subject to implementation review and M1.6.

## 2. Adopt

Adoption keeps the existing two-stage ownership boundary:

```text
raw external allocation
        |
        | explicit unsafe ownership claim
        v
OwnedByteResource
        |
        | safe validated raster adoption
        v
Raster!T
```

The existing `tryAdoptMallocResource` remains the explicit `@system` boundary
for claiming ownership of malloc/free-compatible memory.

The v0.2 Raster adoption path consumes:

```text
OwnedByteResource
PlaneByteLayout[]
Region2D
sample type T
```

and publishes `Raster!T` through the existing `tryImportOwnedRaster!T` /
retained-backing machinery.

Ownership outcomes remain transactional:

### Pre-commit failure

- `OwnedByteResource` remains armed;
- no `Raster!T` is published;
- caller still owns the resource through the token.

### Success

- `OwnedByteResource` is disarmed;
- `Raster!T` retains the backing;
- final retained owner releases the resource exactly once.

### Post-commit failure

- `OwnedByteResource` is disarmed;
- committed ownership is released exactly once;
- no `Raster!T` is published.

The result must expose enough information to distinguish these outcomes.

## 3. Wrap / borrow

`wrap` is **not** an owning Raster constructor.

A borrowed external buffer has no independently retained lifetime, therefore it
must not produce `Raster!T`.

Conceptually:

```text
caller-owned storage
        |
        | lifetime-bound borrow
        v
RasterView!T / WritableRasterView!T
```

A public borrowed-storage wrapper is deferred to M1.3 because it must solve:

- descriptor metadata lifetime;
- bounds validation;
- writable provenance;
- signed strides;
- multi-plane metadata;
- DIP1000 return-scope behavior.

Rejected:

```d
Raster!T wrap(T[] storage, ...)
```

If a function establishes retained ownership, it is semantically `adopt`, not
borrow/wrap.

## 4. Clone

Clone is part of the ownership vocabulary but remains M1.5 / #93.

Invariant:

```text
ordinary Raster copy
    = shared retained backing

clone(source)
    = independent newly owned backing
```

No deep copy may occur through ordinary assignment or copy construction.

## 5. Result model

Fallible owner construction should use an explicit result-carrier direction,
following the established `OwnedRasterImportResult` pattern.

The exact public type names remain provisional.

Expected information includes:

- success/failure;
- construction error category;
- failing plane where relevant;
- ownership disposition for adopt.

Allocation and adoption do **not** need one oversized common error enum if
their failure semantics differ.

A result carrier is preferred over a D `out Raster!T` form where `out` would
reset/destroy a caller's existing retained Raster before validation.

Failure must not silently overwrite an existing owner.

## 6. Allocation implementation route

The first implementation should reuse existing mechanisms:

```text
checked byte count
    -> malloc-compatible storage
    -> OwnedByteResource
    -> PlaneByteLayout[1]
    -> existing owned-raster import
    -> RasterLease!T
    -> Raster!T
```

This avoids a parallel constructor that writes directly into private
`RasterBacking` internals.

If later profiling finds material control-plane overhead, the internal route
may be optimized without changing semantics.

## 7. Adopt implementation route

Similarly:

```text
OwnedByteResource
PlaneByteLayout[]
Region2D
    -> tryImportOwnedRaster!T
    -> RasterLease!T
    -> Raster!T
```

Validation, metadata lifetime and resource release remain single-sourced.

## 8. Foreign storage classification

### malloc/free-compatible owned storage

Accepted now through `OwnedByteResource`.

### caller-borrowed storage

Not adopted. Future view/wrap API only.

### custom foreign release callback

Examples include decoder- or library-specific allocations. The internal
resource model can represent this, but public callback adoption is an
interoperability/safety boundary. Keep it ADAPTER-gated until a concrete
zero-copy consumer justifies it.

### independently owned per-plane allocations

The backing can represent multiple resources internally, but a public
multi-resource adopt constructor remains ADAPTER-gated pending concrete
consumer evidence.

## 9. Safety

Allocate target: public `@safe`.

Adopt is deliberately split:

```text
raw pointer -> OwnedByteResource       @system
OwnedByteResource -> Raster!T          @safe where validated import permits
```

Wrap/borrow should be public `@safe` only if bounds and lifetime can be
expressed honestly. Convenience must not weaken ownership or lifetime safety.

## 10. Initialization cost

M1.2 does not silently promise zero-filled pixel storage.

Before production implementation, allocation must explicitly choose and
document a safe policy for every legal `isRasterSampleType!T`:

- uninitialized storage, if safe and semantically valid;
- value-initialized storage; or
- separate allocate / allocateFilled forms.

Hidden initialization cost is not acceptable merely for convenience.

## 11. Copy, move and destruction

After successful allocate or adopt:

- `Raster!T` copy retains shared backing;
- move transfers the retained handle;
- final retained owner releases physical resources exactly once.

Wrap/borrow has no Raster owner.

Clone, when implemented, owns independent backing; ordinary copies of the clone
then share that new backing.

## 12. Performance expectations

```text
allocate
    O(pixel bytes) storage provisioning; no extra pixel traversal unless the
    selected initialization policy requires it

adopt
    O(metadata/layout validation), O(1) pixel-copy work

Raster owner copy
    O(1)

wrap/view
    O(1) control-plane work when later supported

clone
    O(pixel samples)
```

No constructor should traverse pixels merely to establish ownership.

## 13. Compatibility

M1.2 does not remove or change the frozen v0.1 public surface:

```text
OwnedByteResource
tryAdoptMallocResource
OwnedRasterImportResult
tryImportOwnedRaster
RasterLease!T
```

The v0.2 `Raster!T` family layers above it.

## 14. Test obligations for implementation

Allocate:

- legal sample types;
- width × height overflow;
- byte-count overflow;
- allocation-failure injection;
- zero-area behavior;
- exact one-time release;
- copied owner survives destruction/reset of another copy;
- writable provenance.

Adopt:

- successful malloc-compatible ownership transfer;
- invalid-layout pre-commit failure preserves token ownership;
- post-commit failure releases once;
- multi-plane single-resource import;
- interleaved layout;
- failure does not overwrite an existing Raster.

Compile-contract probes:

- root import;
- legal/rejected `T`;
- no public `RasterBacking` construction;
- no borrowed storage accepted by an owning constructor without transfer;
- move-only ownership token behavior;
- DMD and LDC.

## 15. Explicitly rejected from M1.2

Do not add now:

- implicit owner creation from borrowed slices;
- arbitrary foreign release callbacks in the root API;
- public multi-resource ownership constructor;
- generic layout-policy hierarchy;
- heterogeneous sample planes;
- runtime sample-type erasure;
- hidden deep copy;
- provider/source abstractions;
- cache/scheduler policy.

## 16. Interaction with later M1 issues

M1.3 / #91 owns borrowed view, writable view, plane, row and ROI ergonomics,
including any external-storage wrap surface.

M1.4 / #92 freezes subregion semantics.

M1.5 / #93 owns deep-copy / clone.

M1.6 / #94 audits final parameter order and UFCS.

## 17. M1.2 acceptance checklist

- [x] allocate has explicit ownership and allocation semantics;
- [x] adopt has explicit transfer and failure-disposition semantics;
- [x] wrap/borrow is separated from ownership;
- [x] clone is distinguished from ordinary copy and deferred to #93;
- [x] foreign storage is distinguished from owned storage;
- [x] destruction/copy/move behavior remains the existing retained-owner model;
- [x] allocation starts with a deliberately narrow contiguous single-plane case;
- [x] future multi-plane extension remains possible without changing Raster!T;
- [x] result-carrier direction avoids accidental output destruction;
- [x] safety boundaries are explicit;
- [x] adapter-specific ownership extensions remain gated;
- [x] v0.1 compatibility is preserved;
- [x] no second backing architecture is introduced;
- [x] no production API implementation is promoted by this design change.
