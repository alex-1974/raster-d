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


## Baseline R0.5b — contiguous float copy/fill

Date: 2026-09-29

Reference run:

- architecture: x86-64;
- DMD: 2.111.0;
- LDC: 1.41.0, DMD frontend 2.111.0, LLVM 19.1.7;
- LDC host CPU reported as Skylake;
- build: DUB `release`, forced rebuild;
- workload: 1,048,576 contiguous `float` elements;
- repetitions: 9 after 2 warm-up rounds;
- comparison order: counterbalanced within each pair;
- correctness: scalar and slice variants passed pre/postflight fingerprints.

The effective bandwidth figures below use 8 bytes per copied float (read +
write) and 4 bytes per filled float (write). They are diagnostic effective
bandwidth, not a claim about physical DRAM traffic.

| Compiler | Kernel | Median | MPix/s | Effective GB/s | Slice/scalar time |
| --- | --- | ---: | ---: | ---: | ---: |
| DMD 2.111.0 | copy scalar | 1.112 ms | 943.0 | 7.54 | — |
| DMD 2.111.0 | copy slice | 0.2335 ms | 4490.7 | 35.93 | 0.210 |
| DMD 2.111.0 | fill scalar | 0.5497 ms | 1907.5 | 7.63 | — |
| DMD 2.111.0 | fill slice | 0.3290 ms | 3187.2 | 12.75 | 0.599 |
| LDC 1.41.0 | copy scalar | 0.1724 ms | 6082.2 | 48.66 | — |
| LDC 1.41.0 | copy slice | 0.1400 ms | 7489.8 | 59.92 | 0.812 |
| LDC 1.41.0 | fill scalar | 0.1055 ms | 9939.1 | 39.76 | — |
| LDC 1.41.0 | fill slice | 0.1053 ms | 9958.0 | 39.83 | 0.998 |

Observed within this run:

- DMD slice copy was about 4.76x faster than the scalar loop;
- DMD slice fill was about 1.67x faster than the scalar loop;
- LDC slice copy was about 1.23x faster than the scalar loop;
- LDC scalar and slice fill were effectively equal at the median.

These results are retained as a first local baseline, not as production
promotion evidence. The run records only one workload size and one invocation;
CPU affinity, frequency state, hardware identity/memory configuration,
allocation counters and repeated independent process runs are not yet recorded.

The large DMD/LDC and scalar/slice differences make compiler/code-generation
inspection the next diagnostic step. In particular, R0.5 must determine
whether the slice forms lower to library primitives, vectorized loops, or other
specialized code, and whether LDC already vectorizes the scalar forms. No
handwritten SIMD is justified by this baseline.


## R0.5b abstraction probe — contiguous raster copy

A second release run measured the existing raster execution layers against the
raw copy controls for the same 1,048,576-element `float` workload.

The raster-specific paths were:

1. `RasterView -> asMirContiguousFlat -> scalarCopyContiguous1D`;
2. `RasterView -> checked contiguous dispatch -> non-overlap proof -> memcpy`.

| Compiler | Path | Median | Effective GB/s | Time / raw slice |
| --- | --- | ---: | ---: | ---: |
| DMD 2.111.0 | raw scalar | 1.3394 ms | 6.26 | 8.87x |
| DMD 2.111.0 | raw D slice | 0.1510 ms | 55.55 | 1.00x |
| DMD 2.111.0 | raster Mir Contiguous1D scalar | 4.4539 ms | 1.88 | 29.50x |
| DMD 2.111.0 | raster checked contiguous copy | 0.2819 ms | 29.76 | 1.87x |
| LDC 1.41.0 | raw scalar | 0.1762 ms | 47.61 | 1.25x |
| LDC 1.41.0 | raw D slice | 0.1408 ms | 59.58 | 1.00x |
| LDC 1.41.0 | raster Mir Contiguous1D scalar | 0.2519 ms | 33.30 | 1.79x |
| LDC 1.41.0 | raster checked contiguous copy | 0.2333 ms | 35.96 | 1.66x |

All paths retained the same correctness fingerprint.

Interpretation is deliberately limited to this run. The DMD Mir scalar path is
far slower than both the raw scalar loop and D slice copy, so it must not be
treated as a zero-cost abstraction for contiguous copy. LDC narrows that gap
substantially, but the measured Mir path still trails the raw slice control.

