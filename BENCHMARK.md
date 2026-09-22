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

A complete aerial/satellite imagery corpus is a future `imagery-d`
responsibility rather than part of the generic `raster-d` identity.

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
