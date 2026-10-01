# raster-d Benchmark Principles

## Purpose

Benchmarks are part of architecture development, not an afterthought.

Every major performance-oriented design choice should be evaluated using
repeatable measurements.

## Metrics

At minimum record:

- elapsed time;
- MPix/s;
- effective GB/s where meaningful;
- allocation count;
- allocated bytes;
- temporary-memory peak;
- total working-set peak;
- thread count;
- CPU utilisation where available;
- compiler;
- compiler flags;
- CPU architecture.

## Workload classes

Benchmarks should distinguish:

### Micro

Small kernels used to understand compiler and memory behaviour.

### Region

Typical processing windows such as 2K, 4K and 8K raster regions.

### Streamed

Datasets large enough that whole-raster processing is intentionally undesirable
or impossible under the configured memory budget.

### Interactive

Viewport-oriented workloads involving loading, cancellation, reuse and
prioritisation.

## Correctness invariant

For algorithms with finite neighbourhood requirements:

    whole-raster result
        ≈
    streamed/region result with sufficient context

within defined numerical tolerances.

Tile or region boundaries must not produce artificial output discontinuities.

## Boundary tests

Test data must exercise boundaries that can expose incorrect region,
stride, halo or decomposition behaviour, including:

- requested regions crossing source/materialization boundaries;
- neighbourhood operations crossing decomposition boundaries;
- non-zero logical origins;
- negative and padded strides;
- planar and interleaved layouts;
- empty and degenerate regions;
- adjacent source regions with disjoint or overlapping backing;
- irregular decomposition seams.

Consumer-derived geospatial imagery may additionally contain roads, buildings,
natural features, provider-tile boundaries or mosaic seams, but those are test
fixtures rather than `raster-d` semantics.

## Memory tests

Performance results without memory measurements are incomplete.

Measure separately where possible:

- source/cache memory;
- decoded raster memory;
- processing workspace;
- temporary buffers;
- outputs.

Streamed raster execution should support an explicit residency/memory budget.

## Comparison policy

During R0 it is acceptable and encouraged to maintain multiple competing
implementations.

Examples:

- `mir.ndslice` versus custom stride view;
- planar versus interleaved multi-plane storage;
- generic versus contiguous kernels;
- fixed-tile versus arbitrary-region execution.

Implementations should be discarded when evidence favours a better design.

## Test data and imagery-derived fixtures

Core correctness tests should prefer deterministic synthetic data when that
isolates the property under test.

Real-world raster datasets may be used for stress, performance and
cross-boundary validation when they add evidence unavailable from synthetic
fixtures.

Historical ADR 0002 records that large benchmark imagery is not committed to
Git. Reproducible imagery-derived fixtures should therefore carry sufficient
provenance and content hashes.

A complete aerial/satellite imagery corpus is an `imagery-d` responsibility
rather than part of the generic `raster-d` identity.

## Compilers

Correctness should remain testable with DMD.

Performance measurements should include LDC/LLVM and may compare DMD where
useful.

## Reference and cross-platform benchmarking

raster-d distinguishes stable reference benchmarking from cross-platform
validation.

### Local reference platform

Absolute performance measurements and historical performance comparisons
should use a documented, stable reference machine whenever possible.

The local reference platform should record at least:

- CPU model and microarchitecture;
- operating system and kernel;
- compiler and LLVM version;
- compiler flags;
- thread count and CPU affinity where applicable;
- memory configuration where relevant.

This platform is the primary source for absolute timing comparisons and
performance-regression investigation.

### GitHub-hosted runners

GitHub-hosted runners are used primarily for:

- build and correctness portability;
- operating-system coverage;
- x86-64 and AArch64 coverage;
- compiler/code-generation inspection;
- architecture-specific optimization validation;
- relative comparisons performed within one workflow run.

Absolute elapsed times from independent hosted-runner executions must not be
treated as stable benchmark baselines because runner hardware and system load
are not controlled by the project.

Hosted-runner timing should therefore initially be informational and
non-gating.

### Architecture policy

Core design decisions must not accidentally depend on one CPU ISA.

Performance-oriented implementation work should consider at least:

- x86-64;
- AArch64.

Architecture-specific fast paths are permitted, but architecture-specific
behaviour should not unnecessarily leak into the semantic raster API.

In particular, conclusions based on AVX2 code generation should be checked
against AArch64/NEON code generation when they influence general raster
architecture.

### Performance CI policy

CI should distinguish:

```text
correctness / portability
    -> blocking

code-generation probes
    -> inspectable and reproducible

hosted-runner absolute timing
    -> informational

stable reference-machine timing
    -> performance baseline
```

Relative comparisons within the same hosted runner and process may be useful
for detecting large algorithmic differences, but they must not initially
produce hard regression thresholds.

## M3.2a affine bounds qualification

The production decision is limited to the shared checked relation prefilter
used by same-type transform and neighbourhood; it does not select a new executor.