The checked raster path is qualitatively different: after validation and
physical non-overlap proof it reaches the retained `memcpy` implementation.
Its median remains much closer to the fast raw copy paths on both compilers.
This run includes invocation-local checking and dispatch, so it is not a pure
measurement of the copy primitive.

The raw and raster timings also show substantial sample variation in several
paths. Therefore the current ratios are diagnostic, not stable performance
thresholds. Before changing production code, R0.5 should:

- inspect generated code for raw scalar, raw slice, Mir Contiguous1D and the
  checked-copy path;
- separate one-time adapter/dispatch work from repeated kernel execution where
  the production execution model permits reuse;
- repeat across independent processes and multiple working-set sizes;
- add a same-compilation-unit/combined-build control if generated code suggests
  a compilation-boundary effect.

No handwritten SIMD is justified by these results.


### Combined-build control

A normal-versus-`--combined` control was attempted with both LDC 1.41.0 and
DMD 2.111.0. The combined build did not reach the raster benchmark. Both
compilers failed while compiling Mir's algebraic/annotated modules with the
same attribute mismatch: a `pure nothrow @nogc` `Algebraic.opEquals`
instantiation attempted to call an `Annotated.opEquals` that does not satisfy
those attributes.

Therefore no combined-build timing comparison exists for this probe. The
failure is a toolchain/dependency build-mode observation, not evidence for or
against a raster-d compilation-boundary performance effect.

The accompanying normal builds continued to show the compiler-dependent
pattern. DMD's raster Mir Contiguous1D samples were tightly clustered around
4.28--4.42 ms (median 4.3248 ms), while the checked contiguous path had a
0.3033 ms median. LDC's run was noisier during early samples; after the early
outliers, Mir and checked contiguous samples reached roughly the same
0.13--0.21 ms regime. This reinforces the need for generated-code inspection
and independent-process timing before changing production implementation.


## Affine transform matrix — first release result

Date: 2026-09-29

Kernel:

```d
dst[i] = src[i] * gain + bias;
```

Configuration:

- x86-64 reference machine;
- DMD 2.111.0;
- LDC 1.41.0 / DMD frontend 2.111.0 / LLVM 19.1.7;
- release build;
- deterministic inputs and output fingerprints;
- 2 warm-up rounds;
- 12 measured repetitions;
- rotating four-way execution order;
- variants: scalar D slice loop, D array expression, pointer diagnostic control, Mir contiguous 1D;
- working sets: 65,536; 1,048,576; 8,388,608 float elements.

### Medians

| Compiler | Elements | Scalar | D array | Pointer | Mir contiguous 1D |
|---|---:|---:|---:|---:|---:|
| DMD | 65,536 | 96.6 us | 17.6 us | 57.3 us | 294.3 us |
| DMD | 1,048,576 | 1.7601 ms | 0.6394 ms | 1.2081 ms | 4.8805 ms |
| DMD | 8,388,608 | 14.9431 ms | 6.2730 ms | 9.7595 ms | 39.7841 ms |
| LDC | 65,536 | 10.2 us | 10.2 us | 10.2 us | 10.2 us |
| LDC | 1,048,576 | 0.2606 ms | 0.1962 ms | 0.2010 ms | 0.2290 ms |
| LDC | 8,388,608 | 4.3781 ms | 4.3509 ms | 4.2772 ms | 4.3513 ms |

### Interpretation

The result confirms a compiler-specific source-shape effect.

Under DMD:

- the D array expression is consistently the fastest of the four measured affine forms;
- the pointer diagnostic removes part of the scalar-loop overhead but remains substantially slower than the D array expression;
- the Mir contiguous form is much slower than every other form;
- the performance gap persists from cache-near through large working sets.

Under LDC:

- all four forms converge very closely at 65,536 and 8,388,608 elements;
- at 1,048,576 elements the array, pointer, and Mir variants are somewhat faster than the scalar median, but the raw samples contain substantial outliers;
- the 8,388,608-element result is the strongest large-working-set evidence: all four forms are within roughly 2.4% of one another.

This matches the code-generation diagnostic:

- DMD keeps scalar work scalar, and its Mir form retains a per-element helper call;
- LDC auto-vectorizes scalar, pointer, D-array, and Mir affine forms into essentially the same SIMD loop shape.

### Current engineering conclusion

Do not introduce handwritten SIMD for this affine kernel.

Do not introduce a production compiler split yet.

The evidence does justify treating compiler-specific internal source forms as an allowed future optimization mechanism. A production split would require a representative raster operation, repeated independent runs, supported compiler/version coverage, and a centralized compiler capability gate.

The strongest present candidate is:

- LDC: preserve the clearest portable form that continues to auto-vectorize through the real raster abstraction;
- DMD: investigate D array expressions for already-classified contiguous 1D kernels where their non-overlap and operation-order semantics fit the raster contract.

The raw-pointer form is not promoted. It does not outperform the D array expression under DMD and provides no material advantage under LDC.

### Measurement caveat

The DMD 1 Mi and 8 Mi D-array samples, and several LDC 1 Mi samples, show noticeable spread. These medians are strong enough to establish the large qualitative compiler difference, but not yet precise enough for a small-threshold regression gate. Independent process runs and CPU controls remain required before setting numeric acceptance thresholds.


## R0.5c — real raster ubyte-to-float conversion

The first production-path computational probe uses the retained exact
`ubyte -> float` conversion rather than introducing a synthetic raster API.

The benchmark separates:

1. the existing flat contiguous Mir conversion kernel; and
2. the complete checked contiguous dispatcher, including layout/shape and
   physical non-overlap validation before invoking the same kernel.

The 2026-09-29 Linux x86-64 release run measured:

| Elements | Compiler | Kernel median | Dispatch median | Dispatch/kernel |
| ---: | --- | ---: | ---: | ---: |
| 65,536 | DMD | 0.3623 ms | 0.3375 ms | 0.932 |
| 1,048,576 | DMD | 5.7208 ms | 5.5119 ms | 0.963 |
| 8,388,608 | DMD | 38.7494 ms | 38.8719 ms | 1.003 |
| 65,536 | LDC | 0.1426 ms | 0.1427 ms | 1.001 |
| 1,048,576 | LDC | 2.3053 ms | 2.3242 ms | 1.008 |
| 8,388,608 | LDC | 18.9695 ms | 18.9639 ms | 1.000 |

All correctness fingerprints matched between the kernel-only and checked
dispatch paths.

### Interpretation

For large working sets the checked raster dispatch adds no measurable material
cost relative to the existing conversion kernel. The validation architecture
is therefore not the observed bottleneck in this operation.

The computational kernel itself remains compiler-sensitive. At 8,388,608
samples the measured DMD median is about 2.04 times the LDC median. This is a
large enough difference to justify code-generation inspection and alternative
DMD-friendly kernel formulations.

This run also exhibited substantially more timing variation in several earlier
copy and affine controls than the previous run. Those noisy control medians
must not replace the earlier evidence or be turned into thresholds. The
large-size conversion samples are sufficiently clustered to support the
qualitative compiler-gap conclusion, but the next experiment should retain the
same counterbalanced methodology and inspect generated code before any
production change.

### Decision

Do not weaken or bypass the checked raster dispatch: current evidence shows
that its safety/semantic checks are effectively amortized for raster-sized
contiguous conversion.

Do not introduce handwritten SIMD.

Next isolate the contiguous `ubyte -> float` conversion formulation itself:
compare the current Mir loop with D-slice/index and narrowly scoped pointer
forms under DMD and LDC, then inspect code generation. Any eventual
compiler-specific production specialization must remain below the common
raster semantic/validation boundary.


## R0.5c — conversion source-form isolation

A follow-up experiment isolated the exact `ubyte -> float` computation from
the raster validation layer. Four forms were compared with the same input,
output and correctness fingerprint:

- the current production Mir contiguous 1D kernel;
- a safe D-slice indexed loop;
- a raw-pointer diagnostic loop;
- the full checked raster dispatcher, which reaches the current Mir kernel.

### Large working-set result

At 8,388,608 samples:

| Compiler | Mir | safe D slice | pointer diagnostic | checked dispatch |
| --- | ---: | ---: | ---: | ---: |
| DMD 2.111 | 38.3832 ms | 7.2932 ms | 5.3636 ms | 38.7516 ms |
| LDC 1.41 | 18.7283 ms | 3.1401 ms | 3.2354 ms | 18.6294 ms |

