# ADR 0007: Separate physical residency accounting from cache policy

## Status

Accepted.

## Context

The completed cache-boundary research in `raster-d-research` (Issue #3,
PR #4, main `ae4dec5d9de4f8d8831d6e50954a851743fcaa4c`) established that:

- provider blocks, cache blocks, logical regions and processing tasks are
  distinct concepts;
- retained raster data can use the existing `RasterLease` ownership model;
- a copied lease can outlive cache eviction;
- cache-retained bytes therefore differ from total/request resident bytes;
- physical resources, not logical plane spans, are the correct byte-accounting
  unit;
- one shared/interleaved physical allocation must be counted once;
- over-budget working sets must fail explicitly rather than silently
  oversubscribe memory.

M1.1 through M1.3 intentionally introduced no cache or scheduler API.

## Decision

M1.4 introduces only package-internal bounded-residency accounting.

The production contract has two independent pieces:

1. a way to determine the total physical raster-resource payload retained by a
   `RasterLease`;
2. a small byte-budget admission counter that can admit and release resident
   byte obligations without overflow or underflow.

The contract remains independent of cache identity, replacement policy,
provider geometry, processing decomposition and scheduling.

## Physical resource byte cost

The authoritative physical raster payload already exists in
`RasterBacking.resources_`.

Each `ResourceEntry` represents one retained physical resource and carries its
`byteLength`.

M1.4 therefore sums each `ResourceEntry.byteLength` exactly once.

This naturally avoids double-counting two or more logical planes that share one
physical interleaved allocation.

If the sum is not representable in `size_t`, the query fails explicitly.

An uninitialized `RasterLease` also fails the query.

The M1.4 cost is deliberately the retained raster-resource payload only. It
does not claim to include:

- RasterBacking metadata-table allocations;
- cache bookkeeping;
- operation temporary workspace;
- output buffers owned elsewhere;
- source/decode staging;
- scheduler data;
- GPU memory;
- unrelated process memory.

Those classes require separate accounting if later evidence justifies them.

## Residency admission

The package-internal residency budget stores:

- configured byte limit;
- currently admitted bytes.

Admission succeeds only when the requested byte count fits within the remaining
budget.

Failed admission leaves state unchanged.

Zero-byte admission succeeds and changes nothing.

Release succeeds only when the released amount does not exceed currently
admitted bytes. Failed release leaves state unchanged.

The implementation uses subtraction-based preconditions rather than unchecked
addition:

`requested <= limit - admitted`

under the maintained invariant:

`admitted <= limit`

This avoids arithmetic overflow without introducing another generic arithmetic
abstraction.

## Cache relationship

The residency budget is not a cache budget and is not an eviction mechanism.

Research demonstrated:

`cache-retained bytes != total/request resident bytes`

when independent leases exist.

A later cache may use this accounting contract, but cache policy must remain a
separate layer.

## Empty work

Zero-byte work is valid.

It requires no admission capacity and does not consume the budget.

This is consistent with the existing M1 empty-request/materialization
semantics.

## Public surface

No new public API is introduced.

Physical-cost inspection and residency accounting remain `package(raster)`
implementation details.

They must not be accessible through `import raster` or by external direct
imports of the internal module.

## Non-decisions

This ADR does not define:

- a production cache;
- cache keys or source identity;
- cache block geometry;
- eviction/LRU policy;
- provider tiles;
- block assembly;
- scheduler ownership;
- worker pools;
- prefetch;
- async/cancellation;
- concurrency/locking;
- GPU residency;
- a unified total-process memory manager;
- imagery-specific cache policy.
