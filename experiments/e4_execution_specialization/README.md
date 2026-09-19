# E4 Execution Specialization Research Evidence

This directory preserves the historical evidence used for E4 execution-specialization decisions in `imagery-d`.

The files under `original/` are recovered research artifacts. They are preserved as historical evidence and must not be reformatted, modernized, refactored, or otherwise edited.

`SHA256SUMS` covers the files under `original/` and records their preserved byte content.

## Purpose

E4 investigated whether raster hot paths should depart from the ordinary Mir-based scalar implementation through:

- raw-pointer implementations;
- alias/noalias information;
- `@restrict`;
- `memcpy` lowering;
- floating-point fast-math or reassociation;
- explicit fixed-lane accumulation;
- wider fixed-lane accumulation.

The resulting architecture deliberately keeps specialization narrow and evidence-driven.

## Evidence classification

### `original/initial_codegen/`

Classification: **AUTHORITATIVE**

Initial Mir-versus-raw code-generation probes.

They established that the investigated contiguous copy and integer-reduction kernels did not justify bypassing Mir merely to obtain raw-pointer code generation.

The strict floating-point reduction remained constrained by its numeric semantics.

The directory also retains the captured compiler, options, and import-path context used for the historical experiment.

### `original/policy_codegen/`

Classification: **AUTHORITATIVE**

Policy-level code-generation evidence for:

- unknown-alias raw-pointer copy;
- raw-pointer copy with `@restrict`;
- strict floating-point reduction;
- fast-math floating-point reduction.

This evidence demonstrated that stronger optimizer assumptions can materially change generated code, but does not by itself justify exposing those assumptions in the production API.

Global fast-math is not an accepted project policy.

### `original/fixed_lane4/`

Classification: **AUTHORITATIVE**

Evidence for the explicit fixed-lane4 floating-point specialization.

The fixed-lane4 path has explicit numeric semantics. It is not a silent replacement for the strict reduction.

This directory also preserves the authoritative negative reassociation diagnostic.

`reassoc-warning.txt` records that the attempted reassociation-only LLVM fast-math flag was not recognized by the tested LDC toolchain.

Therefore the attempted reassociation-only experiment is not valid positive evidence for a reassociation policy.

### `original/fixed_lane8_candidate/`

Classification: **SUPPORTING**

Code-generation evidence for an investigated lane8 candidate.

Lane8 was technically viable as an experiment, but the subsequent direct benchmark did not provide evidence for adopting it as another production specialization.

It is retained to document the rejected candidate and avoid repeating the same investigation without new evidence.

### `original/lane4_vs_lane8_benchmark/`

Classification: **AUTHORITATIVE**

Direct fixed-lane4 versus fixed-lane8 benchmark evidence.

The historical run used seven rounds with rotated execution order.

The observed lane4/lane8 median ratio was approximately `0.997`, with the observed range close to `0.986 .. 1.006`.

This supported:

- keeping fixed-lane4 as the explicit specialization already justified by its semantics and evidence;
- not pursuing fixed-lane8.

These historical timings are evidence, not a portable performance threshold.

### `original/noalias/`

Classification: **AUTHORITATIVE**, with the production baseline retained as supporting context.

The probes distinguish three materially different cases.

#### Raw pointers

`pointer_probe.d` demonstrates that raw-pointer parameters annotated with `@restrict` can produce valid LLVM `noalias` parameters and permit `llvm.memcpy` lowering.

This is positive evidence about what LDC/LLVM can express for that raw-pointer function shape.

#### D dynamic arrays

`slice_probe.d` and `slice_probe.log` demonstrate that applying the same approach to the investigated D slice shape produced invalid LLVM attribute placement and a verifier failure.

#### Mir slices

`mir_probe.d` and `mir_probe.log` demonstrate the corresponding verifier failure for the investigated Mir `Slice` function shape.

#### Current baseline

`current_baseline.d` and `current_baseline.ll` preserve the then-current ordinary Mir contiguous-copy baseline for comparison.

The architectural conclusion is:

- writable does not imply noalias;
- contiguous does not imply unique or non-overlapping storage;
- aliasing is a relation between concrete operands;
- non-overlap is proved at the operation that requires it;
- there is no general public alias-proof token;
- there is no global production `@restrict` policy.

### `original/checked_memcpy/`

Classification: **AUTHORITATIVE**

Benchmark evidence for the operation-local checked-non-overlap copy path.

For the raster-relevant historical sizes from 16 KiB through 16 MiB, checked `memcpy` won all six comparisons against the checked scalar path in the retained valid run.

That supported the implementation rule:

> when the operation has already established the required non-overlap relation, use direct `memcpy` for the contiguous copy.

