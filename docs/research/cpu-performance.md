# R0.5 CPU/SIMD performance study

Status: in progress

## Purpose

R0.5 investigates CPU execution performance for representative raster kernels
without assuming that handwritten SIMD is the desired implementation.

The study is evidence for later production decisions. Research implementations
remain separate from production until correctness, performance and API impact
justify promotion.

## Cross-repository evidence carried into R0.5

Existing workspace repositories already demonstrate several relevant failure
modes and successful investigation techniques:

- a hot-path difference can come from the LDC/static-library compilation
  boundary rather than the algorithm itself;
- a small isolated kernel regression can amplify substantially in a real
  consumer;
- inlining and source layout are empirical code-generation questions rather
  than universal style rules;
- validated state can permit narrower internal hot paths without weakening the
  public validation contract;
- fewer instructions or smaller text size need not produce a measurable
  end-to-end throughput improvement;
- necessary allocation or materialization costs must remain in end-to-end
  measurements when they are part of the operation contract.

R0.5 therefore uses controls that distinguish algorithm, representation,
compiler/codegen, compilation boundary and consumer effects.

## Evidence ladder

Performance claims progress through:

    micro kernel
        -> region
        -> representative consumer / pipeline

A microbenchmark result alone is diagnostic evidence.

For suspicious compiler-boundary results, an additional control may compare:

    normal library call
        -> exact same-compilation-unit production copy
        -> combined build

This control exists to avoid promoting an algorithmic workaround for what is
actually a build/code-generation boundary.

## Initial experiment matrix

Kernel families:

- copy/fill;
- plane extraction;
- numeric point conversion;
- LUT-style transforms;
- min/max reduction;
- histogram/reduction;
- small neighbourhood kernels.

Dimensions to vary when relevant:

- contiguous versus strided;
- scalar loop versus D-native array/vector expression versus existing
  raster/Mir form;
- DMD versus LDC;
- normal versus combined/same-unit control when justified;
- normal supported safety configuration versus bounds-check-disabled diagnostic
  builds;
- single-thread versus parallel execution;
- x86-64 versus AArch64 when architecture conclusions are drawn.

Automatic vectorization is examined before handwritten SIMD. Explicit SIMD
requires evidence of a material remaining bottleneck and must not leak ISA
details into the semantic raster API without separate justification.

## Required measurements

Retained results follow `BENCHMARK.md` and record, as applicable:

- elapsed time;
- MPix/s;
- effective GB/s;
- allocation count and allocated bytes;
- temporary-memory peak;
- working-set peak;
- thread count and CPU utilisation;
- compiler/frontend/LLVM version;
- compiler flags and build mode;
- CPU architecture and reference-machine identity;
- workload size/layout/stride;
- correctness fingerprint or numerical-error result.

## Benchmark controls

The common experiment harness starts with:

- deterministic inputs;
- correctness preflight before timing;
- monotonic timing;
- warm-up;
- repeated raw samples and median;
- result fingerprint/sink;
- input preparation outside the timed region unless intentionally measured.

Pairwise experiments should additionally counterbalance execution order. The
initial scaffold does not yet claim to implement every required control; each
control is added before evidence depending on it is retained.

## Promotion rule

No production optimization is promoted merely because it wins a microbenchmark.

Promotion requires:

1. preserved semantics and correctness;
2. a reproducible material improvement in the relevant workload;
3. evidence that the improvement survives the appropriate region/consumer
   boundary;
4. no unjustified architecture or compiler coupling;
5. documented rejected alternatives where they materially informed the
   decision.

## Current state

The initial scaffold contains only deterministic corpus support, timing,
fingerprinting and scalar copy/fill reference kernels. It intentionally makes
no SIMD or performance claim.
