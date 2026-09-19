# E5.3 Conversion Optimization Research Evidence

This directory preserves the historical evidence used for the E5.3 scalar-conversion optimization decisions in `imagery-d`.

The files under `original/` are recovered research artifacts. They are preserved as historical evidence and must not be reformatted, modernized, refactored, or otherwise edited.

`SHA256SUMS` covers the files under `original/` and records their preserved byte content.

## Purpose

E5.3 investigated optimization of the `ubyte -> float` conversion path.

The main questions were:

- whether the ordinary production loop is auto-vectorized;
- whether handwritten SIMD is justified;
- whether alias information is preventing useful optimization;
- whether communicating non-overlap through `@restrict` provides a material performance benefit.

The resulting decision is to keep the ordinary production implementation and rely on LLVM auto-vectorization, including its runtime alias versioning where required.

## Production source

The historical production source is not duplicated under `original/`.

The relevant implementation remains versioned in the repository at `source/imagery/raster/internal/scalar_conversion.d`.

The durable research artifacts record the generated code and measurement evidence associated with that production implementation.

## Evidence classification

### `original/conversion_codegen/`

Classification: **AUTHORITATIVE**

Historical generic and native code-generation output for the production `ubyte -> float` conversion path.

`d-imagery-e5_3d-codegen.txt` preserves the historical build and toolchain context.

The historical native compilation used LDC 1.41.0 with LLVM 19.1.7 on an x86-64 Skylake target.

The optimizer reported a vectorization width of 8 with interleave count 4 for the native experiment, and the generated code contained the expected packed conversion sequence.

The important engineering conclusion is not that every future compiler must use exactly that width. It is that the straightforward production loop was successfully auto-vectorized without handwritten SIMD.

The generated code also exposed a runtime alias check, which motivated E5.3e.

### `original/alias_codegen/`

Classification: **AUTHORITATIVE**

`alias_probe.d` and its LLVM IR isolate the aliasing question.

The unknown-alias raw-pointer form retained runtime vector memory checking.

The raw-pointer `@restrict` form produced LLVM `noalias` information and removed that runtime vector alias check.

This establishes that communicating a valid non-overlap relation can change optimizer structure.

It does **not** establish that introducing such an annotation into the production abstraction is safe or worthwhile.

### `original/alias_benchmark/`

Classification: **AUTHORITATIVE**

This directory contains:

- the benchmark source;
- nine independent historical process runs;
- the resulting multi-process summary.

The final audit used repeated independent processes and paired ratios instead of relying on one benchmark process.

For the larger tested sizes, the retained unknown-alias versus `@restrict` ratios remained close to parity. The historical summary includes:

- 65,536 samples: ratio about `1.0014`;
- 1,048,576 samples: ratio about `1.0045`;
- 4,194,304 samples: ratio about `1.0064`.

The largest-size process medians occurred on both sides of `1.0`.

The evidence therefore did not establish a useful production performance benefit sufficient to justify a new alias contract.

These historical timings are evidence, not portable benchmark thresholds.

## Intermediate evidence intentionally excluded

Earlier single-process benchmark summaries were useful during investigation but were classified as intermediate once the nine-process audit was completed.

They are intentionally not promoted into this durable evidence set.

Likewise, executables, object files, empty stderr files, and redundant generated diagnostics are not part of the preserved authoritative evidence.

## Historical evidence versus replay

The contents of `original/` answer:

> What evidence supported the E5.3 engineering decision at the time?

Future replay tooling answers:

> Does the relevant conclusion still hold with the current supported compiler and current hardware?

The replay contract must not require byte-identical assembly, an exact vector width, or reproduction of historical timing values.

Useful structural replay properties include whether:

- the ordinary production conversion remains vectorizable;
- an unknown-alias path uses runtime alias versioning when required;
- a valid raw-pointer noalias experiment can remove that check.

Useful performance replay asks whether runtime alias versioning has become a demonstrated bottleneck large enough to reconsider the architecture.

## Current E5.3 decisions

The preserved evidence supports the following current project decisions:

- keep the production Mir/scalar conversion kernel;
- rely on LLVM auto-vectorization;
- accept runtime alias versioning for the current conversion path;
- do not add production `@restrict`;
- do not expose a public alias assertion;
- do not introduce a persistent non-overlap token;
- do not add handwritten AVX2 or other handwritten SIMD without new measured evidence;
- do not encode a fixed vector width into the implementation.

## Integrity

Verify the preserved historical artifacts by running `cd experiments/e5_3_conversion_optimization && sha256sum -c SHA256SUMS`.

Do not regenerate `SHA256SUMS` merely because a compiler replay produces different output. Replay artifacts belong outside `original/`.

## Durable replay

`run.sh` is the maintained replay harness for the deterministic E5.3 conclusions.

Compiler-neutral semantic replay can be run with DMD:

`experiments/e5_3_conversion_optimization/run.sh dmd`

The full LLVM structural replay can be run with LDC:

`experiments/e5_3_conversion_optimization/run.sh ldc2`

### Historical integrity

Every preserved file under `original/` is verified against `SHA256SUMS` before live verification starts.

A hash mismatch is a hard failure.

### Compiler-neutral production semantics

Both DMD and LDC compile and execute the unit tests of the current production `ubyte -> float` scalar-conversion kernel.

The tests verify the complete ubyte domain, unequal-length rejection before target modification, and the empty-slice case.

A normal D unittest success summary written to stderr is accepted. Other unexpected stderr remains a failure.

### LDC/LLVM structural contract

When the selected compiler is LDC, the runner additionally verifies optimizer structure.

The current contract requires:

- unknown-alias raw conversion to retain runtime vector alias checking;
- raw-pointer `@restrict` conversion to expose LLVM `noalias`;
- the restrict form not to require the same runtime vector memory check;
- both isolated conversion forms to remain vectorized;
- the production conversion kernel to remain vectorized;
- the production conversion kernel to retain runtime alias versioning.

The replay deliberately does not require a particular SIMD width, instruction mnemonic, register allocation, or byte-identical LLVM IR.

A changed vector width is therefore not by itself a failure.

Loss of production vectorization or a changed alias-versioning strategy is treated as review-required because it may change the engineering conclusion.

### Performance evidence

Historical unknown-alias versus restrict timings remain historical evidence only.

They are not replay PASS/FAIL thresholds.

Performance measurement belongs in a separate optional benchmark runner. A future measurement may motivate renewed investigation, but it must not silently change the production alias contract.

### Repository cleanliness

Generated executables, LLVM IR, DUB metadata, and diagnostics are created below the system temporary directory.

The runner verifies that repository status is unchanged by replay.
