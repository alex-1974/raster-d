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


## R0.5c — promoted contiguous conversion kernel verification

The checked contiguous ubyte-to-float dispatcher was changed to execute the
already-approved non-overlapping flat region through a safe D-slice loop
instead of Mir per-element indexing. Pointer-to-slice formation is confined to
one narrow trusted boundary after layout, extent, and physical non-overlap
validation; the conversion loop itself remains `@safe pure nothrow @nogc`.

Post-change unit tests pass under both DMD and LDC: 29 modules passed.

Representative release medians:

| elements | compiler | Mir control | safe slice | pointer diagnostic | production dispatch |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 292.1 us | 53.7 us | 32.8 us | 50.2 us |
| 1,048,576 | DMD | 4.7289 ms | 0.8723 ms | 0.5522 ms | 0.8181 ms |
| 8,388,608 | DMD | 37.1075 ms | 6.8230 ms | 4.4780 ms | 6.6458 ms |
| 65,536 | LDC | 152.3 us | 7.9 us | 7.9 us | 7.9 us |
| 1,048,576 | LDC | 2.3063 ms | 0.1380 ms | 0.1292 ms | 0.1298 ms |
| 8,388,608 | LDC | 18.8718 ms | 2.9581 ms | 2.9993 ms | 3.1999 ms |

At 8,388,608 samples the production dispatch is approximately 5.58x faster
than the retained Mir control under DMD and 5.90x faster under LDC.

The production dispatch tracks the safe-slice control closely. Validation and
dispatch overhead therefore remain small relative to the removed Mir
per-element cost. The exact ordering between slice and dispatch varies within
normal run noise and should not be interpreted as dispatch itself being faster
than the kernel.

The pointer diagnostic remains non-production evidence. In particular, LDC's
safe slice matches or slightly exceeds pointer performance at the largest
case, while retaining safe source code and automatic SIMD generation. DMD's
pointer diagnostic remains faster, but promotion to an unsafe compiler-specific
kernel is not justified here: the safe production change already removes the
dominant regression without changing public semantics.

### R0.5c promotion conclusion

Promote the safe D-slice execution form for checked flat contiguous
ubyte-to-float conversion. Preserve:

- the existing public and package-level semantic contract;
- validation and physical non-overlap proof before execution;
- the Mir reference/control path for research evidence;
- compiler-independent production source;
- no handwritten SIMD.

This closes the specific contiguous-conversion source-form question. Further
DMD-only optimization, if pursued, must be a separate evidence-backed study
rather than part of this promotion.


## R0.5c — interleaved plane extraction baseline

A research-only plane-extraction matrix compared three equivalent source forms
for extracting channel 1 from interleaved ubyte RGB (stride 3) and RGBA
(stride 4) into a contiguous ubyte destination:

- Mir `Universal` 1D strided view;
- safe D slice indexing;
- trusted pointer diagnostic.

A second safe-slice position was included as an order/noise control.

Representative release medians:

| pixels | compiler | channels | Mir | safe slice | pointer diagnostic |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 3 | 56.8 us | 68.8 us | 32.7 us |
| 65,536 | DMD | 4 | 56.7 us | 68.7 us | 32.4 us |
| 1,048,576 | DMD | 3 | 0.9789 ms | 1.1543 ms | 0.5667 ms |
| 1,048,576 | DMD | 4 | 1.0099 ms | 1.1841 ms | 0.6057 ms |
| 8,388,608 | DMD | 3 | 8.0209 ms | 9.8375 ms | 4.9689 ms |
| 8,388,608 | DMD | 4 | 7.9760 ms | 9.4118 ms | 4.8562 ms |
| 65,536 | LDC | 3 | 18.5 us | 32.2 us | 18.8 us |
| 65,536 | LDC | 4 | 19.1 us | 31.9 us | 19.1 us |
| 1,048,576 | LDC | 3 | 0.3031 ms | 0.5217 ms | 0.3009 ms |
| 1,048,576 | LDC | 4 | 0.3356 ms | 0.5555 ms | 0.3326 ms |
| 8,388,608 | LDC | 3 | 3.1701 ms | 4.6921 ms | 3.1417 ms |
| 8,388,608 | LDC | 4 | 3.6599 ms | 4.9960 ms | 3.6042 ms |

The repeated safe-slice control tracks the first safe-slice position closely,
so the large gap is not explained by benchmark ordering.

### Interpretation

This operation differs materially from contiguous ubyte-to-float conversion.

For interleaved strided reads, Mir does not impose the previously observed
per-element penalty. Under LDC, Mir and the pointer diagnostic are effectively
equivalent across the tested sizes. Under DMD, Mir is slower than the pointer
diagnostic but remains consistently faster than the direct safe-slice indexing
loop.

Stride 4 does not show a systematic advantage over stride 3. In the largest
LDC case it is actually slower for all three forms, so no SIMD-oriented
stride-4 conclusion is justified from timing alone.

The next research question is therefore code generation rather than API or
production promotion: inspect Mir, safe-slice, and pointer forms for fixed
stride 3 and fixed stride 4, with normative release bounds checking preserved
and unchecked builds used only as diagnostics.


## R0.5c — LUT scalar transform baseline

A research-only LUT transform measured the element-wise operation

    target[i] = lut[source[i]]

with an 8-bit source, a 256-entry float LUT, and a float destination. The
initial isolation deliberately compares only a safe D-slice indexed loop with
a trusted raw-pointer diagnostic. Each form is repeated in a second rotating
position to expose order effects.

Representative release medians:

| elements | compiler | safe slice | pointer diagnostic | slice control | pointer control |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 78.7 us | 57.3 us | 78.7 us | 57.2 us |
| 1,048,576 | DMD | 1.3657 ms | 1.0134 ms | 1.3744 ms | 0.9811 ms |
| 8,388,608 | DMD | 11.0376 ms | 8.0469 ms | 10.8422 ms | 7.9833 ms |
| 65,536 | LDC | 70.4 us | 40.2 us | 70.2 us | 40.9 us |
| 1,048,576 | LDC | 1.0492 ms | 0.5815 ms | 1.1542 ms | 0.6111 ms |
| 8,388,608 | LDC | 4.9456 ms | 3.9738 ms | 4.8722 ms | 4.0036 ms |

The duplicate positions preserve the same qualitative ordering, so the
slice/pointer difference is not explained by the four-way execution order.

Unlike the earlier contiguous ubyte-to-float conversion, LDC does not make the
safe slice and pointer formulations equivalent in this LUT workload. At the
largest working set the pointer/slice time ratio is approximately 0.73 under
DMD and 0.80 under LDC. The gap is larger at the smaller LDC sizes.

This is diagnostic evidence only. The pointer form is not a production
candidate on timing alone. The next step is to isolate bounds-check effects and
inspect generated code. In particular, the LUT operation contains two indexed
memory accesses with different bounds contracts: the linear source/target
iteration and the data-dependent LUT lookup. Any unchecked build remains a
diagnostic control, not a proposed production configuration.

No Mir or handwritten SIMD conclusion is drawn from this first LUT baseline.


### LUT bounds-check diagnostic

A diagnostic repeat disabled bounds checking globally through `DFLAGS="-boundscheck=off"`.
This configuration is not a proposed production mode; it exists only to
identify the source of the safe-slice/pointer timing gap.

