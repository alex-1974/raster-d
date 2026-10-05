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

## M3.5 Copy and exact conversion bounds / row qualification

Production baseline is `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.
[Research PR #23](https://github.com/alex-1974/raster-d-research/pull/23)
at `9b3e709111364276d1f7383b6f14326327f6f21f` retains
[the audit and original XPS raw evidence](https://github.com/alex-1974/raster-d-research/blob/9b3e709111364276d1f7383b6f14326327f6f21f/docs/research/m3-copy-conversion-audit.md#reference-xps-qualification--2026-10-03).
The archive SHA256 is
`7c1636331163f30e1479f9d99bbcb230a6520b2396184f21a2fdb73f26d73ae4`;
all 19 checksums verify and the summary reproduces exactly. Collector/source
head 85e1614 mechanically pins complete public/internal modules and preserves
152 unittest blocks and actual-source trust controls.

XPS i7-9750H, CPU affinity 0, unchanged frequency/thermal controls, DMD 2.111.0,
LDC 1.41.0 / LLVM 19.1.7, DUB 1.40.0, G++ 15.2.0. Both D binaries link one
strict C++ object. Six fixed-binary processes, 15 cyclic rounds over five paths
(each order position three times), two warmups, 96 timed and 32 extra semantic
cases, 43,200 timed calls. Reset and complete backing/guard checks are outside
timing. All compiler/process fingerprints match each other and VM evidence.

Large 2048x512 ranges below span three process medians; Copy aggregates three
sample types. Public/Combined compares complete consumers. Combined/C++ is a
scoped execution-reference ratio: C++ omits validation and adds a separate ABI
call. It is not a complete library or language ratio.

| Group | Compiler | Public/Combined | Combined/C++ |
| --- | --- | --- | --- |
| Padded Copy | DMD | 128.592–2892.533x | 0.878–1.161x |
| Padded Copy | LDC | 46.604–934.892x | 0.998–1.643x |
| Flat conversion | DMD | 4.374–4.776x | 2.055–6.721x |
| Flat conversion | LDC | 20.210–23.135x | 0.938–0.998x |
| Padded conversion | DMD | 975.357–980.202x | 3.953–4.065x |
| Padded conversion | LDC | 891.907–1214.341x | 1.007–1.209x |
| Negative-both conversion | DMD | 920.221–929.541x | 2.918–3.516x |
| Negative-both conversion | LDC | 463.266–475.638x | 1.542–1.848x |

ADR 0013 selects checked same-/cross-type bounds plus approved unit-sample-stride
row Copy/conversion, including approved flat conversion. Original flat Copy
and Universal semantic traversal remain. Bounds-only padded Copy is
9.900–10.740x DMD / 14.488–21.845x LDC faster; execution alone retains exact
scans and is only 1.044–1.117x across both compilers. Combining both changes
confirms the large non-flat direction. Exact conversion remains an intermediate
improvement; DMD and signed LDC execution gaps stay open in research Issue #22.

Maximum large-case Public / Combined process spread is 99.55% / 244.36% DMD
and 42.09% / 93.35% LDC, mainly short Copy. LDC padded conversion Combined
also has 45.06% spread; DMD padded Public / Combined is 3.36% / 3.36%.
Full ranges are retained; no confidence interval, timing threshold, precise
near-parity difference or small Flat-Copy gain/regression is inferred. Tiny
zero medians remain below clock resolution. Isolated actual-source DMD scalar
and LDC packed conversion assembly is diagnostic, not full-public causality.
VM LLVM/G++ differ from XPS; no hardware-only attribution is made.

Production promotion validates 120 public backing cases, original tests,
independent relation oracles, CTFE, external visibility and actual-source trust
under both compiler families. These tests validate the clean transfer; the
reported XPS times are for the pinned research consumers. No new production
binary timing, compiler switch, explicit SIMD, threading or AArch64 performance
qualification is claimed.


## M3.4 strict reduction controlled confirmation

The initial strict `float -> double` reduction audit was followed by a
controlled reference-XPS confirmation because the first DMD Pointer advantage
was material but modest.

Retained research:

- raster-d-research Issue #21 / PR #43;
- archive
  `raster-m3-reduction-pointer-confirm-20261005-101445.tar.gz`;
- SHA256
  `46c778441788941e35483e6279a36c05f89b94730416bd1e6f7341b5a04f3b1`.

The collector reuses the qualified strict semantic harness, builds fixed release
binaries, runs six independent processes per compiler on CPU0 and records
governor/frequency/thermal snapshots.

Representative DMD public/pointer medians on XPS i7-9750H:

| Shape/layout | Public / Pointer |
| --- | ---: |
| 256x128 contiguous | ~0.995x |
| 256x128 padded | ~1.128x |
| 256x128 negative-row | ~1.128x |
| 256x128 repeated-row | ~1.128x |
| 2048x512 contiguous | ~1.006x |
| 2048x512 padded | ~1.131x |
| 2048x512 negative-row | ~1.129x |
| 2048x512 repeated-row | ~1.130x |

LDC remains approximately neutral. The historical and then-current Production
reduction modules were byte-identical before promotion.

ADR 0015 and Production PR #63 therefore select the narrow DMD x86-64
Canonical pointer executor while preserving one double accumulator and exact
row-major order. Contiguous Mir, Universal, LDC, reassociation, SIMD reduction
and threading remain unchanged.

## M3.5 compiler-qualified exact conversion follow-up

ADR 0013 was intentionally an intermediate Production step. Its remaining DMD
and signed-LDC gaps were resolved through separate full-public qualification.

### DMD full-public pointer qualification

A same-entry row diagnostic first removed severe function-placement noise, then
a generated full-public selector compared current row execution with a bounded
pointer/count candidate while preserving complete public validation.

The full-public reference-XPS result showed a stable DMD improvement, typically
about 16-22% on large padded/negative/repeated Canonical layouts, while inactive
and LDC controls remained near parity. That result was promoted in Production
PR #62.

The pointer implementation was subsequently used as the **baseline** for the
final SSE2 refresh rather than treated as the final optimization.

### LDC negative-source optimizer boundary

Retained research:

- raster-d-research Issue #44 / PR #45;
- archive
  `raster-m3-ldc-signed-row-xps-20261005-103724.tar.gz`;
- SHA256
  `8293304344d838529816599d3c0fd667a3ab72e5d5c18a260edc1a3665d271cc`.

The experiment uses one full-public entry and changes only the row-local
optimizer boundary. Negative-target-only is an explicit control, allowing
source-row direction to be isolated.

Representative LDC long-block current/boundary medians:

| Width | Negative source | Negative both |
| ---: | ---: | ---: |
| 31 | 0.992x | 1.016x |
| 64 | 1.269x | 1.293x |
| 96 | 1.459x | 1.473x |
| 256 | 2.061x | 2.037x |
| 2048 | 2.445x | 2.422x |

Contiguous, padded positive-source, negative-target-only, repeated-source,
Universal and DMD controls remain near 1.00x. Production PR #64 therefore
selects a safe `pragma(inline, false)` LDC x86-64 row helper only for negative
source row stride and width >=64.

### DMD exact SSE2 refresh against the pointer Production path

Retained research:

- raster-d-research Issue #46 / PR #47;
- archive
  `raster-m3-vector-refresh-xps-20261005-110140.tar.gz`;
- SHA256
  `35eaaeef6bbd1d3d3ac12168a84824eb51456cfbc7660b3bf39b97517ebd3f51`.

The refresh pins Production
`24d948255df014c683d79c5508f13248806062dc`, where the DMD bounded pointer
optimization and LDC signed-source boundary already exist. One generated
full-public entry compares:

- form 0: exact current Production;
- form 1: exact SSE2 only for DMD x86-64 unit-stride rows width >=64.

Widths 31/63, Universal and every LDC case are inactive controls. Six
fixed-binary CPU0-pinned processes are retained for short and long cohorts.
The DMD linked binary contains the expected `movdqu`, `punpck*`,
`cvtdq2ps` and `movups` instruction sequence.

Pooled DMD Production/SSE2 medians:

| Cohort | Active cases | Inactive cases |
| --- | ---: | ---: |
| Short | ~1.695x | ~1.000x |
| Long | ~1.677x | ~0.999x |

Representative long-block DMD medians:

| Width | Contiguous | Padded | Negative source | Negative target | Negative both | Repeated source |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 64 | 1.861x | 1.711x | 1.707x | 1.704x | 1.703x | 1.735x |
| 96 | 1.729x | 1.612x | 1.620x | 1.590x | 1.623x | 1.593x |
| 256 | 1.701x | 1.724x | 1.694x | 1.706x | 1.716x | 1.659x |
| 2048 | 1.565x | 1.565x | 1.633x | 1.611x | 1.614x | 1.606x |

All LDC control cohorts remain near 1.00x.

The SIMD algorithm is the previously qualified exact sixteen-ubyte
unpack/widen/`CVTDQ2PS` kernel with scalar tail; the refresh changes the
comparison baseline, not the algorithm. Earlier bitwise, four-rounding-mode and
guard-page evidence therefore remains applicable to the same core operation.

ADR 0014 and Production PR #65 promote this path for DMD x86-64 width >=64,
superseding the bounded pointer implementation there.

These ratios are reference-machine qualification evidence, not portable
performance promises or CI timing thresholds. AArch64/NEON remains unqualified.
