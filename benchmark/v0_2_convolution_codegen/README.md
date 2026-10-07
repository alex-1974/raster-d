# M5.3 convolution codegen diagnostic

This harness decomposes the remaining DMD-only fixed-convolution signal after
the neighbourhood release-stride bug was fixed.

Input signal:

- DMD 2.111.0 public one-shot/direct-fixed: about 2.90x;
- LDC 1.41.0 public one-shot/direct-fixed: about 0.96x.

All measured paths implement the same centered weighted 3x3 float convolution
with double accumulation and one final float narrowing.

Paths:

- public_convolution:
  production `convolveInto`;
- public_neighbourhood_loop:
  production `applyNeighbourhoodInto` with a benchmark-local kernel matching
  the production coefficient-loop source form;
- hot_neighbourhood_loop:
  approved Canonical 3x3 executor with the same loop kernel;
- hot_neighbourhood_unrolled:
  approved Canonical 3x3 executor with an explicitly unrolled arithmetic kernel;
- direct_unrolled:
  benchmark-local direct Canonical pointer traversal with the same explicit
  arithmetic.

This separates:

1. convolution wrapper/alias effects;
2. public neighbourhood preflight/dispatch effects;
3. kernel loop source-form effects;
4. neighbourhood materialization/executor effects.

No production source is changed by this diagnostic. The XPS runner retains six
CPU-pinned processes per compiler and complete objdump disassembly.
