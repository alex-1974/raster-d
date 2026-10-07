# M5.3 signed-affine neighbourhood codegen diagnostic

This diagnostic isolates the remaining LDC-only 5x3 sample-strided performance
gap after PR #170 introduced the validated signed-affine pointer/stride
executor.

Reference production evidence:

- DMD 2.111.0: sample-strided / Canonical = 0.875674x;
- LDC 1.41.0: sample-strided / Canonical = 6.217490x.

The benchmark-local loops are semantically equivalent and operate on the same
5x3 weighted float neighbourhood.

Measured source forms:

- canonical_static1: source/destination sample stride fixed at 1;
- affine_runtime_s2_d2: source and destination sample strides passed at runtime;
- affine_static_s2_d2: source and destination sample strides fixed at 2 at compile time;
- affine_runtime_s2_d1: source stride 2, destination stride 1;
- affine_runtime_s1_d2: source stride 1, destination stride 2.

The diagnostic answers three questions:

1. Is the LDC penalty caused primarily by runtime sample-stride induction?
2. Does source or destination sample stride dominate?
3. Does compile-time specialization of the known stride recover Canonical-like
   code generation?

No production source form is changed by this harness. The XPS runner retains
DMD/LDC disassembly and six independent CPU-pinned process measurements.
