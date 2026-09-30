# ADR 0004: Define request-bounded raster dependency geometry

## Status

Proposed.

## Context

M1 requires requested-region, halo/context and streaming semantics to move from
research evidence into production architecture.

R0.3a and R0.3b in the separate raster-d-research repository established:

- logical/global request geometry remains separate from resident RasterView geometry;
- request-bounded dependencies can be derived with overflow-safe rectangular margins;
- valid logical input and context missing beyond the logical extent are distinct results;
- processing-task boundaries are not logical-image boundaries;
- task-local halo overlap preserves exact whole/decomposed equivalence;
- logical-image boundary handling must not silently select a border policy;
- bounded residency does not require whole-image materialization.

The research deliberately kept its concrete dependency types out of the
production API pending a separate promotion decision.

The existing production API already exposes Region2D as coordinate-neutral
rectangular geometry. RasterView uses Region2D in resident descriptor space,
while higher layers may use the same value type in logical/global space.

M1 therefore does not need a second region type merely to distinguish those
coordinate spaces. It needs an explicit dependency contract above resident
RasterView geometry.

## Decision

Production architecture adopts a request-bounded rectangular dependency model:

logical output request -> dependency margins -> valid logical input region + directional context deficit

The concepts have these meanings:

- output request: the logical/global region for which output is requested;
- dependency margins: required rectangular context around that request;
- valid input region: the part of the mathematical dependency that lies inside the logical extent;
- context deficit: required context that lies beyond the logical extent.

Clipping the dependency to the logical extent does not itself define border
behaviour. A non-zero context deficit is information about unsatisfied logical
context, not permission to synthesize samples.

## Public surface

No new public API is introduced by this ADR.

Region2D remains the only public rectangular geometry type involved in this
decision.

Dependency margins, context deficit, expanded dependency results and helper
functions remain package-internal initially.

This keeps the public surface small while M1 acquires real production
consumers. Promotion of any dependency type to the public API requires a later
public-surface review with a concrete external consumer.

## Coordinate spaces

Logical/global placement remains outside RasterView.

The architecture keeps logical request/dependency geometry distinct from
RasterView resident descriptor geometry and from PlaneDescriptor physical
stride geometry.

A future source/cache layer may materialize a valid logical input region into a
resident RasterLease whose RasterView.region is rebased to descriptor-space
coordinates such as (0, 0, width, height). That mapping is explicit metadata
owned above RasterView.

## Geometry validation

Request-bounded dependency derivation must reject invalid or unrepresentable
geometry.

Unchecked arithmetic such as x + width, x - leftMargin, or
x + width + rightMargin must not be used when overflow or underflow is
possible.

The production implementation may reuse or internalize overflow-safe absolute
containment and intersection helpers proven by R0.3, but they are not added to
the public Region2D surface merely for convenience.

Failure is distinct from a successful empty geometric result.

## Empty requests

Empty output requests are valid geometry.

For a valid empty request contained in the logical extent, dependency
derivation succeeds with an anchored empty validInput at the request origin and
a zero context deficit on all sides.

Requested margins do not manufacture input for an empty output request.

This preserves anchored empty geometry and avoids using Region2D.init as an
ambiguous failure sentinel.

## Border policy

This ADR does not define border handling.

In particular, context deficit does not imply zero fill, constant fill, clamp,
mirror, wrap, or extrapolation.

An operation or higher-level policy must decide explicitly how missing logical
context is handled.

## Processing boundaries

Processing decomposition and scheduler task boundaries must not create context
deficit when sufficient logical input exists.

A task may therefore materialize an overlapping halo around its output region.
Input dependencies may overlap even when output regions are disjoint.

This is the production architectural form of the R0.3 decomposition-invariance
result.

## First implementation slice

The first production implementation following this ADR is intentionally small:

1. add a package-internal request/dependency geometry module;
2. implement the proven rectangular dependency derivation semantics;
3. retain Region2D as the shared geometry value;
4. add DMD/LDC unit coverage for zero margins, full margins, every logical edge, non-zero logical origins, empty requests, near-size_t.max geometry, and invalid/unrepresentable input;
5. keep all new dependency symbols inaccessible from the public raster package.

The first real production consumer should be the next M1 request/materialization
planning slice, not a speculative scheduler or cache API.

## Consequences

M1 gains a stable semantic boundary for halo/context propagation without
committing the public API to research-only types.

The design preserves the existing coordinate model and keeps border policy,
source policy, cache geometry and scheduling separate.

Later M1 work can build source/materialization and cache behaviour on a checked
dependency primitive rather than re-deriving geometry ad hoc.

## Non-decisions

This ADR does not decide source/provider API, cache-block representation,
provider-tile representation, scheduler/task API, cancellation or priority,
border-policy API, multi-input dependency representation, full-extent
dependency representation, dependency composition, or public dependency types.
