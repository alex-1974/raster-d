# raster-d v0.2 M2.3 — zipTransformInto primitive

Status: implementation candidate for Issue #97.

Baseline:

~~~text
develop
13a3cbc7324be046a2f016ea16e4ee7aca8e0244
~~~

## 1. Decision

v0.2 adds one generic two-input same-type destination-oriented elementwise
primitive:

~~~d
bool zipTransformInto(alias transform, T)(
    scope RasterView!T left,
    size_t leftPlaneIndex,
    scope RasterView!T right,
    size_t rightPlaneIndex,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterZipTransformError error
);
~~~

Canonical UFCS use:

~~~d
left.zipTransformInto!op(
    leftPlaneIndex,
    right,
    rightPlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);
~~~

The plane indices remain a compatibility bridge while RasterPlaneView and
WritableRasterPlaneView are not yet production types.

## 2. Intended role

zipTransformInto is the generic binary elementwise foundation for later:

- arithmetic wrappers;
- pairwise min/max;
- mask combination;
- consumer-defined same-type elementwise kernels.

Those wrappers should delegate to this primitive rather than introduce separate
pixel loops.

## 3. Callable contract

The callable is a compile-time alias usable as:

~~~text
@safe pure nothrow @nogc T, T -> T
~~~

The requirement is enforced by template instantiation.

M2.3 does not introduce:

- runtime callable type erasure;
- string mixins;
- stateful policy objects;
- cross-type conversion;
- numeric saturation/clamping policy;
- image-domain semantics.

## 4. Shape semantics

All three selected planes are interpreted through their views' relative
semantic coordinates.

Required:

~~~text
left.width   == right.width   == destination.width
left.height  == right.height  == destination.height
~~~

Resident Region2D origins do not need to match.

For each successful non-empty coordinate x,y:

~~~text
destination[x,y] = transform(left[x,y], right[x,y])
~~~

## 5. Empty semantics

After all three plane indices and shapes are validated, matching empty shapes
succeed as a no-op.

The callable is not invoked.

As with transformInto, destination injectivity and physical overlap are
irrelevant when no sample is reachable.

## 6. Destination injectivity

For non-empty geometry the destination mapping must be injective.

A writable capability does not imply injectivity. Therefore the same affine
injectivity check used by transformInto remains explicit.

Failure:

~~~text
RasterZipTransformError.nonInjectiveDestination
~~~

No destination write occurs before this check.

## 7. Aliasing semantics

The two sources are read-only.

Therefore:

~~~text
left <-> right overlap
    allowed
~~~

This includes exact identity: the same RasterView/plane may be supplied as both
inputs.

The destination is mutable. To preserve coordinate-wise semantics independent
of traversal order:

~~~text
left <-> destination overlap
    rejected

right <-> destination overlap
    rejected
~~~

The rejection is based on exact reachable sample-byte overlap, not on broad
allocation identity.

The error distinguishes which source conflicts:

~~~text
leftDestinationOverlap
rightDestinationOverlap
~~~

All alias checks complete before the first write.

## 8. Shared overlap mechanism

M2.3 does not copy transformInto's overlap implementation.

The exact same-type overlap decision is centralized in:

~~~text
raster.internal.same_type_overlap
    validatedSameTypePlaneRegionsOverlap
~~~

Both unary transform and zip transform use this helper.

The helper retains the established strategy:

~~~text
checked-wide affine relation classifier
    |
    +-- overlap     -> true
    +-- disjoint    -> false
    +-- arithmetic failure
            |
            v
       exact allocation-free finite fallback
~~~

This refactor is intended to be behavior-preserving for the existing unary
transform family.

## 9. Layout semantics

Every already-valid signed affine raster layout remains semantically supported:

- compact contiguous;
- row-padded;
- sample-strided;
- negative row stride;
- negative sample stride;
- accepted combinations;
- ROI views with non-zero resident origin.

Physical layout does not change logical coordinate pairing.

## 10. Execution specialization

Canonical layouts use an internal direct pointer/row executor when all three
sample strides equal one.

Universal layouts use the public semantic traversal.

The dispatcher is an execution optimization only. It does not own validation,
aliasing, shape, failure or numeric semantics.

No public execution-layout policy is introduced.

## 11. Failure model

RasterZipTransformError:

~~~text
none
invalidLeftPlane
invalidRightPlane
invalidDestinationPlane
shapeMismatch
nonInjectiveDestination
leftDestinationOverlap
rightDestinationOverlap
~~~

The ordering of checks is deliberate and deterministic:

1. left plane;
2. right plane;
3. destination plane;
4. shape;
5. empty success;
6. destination injectivity;
7. left/destination overlap;
8. right/destination overlap;
9. execution.

Every listed failure occurs before the first destination write.

## 12. Allocation and lifetime

zipTransformInto:

- allocates no pixel or metadata storage;
- retains no input or output;
- creates no owner;
- launches no background work;
- owns no scheduler/thread/fiber;
- is @nogc.

Callers control destination allocation and reuse.

## 13. Performance position

zipTransformInto is the binary analogue of transformInto and is intended as the
performance-oriented primitive for two-input elementwise work.

The canonical direct-row executor avoids routing ordinary unit-sample-stride
layouts through per-sample public accessors.

No standalone performance claim is made by M2.3. Later arithmetic wrappers must
not add a second execution loop merely to obtain speed.

## 14. Tests

The implementation directly tests:

- ordinary-call/UFCS equivalence;
- contiguous canonical execution;
- arbitrary signed row/sample strides;
- exact source/source alias acceptance;
- left/destination overlap rejection and pre-write preservation;
- right/destination overlap rejection and pre-write preservation;
- shape mismatch and pre-write preservation;
- non-injective destination rejection;
- matching empty no-op without callable invocation;
- DMD and LDC through Fast CI.

Existing transformInto tests additionally protect the shared overlap extraction
from semantic regression.

## 15. Explicit non-goals

M2.3 does not add:

- allocating zip convenience;
- cross-type binary transforms;
- broadcasting;
- shape coercion;
- automatic ROI intersection;
- in-place update semantics;
- temporary buffering to permit destination overlap;
- arithmetic operator overloads;
- numeric overflow policy;
- SIMD policy surface;
- parallel execution.

## 16. Acceptance mapping

Issue #97 requires shape/layout/alias/failure semantics to be explicit and
tested.

They are frozen by this document and the production/unittest implementation.

The PR is ready to close #97 once DMD and LDC Fast CI are green.
