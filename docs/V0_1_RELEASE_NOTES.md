# raster-d v0.1.0 release notes

Status: **DRAFT**

`raster-d v0.1.0` establishes the first released generic raster-core baseline.

The release is feature-frozen but not yet API-frozen or published.

## Planned public scope

The candidate includes:

- retained physical-resource ownership and validated raster import;
- lease-bound read-only and writable raster views;
- signed row/sample-stride representation;
- strict float-to-double reduction;
- same-type plane Copy;
- generic Fill;
- compile-time point transform;
- fixed 3x3 neighbourhood execution;
- exact ubyte-to-float conversion.

## Performance qualification

The x86-64 baseline has measured DMD/LDC-specific internal execution strategies
without exposing compiler/ISA switches in public API.

Detailed evidence remains in BENCHMARK.md and ADRs.

## Scope boundary

The release deliberately excludes image/color/radiometric semantics,
caller-visible scheduling policy, GPU execution and unqualified AArch64/NEON
performance claims.

## Compatibility

The final source-compatibility statement will be written after the 0.1 API
audit and `freeze/api-0.1.0` checkpoint.

## Validation

Final compiler/platform matrix, external consumer, documentation and published
DUB verification remain pending.
