# ADR 0015: DMD strict Canonical reduction specialization

## Status

Accepted.

## Context

The public strict `float -> double` reduction requires one double accumulator
and exact logical row-major addition order. M3.4 research compared the complete
public operation with alternative Canonical row execution forms while preserving
that semantic graph.

Initial XPS evidence showed a modest DMD advantage for a bounded pointer form.
A controlled six-process confirmation then established that the advantage is
repeatable on large padded, negative-row and repeated-row Canonical layouts,
while contiguous and LDC controls remain near parity.

The historical reduction source used by that research was verified byte-identical
to the corresponding reduction modules on current Production before promotion.

## Decision

For DMD x86-64 strict Canonical reduction, use one private local pointer-based
row executor.

The executor:

- receives an already validated non-empty Canonical plane;
- uses sample stride one;
- supports signed row stride;
- carries exactly one `double` accumulator across all rows;
- visits samples in exact logical row-major order.

The existing contiguous Mir path remains unchanged.

Universal/non-Canonical traversal, LDC and other compilers remain unchanged.

## Safety and numerical semantics

The helper is `@trusted` only for local pointer traversal over the previously
validated retained backing.

It does not:

- reassociate additions;
- use fixed-lane partial sums;
- enable fast-math or contraction;
- introduce SIMD reduction;
- introduce threading.

Therefore the strict one-accumulator semantic graph is preserved.

## Evidence

Controlled confirmation is retained in raster-d-research Issue #21 / PR #43.

Reference archive:

- `raster-m3-reduction-pointer-confirm-20261005-101445.tar.gz`
- SHA256
  `46c778441788941e35483e6279a36c05f89b94730416bd1e6f7341b5a04f3b1`

On the Intel Core i7-9750H reference XPS, six fixed-binary CPU0-pinned DMD
processes showed representative public/pointer medians of roughly 1.128x to
1.131x on large Canonical padded, negative-row and repeated-row cases.
Contiguous and LDC controls remained approximately 1.00x.

Production promotion is PR #63.

## Consequences

Strict numerical semantics remain the specification; compiler-specific execution
is an internal implementation detail.

Manual SIMD reduction, reassociation and parallel reduction remain excluded
until a different public numerical contract explicitly permits them.

AArch64 performance remains unqualified.
