# ADR 0014: Compiler-qualified exact conversion execution

## Status

Accepted.

## Context

ADR 0013 promoted checked same-/cross-type affine bounds and safe approved-row
execution for exact `ubyte -> float` conversion. That deliberately left
compiler-specific execution gaps open.

Subsequent research isolated three independent facts on the reference
x86-64 XPS platform:

1. DMD 2.111.0 benefits materially from a bounded row-local execution form at
   approved unit sample stride and row width at least 64.
2. LDC 1.41.0 / LLVM 19.1.7 loses substantial performance specifically when
   the source row stride is negative; a small out-of-line safe row helper
   restores row-local optimization.
3. The previously qualified exact SSE2 row algorithm still materially
   outperforms the later DMD bounded-pointer Production path when remeasured
   through the complete public operation.

The final refresh compares SSE2 directly against current Production rather than
against an obsolete scalar baseline.

## Decision

Exact `ubyte -> float` conversion keeps one public semantic contract and one
generic fallback, but may select private compiler-qualified row executors after
all existing validation, injectivity and exact overlap checks have succeeded.

### DMD x86-64

For approved unit-sample-stride rows with width at least 64, use the exact SSE2
row kernel:

- load sixteen ubytes with an unaligned 16-byte load;
- widen bytes to words, then words to dwords;
- convert four dword groups with `CVTDQ2PS`;
- store four four-float groups with unaligned stores;
- complete any remainder with the exact scalar conversion.

Every source value is in 0..255 and is exactly representable as `float`.
No fast-math, reassociation or contraction is involved.

Widths below 64 retain the ordinary scalar approved-row path.

### LDC x86-64

For approved unit-sample-stride rows with:

- negative source row stride; and
- width at least 64,

call a small `pragma(inline, false)` safe row-local conversion helper.

Positive-source rows, repeated-source rows, negative-target-only layouts and
other unaffected Canonical forms keep the ordinary Production row path.

### Other compilers / Universal layouts

No compiler-specific executor is selected. Universal/non-unit-sample-stride
traversal remains unchanged.

## Safety

The SSE2 helper reuses the already qualified bounded load/store trust pattern.
Its trusted operations are limited to converting live scoped subslices to
unaligned SIMD load/store pointers of exactly the subslice size. No pointer or
reference escapes.

The LDC negative-source helper is `@safe`; it changes only the optimizer
boundary.

All public validation, error ordering, no-write behavior, empty behavior,
destination injectivity and exact source/destination overlap semantics remain
unchanged.

## Evidence

The DMD bounded-pointer full-public qualification was promoted in PR #62.
The LDC signed-source boundary was promoted in PR #64.

The final SSE2 refresh was performed against Production
`24d948255df014c683d79c5508f13248806062dc` and retained as:

- research Issue #46 / PR #47;
- archive
  `raster-m3-vector-refresh-xps-20261005-110140.tar.gz`;
- SHA256
  `35eaaeef6bbd1d3d3ac12168a84824eb51456cfbc7660b3bf39b97517ebd3f51`.

On the Intel Core i7-9750H reference XPS, six fixed-binary CPU0-pinned
processes produced pooled DMD Production/SSE2 medians of approximately:

- 1.695x for the short active cohort;
- 1.677x for the long active cohort.

Inactive DMD controls and all LDC controls remained near 1.00x. The linked DMD
binary retained the expected SSE2 instruction family.

The final DMD SSE2 Production promotion is PR #65.

## Consequences

Compiler-specific source form is permitted only behind the private execution
boundary and only where qualified evidence supports it.

The semantic API does not expose compiler, ISA or layout-selection controls.

The previous DMD bounded-pointer row implementation remains valuable retained
research evidence but is superseded in Production for width >=64 by the exact
SSE2 kernel.

AArch64/NEON is not inferred from x86-64 evidence and remains separately
qualified future work.