Representative medians:

| elements | compiler | safe slice, checks on | pointer, checks on | safe slice, checks off | pointer, checks off |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 78.7 us | 57.3 us | 59.1 us | 58.6 us |
| 1,048,576 | DMD | 1.3657 ms | 1.0134 ms | 1.0042 ms | 1.0003 ms |
| 8,388,608 | DMD | 11.0376 ms | 8.0469 ms | 8.4424 ms | 8.3592 ms |
| 65,536 | LDC | 70.4 us | 40.2 us | 24.6 us | 24.6 us |
| 1,048,576 | LDC | 1.0492 ms | 0.5815 ms | 0.4724 ms | 0.4715 ms |
| 8,388,608 | LDC | 4.9456 ms | 3.9738 ms | 3.6394 ms | 3.6012 ms |

The duplicate controls in the unchecked run also converge closely.

This diagnostic resolves the initial source-form ambiguity: once bounds checks
are removed, safe-slice indexing and pointer indexing are effectively in the
same performance class under both DMD and LDC. The checked-build pointer
advantage therefore does not justify a pointer-based production kernel.

The next question is narrower and semantic: determine which checks remain
necessary after validating the operation contract. In particular, a source
sample of type `ubyte` is restricted to 0..255, so a LUT contract requiring
at least 256 entries can prove the data-dependent LUT index valid before the
hot loop. Source and destination lengths can likewise be validated once before
execution. Research should test whether expressing those proven invariants
through a narrow execution boundary can recover the unchecked code-generation
class without weakening the external checked contract.

No handwritten SIMD is justified by this result.


### LUT fixed-extent safe-kernel probe

A follow-up kept the build's normal bounds-checking policy and changed only the
LUT representation. The LUT extent was encoded in the safe kernel type as
`scope ref const(float)[256]`. Because the data-dependent index is a
`ubyte`, its value domain is 0..255. Source and target remained ordinary
safe slices.

Representative release medians:

| elements | compiler | dynamic safe slice | fixed 256-entry LUT | pointer diagnostic | fixed-LUT control |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 78.4 us | 63.1 us | 47.8 us | 63.1 us |
| 1,048,576 | DMD | 1.3028 ms | 1.0596 ms | 0.8121 ms | 1.0561 ms |
| 8,388,608 | DMD | 10.5392 ms | 8.5529 ms | 6.6103 ms | 8.4920 ms |
| 65,536 | LDC | 29.4 us | 31.4 us | 24.6 us | 29.4 us |
| 1,048,576 | LDC | 0.4776 ms | 0.5096 ms | 0.4181 ms | 0.4730 ms |
| 8,388,608 | LDC | 4.2708 ms | 4.5490 ms | 3.8495 ms | 4.2306 ms |

Under DMD the fixed-extent safe form materially improves the checked slice
kernel: at 8,388,608 elements its median is about 19% lower than the dynamic
safe-slice median. It still remains about 29% slower than the pointer
diagnostic (or roughly 23% when expressed as the remaining reduction from
fixed-LUT time to pointer time).

Under LDC the fixed-extent form provides no corresponding benefit. The two
fixed-LUT positions also show some order/noise sensitivity, while remaining in
the same broad class as the ordinary checked slice. The pointer diagnostic is
still faster.

This separates the problem further:

- encoding the LUT extent and ubyte index domain is useful code-generation
  information for DMD;
- it is not a portable explanation for the full checked-build gap;
- source/target slice bounds and/or the exact loop/source form remain relevant;
- the previous global bounds-check-off diagnostic remains the important
  control: with all checks disabled, slice and pointer converge under both
  compilers.

Do not promote the pointer diagnostic or introduce a compiler split from this
result. The next probe should preserve the checked external contract while
isolating the already-proven equal-length source/target execution invariant.


### LUT validated execution-boundary probe

A research-only follow-up moved all dynamic contract checks to a narrow
`@trusted` wrapper and passed only validated pointers plus element count to an
internal `@system pure nothrow @nogc` execution kernel. This is a diagnostic
architecture probe, not a production promotion.

Representative release medians:

| elements | compiler | checked slice | validated execution | pointer diagnostic | validated control |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 78.6 us | 23.8 us | 48.4 us | 23.8 us |
| 1,048,576 | DMD | 1.2594 ms | 0.3880 ms | 0.8142 ms | 0.3841 ms |
| 8,388,608 | DMD | 10.9550 ms | 4.0487 ms | 6.9023 ms | 4.1164 ms |
| 65,536 | LDC | 29.7 us | 25.2 us | 25.2 us | 25.2 us |
| 1,048,576 | LDC | 0.4879 ms | 0.4079 ms | 0.4071 ms | 0.4128 ms |
| 8,388,608 | LDC | 4.3813 ms | 3.7443 ms | 3.7220 ms | 3.7084 ms |

Under LDC the result is straightforward: the validated execution form and the
existing pointer diagnostic are effectively in the same performance class.
This supports the hypothesis that one checked boundary followed by an
invariant-exploiting execution kernel can recover the unchecked hot-loop class
without globally disabling checks.

DMD is more surprising. The validated execution kernel is substantially faster
than the existing pointer diagnostic: roughly 2.1x at 1,048,576 elements and
1.7x at 8,388,608 elements. Its duplicate control closely tracks the first
validated position. The largest DMD case contains several late outliers, but
the separation from the pointer diagnostic is much larger than those ordering
effects and is already clear at the smaller sizes.

This DMD result must not yet be interpreted as evidence for a production
architecture. The two pointer-based forms differ in source structure and
call/validation boundaries, so generated-code inspection is required before
attributing the speedup to aliasing, loop optimization, bounds-check
elimination, inlining, or another compiler effect.

The next step is therefore a focused same-module code-generation probe for the
validated execution kernel versus the existing pointer diagnostic under DMD
and LDC, retaining normal release bounds-check policy. No handwritten SIMD or
public API change is justified yet.


### LUT validated-vs-pointer code-generation diagnosis

Focused same-module assembly inspection resolves an important ambiguity in the
runtime result.

DMD emits effectively the same scalar inner loop for the validated execution
kernel and the pointer diagnostic: load one source byte, use it as the LUT
index, load one float, store one float, increment, compare, branch. The exported
wrappers likewise contain the same basic scalar loop shape. No SIMD or
unrolling difference explains the large DMD runtime separation observed in the
benchmark.

LDC likewise makes the two forms essentially equivalent. Both exported probes
use the same four-element unrolled main loop followed by a scalar remainder.
Each unrolled lane performs a byte load, indexed scalar float LUT load, and
scalar float store. This matches the runtime result where validated execution
and pointer diagnostic are in the same performance class under LDC.

Therefore the earlier DMD timing result -- where the validated path was much
faster than the pointer diagnostic -- must not be attributed to a superior
inner-loop instruction sequence. The focused assembly rules that explanation
out. The remaining investigation must look at benchmark-context effects such
as call-site inlining/code placement, wrapper structure, register/ABI context,
or measurement interaction in the full executable.

This also means there is not yet evidence for a DMD-specific production
algorithm. The robust conclusion remains narrower: once repeated checked slice
indexing is removed after validation, a simple pointer/count execution loop is
sufficient for the compiler to generate the desired check-free loop class.
LDC additionally unrolls that loop automatically. Handwritten SIMD remains
unjustified.