Relative to Mir:

- DMD safe slice: 0.190x, approximately 5.26x faster;
- DMD pointer: 0.140x, approximately 7.16x faster;
- LDC safe slice: 0.168x, approximately 5.96x faster;
- LDC pointer: 0.173x, approximately 5.79x faster.

The LDC large-working-set safe-slice and pointer results are effectively in
the same performance class, with the safe slice slightly faster in this run.
The pointer form therefore provides no evidence for an unsafe production path
on LDC.

At 1,048,576 samples the source-form gap is even larger in the measured run:
DMD Mir 4.7440 ms versus slice 0.8787 ms and pointer 0.5467 ms; LDC Mir
2.3011 ms versus slice 0.2138 ms and pointer 0.1622 ms.

### Revised diagnosis

The previous real-raster experiment established that the checked dispatch
layer adds effectively no material cost. This source-form isolation now shows
that the principal bottleneck is not the raster validation architecture and is
not merely a DMD-versus-LDC compiler gap.

The current Mir `ubyte -> float` conversion formulation is substantially
slower than a direct D-slice loop under both tested compilers.

This result is operation-specific. It does not overturn earlier evidence that
Mir can compile away effectively for other kernels under LDC. In particular,
the affine probe showed that LDC could optimize the investigated Mir affine
form into the same broad SIMD class as the other source forms. The conversion
result therefore argues for evidence-driven kernel selection rather than a
global removal of Mir.

### Current decision

The safe D-slice loop is now the leading production candidate for the
classified contiguous 1D `ubyte -> float` conversion path.

Do not promote the raw-pointer diagnostic path: its DMD advantage over the
safe slice requires code-generation explanation, while on LDC it provides no
large-working-set benefit.

Before changing production code:

1. inspect DMD and LDC assembly/LLVM IR for the Mir, safe-slice and pointer
   conversion forms;
2. identify why Mir blocks or prevents the efficient conversion lowering;
3. verify whether the DMD safe-slice gap to pointer is bounds-check related or
   a deeper vectorization/code-generation issue;
4. repeat the decisive large-working-set comparison in independent process
   runs;
5. if the conclusion survives, replace only the classified contiguous 1D
   conversion kernel while preserving the existing checked dispatch and
   generic/strided paths.


## R0.5c — conversion code-generation diagnosis

A standalone code-generation probe compared stable C symbols for the safe
slice, raw-pointer diagnostic, and Mir production conversion call. The probe
was compiled with bounds checks disabled only for diagnosis; normative runtime
evidence remains the safe release benchmark.

### DMD

The safe-slice and pointer probes lower to the same scalar loop:

- byte load with zero extension;
- scalar integer-to-float conversion;
- scalar float store;
- one loop increment/compare.

No SIMD conversion appears in either form. This means the runtime advantage of
the pointer control over the safe slice observed in one DMD benchmark run is
not explained by a fundamentally different unchecked conversion loop in this
diagnostic build.

The Mir probe does not inline the production conversion kernel. It constructs
the call arguments and emits a call to the separately compiled
`scalarConvertUbyteToFloatContiguous1D`.

### LDC / LLVM

The safe-slice and pointer probes produce the same broad optimized shape.
LLVM emits a runtime overlap check and a vector loop operating on eight bytes
per iteration as two `<4 x i8>` loads, two vector unsigned-integer-to-float
conversions, and two `<4 x float>` stores, followed by scalar/unrolled tail
handling.

The LLVM IR explicitly contains:

- vector memory-conflict checking;
- `load <4 x i8>`;
- `uitofp <4 x i8> ... to <4 x float>`;
- `store <4 x float>`.

The Mir probe again does not inline the separately compiled production
conversion kernel; it tail-calls
`scalarConvertUbyteToFloatContiguous1D`.

### Refined conclusion

The direct safe D-slice formulation is compiler-friendly:

- DMD produces a compact scalar conversion loop;
- LDC auto-vectorizes it without unsafe source code.

The code-generation probe does not yet prove that Mir indexing itself is the
sole cause of the slow production conversion. It proves that the current
separate production-kernel boundary prevents this probe from exposing or
optimizing the Mir loop in the caller. The earlier runtime benchmark still
shows that the retained production Mir path is much slower than the direct
slice form.

