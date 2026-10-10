# raster-d v0.2 M5.4 — SIMD qualification

Status: complete.

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


## Slice 1 retained result

Reference archive:
`raster-v0.2-simd-convolution-20261008-090142.tar.gz`

SHA256:
`ee52776194074e7ae9b28a117bde02b5e0ad3c56d6f0d9ad63c2a5c2c2787b02`

Head:
`8a1377b6600d8b2ea1580dac6aa2cc321d331f89`

The recursive manifest verifies completely. The run contains six CPU-pinned
processes per compiler and all three paths produce the same checksum:

`7596c236fe0ac383`

Reference-XPS medians (ns/pixel):

| path | DMD 2.111 | LDC 1.41 |
| --- | ---: | ---: |
| production convolution | 4.507869 | 0.634777 |
| direct scalar control | 2.990443 | 0.648845 |
| explicit `float4` | 6.133271 | 0.664759 |

Same-run ratios:

- DMD explicit SIMD / scalar: 2.012496x, range 1.947720..2.105551;
- DMD production / SIMD: 0.746482x;
- LDC explicit SIMD / scalar: 1.030416x, range 1.000018..1.201719;
- LDC production / SIMD: 0.954107x.

The explicit SIMD candidate is rejected.

DMD does emit packed SSE for the `float4` path, but retains substantial
constant-materialization and temporary stack traffic. The explicit vector form
is therefore materially slower than the direct scalar source form and slower
than production.

LDC already auto-vectorizes the direct scalar control into packed SSE. The
handwritten `float4` form adds no material benefit.

Frequency snapshots vary materially under the powersave governor, therefore
cross-run absolute latency is not used for the decision. The paired same-run
ratios are the retained decision evidence.

## Family reconciliation

The current v0.2 families reconcile with R0.5 as follows.

### Copy and fill

No explicit raster SIMD path is justified.

The qualified contiguous copy path reaches `memcpy`; explicit raster-level
vector copying would duplicate the platform/compiler bulk primitive. Fill is
already in the qualified bulk/slice performance class and has no retained
SIMD-specific deficit.

### Conversion

No explicit SIMD path is justified from current evidence.

The fair same-type `ubyte -> float` v0.2 comparison places generic,
specialized and semantic paths at parity on both baseline compilers. The slower
absolute `ushort -> float` result is a different type pair and cannot be used
as evidence for a specialized SIMD requirement.

### Unary transform

No generic explicit SIMD path is justified.

The production Canonical hot loop applies an arbitrary compile-time callable
per element. R0.5 already measured the representative affine float transform
across scalar D, D array expression, pointer and Mir forms. LDC auto-vectorized
suitable portable source forms into the same broad SIMD class; DMD's gains came
from source shape rather than a handwritten vector kernel.

Replacing the generic callable contract with a fixed vector callable model
would be an API/semantic redesign, not an internal SIMD optimization.

### Binary transform and arithmetic

No explicit SIMD path is justified.

M5.3's focused binary diagnostic established public generic zip and
`multiplyInto` at executor parity. The generic binary transform is also a
compile-time callable surface, so a fixed handwritten vector implementation
would not represent the complete semantic family.

### Reductions

No equivalent explicit SIMD implementation is currently qualified.

Strict sum/mean preserve one accumulator, row-major encounter order and one
final division. Reassociated vector reductions are not semantically equivalent.

Extrema preserve NaN propagation and signed-zero selection. A vector reduction
would require an independent semantic proof and performance case; no retained
bottleneck currently justifies that complexity.

### Neighbourhood and fixed convolution

The strongest explicit-SIMD candidate was tested directly and rejected.

The fixed 3x3 float arithmetic graph is lane-parallel across adjacent outputs,
yet handwritten `core.simd.float4` is materially worse under DMD and neutral
to slightly worse under LDC, where the scalar control already auto-vectorizes.

## M5.4 conclusion

M5.4 finds no production operation family for which handwritten SIMD is
currently justified on the qualified Linux x86-64 reference platform.

The engineering rule remains:

- keep semantic validation and execution boundaries explicit;
- prefer portable D source forms that expose optimization opportunities;
- allow compiler-specific internal source shaping when measured and centralized;
- rely on compiler/platform bulk primitives where appropriate;
- retain explicit SIMD only as a future evidence-driven option;
- never expose compiler or ISA selection in the public raster API without a
  separate semantic requirement.

This conclusion is architecture-specific evidence, not a universal claim that
explicit SIMD can never help raster-d. AArch64/NEON and future compiler
versions require their own measurements before architecture-specific production
selection is introduced.
