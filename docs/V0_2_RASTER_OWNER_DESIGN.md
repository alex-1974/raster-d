# raster-d v0.2 M1.1 — Raster!T owning type design

Status: **design proposal for review; no production API implementation in this change**

Baseline:

```text
branch: develop
commit: ecd346b2b62c1e51d5edea137fb2235bb5a5b31e
```

Issue:

```text
#89 — M1.1 Design Raster!T owning type
```

## 1. Decision

Introduce `Raster!T` as the ergonomic **semantic owning raster handle** for v0.2.

`Raster!T` MUST NOT introduce a second storage or lifetime architecture.

Its retained state is conceptually:

```text
Raster!T
   |
   | private retained ownership
   v
RasterLease!T
   |
   v
existing RasterBacking / SafeRefCounted owner
```

The existing retained backing remains authoritative for:

- physical-resource ownership;
- exact-once release;
- descriptor lifetime;
- region metadata lifetime;
- read/write resource provenance;
- reference-counted shared retention.

`Raster!T` adds caller ergonomics and a clearer domain-level owning type.
It does not replace `RasterLease!T` internally.

## 2. Why a separate semantic owner is justified

The current public model deliberately exposes the lower-level lifetime capability
`RasterLease!T`.

That type is useful at import/materialization boundaries because it makes
retention explicit, but it is not the ideal ordinary user-facing noun for a
materialized raster value.

The v0.2 family needs a type that communicates:

```text
this value retains a complete raster representation
```

rather than:

```text
this value is the lifetime token from which raster views may borrow
```

The semantic distinction is ergonomic, not architectural.

## 3. Rejected alternatives

### 3.1 New owner with independent allocation fields

Rejected.

A second owner containing its own buffer pointer, dimensions and destruction
logic would duplicate:

- ownership;
- release;
- validation;
- descriptor storage;
- writable provenance;
- lifetime rules.

That would contradict the workspace rule that ownership and lifetime should be
explicit and coherent.

### 3.2 `alias Raster = RasterLease`

Rejected.

An alias would preserve implementation identity but would not establish a
distinct semantic owner type or allow the v0.2 owner API to evolve independently
from the lower-level lease contract.

### 3.3 `alias this` from Raster to RasterLease or RasterView

Rejected.

Implicit conversion would blur the owner/view/lifetime distinction and make
borrow boundaries harder to reason about.

### 3.4 Raster owns raw pixel memory directly

Rejected.

Raw memory ownership already belongs to the retained backing/resource layer.

### 3.5 Raster copies pixels on assignment

Rejected.

Ordinary D value copy of `Raster!T` must never imply a deep raster copy.

## 4. Type parameter and legality

Provisional declaration shape:

```d
struct Raster(T)
{
    static assert(
        isRasterSampleType!T,
        "Raster sample type must satisfy isRasterSampleType."
    );

    // private retained state
}
```

`T` uses the existing `isRasterSampleType!T` contract.

No new v0.2 sample trait is introduced by M1.1.
Issue #107 remains responsible for any later sample-trait family refinement.

## 5. Ownership semantics

`Raster!T` is a **shared retained owner**.

Copying a Raster retains the same underlying backing:

```d
auto b = a;
```

does not copy pixels.

Conceptually:

```text
Raster a ----+
             |
             +--> retained RasterBacking
             |
Raster b ----+
```

This matches the already-qualified `RasterLease!T` semantics.

### 5.1 Copy

Copying:

- is shallow with respect to raster pixels;
- increments/retains the existing backing ownership;
- preserves the same semantic raster;
- performs no pixel allocation;
- performs no pixel traversal.

### 5.2 Move

Moving transfers the retained handle in the ordinary D manner.

No special public move-only contract is required for `Raster!T`.

### 5.3 Assignment

Assignment replaces one retained interest with another.

The previously retained backing is destroyed only when the final retained owner
of that backing is released.

### 5.4 Destruction

`Raster!T` itself performs no independent raw-resource destruction.

