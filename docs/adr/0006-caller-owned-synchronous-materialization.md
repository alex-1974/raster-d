# ADR 0006: Use caller-owned synchronous materialization as the first source boundary

## Status

Accepted.

## Context

R0.6 in `raster-d-research` qualified four source/materialization shapes on
both DMD and LDC:

- caller-owned contiguous and padded resident destinations;
- retained/adopted source output with PRE-COMMIT ownership preservation;
- a non-image two-plane interleaved padded scientific/vector-field source;
- arbitrary logical requests over a source with fixed internal blocks.

The evidence showed that provider blocks, cache blocks, scheduler ownership,
image semantics and runtime inheritance are not required at the generic raster
materialization boundary.

M1.1 and M1.2 already provide request dependency geometry and the checked
logical-to-resident `RequestMaterializationPlan`.

## Decision

The first production source boundary is package-internal, synchronous and
caller-owned.

A materialization orchestration helper combines:

`RequestMaterializationPlan + source capability + WritableRasterView!T`

The source capability is compile-time/callable and provides:

`bool materializeInto(Region2D logicalRegion, scope WritableRasterView!T destination)`

The helper forwards exactly `plan.dependency.validInput` as the logical source
region.

The supplied resident destination must exactly match `plan.residentInput`.

## Empty materializations

If `plan.dependency.validInput` is empty and the destination geometry matches
the plan, materialization succeeds without invoking the source.

No allocation or source work is required to materialize an empty dependency.

## Failure model

The orchestration layer distinguishes:

- destination geometry mismatch;
- source/materialization failure.

Source-specific diagnostics remain owned by the source or adapter.

## Context deficit

Context deficit remains part of the materialization plan.

The source layer materializes the valid logical input that exists. It does not
interpret missing logical context and does not select a border policy.

## Ownership and allocation

The orchestration helper performs no allocation and does not transfer
ownership.

The caller owns the destination storage and its lifetime.

R0.6 also proved retained/adopted source output is viable, but that remains a
separate secondary capability and is not part of this first orchestration
contract.

## Public surface

No new public API is introduced.

The orchestration types and helper remain `package(raster)` implementation
details until multiple production consumers justify a separate public review.

## Non-decisions

This ADR does not define a public RasterSource type, cache integration,
scheduling, asynchronous I/O, cancellation, prefetch, provider tiles,
resampling, border policy, source metadata, or a public source-error hierarchy.
