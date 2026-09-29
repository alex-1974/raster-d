# R0.5 CPU/SIMD performance study

This experiment studies CPU execution and code generation for representative
raster kernels. It is research evidence, not a production API.

## Questions

The study separates:

- semantic correctness from performance;
- micro-kernel cost from region and consumer cost;
- contiguous from strided execution;
- DMD from LDC/LLVM behaviour;
- normal separate-library builds from same-compilation-unit controls where
  compiler/link boundaries are suspected;
- automatic vectorization from explicit SIMD;
- single-thread performance from parallel scaling.

Explicit SIMD is not the starting assumption. Portable D forms, compiler
code generation, and measured bottlenecks are examined first.

## Initial kernel families

The planned progression is:

1. copy and fill;
2. plane extraction;
3. numeric point conversion;
4. LUT-style scalar transforms;
5. min/max and histogram/reduction;
6. small generic neighbourhood kernels.

## Measurement discipline

Inputs are prepared before timed regions unless allocation/materialization is
part of the operation being measured.

Measurements use:

- monotonic time;
- warm-up;
- repeated samples;
- median plus raw samples;
- alternating comparison order where two implementations are compared;
- a result fingerprint/sink to prevent dead-code elimination;
- deterministic corpora;
- explicit compiler, flags, architecture and workload metadata.

A micro-kernel improvement is not sufficient evidence for promotion. Important
candidates must also be measured through representative raster region or
consumer paths.

When production and a candidate differ unexpectedly under LDC, a generated or
otherwise exact same-compilation-unit copy of the production kernel may be
used to distinguish algorithm cost from compilation/static-library boundaries.

## Correctness

Correctness preflight runs before timing. Candidate implementations must retain
the intended raster semantics. Bit-identical paths should additionally compare
deterministic fingerprints; numerically tolerant paths require an explicit
error contract.

## Build

Debug builds are useful only as compile/correctness sanity checks. Performance
evidence must use an explicit release build.

Sanity:

    dub run --root=experiments/r0_5_cpu_simd --compiler=dmd
    dub run --root=experiments/r0_5_cpu_simd --compiler=ldc2

Performance:

    dub run --root=experiments/r0_5_cpu_simd --compiler=dmd --build=release --force
    dub run --root=experiments/r0_5_cpu_simd --compiler=ldc2 --build=release --force

Retained measurements must also record the exact compiler version and effective
flags. Compiler/version/flag profiles are recorded in
`docs/research/cpu-performance.md`.

The local benchmark executable is ignored by the repository and is not
research evidence by itself.