Destruction delegates transitively to the existing `RasterLease!T` /
`RasterBacking` ownership chain.

Exact-once release remains the responsibility of the existing backing layer.

## 6. Deep-copy semantics

Deep copy is **not** ordinary copy construction or assignment.

A later explicit operation, currently tracked by M1.5 / #93, will define
deep-copy semantics.

Provisional family direction:

```d
auto copy = clone(source);
```

M1.1 therefore establishes the invariant:

> Copying Raster!T retains backing; cloning Raster!T, if later admitted,
> materializes independent backing.

No hidden deep copy is permitted.

## 7. `.init` semantics

`Raster!T.init` is a valid inert owner.

It:

- retains no backing;
- owns no physical resource;
- allocates nothing;
- releases nothing on destruction;
- represents no logical planes;
- yields the default empty semantic view when borrowed through the eventual
  view API.

Observable semantic state is conceptually:

```text
planeCount == 0
region     == Region2D.init
width      == 0
height     == 0
empty      == true
```

This does **not** mean that every empty raster is `.init`.

A valid retained raster may have:

- one or more logical planes;
- a zero-width and/or zero-height Region2D;
- retained physical resources and metadata.

Therefore:

```text
zero logical area
!=
uninitialized owner
```

The API must not infer backing existence solely from `empty`.

## 8. Geometry and dimensions

`Raster!T` represents exactly the resident geometry already retained by its
backing.

The owner does not introduce a second coordinate model.

Its dimensions derive from the same `Region2D` used by:

- `RasterLease!T`;
- `RasterView!T`;
- `WritableRasterView!T`.

The owner therefore preserves:

- resident descriptor-space coordinates;
- `size_t` coordinates/extents;
- representable empty regions;
- current checked region semantics.

Global logical-dataset placement remains outside `Raster!T`.

## 9. Layout contract

Owning a Raster does not imply any one physical layout.

A `Raster!T` may retain a backing that is:

- contiguous;
- row-padded;
- sample-strided;
- pixel-interleaved through logical planes;
- planar;
- negative-row-stride;
- negative-sample-stride where validated;
- backed by one or more physical resources internally.

The owner must not expose:

- a guaranteed contiguous pointer;
- a guaranteed single allocation;
- a guaranteed single plane;
- an execution-layout class.

Those remain view/execution concerns.

## 10. Mutability contract

Ownership and write capability remain separate.

A `Raster!T` may retain backing that is readable but not writable.

Therefore:

```text
Raster!T owner
!=
WritableRasterView!T capability
```

Writable access must continue through the existing certification path.

A const-qualified owner must not recover mutable capability.

M1.3 / #91 owns the final ergonomic naming for:

- read view;
- writable view;
- plane;
- row;
- ROI.

M1.1 only requires that whatever public view family is selected later borrows
from the Raster owner and preserves the existing DIP1000 lifetime relation.

## 11. Lifetime relation to views

The core invariant remains:

```text
owner lifetime
    >=
borrowed view lifetime
```

A view obtained from a Raster must borrow from the retained state inside that
Raster.

It must not outlive the owner value from which that borrow was derived.

A second independent Raster copy retaining the same backing does not retroactively
extend the lifetime of a borrow tied to the first owner variable.

This conservative DIP1000 relation is intentional and safe.

## 12. Relationship to RasterLease!T

`RasterLease!T` remains an established public v0.1 type and cannot be removed
silently.

For v0.2:

- `Raster!T` is the ordinary semantic owning raster value;
- `RasterLease!T` remains the lower-level retained lifetime capability and
  compatibility surface;
- both share the same backing architecture;
- M1.1 does not deprecate or break RasterLease;
- M1.2 will define how allocate/adopt/wrap constructors produce Raster values;
- existing v0.1 import APIs continue to operate until an explicit compatibility
  decision is made.

No implicit Raster <-> RasterLease conversion is selected.

