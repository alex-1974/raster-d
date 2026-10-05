# ADR 0005: Rebase logical dependencies into resident materialization plans

## Status

Accepted.

## Context

M1.1 introduced package-internal request-bounded dependency geometry.

R0.3 research also proved a second invariant needed by streamed execution:
logical/global dependency geometry is not resident RasterView geometry.

A logical dependency may begin at a very large global coordinate while the
materialized resident raster begins at descriptor coordinate (0, 0).

The production architecture therefore needs a checked metadata bridge between
dependency derivation and future source/cache materialization.

## Decision

Production uses a package-internal request materialization plan.

The plan records:

- the ExpandedDependency in logical/global coordinates;
- the resident input region rebased to descriptor origin (0, 0);
- the requested output region expressed relative to that resident input.

For example:

logical output (1010,2011,4,3)
with logical valid input (1009,2010,6,5)
maps to resident input (0,0,6,5)
and resident output (1,1,4,3).

The output offset is derived from region differences:

residentOutput.x = outputRequest.x - validInput.x
residentOutput.y = outputRequest.y - validInput.y

It is not inferred from dependency margins.

## Ownership and execution

The materialization plan owns no raster storage and performs no allocation.

It does not create RasterLease, RasterView or WritableRasterView values.

A later source or cache consumer may use the plan to obtain or build resident
storage, but that source/cache contract remains a separate decision.

## Empty requests

Empty requests remain successful geometry.

When dependency derivation returns an anchored empty valid input, the resident
input and resident output are both anchored at resident origin with zero
extent.

## Context deficit

The plan retains the complete ExpandedDependency, including directional
context deficit.

Planning therefore does not silently authorize execution when logical context
is unavailable.

Border handling remains outside this ADR.

## Coordinate-space invariant

The architecture preserves three distinct layers:

logical request/dependency geometry
resident descriptor geometry
physical stride/address geometry

Large logical origins never become resident pointer offsets merely because a
region is materialized.

## Public surface

No public API is introduced.

The plan and planning helper remain package(raster) implementation details.

## Consequences

M1 gains a concrete consumer of dependency geometry without prematurely
freezing a provider, cache or scheduler abstraction.

Later source/cache work can consume one stable planning result rather than
re-derive coordinate rebasing independently.

## Non-decisions

This ADR does not define source identity, provider interfaces, cache blocks,
allocation strategy, RasterLease creation, I/O, scheduling, cancellation,
prefetch, border policy or public request types.
