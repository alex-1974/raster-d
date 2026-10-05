# Changelog

All notable changes to `raster-d` are recorded here.

The format follows a simple release-oriented structure. Because `raster-d`
is pre-1.0, later minor releases may intentionally evolve the public API.
Each published release nevertheless has its own frozen source contract.

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
