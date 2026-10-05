# Changelog

## v0.1.0 — 2026-10-05

First released generic raster-core baseline.

### Added

- retained physical-resource ownership and validated raster import;
- lease-bound read-only and writable raster views;
- descriptor-space regions and signed-stride multi-plane layouts;
- strict float-to-double reduction;
- same-type plane Copy;
- exact generic Fill;
- compile-time point transform;
- fixed 3 x 3 neighbourhood execution;
- exact ubyte-to-float conversion;
- bounded request residency, retained reuse and multi-block dependency assembly;
- public DDox documentation with compiler-checked examples;
- release API, compiler/platform, benchmark and archive-consumer qualification.

### Qualified

- public 0.1 source contract at `freeze/api-0.1.0`;
- DMD 2.111.0 / 2.112.1 / 2.113.0;
- LDC 1.41.0 / 1.42.0 / 1.43.0;
- minimum supported compiler/package floor described in README.md;
- Linux x86-64, Linux ARM64, Windows x86-64, macOS x86-64 and macOS ARM64;
- experimental Windows ARM64/LDC candidate;
- reference-XPS Production performance baseline recorded in BENCHMARK.md.

### Deferred

- AArch64/NEON performance qualification;
- later compiler/frontend performance retuning;
- caller-owned parallel scheduling;
- GPU execution;
- image-domain semantics owned by imagery-d.