### LUT identical-contract delegated-vs-inline A/B probe

To remove the earlier signature/validation mismatch, a controlled A/B probe
gave both variants the same slice-based external signature and the same
validation contract. The only intended difference was loop placement:

- delegated: checked wrapper calls the pointer/count execution kernel;
- inline: the same wrapper writes the pointer loop directly.

Representative medians:

| elements | compiler | delegated | inline | delegated control | inline control |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 24.4 us | 32.1 us | 24.4 us | 32.1 us |
| 1,048,576 | DMD | 0.4698 ms | 0.6312 ms | 0.5276 ms | 0.6275 ms |
| 8,388,608 | DMD | 4.3336 ms | 4.9173 ms | 4.5024 ms | 5.5161 ms |
| 65,536 | LDC | 26.0 us | 25.9 us | 26.0 us | 26.0 us |
| 1,048,576 | LDC | 0.4191 ms | 0.4174 ms | 0.4175 ms | 0.4155 ms |
| 8,388,608 | LDC | 5.9810 ms | 6.8270 ms | 5.1798 ms | 3.8261 ms |

For DMD the small case is exceptionally stable and shows a repeatable
delegated advantage. The 1 Mi case preserves the same ordering despite more
system noise. The 8 Mi case is noisier but still has both delegated medians
below their corresponding inline medians. Combined with the earlier focused
assembly, this points to a benchmark-context/code-layout/inlining effect rather
than a different scalar loop algorithm.

For LDC the 65 Ki and 1 Mi cases are effectively equal, as expected from the
near-identical generated loops. The 8 Mi measurements are not suitable for a
fine-grained comparison: raw samples vary widely and, importantly, the control
positions reverse the apparent first-pair ordering. No LDC large-working-set
delegated/inline conclusion should be drawn from that run.

This probe strengthens two methodological requirements for later R0.5 work:
small hot-loop differences need duplicate positions/raw samples, and
large-working-set measurements should be repeated under a more controlled
runtime environment before promotion claims are made.

No production split is promoted from the DMD delegated advantage yet. A
focused full-executable/code-placement diagnosis is warranted if the effect is
important enough to retain; otherwise the broader architectural result is
already clear: validate once, then execute a simple check-free internal loop.


## R0.5d — ubyte min/max reduction

The first reduction probe deliberately uses `ubyte` and computes minimum and
maximum together. This avoids floating-point NaN-policy ambiguity while testing
a reduction with loop-carried state.

Measured forms:

- ordinary checked D slice loop;
- pointer diagnostic with the same scalar operation graph;
- manually split four-lane pointer reduction;
- duplicate pointer control position.

The strengthened benchmark sink mixes every invocation non-commutatively with
an invocation counter; the earlier extreme LDC result therefore survives a
DCE-resistant control.

Representative medians after sink hardening:

| elements | compiler | slice | pointer | four lane | pointer control |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 64.2 us | 64.1 us | 72.2 us | 64.6 us |
| 1,048,576 | DMD | 1.0623 ms | 1.0431 ms | 1.1511 ms | 1.0748 ms |
| 8,388,608 | DMD | 8.4383 ms | 8.5531 ms | 9.2449 ms | 8.6947 ms |
| 65,536 | LDC | 1.2 us | 1.2 us | 31.1 us | 1.2 us |
| 1,048,576 | LDC | 29.1 us | 27.3 us | 0.5483 ms | 36.8 us |
| 8,388,608 | LDC | 0.6458 ms | 0.6204 ms | 4.3648 ms | 0.7579 ms |

The large LDC working-set samples are noisy, so their precise ratios are not
promotion thresholds. The 65 KiB result is exceptionally stable and is useful
for code-generation diagnosis.

Focused assembly explains the compiler difference.

DMD keeps the simple reduction scalar: one byte load followed by scalar
comparisons/conditional updates and a scalar loop branch. Its manual four-lane
form substantially increases register pressure and generated-code complexity
and is slower in all measured sizes.

LDC recognizes the simple loop as a vector reduction. Its main path consumes
32 source bytes per iteration using two 16-byte loads and paired unsigned-byte
`pminub` / `pmaxub` accumulators, then performs horizontal vector reduction
and scalar tail handling.

The manual four-lane source form prevents this clean contiguous vector
reduction. LLVM still attempts vectorization, but because the source program
expresses four interleaved logical lanes it emits many individual byte loads
plus `movd` and `punpck*` packing operations before vector min/max work.
The resulting code is dramatically slower than the ordinary loop.

This is strong evidence against manually spelling scalar lane decomposition as
a generic optimization strategy. For this exact integer min/max operation, the
simplest D loop exposes the operation to LDC/LLVM best and is also faster than
the manual lane form under DMD. No handwritten SIMD or compiler-specific
production split is justified by this probe.

The result is operation-specific. Floating-point min/max requires a separate
semantic study because NaN handling, signed zero and ordering policy can change
which transformations are valid.


### Finite float min/max probe

A follow-up probe repeats the min/max experiment for `float`, but deliberately
restricts the timed corpus to finite, non-zero values. This isolates code
generation without yet defining raster-d semantics for NaN or signed zero.

Representative medians:

| elements | compiler | slice | pointer | four lane | pointer control |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 79.3 us | 63.0 us | 59.1 us | 63.1 us |
| 1,048,576 | DMD | 1.3384 ms | 1.0478 ms | 0.9785 ms | 1.0591 ms |
| 8,388,608 | DMD | 11.2661 ms | 8.9274 ms | 8.1876 ms | 8.9298 ms |
| 65,536 | LDC | 64.1 us | 64.1 us | 20.3 us | 64.1 us |
| 1,048,576 | LDC | 1.1469 ms | 1.0902 ms | 0.3956 ms | 1.1307 ms |
| 8,388,608 | LDC | 13.9513 ms | 12.8659 ms | 6.9113 ms | 13.5119 ms |

The LDC 8 Mi-element samples are highly variable, including the four-lane
samples, so the large-working-set median is diagnostic rather than a stable
speedup claim. The 65,536-element samples are much tighter.

Unlike `ubyte`, the explicit four-lane float source form is faster in the
measured finite corpus under both compilers. This does not justify production
promotion. The source form changes the reduction graph, and for unrestricted
IEEE floating-point inputs NaN handling and signed-zero behavior can make such
reassociation observably different.

The next step is therefore semantic rather than performance tuning: characterize
the ordinary scalar operation graph and the candidate lane graph on NaN
placement and +/-0.0 permutations. Only after a required float min/max semantic
contract is explicit can code-generation alternatives be classified as
equivalent implementations or deliberately different numeric semantics.


### Float min/max semantic counterexample

Hand-selected NaN and signed-zero cases initially produced bit-identical results
between the scalar and four-lane graphs under both DMD and LDC. An exhaustive
bounded state-space search was therefore added rather than inferring general
equivalence from examples.

Alphabet:

- NaN
- -infinity
- -3.5
- -0.0
- +0.0
- 2.25
- +infinity

The length-9 search found the same first mismatch under both compilers at case
50618. The encoded sequence is:

