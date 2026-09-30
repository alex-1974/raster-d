# ADR 0008: Bounded generic retained store with caller-owned identity

## Status

Accepted.

## Context

M1.4 established physical retained-resource byte accounting and bounded
request/working-set residency admission.

The completed cache-identity research in `raster-d-research` Issue #5 and
PR #6 established a separate identity boundary:

- semantic raster identity is caller-owned;
- provider block/tile geometry is not generic identity;
- resident stride, padding and allocation address are not semantic identity;
- generic lookup/store mechanics need not understand source, generation,
  Region2D or schema fields;
- equality and hashing can be compile-time specialized;
- real `RasterLease!T` values are compatible with this model;
- incomplete or unstable caller identity cannot be repaired by the store.

The research integration commit is:

`3371e2f6474d5f3adee49d1741392598b30e81c9`

The final qualified research run is:

`36709832099`

## Decision

M1.5 introduces a package-internal bounded retained store.

The store is generic over:

- sample type `T`;
- caller-owned `Key`;
- compile-time entry capacity;
- caller-supplied hash function;
- caller-supplied equality function.

It stores typed `RasterLease!T` values.

The store does not define or inspect source identity, source generation,
Region2D, schema identity, provider geometry or image semantics.

## Caller identity contract

The caller owns semantic key construction.

The caller must ensure:

- equal keys identify semantically reusable retained raster values;
- semantically distinct values receive distinct keys;
- mutable/changing sources update their key when required;
- equality is stable while a key is stored;
- hashing is stable while a key is stored;
- `sameKey(a, b) => hashKey(a) == hashKey(b)`;
- key copy/move/reset operations and the supplied hash/equality callbacks are
  compatible with the store's `nothrow` / `@nogc` control-plane paths.

A key type or callback set that cannot satisfy those compile-time attributes is
not a valid instantiation of this internal store shape.

The store cannot infer whether a caller key omitted a semantic distinction.

## Bounded storage

Two independent limits apply.

### Entry capacity

The store has a compile-time fixed number of entry slots.

No store lookup or insertion allocates a dynamic entry table.

When every entry slot is occupied, insertion fails explicitly.

### Store-retained byte limit

The store has its own retained-byte limit.

This limit counts the physical raster-resource payload retained by store-owned
leases.

The byte cost comes from the M1.4 package-internal
`RasterLease.tryPhysicalResourceBytes()` query.

Insertion succeeds only when:

`valueBytes <= retainedByteLimit - retainedBytes`

under the maintained invariant:

`retainedBytes <= retainedByteLimit`

Rejected insertion leaves store state unchanged.

## Relationship to M1.4 ResidencyBudget

The M1.4 `ResidencyBudget` is not reused as the retained-store budget.

The two accounting domains remain distinct:

```text
request / operation residency admission
!=
bytes retained by reusable store
```

A future engine-level memory policy may coordinate them, but M1.5 does not
introduce that policy.

## Ownership

Successful insertion moves one caller-owned `RasterLease!T` into the store.

Lookup copies the stored lease into the output, retaining the same backing.

Therefore an acquired lease remains valid even if the store later clears its
own entries.

Clearing the store:

- releases every store-owned lease;
- resets entry count;
- resets store-retained byte accounting.

Independent copied leases remain responsible for their own retained lifetime.

## Duplicate keys

Insertion of an already present key is rejected explicitly.

M1.5 does not silently replace the retained value for an existing semantic key.

Replacement semantics belong to a later policy layer.

## Replacement policy

M1.5 defines no automatic eviction policy.

It does not select:

- LRU;
- FIFO;
- clock;
- age-based replacement;
- priority replacement.

When entry capacity or retained-byte capacity is exhausted, insertion fails.

This keeps identity, ownership and memory accounting stable before replacement
policy is promoted.

## Invalid retained values

An uninitialized lease is invalid and insertion fails.

M1.5 does not add a separate semantic contract for zero-byte retained raster
representations; their validity remains governed by the existing raster
construction/import contracts.

## Public surface

No new public API is introduced.

The retained-store type, insertion result and helpers remain
`package(raster)`.

They must be inaccessible both through `import raster` and through external
direct import of the internal module.

## Non-decisions

This ADR does not define:

- public RasterCache or retained-store APIs;
- source identity types;
- schema identity types;
- provider/cache block geometry;
- automatic eviction;
- concurrency or locking;
- scheduler ownership;
- worker pools;
- async/cancellation/prefetch;
- persistent/distributed caches;
- GPU residency;
- imagery-specific cache policy.
