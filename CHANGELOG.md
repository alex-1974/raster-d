# Changelog

All notable changes to `raster-d` are recorded here.

The format follows a simple release-oriented structure. Because `raster-d`
is pre-1.0, later minor releases may intentionally evolve the public API.
Each published release nevertheless has its own frozen source contract.

## 0.5.1 — 2026-10-25

### Added

- opt-in, bounded parallel row kernels for callback-scoped affine plane
  borrows through `withPlanesIntoParallel`;
- generic `parallelRows` execution primitive with caller-selected worker and
  chunk limits, sequential fallback, and synchronous worker joining;
- DMD/LDC correctness, ThreadSanitizer, stride/ROI/aliasing tests and release
  benchmark matrix for 1024×768 and 1920×1080.

### Scheduling and safety

- no process-global worker pool or hidden persistent scheduler;
- `@safe nothrow` row callbacks with explicit partial-write-on-failure
  semantics;
- static worker batches and atomic failure publication to avoid a central
  scheduling lock.

## 0.5.2 — 2026-10-25

### Added

- scoped multi-phase parallel row execution through
  `ParallelRowsOperation`;
- source-only `withPlanesParallel` execution without a fabricated
  destination;
- `withPlanesParallelPhases` and `withPlanesIntoParallelPhases` for
  barrier-separated analysis and transformation phases;
- stable worker indices within a scoped operation, with explicit synchronous
  failure and join semantics.

### Qualification

- DMD and LDC unit tests pass;
- source-only, destination, multi-phase, barrier and callback-failure tests
  pass;
- release benchmark coverage includes the complete two-phase data-plane
  workload at 1024×768 and 1920×1080.

## 0.5.0 — 2026-10-24

### Added

- public `RasterPlaneRow` and `WritableRasterPlaneRow` exports through
  `import raster`;
- callback-scoped row data and sample-stride access for interleaved and
  planar downstream kernels;
- an external RGB data-plane benchmark covering DMD and LDC code generation.

### Performance

- the benchmarked DMD interleaved `ubyte` to `float` workload improved from
  3.78 ns/pixel to 1.79 ns/pixel when row data and stride are hoisted once per
  row, with no material LDC regression.

## 0.4.1 — 2026-10-24

### Fixed

- corrected element-to-byte stride conversion in affine envelope and alias
  validation;
- enabled safe interleaved mixed-type affine windows after exact
  `ubyte`-to-`float` overlap classification;
- added the public multi-plane contiguous callback and DMD/LDC benchmark
  coverage for affine row access.

## 0.4.0 — 2026-10-23

### Added

- scoped public affine and multi-plane data-plane windows for downstream
  kernels, including mixed-type source/destination execution;
- conservative source/destination and destination/destination byte-envelope
  overlap rejection before kernel callbacks;
- DMD/LDC consumer, lifetime, benchmark and archive-gate coverage for the
  data-plane contract.

## 0.3.0 — 2026-10-22