`[-infinity, NaN, +0.0, NaN, NaN, -0.0, NaN, NaN, NaN]`

Results:

- scalar: min = `0xff800000` (-infinity), max = `0x00000000` (+0.0)
- four lane: min = `0xff800000` (-infinity), max = `0x80000000` (-0.0)

Therefore the four-lane graph is **not bitwise equivalent** to the current
ordinary `<` / `>` scalar graph for unrestricted IEEE float inputs. This is
a semantic counterexample, not a compiler-specific code-generation effect:
DMD and LDC report the identical mismatch.

Consequences:

1. The finite-corpus speedup cannot by itself justify replacing a strict scalar
   float min/max implementation with this four-lane graph.
2. Any future fast float reduction must first have an explicit public/internal
   numeric contract for NaN and signed zero.
3. If raster-d requires exact preservation of the ordinary scalar graph, this
   four-lane implementation is invalid for that strict mode.
4. A separately named/documented relaxed or normalized semantic mode could
   still permit a faster reduction graph, but only if such semantics are
   independently useful to consumers; performance alone is not sufficient
   reason to invent that API.
5. Integer min/max remains a separate result: LDC's simple `ubyte` loop is
   already efficiently vector-reduced and manual lane splitting is harmful.


### Ubyte histogram reduction

No production histogram path currently exists in raster-d, so this probe remains
research-only. It measures a 256-bin `ubyte -> ulong[256]` histogram using a
safe slice loop, a check-free pointer diagnostic, and four private 256-bin
histograms followed by a merge.

Representative medians:

| elements | compiler | slice | pointer | four histograms | pointer control |
|---:|---|---:|---:|---:|---:|
| 65,536 | DMD | 35.5 us | 31.5 us | 38.5 us | 31.7 us |
| 1,048,576 | DMD | 0.5772 ms | 0.5118 ms | 0.6259 ms | 0.5157 ms |
| 8,388,608 | DMD | 4.8367 ms | 4.3472 ms | 5.0723 ms | 4.3417 ms |
| 65,536 | LDC | 28.6 us | 28.7 us | 30.1 us | 28.7 us |
| 1,048,576 | LDC | 0.4665 ms | 0.4463 ms | 0.4799 ms | 0.4429 ms |
| 8,388,608 | LDC | 3.8409 ms | 3.6768 ms | 4.1667 ms | 3.7134 ms |

The four-private-histogram form does not recover its extra state and merge cost
for this deterministic corpus at any measured size. At 8 Mi elements it is
about 16.7% slower than the pointer diagnostic under DMD and about 13.3% slower
under LDC. There is therefore no evidence here for promoting manual lane-private
histograms.

The safe-slice form is consistently slower than the pointer diagnostic under
DMD (roughly 11--13% in these measurements) and modestly slower under LDC at
the larger sizes. As with earlier R0.5 probes, this does not justify an unsafe
production pointer loop. A focused code-generation/bounds-check diagnostic is
required to determine whether the difference is source-form overhead rather
than an algorithmic advantage.


#### Histogram code-generation diagnosis

A focused code-generation probe explains the safe-slice versus pointer timing
difference.

DMD keeps a per-element bounds check for the histogram index in the safe slice
loop before incrementing the selected bin. The pointer diagnostic has the same
basic load/index/increment loop without that check. This matches the measured
roughly 11--13% DMD gap and is evidence of checked source-form overhead, not a
different histogram algorithm.

LDC proves the ubyte index is within the 256-bin histogram after the entry
length check. Its slice and pointer hot loops are effectively the same: both
are unrolled four elements per iteration and perform four byte-load/bin-increment
pairs without per-element bin bounds checks. This matches the much smaller LDC
runtime gap.

The four-private-histogram form allocates 8192 bytes of stack state. LDC emits
four 2048-byte clears, four independent indexed increments, and a vectorized
merge using packed 64-bit additions. Even with an efficient SIMD merge, the
extra state initialization and merge do not pay back for the measured corpus.

Conclusion: no unsafe pointer production path and no manual four-histogram
specialization are justified. For a future production histogram API, prefer the
simple safe representation first. If DMD histogram performance becomes a
consumer bottleneck, investigate a narrowly validated execution boundary that
lets the hot loop operate on a statically known 256-bin target without changing
public safety semantics.


## R0.5e — canonical region / row-stride baseline

The first R0.5e probe isolates physical row layout from neighbourhood arithmetic.
It applies the same affine float point transform to a fixed logical 2048 x 512
region while varying the physical row stride.

| Compiler | Stride | Safe rows | Pointer diagnostic | Pointer control |
|---|---:|---:|---:|---:|
| DMD | 2048 | 1.0429 ms | 0.5423 ms | 0.5457 ms |
| DMD | 2112 | 1.0754 ms | 0.5919 ms | 0.6067 ms |
| DMD | 2304 | 1.0870 ms | 0.5950 ms | 0.5906 ms |
| DMD | 4096 | 1.1460 ms | 0.6547 ms | 0.6525 ms |
| LDC | 2048 | 0.1747 ms | 0.1709 ms | 0.1721 ms |
| LDC | 2112 | 0.1826 ms | 0.1827 ms | 0.1794 ms |
| LDC | 2304 | 0.2023 ms | 0.1971 ms | 0.1963 ms |
| LDC | 4096 | 0.2069 ms | 0.2004 ms | 0.1993 ms |

The logical work is identical in all rows. Stride 2048 is fully contiguous;
2112 and 2304 add increasing row padding; 4096 models a narrow region retaining
a parent row stride twice its logical width.

LDC maps the safe row form and pointer diagnostic to essentially the same
performance class. The contiguous safe-row median is only about 2.2% above the
pointer diagnostic, and the padded cases remain within a few percent. This is
strong evidence that the existing Canonical layout model does not inherently
require a material abstraction penalty under the primary performance compiler.

Physical row spacing itself is measurable but moderate. From stride 2048 to
4096, the LDC pointer median rises from 0.1709 to 0.2004 ms (about 17%), while
the DMD pointer median rises from 0.5423 to 0.6547 ms (about 21%). This is a
real locality/layout effect rather than extra logical work.

DMD shows a separate source-form problem: the safe row loop is roughly
1.8--1.9x the pointer diagnostic across the matrix. Given the earlier R0.5
bounds-check/code-generation results, this is diagnostic evidence for a focused
DMD codegen check rather than evidence against Canonical row execution. It does
not justify an unsafe public or production representation.

R0.5e therefore proceeds to a real neighbourhood/halo kernel. A DMD row-loop
codegen probe can be retained as a secondary diagnostic if that compiler
remains important for the eventual consumer hot path.


### 3x3 neighbourhood with explicit one-sample halo

A second R0.5e probe measures a 3x3 box sum over a fixed 2048 x 512 output
region. The input contains an explicit one-sample halo, so border policy is not
part of the timed kernel. Input row strides are 2050 (minimum dense halo row),
2112, 2304 and 4096.

