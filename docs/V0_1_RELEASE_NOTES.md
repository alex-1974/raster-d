# raster-d v0.1.0 release notes

Status: **RELEASE CANDIDATE — QUALIFIED FOR PROMOTION**

`raster-d v0.1.0` establishes the first released generic raster-core baseline.

The feature set and public source contract are frozen. Publication begins only
after the qualified `release/0.1` state is promoted to `main` and the full
release gate passes there.

## Public scope

The release includes:

- retained physical-resource ownership and validated raster import;
- lease-bound read-only `RasterView`;
- lease-bound `WritableRasterView`;
- descriptor-space `Region2D` geometry;
- multi-plane layouts with signed row/sample strides;
- strict row-major `float -> double` reduction;
- same-type plane Copy;
- exact generic Fill;
- compile-time point transform;
- fixed 3 x 3 neighbourhood execution;
- exact `ubyte -> float` conversion.

The supported aggregate consumer entry point is:

~~~d
import raster;
~~~

The caller-visible 0.1 contract is recorded by
`freeze/api-0.1.0` at
`7afcaad4181566d21ca7ced78cf7b417eae8adbf`.

## Ownership and lifetime

`OwnedByteResource` is the move-only resource-transfer token.
`tryImportOwnedRaster` transfers successfully validated ownership into a
copyable `RasterLease!T`.

Views are non-owning lease-bound capabilities and are qualified through DIP1000
lifetime probes. `RasterLease!T.init` is an inert valid default state:
`view()` returns an empty read-only view and `tryWritableView()` fails
cleanly with an empty writable view.

## Numerical and mutation contracts

The release preserves:

- exact same-type Copy;
- exact `ubyte -> float` conversion for all source values;
- strict logical row-major reduction with one double accumulator;
- caller-defined point-transform semantics;
- row-major 3 x 3 neighbourhood kernel input with center at index 4;
- pre-write structural/overlap validation for operations whose failure contract
  requires destination preservation.

Compiler- and ISA-specific execution remains private and does not alter these
observable contracts.

## Performance qualification

The qualified x86-64 implementation contains measured compiler-specific
internal execution paths for DMD 2.111 and LDC 1.41 without exposing
compiler/ISA switches through public API.

The final reference-XPS Production archive is:

~~~text
raster-release-0.1-baseline-20261005-152725.tar.gz
SHA256 b3711e7800c52cbd97f4313a214eec4326846100640af570b4fcacf4a0fd3ae1
~~~

Its recursive manifest is 47/47 PASS, with six CPU0-pinned processes per
compiler and stable checksums for all seven retained workloads.

Detailed measurements and interpretation are in `BENCHMARK.md`.

## Compiler and platform qualification

The release passes the controlled compiler-generation matrix:

- DMD 2.111.0;
- DMD 2.112.1;
- DMD 2.113.0;
- LDC 1.41.0;
- LDC 1.42.0;
- LDC 1.43.0.

The minimum supported package/compiler floor also passes on the platforms where
those packages are supported:

- Linux x86-64: DMD 2.101.2 / LDC 1.31.0;
- Linux ARM64: LDC 1.31.0;
- Windows x86-64: DMD 2.101.2 / LDC 1.31.0;
- macOS x86-64: DMD 2.112.1 / LDC 1.41.0;
- macOS ARM64: LDC 1.41.0.

The supported current-platform matrix passes on Linux x86-64, Linux ARM64,
Windows x86-64, macOS x86-64 and macOS ARM64. The experimental Windows ARM64
LDC job also passes for this release candidate.

## Package and documentation qualification

The release candidate passes:

- strict public-only DDox generation;
- one rendered compiler-checked Example for every inventoried public symbol
  page;
- documented internal production helpers required by the documentation policy;
- external API positive/negative compile contracts;
- retained-import link closure;
- a clean external consumer built from a `git archive` outside the repository
  checkout with baseline DMD and LDC.

The package metadata declares the MIT license and the repository contains the
corresponding license text.

## Scope boundary

The release deliberately excludes:

- image, colour and radiometric semantics owned by `imagery-d`;
- caller-visible scheduling or worker policy;
- GPU execution;
- AArch64/NEON performance qualification;
- performance promises for later compiler/frontend generations.

AArch64 functional correctness is release-qualified where covered by the
platform matrix; architecture-specific NEON performance work is deferred.

## Compatibility

`v0.1.0` is a pre-1.0 release. The 0.1 caller-visible source contract is
frozen for this release, but later pre-1.0 minor releases may intentionally
evolve the API under the workspace release policy.

## Remaining publication steps

Before publication:

1. promote the qualified `release/0.1` state to `main`;
2. require the full release gate on `main`;
3. create the annotated/signed `v0.1.0` tag from that qualified commit;
4. verify GitHub Release and stable/versioned documentation publication;
5. verify the published DUB package from a fresh external consumer.