Any explicit bridge, if needed, must be justified by a concrete v0.2 use case
rather than added speculatively.

## 13. Construction boundary

M1.1 does not finalize the allocate/adopt/wrap API.

That is M1.2 / #90.

However, all successful Raster construction must converge on the same existing
retained backing.

Conceptually:

```text
allocate / adopt / wrap / clone
              |
              v
validated existing construction/import layer
              |
              v
RasterLease!T / retained RasterBacking
              |
              v
Raster!T
```

No constructor may bypass:

- sample legality;
- byte/layout validation;
- resource ownership rules;
- writable provenance;
- retained metadata lifetime.

## 14. Allocation contract

Ordinary Raster operations that merely:

- copy the owner handle;
- move it;
- inspect dimensions;
- obtain a borrow;

must not allocate pixel storage.

Construction that materializes new storage must make allocation explicit through
its API family and documentation.

This follows the workspace rule:

> allocation is allowed; hidden and unnecessary allocation is not.

## 15. Public safety target

The ordinary `Raster!T` surface should be `@safe` wherever practical.

Expected shape:

```text
public @safe owner/view API
        |
        v
existing small @trusted ownership/borrow boundary
        |
        v
validated backing / pointer machinery
```

M1.1 does not widen any raw-pointer public surface.

Foreign ownership claims remain explicit `@system` adapter boundaries where
the library cannot prove allocation provenance.

## 16. Exception and GC contract

M1.1 does not make a blanket `nothrow` or `@nogc` promise for all future
constructors.

Reasons:

- retained owner creation may allocate metadata/reference-counted state;
- allocation failure and resource acquisition belong to construction semantics;
- `@nogc` is valuable in hot operations but is not a workspace dogma.

Borrow/view operations should preserve their existing strong
`nothrow/@nogc` contracts where the final M1.3 API permits.

## 17. Public property direction

M1.1 recommends that ordinary owner inspection eventually expose the same
semantic geometry vocabulary as views:

```text
planeCount
region
width
height
empty
```

These are not independent stored fields in Raster.

They derive from the retained backing/view state.

This avoids duplicated geometry state that could become inconsistent.

Final member-vs-free-function form remains M1.3 / M1.6 work.

## 18. Multi-plane direction

`Raster!T` must support the existing homogeneous multi-plane representation
without making speculative claims about heterogeneous sample types.

One Raster has:

- one sample type `T`;
- one common resident Region2D;
- one ordered logical plane set;
- potentially different physical plane strides/bases;
- potentially shared physical resource(s).

Do not broaden M1.1 into:

- runtime sample-type erasure;
- heterogeneous plane sample types;
- image-channel semantics;
- mixed-resolution plane collections.

Those require separate evidence.

## 19. Error model

The owner type itself does not require an operation error enum merely to exist.

Construction errors belong to the construction family that can fail.

M1.2 must decide whether allocating/adopting/wrapping Raster construction uses:

- result carriers;
- `try...` + out/ref;
- another repository-consistent explicit mechanism.

M1.1 only requires:

- failure never publishes a partially valid Raster;
- ownership outcome is deterministic;
- `.init` remains a valid failure/reset destination when appropriate;
- existing ownership obligations are not silently dropped.

## 20. Testable contract

An eventual implementation of this design must be testable with at least the
following cases.

### Default state

```text
Raster!ubyte.init
- owns/retains no backing
- has zero planes
- has Region2D.init
- is empty
- creates no resource-release event
```

### Shared retained copy

Construct one Raster, copy it, destroy/reset one copy.

Expected:

- the other owner remains valid;
- pixel data remains accessible;
- physical resource is not released early.

Destroy/reset the final owner.

Expected:

- physical resource releases exactly once.

### No deep copy

Copying the Raster must preserve shared backing identity indirectly through
observable mutation/retention tests without exposing backing identity publicly.

### Read borrow lifetime

A read view cannot escape the Raster owner from which it borrows.

### Writable borrow lifetime

