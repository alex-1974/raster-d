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


## Copy code-generation diagnostic

The first abstraction probe found a material compiler-dependent gap between the
raw, Mir Contiguous1D, and checked contiguous copy paths. Inspect generated code
before changing production implementation.

From the repository root, build the experiment normally first. Then retain
compiler output in a temporary directory rather than committing generated
assembly/IR to the repository.

For LDC, use the experiment source plus the raster-d source tree and inspect
LLVM optimization/vectorization output for the instantiated copy loops. For
DMD, retain assembly and compare the raw scalar loop with the instantiated Mir
Contiguous1D loop. The checked raster path should additionally be inspected to
confirm the expected call/lowering to `memcpy`.

The diagnostic questions are:

- does the raw D slice lower to a bulk-copy primitive;
- does LDC vectorize the raw scalar loop;
- what loop does Mir Contiguous1D instantiate under DMD and LDC;
- are Mir indexing/shape operations retained inside the element loop;
- is the relevant raster/Mir code inlined across the normal library boundary;
- does a combined/same-unit build materially change the generated hot loop;
- does the checked contiguous path reach `memcpy` after its one-time checks.

Generated-code observations are explanatory evidence. Performance conclusions
still require timing on the reference machine.


### Isolated copy probe

`source/codegen_copy_probe.d` contains four intentionally small exported
functions with stable C linkage:

- `probeScalar`: indexed D slices;
- `probeSlice`: D slice assignment;
- `probePointer`: indexed raw pointers;
- `probeMir`: Mir flat Contiguous slices.

The probe exists only to explain compiler code generation. It does not propose
a production API and its raw-pointer function is not a safety recommendation.
Compile this file directly with the same release optimization family used by
the DUB build and inspect the four named functions.
