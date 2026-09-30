# ADR 0009: Caller-described multi-block dependency resolution

## Status

Accepted.

## Context

M1.1 through M1.5 establish logical dependency geometry, logical-to-resident
planning, synchronous caller-owned materialization, bounded residency accounting
and a bounded retained store over caller-owned semantic keys.

The remaining M1 bridge is to satisfy one logical dependency from more than one
retained/source block without making block selection, provider tiling or
scheduler policy part of raster semantics.

Completed research already demonstrates provider/cache/request geometry
independence, request assembly from several retained blocks, halo-overlap reuse,
caller-owned semantic identity, retained RasterLease reuse and whole/decomposed
neighbourhood equivalence.

## Decision

M1.6 introduces one package-internal sequential resolver.

The caller supplies:

- the exact logical dependency region to fill;
- a caller-owned resident WritableRasterView destination rebased to (0, 0);
- a list of block descriptors;
- the M1.5 retained store;
- a retained-materialization source capability.

Each block descriptor contains only a caller-owned semantic Key and the logical
Region2D represented by that retained/source value.

The resolver never chooses block geometry.

## Coverage validation

Before any store lookup, source call or destination write, M1.6 validates the
complete descriptor coverage.

For a non-empty dependency:

1. every block region must have a representable extent;
2. every block is intersected with the requested dependency;
3. non-empty intersections must be pairwise disjoint;
4. the sum of intersection areas must exactly equal the requested dependency area;
5. all area arithmetic is overflow checked.

Blocks may extend beyond the requested dependency. Blocks that do not intersect
the dependency are ignored after validation. A valid empty dependency is zero
work.

## Retained/source resolution

For each intersecting block the resolver first attempts retained-store lookup.
On a miss it invokes a caller-supplied retained materializer equivalent to:

    bool materializeRetained(
        Region2D logicalRegion,
        out RasterLease!T lease
    )

It then validates block shape and plane topology, copies only the logical
intersection into the corresponding resident destination coordinates, and after
successful use attempts to retain the miss result in the store.

The retained-materialization capability owns allocation/source policy. It may
itself use M1.3 plus a caller-owned allocation strategy.

Because the resolver is @safe, the capability must be safely callable at this
boundary. A source adapter may use a narrowly audited @trusted implementation
to encapsulate validated allocation/import machinery.

## Cache admission is not request success

A successfully materialized miss can satisfy the current dependency even when
the M1.5 store rejects retention because it is full or over its retained-byte
budget.

Therefore store insertion failure is not request resolution failure.

## Coordinate model

Logical placement remains outside RasterView. Block placement and requested
dependency use logical coordinates; retained RasterLease and destination use
resident coordinates. Large logical coordinates therefore do not enter resident
pointer geometry.

## Transfer path

M1.6 uses a simple generic per-sample reference transfer over all logical planes.
This is correctness machinery, not a performance commitment. Later optimization
may replace it with ROI/copy fast paths without changing the semantic contract.

## Failure semantics

M1.6 distinguishes invalid block coverage, destination-region mismatch,
source/materialization failure, invalid retained source value, returned block
shape mismatch, plane-count mismatch and sample-transfer failure.

Store miss is ordinary control flow. Store insertion rejection after successful
source materialization is also not request failure.

M1.6 does not promise transactional rollback. A later failure may leave
already-written destination samples and successfully retained earlier blocks.

## Public surface

All new M1.6 symbols remain package(raster). They are not exported from import
raster and must remain unusable through external direct import of the internal
module.

## Non-decisions

M1.6 does not define cache-block geometry selection, provider identity,
eviction/replacement, a public cache/source API, scheduling, processing-task
decomposition, parallelism, async/cancellation/prefetch, border policy or
image-specific semantics.