The next diagnostic must therefore inspect the generated body of
`scalarConvertUbyteToFloatContiguous1D` itself, and compare normal
separate-library compilation with a same-translation-unit or combined build.
This follows the previously observed workspace pattern where compilation
boundaries can materially affect LDC code generation.

Do not introduce compiler-specific production code or handwritten SIMD on the
basis of this probe. The safe slice remains the leading candidate, but the
remaining question is whether replacing Mir indexing is necessary or whether
the same semantics can be recovered through compilation/inlining structure.


## R0.5c — same-translation-unit Mir control

The same-TU control resolves an important ambiguity in the conversion result.

### LDC

When an exact copy of the Mir conversion loop is visible in the same
translation unit, LDC inlines through the Mir slice abstraction and emits the
same broad vectorized conversion shape as the direct slice and pointer
controls:

- two `<4 x i8>` loads per vector iteration;
- vector `uitofp` to `<4 x float>`;
- two vector stores;
- scalar/unrolled tail handling.

The wrapper `probeConvertMirSameTu` itself contains the vectorized loop after
optimization. In contrast, `probeConvertMir`, which calls the normal
production module, remains a tail call to the externally compiled
`scalarConvertUbyteToFloatContiguous1D`.

Therefore Mir indexing is not intrinsically preventing LDC vectorization for
this kernel. Visibility/optimization across the production compilation
boundary is a material part of the observed performance problem.

### DMD

DMD does not inline the same-TU Mir helper into the C-symbol wrapper in this
probe. Both the same-TU Mir wrapper and the normal production Mir wrapper
retain calls, while the direct slice and pointer controls remain compact
scalar loops.

This is consistent with the earlier DMD/Mir observations but does not yet show
the body generated for the same-TU helper or production helper. DMD therefore
requires separate body-level inspection before choosing a compiler-specific
implementation.

### Consequence

The evidence now separates compiler strategy:

- LDC: preserve the possibility of Mir-based source where optimization
  visibility can be guaranteed; test a combined build before replacing the
  abstraction solely for LDC.
- DMD: direct safe slices remain the strongest simple source-form candidate;
  inspect helper bodies and measure a production-equivalent slice kernel
  before promotion.
- Both: no handwritten SIMD is justified. LDC already generates suitable SIMD
  from safe D source.

The next experiment should measure normal versus combined LDC execution and
inspect the DMD helper bodies. A production change should follow only if those
results confirm the expected compiler-specific behavior.


## R0.5c — DMD Mir helper body and LDC combined-build attempt

Body-level DMD disassembly explains the severe Mir conversion cost. The
same-TU Mir helper still performs a call to Mir
`Slice.opIndexAssign` for every output element. The loop therefore consists
of the byte load and scalar conversion followed by an out-of-line Mir target
assignment call on each iteration. DMD does not eliminate that abstraction in
this configuration.

This materially strengthens the case for a direct safe D-slice execution
kernel for DMD contiguous conversion. The direct slice diagnostic has no
per-element helper call.

The attempted LDC `dub --combined` benchmark did not produce performance
evidence because compilation failed inside the pinned Mir dependency
combination. The failure reports attribute mismatches while instantiating
Mir Algebraic/Annotated equality (`pure`, `@nogc`, and `nothrow`).
Therefore no conclusion about combined-build runtime performance may be drawn
from this attempt.

This combined-build failure is a toolchain/dependency constraint worth
tracking separately. It does not invalidate the same-TU LDC result: when the
conversion body is visible to LDC, the Mir indexing abstraction is optimized
away and the conversion is vectorized.

Current direction:

- DMD contiguous ubyte-to-float: test a safe direct-slice production-equivalent
  kernel; the existing Mir target assignment is demonstrably unsuitable for
  this hot loop.
- LDC: a safe direct-slice kernel is also compiler-friendly and auto-vectorizes,
  so it may provide the simplest compiler-independent production solution even
  though Mir can optimize well when visible.
- Do not require `--combined` as a raster-d performance mechanism while the
  current dependency/toolchain combination cannot build it.
- Do not introduce handwritten SIMD; the source-form problem is already
  sufficient to explain the evidence.
