# raster-d v0.2 M4.4 — generic border policy model

Status: implementation candidate for Issue #111.

Baseline:

~~~text
develop
718350272f5284c37be1abc42c369059edd96d07
~~~

## 1. Goal

M4.4 defines generic raster border semantics independently of imagery meaning.

Promoted public policy types:

~~~text
RasterValidBorder
RasterConstantBorder!T
RasterClampBorder
RasterMirrorBorder
RasterWrapBorder
~~~

Each exposes a compile-time RasterBorderKind.

## 2. Why policies are types

Border mode is semantic operation policy, not ordinary per-pixel request data.

The policy kind is therefore selected by type.

This allows future spatial executors to use static dispatch without a runtime
mode branch inside the hot sample loop.

Stateless policies contain no instance fields:

~~~text
valid
clamp
mirror
wrap
~~~

Constant border carries exactly one runtime field:

~~~text
T value
~~~

because the constant sample itself is caller data.

## 3. Valid

RasterValidBorder synthesizes no outside sample.

Every required source coordinate must already be available under the operation's
source/residency contract.

This is exactly the semantic policy currently implemented by
applyNeighbourhoodInto.

Missing halo remains a structural failure.

## 4. Constant

RasterConstantBorder!T returns the caller-supplied constant for coordinates
outside the valid source extent.

Inside coordinates are read unchanged from the source.

T may be any isRasterSampleType-compatible sample representation, including POD
pixel structs and static arrays.

This policy does not imply any image-specific background, alpha, NoData or
radiometric interpretation.

## 5. Clamp

RasterClampBorder maps each outside coordinate independently to the nearest
valid edge coordinate.

For an axis of extent N > 0:

~~~text
c < 0   -> 0
c >= N  -> N - 1
else    -> c
~~~

Clamp is undefined for a zero-length source axis.

Any operation using clamp must reject an empty required axis before coordinate
mapping.

## 6. Mirror

RasterMirrorBorder uses edge-inclusive symmetric reflection.

For extent N > 0 the period is 2*N.

For N = 4 the conceptual infinite index pattern is:

~~~text
... 2 3 | 3 2 1 0 | 0 1 2 3 | 3 2 1 0 | 0 1 ...
~~~

With Euclidean remainder:

~~~text
r = modEuclidean(c, 2*N)

if r < N:
    mapped = r
else:
    mapped = 2*N - 1 - r
~~~

Both edge samples are therefore repeated at reflection boundaries.

This explicit definition avoids ambiguity with reflect-without-edge-repeat
conventions used by some external libraries.

Mirror is undefined for a zero-length source axis.

## 7. Wrap

RasterWrapBorder uses periodic Euclidean wrapping.

For extent N > 0:

~~~text
mapped = modEuclidean(c, N)
~~~

Negative coordinates wrap from the opposite side.

The contract is mathematical Euclidean modulo, not D/C remainder semantics for
negative operands.

Wrap is undefined for a zero-length source axis.

## 8. Empty-source behavior

Policy alone does not define an output domain.

For clamp, mirror and wrap, coordinate mapping requires a non-zero source
extent.

Valid cannot synthesize samples.

Constant can conceptually supply outside values, but an operation must still
define whether an output request over an empty source is legal.

That remains an operation-level contract rather than being silently invented by
the border policy type.

## 9. Separation from imagery semantics

These policies operate only on generic raster coordinates and sample values.

They do not define:

- NoData;
- alpha;
- transparency;
- image background meaning;
- colour-space behavior;
- radiometric fill;
- provider tile-edge semantics;
- dataset validity masks.

Higher layers may choose policy values appropriate to their own meaning.

## 10. Separation from source materialization

Border policy does not alter M1 dependency/materialization semantics.

It remains distinct from:

~~~text
logical dataset extent
ContextDeficit
resident halo availability
provider/source tile boundaries
cache block boundaries
~~~

A higher-level operation decides where border policy is applied relative to
logical/request geometry.

## 11. Compile-time specialization rule

Policy kind is available as:

~~~d
Policy.kind
~~~

and may be used with static if when this removes actual hot-path work or
branches.

The model does not require a runtime enum switch for policy selection.

This is directly useful for spatial kernels:

~~~text
valid:
    no border coordinate mapping in approved resident-halo path

constant:
    outside test + constant value path

clamp/mirror/wrap:
    policy-specific coordinate mapping
~~~

Future execution code must still measure specialized source forms before adding
compiler- or shape-specific complexity.

## 12. Runtime state

The model intentionally minimizes policy state:

~~~text
RasterValidBorder       0 semantic runtime fields
RasterClampBorder       0
RasterMirrorBorder      0
RasterWrapBorder        0

RasterConstantBorder!T  1 field: T value
~~~

Fast CI asserts the stateless-policy tuple field count and validates the
constant-policy sample constraint.

## 13. Constant sample constraints

RasterConstantBorder!T uses the existing isRasterSampleType contract.

Accepted examples include:

~~~text
ubyte
float
ubyte[4]
plain POD pixel structs without indirections
~~~

Rejected examples include:

~~~text
pointers
dynamic arrays
qualified sample types
indirection-owning/destructible sample types
~~~

No separate border-only sample type system is introduced.

## 14. Relationship to applyNeighbourhoodInto

The M4.3 applyNeighbourhoodInto primitive remains the valid/resident-halo base
operation.

M4.4 does not weaken or silently change that API.

Future border-aware spatial/convolution wrappers can reuse the same shape,
kernel, destination and execution machinery while specializing only the sample
acquisition boundary.

This keeps:

~~~text
neighbourhood geometry
border semantics
kernel semantics
destination
execution specialization
~~~

separate.

## 15. Relationship to convolution

Issue #112 should use these policy types.

Convolution should not invent independent edge-mode enums or duplicate border
coordinate semantics.

The same border types are intended to be reusable for any later generic spatial
operation whose coordinate contract is compatible.

## 16. Policies promoted

All five Issue #111 candidates are promoted because their generic raster
semantics can be specified without image-domain meaning:

~~~text
valid
constant
clamp
mirror
wrap
~~~

No additional policies are introduced.

In particular, M4.4 does not invent:

- transparent;
- NoData;
- alpha-aware;
- extrapolated;
- radiometric;
- provider-specific

border modes.

## 17. Compile-contract qualification

Fast CI compiles the root-import public policy surface with DMD and LDC.

Positive probes include:

- all stateless policy types;
- scalar constant policy;
- POD constant policy.

Negative probes reject invalid constant sample representations such as pointers,
dynamic arrays and qualified sample types.

## 18. Acceptance mapping

Issue #111 requires generic raster border handling independent of imagery
semantics.

Satisfied by the five explicitly defined coordinate/sample policies.

It requires only justified policies to enter production.

Only the five audited generic candidates are promoted; no imagery-derived modes
are added.

It requires compile-time specialization when that removes actual hot-path work.

Policy kind is type-level, so future executors can remove runtime mode branches.
Stateless policies carry no semantic runtime policy fields; constant carries
only its required caller value.