| Compiler | Stride | Safe rows | Pointer diagnostic | Pointer control |
|---|---:|---:|---:|---:|
| DMD | 2050 | 5.7783 ms | 2.4610 ms | 2.4155 ms |
| DMD | 2112 | 5.2051 ms | 2.2924 ms | 2.2562 ms |
| DMD | 2304 | 5.3723 ms | 2.3092 ms | 2.3421 ms |
| DMD | 4096 | 5.2736 ms | 2.3551 ms | 2.3281 ms |
| LDC | 2050 | 0.6252 ms | 0.5031 ms | 0.4608 ms |
| LDC | 2112 | 0.6187 ms | 0.4476 ms | 0.4520 ms |
| LDC | 2304 | 0.6242 ms | 0.4554 ms | 0.4675 ms |
| LDC | 4096 | 0.6372 ms | 0.4712 ms | 0.4621 ms |

The principal result is that large parent row stride is not itself expensive
for this neighbourhood. Relative to stride 2112, stride 4096 changes the
pointer median by only about 2.7% under DMD and 5.3% under LDC. This supports
the existing Canonical/ROI model for neighbourhood execution: retaining a
parent row stride does not inherently impose a large throughput penalty.

Stride 2050 is somewhat slower in the pointer measurements, especially under
LDC, despite being the physically densest halo layout. It should therefore not
be assumed that minimum row pitch is always optimal; alignment/cache/codegen
effects need separate evidence before drawing a layout rule.

The more important result is source form. DMD's safe indexed-row kernel is
roughly 2.25--2.35x the pointer diagnostic across the stable cases. LDC, unlike
the earlier pointwise row probe, also shows a material gap for the 3x3 access
pattern: the safe-row median is roughly 35--40% above the pointer diagnostic
for strides 2112--4096. The repeated shifted accesses therefore justify a
focused code-generation/bounds-check diagnostic for this exact kernel.

This remains diagnostic evidence only. It does not justify exposing pointers,
removing validation, prescribing row alignment, or introducing handwritten
SIMD.


#### 3x3 neighbourhood code-generation diagnosis

The code-generation probe explains the safe-row gap on both compilers.

DMD retains bounds checks throughout the inner neighbourhood loop. The safe
form checks the destination index and repeatedly checks the shifted source
indices for x, x+1 and x+2 across the three input rows. The pointer diagnostic
instead emits the expected compact scalar sequence of nine float loads/adds
and one store. The measured greater-than-2x gap is therefore attributable to
checked indexing/code generation, not to the Canonical stride or explicit-halo
model.

LDC reaches a stronger optimization in the pointer diagnostic: after loop and
alias/runtime legality checks it vectorizes four adjacent output samples at a
time using packed float loads/adds/stores. The safe slice form contains a much
larger range-proof/control block for the repeated shifted accesses. Although
LLVM attempts to reason about those bounds, that source form does not expose
the same compact vectorized hot path. This explains the measured roughly
35--40% safe-row overhead in the stable stride cases.

This is the clearest R0.5 evidence so far for a validated internal execution
boundary for neighbourhood kernels: validate dimensions, halo reach, physical
ranges and target capacity once at the safe semantic boundary, then permit a
narrow trusted implementation to execute a prevalidated row kernel without
per-sample slice checks. Such a boundary must remain internal and preserve the
existing RasterView/RasterTargetPlane safety and layout contracts.

The evidence does not justify public pointer APIs or handwritten SIMD. LDC
already demonstrates that ordinary scalar D source can become packed SIMD once
the compiler can prove the execution region. DMD still emits scalar arithmetic,
so compiler-specific SIMD work should only be reconsidered after measuring a
validated-boundary implementation.


#### Validated execution-boundary experiment

The R0.5e harness then tested the proposed architecture directly. A `@safe`
wrapper validates row reach, halo reach, multiplication overflow and destination
capacity once, passes slices across the boundary, and a narrow `@trusted`
implementation extracts their pointers and runs the otherwise identical 3x3
loop without per-sample slice checks.

| Compiler | Stride | Safe rows | Validated boundary | Pointer diagnostic | Pointer control |
|---|---:|---:|---:|---:|---:|
| DMD | 2050 | 4.9901 ms | 2.2492 ms | 2.3373 ms | 2.3741 ms |
| DMD | 2112 | 4.9184 ms | 2.2046 ms | 2.3739 ms | 2.3360 ms |
| DMD | 2304 | 4.9195 ms | 2.2026 ms | 2.3549 ms | 2.3767 ms |
| DMD | 4096 | 4.9296 ms | 2.2375 ms | 2.3967 ms | 2.3454 ms |
| LDC | 2050 | 0.6089 ms | 0.4507 ms | 0.4503 ms | 0.4487 ms |
| LDC | 2112 | 0.6026 ms | 0.4375 ms | 0.4367 ms | 0.4353 ms |
| LDC | 2304 | 0.6082 ms | 0.4388 ms | 0.4400 ms | 0.4829 ms |
| LDC | 4096 | 0.6200 ms | 0.4518 ms | 0.4522 ms | 0.4515 ms |

Under LDC the validated boundary and pointer diagnostic converge to effectively
the same performance across the complete stride matrix. The one-time safe
validation is negligible at this region size, while removing repeated checked
indexing restores the compact/vectorizable inner kernel.

Under DMD the validated path reduces runtime from about 4.9--5.0 ms to about
2.20--2.25 ms. It happens to measure modestly faster than the pointer controls
in this run, but the inner algorithms are equivalent and that difference is
not treated as an algorithmic advantage. The robust conclusion is convergence
to the pointer performance class and removal of more than half of the
safe-slice runtime.

This experiment confirms the R0.5e architecture hypothesis for this kernel:
a safe semantic entry point plus complete once-per-region validation can feed a
small trusted, check-free execution kernel without paying per-sample safety
cost. The result preserves the existing Canonical explicit-row-stride model;
even stride 4096 converges with the corresponding pointer control.

Promotion is not automatic. Before a production implementation, the validation
predicate should be factored around the existing RasterView/RasterTargetPlane
and execution-layout contracts, tested with zero/degenerate dimensions,
overflow boundaries, insufficient halo/reach, padded and negative-stride cases
where applicable, and checked for source/target alias requirements. The trusted
surface should remain minimal. No public pointer API and no handwritten SIMD
are supported by this evidence.


#### Signed Canonical row-stride matrix

The existing execution-layout contract permits a Canonical plane to have a
negative outer row stride as long as logical x remains forward unit stride.
R0.5e therefore repeated the validated 3x3 halo kernel with the same physical
pitches in both row directions.

| Compiler | Pitch | Positive row stride | Negative row stride | negative / positive |
|---|---:|---:|---:|---:|
| DMD | 2050 | 2.4657 ms | 2.3225 ms | 0.94x |
| DMD | 2112 | 2.4598 ms | 2.4093 ms | 0.98x |
| DMD | 2304 | 2.4141 ms | 2.4227 ms | 1.00x |
| DMD | 4096 | 2.4000 ms | 2.4519 ms | 1.02x |
| LDC | 2050 | 0.6075 ms | 1.7599 ms | 2.90x |
| LDC | 2112 | 0.7811 ms | 1.7619 ms | 2.26x |
| LDC | 2304 | 0.4646 ms | 1.6304 ms | 3.51x |
| LDC | 4096 | 0.4673 ms | 1.7543 ms | 3.75x |

