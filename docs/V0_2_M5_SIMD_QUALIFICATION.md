# raster-d v0.2 M5.4 — SIMD qualification

Status: active.

## Goal

M5.4 reconciles the completed R0.5 CPU/SIMD research with the current v0.2
production families after the M5.3 source/code-generation audit.

Explicit SIMD is not assumed to be desirable. The decision ladder is:

1. preserve public semantics and validation;
2. inspect the current production source form and generated code;
3. prefer portable D source forms and compiler auto-vectorization when they
   already reach the relevant performance class;
4. use explicit SIMD only when a retained same-semantics diagnostic shows a
   material reproducible gain;
5. keep compiler/ISA selection internal and centralized;
6. retain a portable semantic fallback.

## Workspace/repository state note

The current workspace transition table still lists raster-d as not migrated at
the historical `research/r0_4e-persistent-workers` checkpoint.

The actual repository state is newer:

- `develop` is the protected default branch;
- `main` is protected release state;
- `research-integration` exists;
- Fast CI targets `develop` and pull requests to `develop`.

M5.4 therefore follows the current repository workflow while preserving the
historical research branches unchanged.

## R0.5 handoff

R0.5 concluded on the available x86-64 hardware that handwritten SIMD was not
yet justified. The important wins came from source shape, validation/hot-loop
separation and compiler-specific optimization boundaries.

M5.3 has since resolved the material v0.2 compiler/source-form cliffs. M5.4
therefore re-tests SIMD opportunities against the current production forms
rather than promoting old research implementations.

## Candidate matrix

| Family | M5.4 status | Rationale |
| --- | --- | --- |
| copy | not first candidate | contiguous non-overlap path already reaches `memcpy`; explicit raster SIMD would duplicate a bulk primitive |
| fill | not first candidate | current qualified throughput is already in the bulk/slice class; no retained SIMD-specific deficit |
| conversion ubyte->float | no current SIMD gap | generic, specialized and semantic paths are at same-type-pair parity on DMD/LDC |
| conversion ushort->float | diagnostic input only | absolute throughput is slower, but no specialized same-pair SIMD control exists yet; do not infer SIMD need from a different type pair |
| strict sum / mean | semantics-constrained | row-major one-accumulator order is part of the contract; reassociating SIMD reduction is not equivalent |
| min / max / minMax | semantics-constrained | NaN propagation and signed-zero selection must be preserved; explicit vector reduction requires separate proof |
| unary transform | candidate after fixed kernel | LDC can auto-vectorize suitable pointwise forms; arbitrary user callable limits generic explicit-SIMD substitution |
| binary transform/arithmetic | secondary candidate | current public generic multiply is at executor parity; no material wrapper/executor SIMD signal remains |
| fixed neighbourhood/convolution | **primary candidate** | fixed arithmetic graph and adjacent outputs are naturally lane-parallel; DMD remains materially slower than LDC on qualified fixed 3x3 code |

## First diagnostic

`benchmark/v0_2_simd_convolution` compares one fixed 3x3 float convolution
with `Accumulator=float` through:

- production `convolveInto`;
- benchmark-local scalar direct traversal;
- benchmark-local explicit `core.simd.float4` traversal.

The vector path processes four adjacent output pixels per iteration, preserves
the same nine-term per-lane order, uses unaligned vector loads/stores, and falls
back to the scalar kernel for the tail.

This is diagnostic evidence only. It does not establish runtime ISA dispatch,
alignment policy, AVX width, public vector types or a production SIMD path.

## Promotion gate

A SIMD production candidate must satisfy all of the following:

- exact or explicitly contracted semantic equivalence;
- DMD and LDC correctness;
- reference-XPS retained timing with independent processes and CPU affinity;
- generated-code inspection;
- material gain over both the production path and a fair scalar/source-form
  control;
- no regression on the compiler that already auto-vectorizes well;
- centralized, testable compiler/ISA selection;
- portable fallback;
- no public API exposure of compiler or ISA choice.
