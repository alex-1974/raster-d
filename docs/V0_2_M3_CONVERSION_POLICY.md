# raster-d v0.2 M3.5 — generic conversion policy model

Status: implementation candidate for Issue #104.

Baseline:

~~~text
develop
9c7340de0ccec10232d5b7d32de301a36f0e2059
~~~

## 1. Purpose

M3.5 defines the semantic policy layer required before the generic
destination-oriented conversion API in #105.

The goal is to prevent growth of unrelated one-off conversion functions with
incompatible overflow, rounding and NaN behavior.

## 2. Promoted public policy

v0.2 initially promotes exactly one public policy:

~~~d
RasterConversionPolicy.exact
~~~

No other candidate policy is public in M3.5.

This is deliberate.

Issue #104 requires that only policies with fully specified behavior be
promoted. The existing production ubyte -> float conversion already provides
evidence for exact representation conversion.

## 3. Exact conversion semantics

exact means that the complete source type domain is representable in the
destination type without numerical information loss.

For a source/destination type pair accepted under exact:

- every legal source value converts exactly;
- no rounding policy is needed;
- no truncation occurs;
- no saturation occurs;
- no clamping occurs;
- no numeric overflow can occur;
- no per-sample numeric failure is possible;
- unsupported type pairs are rejected at compile time by the generic conversion
  API rather than discovered after destination writes begin.

This policy is about representation conversion only.

It does not perform:

- image normalization;
- scale/offset radiometric conversion;
- color-space conversion;
- gamma conversion;
- NoData interpretation;
- mask/validity propagation.

Those remain outside raster-d core where domain semantics require them.

## 4. Supported initial numeric representations

The initial exact relation is defined only over:

~~~text
byte
ubyte
short
ushort
int
uint
long
ulong
float
double
~~~

real is deliberately excluded because its precision/representation is
target-dependent.

Representation-safe raster types outside this numeric family are not implicitly
ordered into conversion semantics.

## 5. Exact integer -> integer relation

An integer conversion is universally exact when the full mathematical source
range is contained in the destination range.

Rules:

Signed -> signed:

~~~text
destination width >= source width
~~~

Unsigned -> unsigned:

~~~text
destination width >= source width
~~~

Unsigned -> signed:

~~~text
destination width > source width
~~~

Signed -> unsigned:

~~~text
rejected
~~~

Examples:

~~~text
byte   -> short    exact
ubyte  -> ushort   exact
ubyte  -> short    exact
uint   -> ulong    exact
uint   -> long     exact

short  -> ubyte    not universally exact
int    -> uint     not universally exact
ulong  -> long     not universally exact
~~~

## 6. Exact integer -> floating relation

The complete integer domain must fit in the destination binary significand.

For binary32 float:

~~~text
byte   -> float    exact
ubyte  -> float    exact
short  -> float    exact
ushort -> float    exact

int    -> float    not universally exact
uint   -> float    not universally exact
long   -> float    not universally exact
ulong  -> float    not universally exact
~~~

For binary64 double:

~~~text
byte   -> double   exact
ubyte  -> double   exact
short  -> double   exact
ushort -> double   exact
int    -> double   exact
uint   -> double   exact

long   -> double   not universally exact
ulong  -> double   not universally exact
~~~

The existing production ubyte -> float conversion is therefore one exact-policy
instance.

## 7. Exact floating -> floating relation

Initial portable exact relations are:

~~~text
float  -> float    exact
float  -> double   exact
double -> double   exact
~~~

Rejected:

~~~text
double -> float    not universally exact
~~~

float -> double preserves all finite values exactly and also preserves the
source floating domain's infinities and NaN-ness without introducing a
rounding/narrowing policy.

No public contract promises preservation of a particular NaN payload/sign
unless a later policy explicitly requires it.

## 8. Floating -> integer

No floating -> integer pair is universally exact.

The floating source domain contains:

- fractional values;
- values outside integer range;
- positive and negative infinity;
- NaN.

Therefore floating -> integer requires additional semantics and is not part of
RasterConversionPolicy.exact.

## 9. Why checked is not yet promoted

checked sounds simple but is incomplete without answering at least:

- what does float -> integer do with fractional values?
- which rounding mode applies?
- what happens for NaN?
- what happens for +Inf/-Inf?
- is -0 accepted for unsigned zero?
- is exactness required after conversion, or only destination range?
- does failure occur before any destination write?
- does the operation pre-scan, buffer, or permit partial output?

Until those are frozen, checked is not public.

## 10. Why saturating is not yet promoted

saturating requires explicit semantics for:

- signed/unsigned endpoints;
- floating infinities;
- NaN;
- fractional float -> integer values;
- rounding order relative to saturation;
- signed zero;
- integer -> floating cases where finite overflow is impossible/possible.

No such public contract is promoted in M3.5.

## 11. Why narrowing is not yet promoted

narrowing is not one numerical semantic.

It could mean:

- D cast behavior;
- modulo truncation;
- bit truncation;
- range-checked narrowing;
- rounded floating narrowing;
- lossy but finite conversion.

A policy with that name would be ambiguous and therefore is not public.

## 12. Why rounding policies are not yet promoted

Rounding matters primarily where representation cannot be exact.

Potential policies include:

~~~text
toward zero
toward +infinity
toward -infinity
nearest ties-to-even
nearest ties-away
~~~

They also require defined behavior for NaN, infinity, overflow and destination
range.

M3.5 deliberately does not invent these policies ahead of a concrete consumer
need and full specification.

## 13. Compile-time relation

The repository adds a package-internal relation:

~~~text
isUniversallyExactRasterConversion!(From, To)
~~~

It exists to implement #105's constraints.

It is intentionally not root-exported.

Issue #107 owns the later decision whether a public trait such as
isExactConvertible represents a sufficiently useful caller-visible capability.

The implementation includes compile-time boundary tests for:

- integer range containment;
- integer -> float precision limits;
- integer -> double precision limits;
- float -> double widening;
- double -> float rejection;
- floating -> integer rejection;
- real rejection.

## 14. Relationship to v0.1 conversion

The existing:

~~~d
tryConvertUbyteToFloatPlane(...)
~~~

remains unchanged.

Its successful sample result is exactly:

~~~d
cast(float) sourceSample
~~~

for the full ubyte domain, which is precisely RasterConversionPolicy.exact.

It remains compatibility/evidence while #105 builds the generic family.

## 15. Failure/output-state direction for #105

Because M3.5 exact accepts only universally exact type pairs, numeric conversion
itself cannot fail per sample.

Therefore #105 can preserve a strong destination-state contract:

- structural/request failures are detected before the first destination write;
- once execution begins, exact sample conversion has no numeric failure path;
- no hidden scratch raster is required merely to provide atomic numeric
  conversion failure.

This is a key reason for promoting universal exact conversion first.

## 16. Policy selection mechanism

RasterConversionPolicy is a public semantic enum.

For the generic conversion API, policy selection may be used as a compile-time
semantic parameter where it controls legal type pairs and implementation shape.

M3.5 does not yet freeze #105's final function signature.

It does freeze that an operation claiming exact must obey the exact relation
defined here.

## 17. Allocation and scheduling

Conversion policy itself does not imply allocation or scheduling.

The destination-oriented #105 form remains the performance-oriented primitive.

The allocating #106 form must be a convenience wrapper over the same semantic
conversion.

No policy may silently introduce:

- destination allocation in an Into form;
- background work;
- global scheduling;
- image-domain normalization.

## 18. Public compatibility position

Current public surface added by M3.5:

~~~text
RasterConversionPolicy
RasterConversionPolicy.exact
~~~

Future enum members are not implied or promised by this issue.

Adding a new policy later requires:

- complete behavior specification;
- positive/negative type constraints;
- failure/output-state semantics;
- DMD/LDC tests;
- numerical edge tests;
- performance qualification when relevant.

## 19. Acceptance mapping

Issue #104 goal:

Replace ad-hoc conversion growth with explicit conversion semantics.

Satisfied by introducing one public policy family and a single exact semantic
contract for the first generic conversion path.

Candidate policies:

- exact -> PROMOTED;
- checked -> DEFERRED;
- saturating -> DEFERRED;
- narrowing -> DEFERRED;
- explicit rounding -> DEFERRED.

Acceptance:

Only policies with fully specified behavior are promoted.

M3.5 promotes only exact and explicitly records why all other candidates remain
unpromoted.