The experiment did **not** establish a portable architecture-independent size threshold.

`results-dub.txt` is the retained valid historical result.

A separate recovered result file containing zero timings was classified as invalid and is intentionally not preserved here.

### `original/supporting_general_benchmark/`

Classification: **SUPPORTING / SUPERSEDED**

This was the later usable general E4 benchmark generation.

It remains useful as historical context because it exercised several candidate mechanisms in one harness and separated benchmark driver and kernels.

Later targeted experiments provide stronger evidence for the final lane and checked-copy decisions, so this benchmark must not be treated as the primary replay or performance gate.

## Evidence intentionally not preserved

The durability audit identified artifacts that should not be promoted into the durable evidence set, including:

- the earlier general E4 benchmark generation whose result files were empty;
- the invalid zero-timing checked-copy result;
- redundant object files and executables;
- redundant compiler-description snapshots;
- the invalid reassociation-only result as positive policy evidence.

The negative compiler diagnostic explaining why the reassociation attempt was invalid is preserved.

## Historical evidence versus replay

The contents of `original/` answer:

> What evidence was actually available when the engineering decision was made?

Future replay tooling has a different role:

> Does the relevant structural or performance conclusion still hold on the current supported toolchain and hardware?

These are intentionally separate questions.

Historical benchmark timings must not be converted into brittle CI thresholds.

Code-generation replay should prefer structural properties relevant to the decision instead of requiring byte-identical assembly across compiler releases.

Performance replay should detect meaningful regressions or changed conclusions, not require reproduction of historical nanosecond values.

## Current E4 decisions

The preserved evidence supports the following current project decisions:

- keep Mir as the ordinary internal representation;
- do not bypass Mir solely for raw-pointer code generation;
- do not introduce global `@restrict`;
- do not equate writable or contiguous storage with non-aliasing;
- prove non-overlap operation-locally when required;
- use direct `memcpy` after the required non-overlap relation has been established;
- do not enable global fast-math;
- retain fixed-lane4 only as an explicit specialization with explicit numeric semantics;
- do not pursue fixed-lane8 without new evidence;
- do not add handwritten SIMD without a new concrete bottleneck and measurement.

## Integrity

Verify the preserved historical artifacts by running `cd experiments/e4_execution_specialization && sha256sum -c SHA256SUMS`.

Do not regenerate `SHA256SUMS` merely because a compiler replay produces different output. Replay artifacts belong outside `original/`.

## Durable replay

`run.sh` is the maintained replay harness for the deterministic E4 conclusions.

Run it with LDC:

`experiments/e4_execution_specialization/run.sh ldc2`

LDC is required because the structural E4 evidence depends on LDC-specific attributes and LLVM IR.

The runner performs four classes of checks.

### Historical integrity

Every preserved file under `original/` is verified against `SHA256SUMS` before any live compilation starts.

A hash mismatch is a hard failure.

### Structural LLVM IR contract

The live LDC compilation checks decision-relevant properties rather than byte-identical generated code.

The current contract requires:

- the ordinary pointer-copy probe to remain without a noalias promise;
- the raw-pointer `@restrict` probe to expose LLVM `noalias`;
- the valid raw-pointer restrict case to permit `llvm.memcpy` lowering;
- the strict floating-point reduction to remain free of fast-math;
- the explicit fast-math probe to retain fast floating-point operations;
- fixed-lane4 to remain an explicit non-fast-math floating-point implementation;
- the baseline and initial research symbols to remain compilable.

The harness deliberately does not require exact instruction sequences, exact vector widths, register allocation, or byte-identical LLVM IR.

### Toolchain change detectors

The historical D-slice and Mir-slice `@restrict` probes are currently expected to fail LDC/LLVM verification because `noalias` is applied to an incompatible aggregate parameter shape.

The runner treats successful compilation, or a materially changed failure mode, as review-required rather than silently accepting a changed compiler contract.

These probes document a toolchain property. They are not production compile-negative API tests.

The historical reassociation probe is different: its old diagnostic is retained as historical evidence, but current LDC accepts the source without that diagnostic. Therefore the historical warning text is explicitly not a live replay gate.

### Performance evidence

Historical timings are not replay PASS/FAIL criteria.

The durable `run.sh` does not decide whether lane4, lane8, scalar copy, or `memcpy` is faster on the current machine.

Performance experiments belong in a separate optional benchmark runner and must be interpreted as measurements, not architecture-independent thresholds.

### Repository cleanliness

All generated IR, binaries, diagnostics, and temporary metadata are created below the system temporary directory.

The runner verifies that repository status is unchanged by replay.