DMD is effectively insensitive to physical row direction in this experiment.
LDC is not: negative row traversal is materially slower, by roughly 2.3--3.8x
for these medians. The positive signed-stride measurements at pitches 2050 and
2112 are noisier than the earlier positive-only benchmark, so the exact ratios
should not be overinterpreted; the large negative-stride penalty is nevertheless
unambiguous.

This does not invalidate the Canonical semantic classification. It shows that
Canonical is not necessarily one performance class. No new public or internal
layout enum should be introduced from timing alone. A dedicated code-generation
probe now compares a positive-only stride, a runtime signed stride, and an
explicit negative-magnitude stride to determine whether LDC loses vectorization
or incurs another loop-shape penalty before any specialization decision.


##### Signed-stride code-generation diagnosis

The dedicated code-generation probe rules out the simplest explanation for the
LDC negative-row-stride penalty. LDC 1.41 keeps a four-float SIMD inner loop
for all three forms: positive-only pitch, runtime signed row stride, and an
explicit negative-magnitude row stride. The negative form therefore does not
merely fall back to scalar arithmetic.

The negative form does, however, require substantially different address
setup and outer-row pointer evolution. This makes the measured penalty a
memory-traversal/address-generation/code-shape question rather than evidence
that Canonical negative row stride is intrinsically non-vectorizable.

DMD remains scalar for all three probe forms, matching the benchmark result
that changing the sign of the outer stride has little effect there.

No compiler-specific production specialization is justified yet. The next
control should separate logical row orientation from physical traversal:
process the same negatively represented Canonical source through a normalized
positive physical row walk, while preserving the requested logical output
orientation. If that recovers LDC throughput, row traversal direction rather
than SIMD eligibility is the relevant specialization axis.


##### Row-direction isolation

A 2x2 control separated source-row and destination-row traversal direction at
pitches 2304 and 4096 while preserving the same logical 3x3 computation and
checking every variant against one reference result.

The result does not support row direction itself as the cause of the earlier
LDC negative-signed-stride penalty. On LDC 1.41 all four direction
combinations remained in the same broad performance class (approximately
0.46--0.58 ms medians in these runs). At pitch 4096, reverse source traversal
with forward destination traversal measured 0.581 ms, far below the roughly
1.82 ms measured for the actual runtime-signed negative-stride kernel in the
preceding run. DMD likewise showed no material direction-specific class split.

Together with the code-generation probe, this narrows the issue: negative
physical traversal is not inherently slow and LLVM still vectorizes the
negative-stride kernel. The remaining important difference is source shape
and address representation: the direction matrix selects a logical row and
then uses positive size_t row/pitch arithmetic, whereas the real Canonical
kernel carries a signed ptrdiff_t rowStride through row-address formation.

Do not change Canonical classification or introduce compiler-specific/SIMD
production paths from this evidence. The next probe should vary only signed
address-expression shape while keeping traversal, data, arithmetic, and
destination mapping fixed.


##### Address-shape and code-generation follow-up

A negative-Canonical address-shape benchmark compared runtime signed
multiplication, incremented row pointers, and positive pitch magnitude. LDC
1.41 placed all three in the same slow class (about 1.58--1.67 ms at pitches
2304/4096); changing arithmetic spelling alone did not recover the roughly
0.5 ms direction-control result. DMD did show a separate useful observation:
incremented row pointers reduced these runs from about 2.42 ms to about
1.83--1.86 ms, but this is compiler-specific research evidence, not yet a
production specialization.

A direct standalone ASM probe then corrected an earlier interpretation. The
fast LDC reverse-index control is a compact scalar loop: it uses scalar
movss/addss operations and advances precomputed source-row pointers and the
destination row pointer. The runtime signed-stride forms are vectorized only
through LLVM loop versioning: substantial runtime memory-overlap/legality
checks select between a scalar loop and a 4-float movups/addps loop.

Therefore the presence of a SIMD loop in assembly does not prove that the
measured negative-Canonical invocation executes that SIMD path. The remaining
high-value question is now the runtime path selection/alias proof, not signed
multiplication, row direction, or SIMD eligibility in isolation.

Next isolate this with a probe that makes source/destination non-overlap
explicitly provable to the compiler where D permits it, or otherwise records
which versioned path is taken without perturbing the hot loop. Do not add a
public noalias/uniqueness contract: RasterTargetPlane currently provides no
such guarantee. Any production optimization must preserve that contract or
perform a validated runtime non-overlap dispatch before entering a narrower
trusted kernel.


##### Alias-path control

A runtime control using separate heap allocations confirmed that the complete
source and destination intervals were disjoint. In one LDC run the source was
[0x730f22d00010,0x730f23508010) and the destination
[0x730f23509010,0x730f23909010), leaving a 4096-byte gap. The ordinary signed
kernel measured 1.7320 ms median and the same kernel after an explicit
invocation-local non-overlap proof measured 1.7346 ms. The proof therefore
does not change the performance class or communicate a persistent no-alias
property through the function boundary.

Reading the standalone LDC assembly also refines the loop-versioning result:
the signed kernel branches to a scalar fallback when its generated overlap
condition is true and to the 4-float movups/addps loop when that condition is
false. For the fully disjoint allocations above, aliasing is therefore not a
credible explanation for the approximately 1.7 ms result.

The important inversion is that the previously fast reverse-index control is
itself scalar in the standalone LDC assembly, while the signed forms contain
a SIMD fast path. The next question is consequently stencil code quality:
compare the compact scalar control with LLVM's vectorized overlapping-window
loads/address recurrences rather than assuming SIMD is intrinsically faster.


##### Sliding-window algorithm control

A research-only 3x3 sliding-window control reduced repeated source work by
forming vertical column sums and reusing two columns for the next output.
This changes the floating-point evaluation graph and is therefore not a
drop-in implementation of the exact baseline semantic.

At 2048x512 with pitch 4096 and negative row stride:

- DMD: exact baseline 2.1714 ms; sliding 2.4469 ms (about 12.7% slower).
- LDC: exact baseline 1.8158 ms; sliding 1.2306 ms (about 32.2% faster).

Thus reducing nominal loads/additions is not intrinsically faster; the result
is compiler-sensitive. The LDC improvement does show that stencil
reassociation/reuse can matter, but even this control remains well behind the
roughly 0.5 ms reverse-index control observed earlier. Explicit SIMD is
therefore still premature. Inspect baseline/sliding/reverse code generation
next, especially vectorization, loop-carried dependencies, load structure,
and pointer recurrences.


##### Sliding/reverse code-generation correction

The isolated three-way code-generation probe corrects an earlier
interpretation. LDC's box3ReverseControl is not intrinsically scalar: like
box3Exact it is loop-versioned and contains both a scalar alias fallback and a
four-float movups/addps SIMD path. Moreover, the SIMD inner loops of
box3Exact and box3ReverseControl have essentially the same nine overlapping
vector loads and eight vector additions per four outputs. The earlier
approximately 0.5 ms reverse-control result therefore cannot be explained by
a uniquely compact scalar inner loop or by avoiding the overlapping SIMD load
pattern.

The important structural difference is outside that inner loop. box3Exact
carries the signed stride directly through row-pointer recurrences, whereas
box3ReverseControl derives row locations from positive pitch/index geometry
and then advances its prepared row pointers in the opposite physical
direction. This outer-loop/address-formation distinction is now the next
variable to isolate while holding the inner arithmetic graph constant.