This minor version adds generic numeric histograms for consumers including
`imagery-d`. Its source/API freezes are recorded at
`freeze/feature-0.3.0` and `freeze/api-0.3.0`, with qualification evidence
in [issue #254](https://github.com/alex-1974/raster-d/issues/254).
All 66 published v0.2 root exports are retained; six histogram exports are
added. The v0.2.0 release and freeze tags remain unchanged.
The signed release tag and registry listing, rather than this changelog date,
are authoritative for actual publication availability.

### Added

- exact, allocation-free `ubyte` histogram reduction with 256 `ulong`
  counts, signed-stride/ROI support, checked count overflow and composable
  window counts (raster-d issue #251). These APIs are **not**
  part of the frozen v0.2.0 release.
- Generic caller-buffered interval histograms for all 10 numeric sample types,
  exact signed and 64-bit integral bin assignment, finite floating range policy,
  explicit out-of-range/NaN counts, and ROI/tiled composition (issue #251).
  Introduced in v0.3.0; not present in published v0.2.0.

### Documentation and release

- Frozen API contract: `docs/API_0_3.md`.
- Release notes: `docs/V0_3_RELEASE_NOTES.md`.
- Exact-head release qualification: `docs/V0_3_RELEASE_GATE.md` and issue #254.

## 0.2.0 — 2026-10-10

The v0.2.0 feature set and public API are frozen at
`freeze/feature-0.2.0` and `freeze/api-0.2.0`, respectively.
v0.2.0 is published as a signed Git tag, GitHub Release and DUB package.
The release matrices, documentation build and external archive consumers
passed at the release candidate; postpublication Pages and independent
DUB consumer checks also passed. The full editorial Ddoc review and
exact-head prepromotion content sign-off remain historically unverified
and are tracked in issue #198.

### Added and expanded

- generic, checked destination-oriented raster operation families,
  including exact sample conversion and typed reductions;
- fixed compile-time convolution kernels on the established
  neighbourhood execution family;
- v0.2 public API contract inventory in `docs/API_0_2.md`.

### Performance and compatibility

- M5 compiler/codegen, SIMD and comparable-C++ performance qualification
  recorded in the repository's release evidence documents;
- existing raster ownership and borrowing semantics retained, without
  adding a package-wide DIP1000 requirement;
- public API frozen independently of the earlier v0.1.0 source contract.

### Documentation and release qualification

- beginner introduction explaining raster grids and the library boundary;
- practical guides for zero-copy ROI, checked sums, exact conversion and
  neighbourhood/halo requirements;
- release-content gate requiring an exact-head README, changelog, Ddoc/DDox,
  Pages and publication-status audit immediately before promotion.

Detailed release notes and qualification history are in
`docs/V0_2_RELEASE_NOTES.md`. The immutable release is
[`v0.2.0`](https://github.com/alex-1974/raster-d/releases/tag/v0.2.0).

## 0.1.0 — 2026-10-05

First public release of the generic raster-core library.

### Added

- retained ownership for one or more physical byte resources;
- validated multi-plane raster backing with signed row/sample strides;
- lease-bound read-only `RasterView` and public `WritableRasterView`;
- external owned-raster import with explicit ownership disposition;
- strict `float -> double` row-major reduction;
- same-type plane Copy;
- generic Fill;
- compile-time point transform;
- fixed 3 x 3 neighbourhood execution;
- exact `ubyte -> float` conversion;
- bounded request residency and retained reuse;
- exact multi-block dependency assembly for streamed raster requests;
- public-only DDox documentation with one compiled Example per public symbol;
- release benchmark, API-freeze, archive-consumer, compiler-floor and
  platform qualification gates.

### Performance

- qualified x86-64 DMD/LDC Canonical execution paths for the public M2/M3
  operation family;
- DMD 2.111 exact SSE2 row conversion for qualified `ubyte -> float` cases;
- LDC 1.41 negative-source optimizer-boundary specialization for exact
  conversion;
- DMD 2.111 strict-reduction Canonical pointer executor;
- final reference-XPS Production baseline retained in `BENCHMARK.md`.

These are implementation choices, not public compiler/ISA switches.

### Fixed during release qualification

- `RasterLease!T.init.view()` now returns inert `RasterView!T.init`
  instead of entering an uninitialized retained-owner borrow;
- retained-store implementation no longer relies on local `ref` variables
  unsupported by the documented D 2.101 compiler floor;
- release benchmark reduction checksum accumulation now starts from `0.0`;
- release/compile-negative workflows invoke shell probes explicitly through
  `bash`, independent of executable-file mode.

### Compatibility

The v0.1.0 public source contract is frozen by:

```text
freeze/api-0.1.0
7afcaad4181566d21ca7ced78cf7b417eae8adbf
```

The final release candidate preserves that public contract. Post-freeze changes
are internal implementation, validation, benchmark, CI, documentation and
packaging hardening only.

### Validation

The release candidate is qualified against:

- DMD 2.111.0 / 2.112.1 / 2.113.0;
- LDC 1.41.0 / 1.42.0 / 1.43.0;
- documented compiler floors including DMD 2.101.2 and LDC 1.31.0 where
  supported by platform;
- Linux x86-64 and ARM64;
- Windows x86-64;
- macOS x86-64 and ARM64;
- experimental Windows ARM64/LDC;
- baseline DMD/LDC external git-archive consumers;
- strict public-only DDox and compiled Example gates.

### Deferred

Not part of v0.1.0 qualification:

- AArch64/NEON performance tuning;
- caller-owned parallel scheduling;
- GPU execution;
- image/color/radiometric semantics owned by `imagery-d`;
- performance retuning for later compiler/frontend generations.