A writable view cannot escape the mutable Raster owner from which it borrows.

### Const owner

A const Raster cannot recover writable capability.

### Empty retained raster

A successfully constructed raster with one plane and zero area remains
distinguishable semantically from Raster.init by plane/backing state.

### Layout neutrality

The same Raster ownership/view semantics hold for:

- contiguous;
- padded;
- interleaved;
- signed-stride layouts.

### Sample constraint

Supported `isRasterSampleType` representatives instantiate Raster.

Rejected sample types fail at compile time.

## 21. Compile-contract requirements

The implementation slice following this reviewed design should add positive and
negative external consumer probes covering:

- legal Raster sample types;
- rejected Raster sample types;
- owner copy/retention behavior;
- no escaping read borrow;
- no escaping writable borrow;
- no writable borrow from const owner;
- no access to private retained backing;
- root-package import.

The tests must run on both required Fast CI compilers.

## 22. Performance expectations

M1.1 introduces no pixel algorithm and therefore makes no throughput claim.

The owner abstraction must nevertheless avoid avoidable overhead:

- owner copy should be O(1) retained-handle work;
- move should not traverse pixels;
- geometry inspection should be O(1);
- view borrow should be O(1) apart from existing writable certification behavior;
- no owner operation should copy raster pixels unless explicitly documented as
  clone/materialization.

Any meaningful overhead relative to direct RasterLease usage should be measured
before release qualification if implementation layering introduces additional
work.

## 23. Provisional API sketch

The following is **illustrative only** and deliberately does not freeze M1.2 or
M1.3 naming:

```d
struct Raster(T)
{
private:
    RasterLease!T lease_;

public:
    // Semantic inspection eventually mirrors RasterView.
    // Final member/free-function surface is owned by M1.3/M1.6.

    // Construction is owned by M1.2.
    // Deep copy is owned by M1.5.
}
```

No `alias this`.

No raw backing pointer.

No implicit deep copy.

No hidden allocation.

## 24. Interaction with later M1 issues

### M1.2 / #90

Defines:

- allocate;
- adopt;
- wrap/borrow where justified;
- ownership-transfer result model;
- construction layout choices.

### M1.3 / #91

Defines:

- view;
- writableView;
- region/ROI;
- plane;
- row;
- owner/view ergonomic surface.

### M1.4 / #92

Freezes detailed subregion semantics and executable invariants.

### M1.5 / #93

Defines explicit deep-copy / clone semantics.

### M1.6 / #94

Audits final free-function ordering and UFCS ergonomics.

M1.1 intentionally does not steal those decisions.

## 25. Decision summary

Accepted:

```text
Raster!T
    = semantic shared retained owner
    = private wrapper over existing RasterLease!T
    = no second backing architecture
    = no implicit deep copy
    = no implicit mutable capability
    = no implicit layout guarantee
```

Preserved:

```text
RasterLease!T
RasterBacking
RasterView!T
WritableRasterView!T
existing validation/certification
existing retained-resource destruction
```

Deferred:

```text
allocation/adoption/wrap names
view-family names
plane/row API
clone implementation
UFCS normalization
heterogeneous sample types
public adapter extensions
```

## 26. M1.1 acceptance checklist

- [x] design reuses the existing ownership/backing/lease model;
- [x] no second storage/lifetime architecture is introduced;
- [x] `.init` semantics are explicit;
- [x] copy/move/destruction semantics are explicit and testable;
- [x] deep copy is explicitly separated from ordinary copy;
- [x] geometry and layout contracts are explicit;
- [x] ownership is separated from writable capability;
- [x] view lifetime remains tied to the owner borrow;
- [x] public `@safe` direction and trusted boundary are explicit;
- [x] hidden allocation is rejected;
- [x] homogeneous multi-plane support is preserved without speculative
      heterogeneous universality;
- [x] M1.2/M1.3/M1.5/M1.6 responsibilities remain deferred;
- [x] no production API implementation is promoted by this design change.