LDC's sliding form is genuinely different: it vectorizes the vertical column
sums and uses shuffles to carry/reconstruct the horizontal sliding window.
DMD keeps all three forms scalar; its sliding loop exposes the expected
loop-carried c0/c1/c2 dependency. These observations explain why the sliding
experiment is compiler-sensitive but do not justify explicit SIMD yet.


##### Outer-address isolation and direction-matrix audit

Holding the exact nine-load/eight-add inner expression constant did not
reproduce the earlier approximately 0.5 ms LDC class. At pitch 4096:

- DMD: signed recurrence 1.8303 ms, magnitude recurrence 1.7841 ms, indexed
  magnitude 2.1472 ms.
- LDC: signed recurrence 1.7214 ms, magnitude recurrence 1.7009 ms, indexed
  magnitude 1.6339 ms.

Thus neither signed pointer recurrence nor its simple positive-magnitude
rewrites explain a factor-of-three difference.

Re-reading neighbourhood_direction_matrix_bench.d reveals that the earlier
direction matrix did not execute the negative-Canonical representation. Its
kernel accepts only a positive size_t pitch and represents reverse traversal
by selecting y = height - 1 - step before computing y*pitch. The source
storage itself is not reversed despite an obsolete comment saying that
reversed storage had been prepared. Consequently the roughly 0.5 ms LDC
direction-matrix timings are evidence about loop traversal order with positive
pitch/index geometry, not evidence that a negative signed rowStride can be
made equally fast by a trivial outer-loop rewrite.

This invalidates the earlier use of the direction matrix as a direct control
for the negative-Canonical slowdown. Keep the timings as research evidence,
but narrow their interpretation. The next benchmark must compare actual
validated RasterView Canonical execution with positive and negative
rowStride using the same logical corpus and an independent correctness oracle.


##### Validated RasterView Canonical neighbourhood result

A production-shaped benchmark now constructs both source variants through
validateRasterBackingLayout, creates RasterView only after successful backing
validation, verifies Canonical execution traits, adapts through
asMirCanonical, and writes to a contiguous RasterTargetPlane. Positive and
negative physical layouts contain the same logical samples and are checked
against an independent logical-value oracle. Validation and fixture creation
are outside the timed region.

An initial release-build run accidentally placed the timed kernel call inside
assert; release compilation removed that call. Those microsecond timings are
invalid and are excluded. An audit found no equivalent assert-wrapped timed
operation in the other R0.5 benchmark files. Commit fce5138 corrected this
benchmark to execute and check the operation explicitly.

Corrected 2048x512, pitch 4096 results:

- DMD: positive 10.8170 ms; negative 10.6977 ms. Row direction is effectively
  neutral (negative is about 1.1% faster in this run), but this Mir-indexed
  production-shaped kernel is much slower than the earlier trusted
  check-free raw kernels.
- LDC: positive 0.6932 ms; negative 1.7204 ms. Negative Canonical row traversal
  is about 2.48x slower.
- The LDC negative result falls in the same approximately 1.6-1.8 ms class as
  the earlier negative signed-stride/raw controls, while the positive result
  is in the fast sub-millisecond class.

This establishes that the LDC positive/negative Canonical asymmetry is real
for the current RasterView -> asMirCanonical -> contiguous-target execution
shape. It is not evidence that RasterView itself is generally expensive:
positive Canonical execution is already fast under LDC. Conversely, DMD shows
no meaningful direction asymmetry here; its issue is the much larger cost of
the Mir-indexed neighbourhood expression itself.

Do not change the public Canonical contract or add hand SIMD from this result.
The next specialization/codegen question is whether a validated internal
negative-row specialization can preserve RasterView semantics while presenting
the hot loop to LDC in a positive-pitch/index form, and whether DMD needs a
separate check-free internal neighbourhood kernel rather than Mir element
indexing.


##### R0.5f compiler-specific execution candidate

A follow-up kept the validated RasterView/RasterTargetPlane semantic boundary
but compared the Mir-indexed Canonical kernel with a research-only narrow
trusted kernel. The trusted kernel extracts validated execution metadata once,
branches on row-stride sign outside the hot loops, and uses check-free row
pointers internally. The negative branch converts the signed stride to a
positive magnitude and subtracts that magnitude when deriving rows. The exact
nine-load/eight-add expression and logical output order are unchanged.

Linux x86-64, 2048x512 output, pitch 4096:

| Compiler | Rows | Mir view | Trusted | Trusted / Mir |
| --- | --- | ---: | ---: | ---: |
| DMD 2.111 | positive | 11.5562 ms | 1.9255 ms | 0.167 |
| DMD 2.111 | negative | 11.4237 ms | 1.7935 ms | 0.157 |
| LDC 1.41 | positive | 0.4785 ms | 0.4787 ms | 1.000 |
| LDC 1.41 | negative | 1.6043 ms | 1.6115 ms | 1.004 |

The compiler-specific conclusions are now materially different.

For DMD, the validated trusted execution form is about 6.0x faster for
positive rows and 6.4x faster for negative rows than the Mir-indexed form.
Positive versus negative row direction is not the material DMD issue. This is
strong evidence for investigating a DMD-oriented internal check-free
neighbourhood execution path below the common validation/semantic boundary.

For LDC, the trusted source form does not improve either direction. Positive
Mir and trusted medians are effectively identical, as are negative Mir and
trusted medians. The negative Canonical case remains about 3.35-3.37x slower
than the positive case. Therefore branching once on stride sign, using a
positive pitch magnitude, and spelling negative traversal as pointer
subtraction are insufficient to recover the positive-row performance class.

This rejects a single universal source-form optimization for this operation.
It supports compiler-specific internal optimization research while retaining a
compiler-independent public RasterView/Canonical contract. Architecture and
operating-system specializations are also allowed research dimensions, but
must be introduced only where measurements on those targets justify them.

No handwritten SIMD is justified by these results. LDC already reaches the
fast approximately 0.48 ms class for positive Canonical execution from ordinary
D source. The remaining LDC question is what property of the negative physical
row layout prevents equivalent throughput.


##### Negative Canonical physical-forward control

To isolate physical stream direction, the negative Canonical source was
processed with logical output rows visited in reverse order. This makes source
row addresses advance physically forward while preserving each output
sample's exact nine-load/eight-add expression and logical destination.

Linux x86-64, 2048x512 output, pitch 4096:

| Compiler | Negative trusted | Negative physical-forward |
| --- | ---: | ---: |
| DMD 2.111 | 2.0818 ms | 1.8101 ms |
| LDC 1.41 | 1.6165 ms | 1.6173 ms |

For LDC the two medians are effectively identical. Physical forward versus
backward progression of the source rows therefore does not explain the roughly
3.2-3.4x gap from the positive Canonical execution class in these runs. The
next diagnostic must distinguish the runtime-selected LLVM loop-version path:
in particular, whether alias/legality checks select the vector loop or scalar
fallback for the concrete positive and negative RasterView invocations.

DMD improves by roughly 13% in this run when the negative source is traversed
physically forward, but both forms remain in the same approximately 2 ms
trusted-kernel class and both remain far faster than the Mir-indexed DMD path.
This secondary direction effect does not change the DMD architectural
conclusion.