Pinned research: [Issue #15](https://github.com/alex-1974/raster-d-research/issues/15),
head `59dcdbb8098e070f3ae2d8c75c8de1a766889f0e`,
[Gate 4 and raw XPS evidence](https://github.com/alex-1974/raster-d-research/tree/59dcdbb8098e070f3ae2d8c75c8de1a766889f0e/experiments/m3_affine_consumer/evidence/2026-09-30-xps).
The harness uses pinned production consumers with only their relation predicate
changed, alternating A/B order, two warmups and nine samples. Every call checks
complete output and padding outside the timer. Three independent processes per
compiler passed all 72 cases (1,296 timed calls) with matching hashes.

On XPS i7-9750H, large 2048x512 outputs across all four source/target row-sign
combinations had these baseline/candidate median ratios across the three runs:

| Consumer | DMD 2.111 | LDC 1.41 / LLVM 19.1.7 |
| --- | --- | --- |
| Point transform | 9.765–10.141x | 11.350–11.796x |
| Neighbourhood 3x3 | 1.322–1.391x | 1.955–2.027x |

These are end-to-end consumer measurements, not kernel-only throughput claims.
Small Universal cases are correctness coverage with noisy timings, not a tight
performance gate. AArch64 and cross-type performance are unqualified. Production
CI checks semantics and internal visibility rather than machine-dependent timing.

## M3.2b Canonical point-transform executor qualification

The independent executor comparison starts from production `b263477bdbbe0dc3e8c469ac3867eda345ba364c`,
after the M3.2a bounds prefilter. Pinned research:
[Issue #14](https://github.com/alex-1974/raster-d-research/issues/14),
head `e88443926f87dfd7c1068369bf9f5035bb6156e6`,
[raw XPS evidence and qualified summary](https://github.com/alex-1974/raster-d-research/tree/e88443926f87dfd7c1068369bf9f5035bb6156e6/experiments/m3_transform_executor/evidence/2026-10-01-xps).

The XPS i7-9750H run uses CPU affinity 0, DMD 2.111 and LDC 1.41 / LLVM 19.1.7,
without frequency/thermal controls. Three independent fixed-binary processes
per compiler pass all 41 cases and special-float checks, with matching output
hashes. Public baseline, generic pointer and safe row-slice candidates rotate
order over nine samples after two warmups. Every call verifies full output,
padding and source preservation outside the timer (6,642 timed calls).

For large 2048x512 outputs, across four padded row-sign combinations and the
contiguous case, public-baseline/pointer median ratios span:

| Sample type | DMD 2.111 | LDC 1.41 / LLVM 19.1.7 |
| --- | --- | --- |
| float | 17.433–24.001x | 8.209–12.974x |
| ubyte | 9.015–9.475x | 5.751–37.896x |

Pointer beats slice in every paired large DMD case: slice/pointer ratios are
1.764–2.398 for float and 1.212–1.273 for ubyte. LDC has no stable material
slice advantage. M3.2b therefore selects one generic pointer executor, including
POD samples, without compiler-specific source selection.

These are end-to-end consumer measurements. Inter-process spread reaches 46.56%
for large DMD float pointer cases; exact speedup promises and portable timing
thresholds are unsupported. Small Universal cases qualify correctness, not
performance. AArch64 performance remains unqualified. The original collector's
hardcoded container label is preserved in raw SUMMARY.md and corrected only in
QUALIFIED_SUMMARY.md; numeric results are unchanged. CI checks semantics,
visibility and the actual-source trust boundary rather than timing.

## M3.3 Canonical fill executor qualification

Production baseline `d4763ff0b95999743ea43d0b1dcca44fc68773d1` follows M3.2.
[Research Issue #17](https://github.com/alex-1974/raster-d-research/issues/17)
compares the complete public fill consumer with mechanically pinned Pointer
and Slice candidates; all validation and Universal behavior is retained.
The [qualification record](https://github.com/alex-1974/raster-d-research/tree/97ed8a11d86b42464a55aa90d69b8b8f7b778b52/experiments/m3_fill_executor/evidence/2026-10-01-xps)
preserves raw files and their verified checksums. Uploaded source is research
`ea6fc86e12dcf442c3d99ff1dc0a8ddc04cc9c8b`.

XPS i7-9750H, affinity CPU 0; DMD 2.111.0, LDC 1.41.0 / LLVM 19.1.7, DUB 1.40.0;
frequency/thermal controls unchanged. Six independent fixed-binary processes
pass 70 float/ubyte/POD cases, bitwise special floats and invalid/empty checks;
all hashes match. Two warmups and nine cyclic-order samples per path yield
11,340 timed calls, with complete output/padding checks outside each timer.
Both inherited test suites and actual-source trust challenges pass.

Across all six large Canonical layouts (contiguous, padded, negative, repeated
and overlapping rows), public/Slice median ratios span:

| Sample type | DMD 2.111 | LDC 1.41 / LLVM 19.1.7 |
| --- | --- | --- |
| float | 9.232–13.845x | 2.247–16.350x |
| ubyte | 61.527–282.100x | 11.892–151.867x |

Slice improves every large paired DMD ubyte comparison with Pointer. DMD float
is mostly near parity; LDC preferences vary. LDC padded float Slice is
3.6–15.8% slower than Pointer in all three runs. ADR 0012 accepts that measured
tradeoff for one generic source form with a narrower trusted boundary and the
consistent DMD ubyte benefit; no compiler-specific selection is admitted.

Large process spread reaches 150.99% for DMD ubyte Slice, 157.86% for LDC ubyte
Slice and 355.03% for LDC ubyte Pointer. Repeated/overlapping rows concern logical
repeated writes to shared physical samples, not independent-memory bandwidth.
Tiny cases can lie below timer resolution; zero-median ratios are omitted.
These are end-to-end observations, not precise portable promises or timing
thresholds. AArch64 performance remains unqualified.
