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


## Affine transform matrix

The release harness also compares the same affine transform

`dst[i] = src[i] * gain + bias`

through four source forms:

- scalar D slice indexing;
- D array expression;
- raw-pointer diagnostic control;
- the existing Mir contiguous 1D raster execution path.

It runs 65,536, 1,048,576, and 8,388,608 float elements. Each size uses two
warm-up rounds and 12 measured repetitions with a rotating four-way execution
order. A deterministic output fingerprint is checked before and after timing.

Run the matrix as part of the normal release harness:

```bash
dub run --root=experiments/r0_5_cpu_simd --compiler=dmd --build=release --force
dub run --root=experiments/r0_5_cpu_simd --compiler=ldc2 --build=release --force
```

The pointer variant is diagnostic evidence only. It does not establish a
production pointer API or justify an unsafe hot path. Likewise, the matrix is
intended to determine whether portable D source forms preserve compiler
optimization; it is not evidence for handwritten SIMD by itself.


## ubyte-to-float code-generation probe

The conversion source-form result is followed by a standalone probe with stable
C symbols:

- `probeConvertSlice`;
- `probeConvertPointer`;
- `probeConvertMir`.

Compile this probe directly so assembly can be compared without benchmark
driver noise. Use the same release optimization class as the benchmark.

```bash
mkdir -p /tmp/raster-r05-convert-codegen

dmd -c -O -release -inline -boundscheck=off \
  -preview=dip1000 \
  -I=source \
  -I=experiments/r0_5_cpu_simd/source \
  -I=~/.dub/packages/mir-core/1.7.4/mir-core/source \
  -I=~/.dub/packages/mir-algorithm/3.22.4/mir-algorithm/source \
  experiments/r0_5_cpu_simd/source/conversion_codegen_probe.d \
  -of=/tmp/raster-r05-convert-codegen/convert-dmd.o

ldc2 -c -O3 -release -boundscheck=off \
  -preview=dip1000 \
  -I=source \
  -I=experiments/r0_5_cpu_simd/source \
  -I=~/.dub/packages/mir-core/1.7.4/mir-core/source \
  -I=~/.dub/packages/mir-algorithm/3.22.4/mir-algorithm/source \
  experiments/r0_5_cpu_simd/source/conversion_codegen_probe.d \
  -of=/tmp/raster-r05-convert-codegen/convert-ldc.o

ldc2 -c -O3 -release -boundscheck=off -output-ll \
  -preview=dip1000 \
  -I=source \
  -I=experiments/r0_5_cpu_simd/source \
  -I=~/.dub/packages/mir-core/1.7.4/mir-core/source \
  -I=~/.dub/packages/mir-algorithm/3.22.4/mir-algorithm/source \
  experiments/r0_5_cpu_simd/source/conversion_codegen_probe.d \
  -of=/tmp/raster-r05-convert-codegen/convert-ldc.ll
```

The `-boundscheck=off` probe is diagnostic only. The measured benchmark remains
the normative safe-source evidence. This probe asks whether bounds checks,
vectorization, conversion lowering, or retained Mir helper calls explain the
observed source-form differences.