##### R0.5f negative physical-forward control

To isolate physical stream direction, the negative Canonical fixture was run
with logical output rows visited in reverse order. This makes successive source
row addresses advance physically forward while preserving each output sample's
exact nine-load/eight-add expression and logical destination.

Linux x86-64, 2048x512 output, pitch 4096:

| Compiler | Negative trusted | Negative physical-forward |
| --- | ---: | ---: |
| DMD 2.111 | 2.1204 ms | 1.8432 ms |
| LDC 1.41 | 1.6945 ms | 1.6804 ms |

For LDC the physical-forward control remains in the same approximately
1.68-1.69 ms class. It does not approach the positive Canonical view result
(0.4833 ms in the same run). Therefore backward progression of the source
stream is not the principal explanation for the LDC negative-Canonical
penalty.

DMD improves by about 13% in this run, so traversal order may be a secondary
DMD tuning dimension, but it is not required to explain the much larger
Mir-versus-trusted DMD result.

The next LDC diagnostic should inspect the production-shaped generated control
flow and determine which LLVM loop-version is actually selected at runtime.
In particular, test whether runtime alias/legality conditions or another
versioning guard distinguish the positive and negative layouts. SIMD presence
in assembly alone is insufficient evidence that the measured invocation uses
the SIMD version.


##### R0.5f LDC negative-Canonical loop-versioning cause

A standalone LDC 1.41 code-generation probe exposed the runtime
loop-versioning guards for positive and negative Canonical row traversal. Both
the positive and negative kernels contain scalar and four-float SIMD inner
loops. A separate negative physical-forward form is scalar-only, explaining
why that control could not recover the positive SIMD throughput.

The production-shaped benchmark then printed its actual allocation geometry
outside the timed region. Both positive and negative runs had completely
disjoint source and destination allocations. The negative run still measured
1.6334 ms versus 0.5361 ms positive.

For the negative generated kernel, the decisive guard sequence shifts the
positive pitch by two (bytes), negates it, records the sign flag with `sets`,
and ORs that result into the aggregate loop-versioning condition before
`testb` selects scalar versus SIMD execution. With the benchmark pitch of
4096 elements, negating the positive byte stride necessarily produces a
negative signed value, so this sign component is true. For the observed
ordinary non-wrapping address geometry the actual overlap subconditions are
false, but the sign component alone keeps the aggregate guard true and selects
the scalar fallback.

Therefore the approximately 3x-3.5x LDC penalty for the current negative
Canonical 3x3 kernel is not explained by cache stream direction or real
source/destination overlap. It is caused by the optimizer's runtime
loop-versioning/legality proof for this source form: SIMD code is emitted, but
the measured ordinary positive pitch magnitude cannot select it.

This is compiler/code-shape evidence, not a raster-d semantic restriction.
The public Canonical contract should continue to allow signed row stride. The
next research step is to find an equivalent exact-arithmetic internal source
form that lets LDC prove/vectorize negative Canonical execution without
weakening alias safety, changing logical semantics, or adding handwritten
SIMD. Compiler-specific specialization is justified only if such a form
remains beneficial under benchmark and codegen qualification.


##### R0.5f row-kernel source-form control

A further candidate moved signed Canonical row traversal into an outer trusted
loop and expressed the inner 3x3 operation as a separate row kernel receiving
only three concrete source-row pointers, one destination-row pointer, and
width. The arithmetic graph remained unchanged.

Linux x86-64, 2048x512 output, pitch 4096:

| Compiler | Rows | Trusted | Row kernel |
| --- | --- | ---: | ---: |
| DMD 2.111 | positive | 1.8143 ms | 1.9440 ms |
| DMD 2.111 | negative | 1.8375 ms | 1.9780 ms |
| LDC 1.41 | positive | 0.5018 ms | 0.5113 ms |
| LDC 1.41 | negative | 1.7129 ms | 1.7055 ms |

The row-kernel decomposition does not recover the LDC negative-Canonical SIMD
performance class. Positive LDC remains approximately 0.5 ms and negative
remains approximately 1.7 ms. DMD is modestly slower with the decomposition.

This rejects source-level row-function decomposition by itself as the
specialization. The standalone code-generation probe showed that a row body
with concrete row pointers can be vectorized, but the production-shaped
benchmark demonstrates that expressing the operation as a helper is not
sufficient. A plausible compiler-level explanation is that optimization/inlining
recombines the helper with the signed-stride outer context and reconstructs the
same conservative loop-versioning condition. That explanation must be
verified in generated code before it is treated as established.

The next diagnostic should therefore compare generated code for the actual
row-kernel benchmark path and then test a research-only no-inline boundary (or
equivalent compiler optimization boundary) as a causal control. Such a control
is not yet a proposed production design.


##### R0.5f no-inline causal control

The row-kernel experiment was repeated with the inner row operation kept
explicitly out of line via `pragma(inline, false)`. No algorithm, logical
layout, arithmetic graph, source corpus, or target layout changed.

Linux x86-64, 2048x512 output, pitch 4096:

| Compiler | Rows | Trusted | Row kernel | Row no-inline |
| --- | --- | ---: | ---: | ---: |
| DMD 2.111 | positive | 1.7636 ms | 1.8841 ms | 1.8685 ms |
| DMD 2.111 | negative | 1.7993 ms | 1.8509 ms | 1.7929 ms |
| LDC 1.41 | positive | 0.4611 ms | 0.9605 ms | 0.5420 ms |
| LDC 1.41 | negative | 1.6443 ms | 1.6927 ms | 0.5206 ms |

The LDC negative result is decisive for the causal question. Keeping the row
kernel out of line reduces the negative case from 1.6443 ms to 0.5206 ms,
about 3.16x faster, and removes the positive/negative performance asymmetry:
the no-inline positive and negative medians are 0.5420 and 0.5206 ms.

Together with the earlier code-generation evidence, this strongly supports
the explanation that inlining/recombination with the signed-stride outer loop
causes LLVM 19.1.7 in LDC 1.41 to construct a conservative loop-versioning
guard that selects the scalar fallback for ordinary negative Canonical
execution. Preserving the row-kernel optimization boundary allows the local
three-row loop to remain in the vectorizable performance class.

This is not a universal recommendation to disable inlining. LDC positive
Canonical remains faster in the ordinary trusted integrated form (0.4611 ms)
than in the no-inline row form (0.5420 ms), while DMD shows no material
no-inline benefit and retains the ordinary trusted kernel as the best current
form. The evidence therefore supports compiler- and layout-specific internal
execution specialization rather than one source form for all cases.

Current evidence-backed candidates for this 3x3 operation on Linux x86-64 are:

- DMD 2.111: validated semantic boundary -> ordinary trusted check-free kernel
  for both positive and negative Canonical row stride.
- LDC 1.41 / LLVM 19.1.7: ordinary trusted/integrated kernel for positive
  Canonical row stride; preserved out-of-line row kernel for negative
  Canonical row stride.

These remain research candidates. Before production promotion, qualify the
result across dimensions/pitches, replace research-only signed-stride
assertions with robust validated magnitude handling, inspect final generated
code, and centralize compiler/version/architecture selection rather than
scattering compiler conditionals. No handwritten SIMD is justified.
