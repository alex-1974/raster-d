# raster-d v0.2 M1.6 — API / UFCS audit

Status: **M1 API-shape freeze and executable UFCS audit**

Baseline:

~~~text
branch: develop
commit: 5505b524de7698ac0ef3d4fe0947a142ab261c89
~~~

Issue: #94 — M1.6 Audit UFCS ergonomics for v0.2 API

## 1. Workspace rule

The workspace D contract is authoritative:

- public free functions should normally place the semantic subject first;
- the same free function should support both ordinary-call and UFCS syntax;
- UFCS is not a reason to duplicate an operation as both member and free
  function;
- parameter order must not distort mathematics, ownership, mutation or failure
  semantics merely to look fluent;
- parameter order and names are source-compatibility concerns.

M1.6 applies that rule to raster-d.

## 2. Decision

v0.2 uses one canonical callable for each new operation.

When an operation has a natural semantic subject, that subject is the first
runtime parameter so both forms name the same function:

~~~d
copyInto(source, destination);
source.copyInto(destination);
~~~

No second member implementation is added merely to enable UFCS.

Construction functions without a meaningful existing subject are not distorted
for UFCS.

## 3. API categories

M1.6 separates three categories.

### 3.1 semantic state / capability properties

Properties that describe a value itself may remain members:

~~~text
planeCount
region
width
height
empty
~~~

This matches the established RasterView/WritableRasterView vocabulary.

M1.6 does not add redundant free-function wrappers such as:

~~~d
width(view)
~~~

solely to obtain:

~~~d
view.width()
~~~

because property access already has the natural member form.

### 3.2 algorithms and capability transitions

New v0.2 operations use free functions where the first argument is the semantic
subject.

Examples:

~~~text
view(owner)
tryWritableView(owner, ...)
tryPlane(view, ...)
tryRow(plane, ...)
tryRoi(plane, ...)
tryClone(source)
~~~

### 3.3 constructors / ownership acquisition

Construction has no pre-existing Raster subject.

Therefore functions such as:

~~~text
tryAllocateRaster
tryAdoptRaster
~~~

remain ordinary free constructors.

They are not reordered around an incidental argument just to manufacture UFCS.

## 4. Existing v0.1 evidence

The current public raster-d free functions already follow the subject-first
pattern in important families.

Examples:

~~~d
destination.tryFillRasterPlane(planeIndex, value);

