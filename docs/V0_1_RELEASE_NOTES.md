# raster-d v0.1.0 release notes

`raster-d v0.1.0` establishes the first released generic raster-core
baseline.

The release provides retained raster ownership and views, checked generic
operations, streamed-residency building blocks, and qualified x86-64 CPU
execution without importing image, colour, radiometric or scheduler semantics
into the raster API.

## Public scope

v0.1.0 includes:

- retained physical-resource ownership and validated owned-raster import;
- lease-bound read-only `RasterView` and `WritableRasterView`;
- signed row/sample-stride representation;
- `Region2D`, plane descriptors and byte-layout descriptors;
- strict logical row-major `float -> double` reduction;
- same-type plane Copy;
- generic Fill;
- compile-time point transform;
- fixed 3 x 3 neighbourhood execution;
- exact `ubyte -> float` conversion.

The aggregate supported consumer entry point is:

~~~d
import raster;
~~~

For the complete frozen contract, see `docs/API.md`.

## Streaming and residency foundation

The production implementation also contains the internal contracts required
for bounded streamed execution:

- requested-region dependency planning;
- synchronous caller-owned materialization;
- bounded request residency;
- bounded retained reuse;
- exact multi-block dependency assembly.

Block geometry selection, replacement policy, scheduling and parallel execution
remain outside the public raster API.

## Performance qualification

The qualified x86-64 implementation contains evidence-driven DMD/LDC internal
execution strategies while preserving one public semantic contract.

Notable qualified paths include:

- DMD exact SSE2 `ubyte -> float` row conversion on the qualified width/layout
  family;
- LDC negative-source row optimizer boundary for exact conversion;
- DMD strict-reduction Canonical pointer execution;
- generic Canonical fast paths for Copy, Fill, point transform and 3 x 3
  neighbourhood operations.

The final reference-XPS Production baseline and evidence hashes are recorded in
`BENCHMARK.md`.

Compiler/ISA selectors, raw execution pointers, Mir adapters and execution
layout classification remain non-public.

## Release-qualification fixes

The release audit found and corrected several issues before publication:

- `RasterLease!T.init.view()` now returns inert `RasterView!T.init` rather
  than entering an uninitialized retained-owner borrow;
- documentation and named-argument qualification now consistently freeze the
  strict-reduction output parameter name as `sum`;
- retained-store code was made compatible with the supported D 2.101 frontend
  by removing local `ref` aliases while preserving store semantics;
- compile-negative release workflows now invoke shell probes explicitly through
  `bash`;
- the benchmark-only strict-reduction checksum sink now starts from `0.0`.

None of the post-API-freeze fixes changes the frozen public 0.1 source contract.

## Documentation

v0.1.0 establishes the documentation quality baseline used for future releases:

- 50 public DDox symbol pages;
- 50 own compiler-checked rendered Examples;
- public-only DDox navigation;
- module Ddoc and production internal-function Ddoc verification;
- decision-comment review for important ownership, numerical and performance
  choices;
- versioned GitHub Pages build support.

## Compatibility

The immutable public API checkpoint is:

~~~text
freeze/api-0.1.0
7afcaad4181566d21ca7ced78cf7b417eae8adbf
~~~

The release candidate preserves this contract.

The qualified source/frontend floor is DMD/Phobos 2.101 with corresponding
LDC 1.31 where platform packages permit it. The controlled release-generation
matrix additionally covers DMD 2.111.0/2.112.1/2.113.0 and
LDC 1.41.0/1.42.0/1.43.0.

## Validation

The final release candidate passes:

- controlled six-compiler release-generation matrix;
- supported Linux x86-64/ARM64, Windows x86-64 and macOS x86-64/ARM64 matrix;
- experimental Windows ARM64/LDC gate;
- supported compiler-floor matrix;
- external git-archive consumers with DMD 2.111.0 and LDC 1.41.0;
- API positive/negative compile contracts and DIP1000 lifetime gates;
- strict DDox and documented Example gates;
- reference-XPS Production benchmark qualification.

## Scope boundary

v0.1.0 deliberately does not claim:

- AArch64/NEON performance qualification;
- caller-owned parallel scheduling policy;
- GPU execution;
- image, colour or radiometric semantics;
- performance qualification for later compiler/frontend generations.

Those are future work, not incomplete v0.1.0 release requirements.

## Upgrade notes

This is the first public release, so no source migration is required.

Consumers should prefer `import raster;` and avoid depending on
`package(raster)` or `raster.internal` implementation details.
