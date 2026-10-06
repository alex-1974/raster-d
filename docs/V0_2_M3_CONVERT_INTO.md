# raster-d v0.2 M3.6 — generic destination-oriented conversion

Status: implementation candidate for Issue #105.

Baseline:

~~~text
develop
d755596e9ba4feab6de90db739cec17ca998a3ea
~~~

## 1. Public API

v0.2 adds:

~~~d
bool convertRasterInto(
    To,
    RasterConversionPolicy Policy = RasterConversionPolicy.exact,
    From
)(
    scope RasterView!From source,
    size_t sourcePlaneIndex,

    scope ref WritableRasterView!To destination,
    size_t destinationPlaneIndex,

    out RasterConversionError error
);
~~~

UFCS:

~~~d
source.convertRasterInto!float(
    sourcePlaneIndex,
    destination,
    destinationPlaneIndex,
    error
);
~~~

Explicit policy spelling:

~~~d
source.convertRasterInto!(
    float,
    RasterConversionPolicy.exact
)(...);
~~~

Because exact is currently the only promoted policy, it is also the template
default.

## 2. Error model

~~~d
enum RasterConversionError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    shapeMismatch,
    nonInjectiveDestination,
    sourceDestinationOverlap
}
~~~

The exact policy has no per-sample numeric failure.

Every false result is therefore a structural/request failure.

## 3. Type constraints

Instantiation requires:

~~~text
Policy == RasterConversionPolicy.exact
and
isUniversallyExactRasterConversion!(From, To)
~~~

The relation is the M3.5 contract.

Examples accepted:

~~~text
ubyte  -> float
ushort -> int
uint   -> long
int    -> double
float  -> double
double -> double
~~~

Examples rejected at compile time:

~~~text
int    -> float
long   -> double
double -> float
float  -> int
~~~

The relation remains package-internal until #107 decides whether a public trait
is genuinely useful.

## 4. Exact conversion result

For every successful logical coordinate:

~~~d
destination[x,y] = cast(To) source[x,y]
~~~

The type constraint guarantees that this cast is exact for every possible From
value.

No successful conversion performs:

- rounding;
- truncation;
- saturation;
- clamping;
- numeric overflow handling;
- per-sample retry;
- hidden widening policy.

## 5. Structural preflight and output state

All semantic failures are resolved before the first destination write.

Validation order:

1. source plane;
2. destination plane;
3. logical shape;
4. matching empty shape;
5. destination injectivity;
6. exact physical source/destination sample-byte overlap;
7. conversion execution.

Therefore on false:

~~~text
destination content is unchanged
~~~

No temporary raster is required to provide this guarantee because exact
conversion itself cannot fail numerically after execution begins.

## 6. Empty input

Matching empty source/destination shapes succeed as a no-op.

No sample pointer is dereferenced and destination storage is unchanged.

## 7. Destination injectivity

A non-empty destination mapping must be injective.

This is required because conversion writes one result per logical destination
coordinate and does not define multiple-write ordering to aliased physical
samples.

Read-only source self-aliasing remains valid.

## 8. Source/destination overlap

Actual reachable sample-byte overlap is rejected before writing.

Sharing one retained backing allocation is not itself an error.

Disjoint reachable sample bytes inside the same backing are legal.

The historical ubyte -> float pair continues to use its qualified checked-wide
overlap classifier.

Other exact type pairs use a generic allocation-free classifier:

- first, compute reachable sample-address envelopes;
- if envelopes are disjoint, reject overlap in O(N) preflight;
- only if envelopes overlap, perform exact sample-byte pair classification.

This is a correctness-first generic fallback and does not replace the qualified
ubyte -> float path.

Future M5 optimization may specialize additional type pairs if profiling shows
the generic relation preflight is material.

## 9. Layout independence

Every validated resident signed-affine layout is semantically supported:

- contiguous;
- padded;
- positive/negative row stride;
- positive/negative sample stride;
- interleaved/universal;
- ROI.

Execution is logical row-major and uses already validated base pointers and
signed strides.

Physical layout does not alter converted values.

## 10. v0.1 compatibility

The existing:

~~~d
tryConvertUbyteToFloatPlane(...)
~~~

remains unchanged.

For generic:

~~~d
RasterView!ubyte -> WritableRasterView!float
~~~

convertRasterInto delegates internally to the same qualified v0.1 production
engine.

This preserves the established fast path and overlap semantics instead of
creating a second ubyte -> float implementation.

## 11. Allocation / ownership / scheduling

convertRasterInto is:

~~~text
@safe
nothrow
@nogc
~~~

It:

- allocates no output storage;
- allocates no scratch raster;
- retains neither operand;
- transfers no ownership;
- launches no worker/task;
- uses no hidden scheduler.

The caller owns and may reuse destination storage.

## 12. Compile-contract qualification

Fast CI now runs an external compile-only probe for both DMD and LDC.

Expected compile:

~~~text
ubyte  -> float with default exact policy
ushort -> int with explicit exact policy
~~~

Expected rejection:

~~~text
int    -> float
long   -> double
double -> float
float  -> int
~~~

This tests the root-import consumer surface rather than only private helper
traits.

## 13. Failure output-state tests

Runtime tests cover:

- successful ubyte -> float;
- explicit-policy integer widening;
- float -> double including NaN/infinity;
- signed source and destination strides;
- shape mismatch with unchanged destination;
- exact byte-overlap rejection with unchanged shared storage;
- matching empty no-op.

## 14. Performance position

The common qualified ubyte -> float path is reused directly.

The generic path uses direct validated pointer/stride execution and no public
per-sample accessor.

For generic different-size pairs, exact overlap preflight is deliberately
correctness-first. The first envelope check avoids quadratic pair classification
when physical envelopes are disjoint.

Any stronger generic affine byte-overlap specialization belongs to measured M5
optimization work rather than being copied mechanically from the historical
ubyte -> float implementation.

## 15. Acceptance mapping

Issue #105 requires:

### policy and type constraints explicit

Exact policy plus universally-exact From -> To relation.

### failure output state documented

Every false result is pre-write; destination remains unchanged.

### legal layouts semantically equivalent

All validated signed-affine layouts use identical exact conversion semantics.

### no hidden allocation

No allocation or scratch materialization.

### positive and negative compile-contract tests

External compile-only DMD/LDC probes cover supported and rejected
instantiations.

The PR is ready to close #105 once both Fast CI gates are green.