source.tryCopyRasterPlane(
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

source.trySumFloatToDouble(
    planeIndex,
    sum
);

source.tryConvertUbyteToFloatPlane(
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
~~~

M1.6 adds executable tests through the public root import for these UFCS forms.

The tests intentionally use default views because they verify public dispatch,
template instantiation and parameter ordering, not successful pixel work.

## 5. Existing v0.1 API remains unchanged

M1.6 does not rename or reorder the frozen v0.1 surface.

Existing names such as:

~~~text
tryFillRasterPlane
tryCopyRasterPlane
tryTransformRasterPlane
trySumFloatToDouble
tryConvertUbyteToFloatPlane
tryApplyRasterNeighbourhood3x3
~~~

remain source-compatible.

The v0.2 family may add cleaner plane-oriented names later, but compatibility
wrappers are not silently rewritten.

## 6. Raster!T owner inspection

Raster!T should expose the semantic state vocabulary directly as properties:

~~~text
planeCount
region
width
height
empty
~~~

These properties derive from retained backing/view state.

They are not duplicated as free functions.

Reason:

- they are value state, not independent algorithms;
- the existing view family already uses this shape;
- member property access is clearer than artificial UFCS for noun properties.

## 7. Read view

Canonical v0.2 direction:

~~~d
RasterView!T view(
    scope return ref const Raster!T raster
);
~~~

Conceptually.

Ordinary call:

~~~d
auto v = view(raster);
~~~

UFCS:

~~~d
auto v = raster.view();
~~~

The exact qualifier spelling is implementation-sensitive and must preserve the
M1.1 lifetime contract.

There is one callable, not both a Raster.view member and a duplicate free
function.

## 8. Writable view

Canonical direction:

~~~d
WritableRasterView!T tryWritableView(
    scope return ref Raster!T raster,
    out bool success
);
~~~

Conceptually.

UFCS:

~~~d
auto writable = raster.tryWritableView(success);
~~~

The mutable Raster is first because it is the capability source.

The success output follows the semantic inputs.

A const Raster must not match this overload.

## 9. Plane selection

Canonical direction:

~~~d
RasterPlaneView!T tryPlane(
    scope RasterView!T view,
    size_t planeIndex,
    out bool success
);
~~~

and:

~~~d
WritableRasterPlaneView!T tryPlane(
    scope ref WritableRasterView!T view,
    size_t planeIndex,
    out bool success
);
~~~

UFCS:

~~~d
auto p = view.tryPlane(index, success);
auto wp = writable.tryPlane(index, success);
~~~

The parent capability is first.

The selector follows.

The success result is last.

## 10. ROI on existing v0.1 full views

RasterView.tryRoi and WritableRasterView.tryRoi already exist as members and are
frozen v0.1 API.

M1.6 does not add duplicate free-function wrappers merely to make them look like
new v0.2 functions.

Their established use remains:

~~~d
auto child = view.tryRoi(relative, success);
~~~

This is an intentional compatibility exception to the new-free-function
direction.

## 11. ROI on new plane views

For the new M1.3 plane types, canonical direction is one free function:

~~~d
RasterPlaneView!T tryRoi(
    scope RasterPlaneView!T plane,
    Region2D relative,
    out bool success
);
~~~

and writable equivalent.

UFCS:

~~~d
auto child = plane.tryRoi(relative, success);
~~~

No member/free duplicate pair is introduced.

## 12. Row selection

Canonical direction:

~~~d
RasterPlaneView!T tryRow(
    scope RasterPlaneView!T plane,
    size_t y,
    out bool success
);
~~~

and writable equivalent.

UFCS:

~~~d
auto row = plane.tryRow(y, success);
~~~

The result remains the same plane-view type with height 1.

No RowView type and no T[] row return are introduced by M1.6.

## 13. Allocation

Construction is not naturally subject-oriented.

Canonical naming direction:

~~~text
tryAllocateRaster!T(width, height)
~~~

with an explicit result carrier rather than an out Raster that could destroy an
existing owner before validation.

No UFCS form is required or encouraged.

Rejected parameter tricks include placing width, allocator state or an empty
Raster first merely to obtain fluent syntax.

## 14. Adoption

Canonical naming direction:

~~~text
tryAdoptRaster!T(resource, planes, region)
~~~

where the result carrier reports both construction failure and ownership
disposition.

The first parameter is the ownership token because ownership transfer is the
central operation input.

Although D would technically permit:

~~~d
resource.tryAdoptRaster!T(...)
~~~

M1.6 does not define that as the preferred user syntax.

The operation semantically constructs a Raster; it is documented primarily as a
free constructor.

UFCS availability is incidental here, not an ergonomic design target.

## 15. Clone

M1.5 defines clone as explicit, fallible materialization.

To align with raster-d's established fallible-operation vocabulary, M1.6 selects
the public naming direction:

~~~text
tryClone
~~~

rather than an infallible-looking bare clone.

Canonical source-first shape:

~~~d
auto result = tryClone(source);
~~~

UFCS:

~~~d
auto result = source.tryClone();
~~~

The canonical semantic source is RasterView!T.

A Raster!T convenience overload may delegate to view(raster) if implementation
evidence shows it improves ordinary use without creating semantic ambiguity.

No member implementation is added solely for that syntax.

## 16. Why tryClone, not clone

Clone performs allocation and can fail for:

- invalid source;
- checked size overflow;
- allocation failure;
- backing construction failure;
- internal copy/publication failure.

The repository already uses try-prefixed names for expected non-exceptional
failure.

Therefore tryClone communicates the failure channel before a caller reads the
result type.

This is a naming decision; the result carrier remains the authoritative detailed
failure record.

## 17. Result carriers

For new fallible constructors/materializers, the preferred parameter shape is:

~~~text
semantic inputs...
-> result carrier
~~~

not:

~~~text
semantic inputs..., out Raster
~~~

when out semantics could reset or destroy an already-live owner.

Result carriers should expose:

- ok;
- semantic error;
- operation-specific disposition where needed;
- successful Raster payload through a safe ownership transfer/access pattern.

The exact payload accessor is implementation work and must preserve move/copy
semantics correctly.

## 18. Output/error parameters on non-owning operations

Existing v0.1 non-allocating operations retain their current output/error
parameters for compatibility.

For new destination-oriented operations, parameter order follows:

~~~text
subject
other semantic operands
destination
policy/options
failure output/result
~~~

unless a specific operation has a stronger domain reason.

Error/result outputs go last by default because they are not the semantic
subject.

## 19. Destination-oriented algorithm direction

M0.4 already established Into-style operation families.

M1.6 freezes the UFCS ordering rule for later M2-M4 APIs:

~~~text
source first
destination after source-specific inputs
error/result last
~~~

Examples of desired reading:

~~~d
sourcePlane.copyInto(destinationPlane);
sourcePlane.transformInto(destinationPlane, transform);
sourcePlane.convertInto(destinationPlane, policy);
sourcePlane.applyNeighbourhoodInto(destinationPlane, kernel, border);
~~~

These examples establish ordering and naming direction only.

The exact later-operation signatures remain owned by their M2-M4 issues.

## 20. Fill is destination-oriented

Fill differs because there is no source.

The destination is therefore the semantic subject:

~~~d
destinationPlane.fill(value);
~~~

Conceptually this maps to one free function:

~~~d
fill(destinationPlane, value);
~~~

No duplicate destinationPlane.fill member is needed.

## 21. Symmetric operations

UFCS must not distort genuinely symmetric semantics.

If a future operation is mathematically symmetric and neither operand is a
natural subject, M1.6 does not require arbitrary operand privileging merely to
produce fluent syntax.

Parameter ordering must reflect the domain first.

## 22. Mutation and ref

A writable destination/capability may require ref to preserve mutation and
lifetime rules.

UFCS does not change that contract.

For example:

~~~d
fill(ref destination, value);
~~~

can still be called as:

~~~d
destination.fill(value);
~~~

when D's type/lifetime rules permit.

M1.6 does not replace required ref with value passing for ergonomic appearance.

## 23. Templates

Compile-time semantic customization remains template syntax where already
justified.

For example:

~~~d
source.tryTransformRasterPlane!transform(...);
source.tryApplyRasterNeighbourhood3x3!kernel(...);
~~~

Later plane-oriented families may likewise template on a callable or fixed
shape when that information is genuinely compile-time.

UFCS does not justify string mixins or duplicate generated call surfaces.

## 24. Parameter names

Because D supports named arguments, parameter names are part of the API freeze
where applicable.

Preferred semantic vocabulary:

~~~text
raster
view
plane
source
destination
planeIndex
relative
region
value
transform
kernel
policy
success
error
resource
planes
width
height
~~~

Avoid leaking internal vocabulary such as:

~~~text
executionLayout
backend
simdClass
resourceEntry
descriptorBase
~~~

into semantic APIs unless those become independently public concepts.

## 25. Boolean success outputs

Existing view-subselection APIs use out bool success.

M1.6 preserves this pattern for small O(1) capability-selection operations:

~~~text
tryWritableView
tryPlane
tryRow
tryRoi
~~~

when the only expected failure distinction is yes/no.

Operations with multiple meaningful failure categories should prefer an error
enum or result carrier rather than proliferating boolean outputs.

## 26. Error enums

Where a semantic operation has distinct caller-actionable failures, keep the
error type specific to that family.

Do not create one universal RasterError solely for naming symmetry.

This preserves the M1.2 decision that allocation/adoption and other operations
need not share an oversized failure taxonomy.

## 27. Root exports

When M1 production types/functions are implemented, the intended root-visible
v0.2 semantic additions are:

~~~text
Raster
RasterPlaneView
WritableRasterPlaneView
construction result/error types
clone result/error types
new free functions required by the M1 family
~~~

Internal types remain internal:

~~~text
RasterBacking
ResourceEntry
execution layout classifiers
certification internals
copy dispatch internals
allocator/test seams
~~~

RasterLease remains public v0.1 compatibility surface.

## 28. No alias this

M1.6 reaffirms the M1.1 rejection of alias this between:

- Raster and RasterLease;
- Raster and RasterView;
- read and writable capabilities.

UFCS gives ergonomic call syntax without implicit type conversion.

## 29. No extension-method duplication

Rejected pattern:

~~~d
struct RasterPlaneView(T)
{
    void copyInto(...);
}

void copyInto(T)(RasterPlaneView!T source, ...);
~~~

when both implement the same semantic operation.

Accepted pattern:

~~~d
void copyInto(T)(RasterPlaneView!T source, ...);
~~~

called either as:

~~~d
copyInto(source, destination);
source.copyInto(destination);
~~~

## 30. Compatibility boundary

v0.1 member functions remain members because changing/removing them would be a
source compatibility break.

M1.6 therefore does not mechanically rewrite existing API into free functions.

The no-duplication rule applies to new v0.2 APIs; compatibility surface is
preserved deliberately.

## 31. Executable UFCS evidence

M1.6 adds a root-import unittest module that compiles and executes representative
failure paths through UFCS for:

- tryFillRasterPlane;
- tryCopyRasterPlane;
- tryTransformRasterPlane;
- tryApplyRasterNeighbourhood3x3;
- trySumFloatToDouble;
- tryConvertUbyteToFloatPlane.

This proves that the repository's existing first-argument ordering behaves as
expected under both required compilers.

It does not invent mock v0.2 production functions merely to satisfy a syntax
test.

Every future implementation of the new M1 free functions must add direct compile
tests for its exact documented ordinary-call and UFCS forms in the same change.

## 32. Required implementation-time examples

When each new M1 callable is promoted, its Ddoc/test evidence should include both
forms where useful.

Example:

~~~d
auto p1 = tryPlane(view, 0, success);
auto p2 = view.tryPlane(0, success);
~~~

Both forms must resolve to the same free function.

Avoid redundant examples when the second form adds no clarity, but compile
coverage should establish both where source compatibility matters.

## 33. M1 final naming direction

The final M1 design vocabulary is:

~~~text
Types
    Raster!T
    RasterView!T                  existing
    WritableRasterView!T          existing
    RasterPlaneView!T
    WritableRasterPlaneView!T
    RasterLease!T                 existing compatibility

Owner state
    planeCount
    region
    width
    height
    empty

Capability/view operations
    view
    tryWritableView
    tryPlane
    tryRoi
    tryRow

Ownership/materialization
    tryAllocateRaster
    tryAdoptRaster
    tryClone
~~~

Existing v0.1 names are preserved unchanged.

## 34. Calls intentionally not selected

M1.6 rejects these as canonical new API:

~~~d
raster.getView();
raster.asView();
raster.makeWritableView();
view.getPlane(index);
plane.getRow(y);
deepCopy(source);
copyRaster(source);       // ambiguous with shallow owner copy
raster.clone();           // as a distinct member implementation
allocate(width, height);  // noun/context unclear at root package
adopt(resource, ...);     // target noun unclear at root package
~~~

A UFCS call such as source.tryClone() is still valid because it resolves to the
single free function; the rejection above is specifically a duplicate member
implementation.

## 35. Relationship to later milestones

M1.6 freezes the ergonomic rules and M1 naming direction.

Later milestones may refine operation-family names such as copyInto,
transformInto, convertInto and neighbourhood/convolution operations inside their
own semantic issues.

They must continue to follow:

- semantic subject first;
- destination orientation where appropriate;
- no member/free duplication;
- explicit allocation;
- no internal execution vocabulary in the public signature.

If a later issue finds a genuine semantic reason to deviate, it must document
that reason rather than silently contradict M1.6.

## 36. M1 completion state

After M1.6, M1 has defined:

~~~text
M1.1  Raster owner semantics
M1.2  allocate/adopt/wrap ownership boundary
M1.3  ergonomic view/plane/row family
M1.4  ROI/subregion semantics
M1.5  explicit clone/deep-copy semantics
M1.6  naming, parameter order and UFCS rules
~~~

Production implementation remains staged work.

This audit does not claim that the not-yet-implemented v0.2 callables already
exist.

## 37. Acceptance checklist

- [x] parameter ordering is deliberate;
- [x] semantic subject is first where one naturally exists;
- [x] construction APIs are not distorted merely for UFCS;
- [x] current public free-function UFCS forms have executable root-import tests;
- [x] new v0.2 APIs require exact ordinary-call/UFCS compile tests when
      implemented;
- [x] no redundant member/free-function pair is introduced for new API merely
      for syntax;
- [x] existing v0.1 members remain for compatibility;
- [x] Raster state properties remain member properties rather than artificial
      free-function wrappers;
- [x] tryClone is selected as the fallible deep-copy naming direction;
- [x] parameter names use semantic vocabulary and avoid internal execution
      details;
- [x] result/error outputs follow semantic operands;
- [x] later Into-style algorithm families inherit the same ordering rule;
- [x] no production v0.2 API is falsely claimed to exist by this audit.
