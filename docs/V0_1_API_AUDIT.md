# raster-d v0.1.0 public API audit

Status: **IN PROGRESS**

Baseline branch:

```text
release/0.1
```

Feature-freeze checkpoint:

```text
freeze/feature-0.1.0
d8cbcb270d24a344f59c4a7f1880848add38c975
```

This audit qualifies the caller-visible source contract before the immutable
`freeze/api-0.1.0` checkpoint is created.

## A1 — supported import surface

The supported aggregate consumer entry point is:

```d
import raster;
```

Root exports are limited to:

- `isRasterSampleType`;
- `Region2D`;
- `PlaneDescriptor`;
- `PlaneByteLayout`;
- `OwnedByteResource`;
- `tryAdoptMallocResource`;
- `OwnedRasterResourceDisposition`;
- `OwnedRasterImportError`;
- `OwnedRasterImportResult`;
- `tryImportOwnedRaster`;
- `RasterLease`;
- `RasterView`;
- `WritableRasterView`;
- `trySumFloatToDouble`;
- `tryFillRasterPlane`;
- `RasterTransformError`;
- `tryTransformRasterPlane`;
- `RasterNeighbourhood3x3Error`;
- `tryApplyRasterNeighbourhood3x3`;
- `RasterCopyError`;
- `tryCopyRasterPlane`;
- `UbyteToFloatConversionError`;
- `tryConvertUbyteToFloatPlane`.

Directly importable infrastructure modules may exist as implementation files,
but their construction/resource/validation/execution declarations are
`package(raster)` or private and are not part of the external source API.

Automated negative probes cover:

- `raster.resource`;
- `raster.validation`;
- `raster.construction`;
- `raster.import_single_resource`;
- `raster.internal.execution_layout`;
- raw read/write view factories;
- `RasterBacking`.

Status: pending CI confirmation.

## A2 — sample/template constraints

Public sample-bearing types and generic operations use the shared
`isRasterSampleType!T` representation policy.

Accepted examples include primitive numeric values, static arrays of supported
values and POD structs without indirections.

Rejected examples include:

- pointers;
- dynamic arrays;
- qualified sample types;
- types with indirections;
- non-POD ownership/destruction semantics.

The release API probe instantiates public types with supported and rejected
representatives.

Status: pending CI confirmation.

## A3 — names and argument order

The 0.1 operation family uses source-before-destination ordering where both
exist.

Frozen operation parameter names are:

```text
trySumFloatToDouble:
    source, planeIndex, result

tryFillRasterPlane:
    destination, planeIndex, value

tryTransformRasterPlane:
    source, sourcePlaneIndex,
    destination, destinationPlaneIndex,
    error

tryApplyRasterNeighbourhood3x3:
    source, sourcePlaneIndex, sourceOutputRegion,
    destination, destinationPlaneIndex,
    error

tryCopyRasterPlane:
    source, sourcePlaneIndex,
    destination, destinationPlaneIndex,
    error

tryConvertUbyteToFloatPlane:
    source, sourcePlaneIndex,
    destination, destinationPlaneIndex,
    error

tryAdoptMallocResource:
    base, byteLength, owned

tryImportOwnedRaster:
    resource, planes, residentRegion, lease
```

Retained/view parameter names are likewise source-compatible where the baseline
compiler accepts D named arguments.

Status: pending compiler gate.

## A4 — default state

Accepted `.init` contracts:

- `Region2D.init` is empty and has representable extent;
- public operation error enums use `.none` as `.init`;
- `OwnedRasterResourceDisposition.init` is `.unchanged`;
- `OwnedRasterImportResult.init` is deliberately failure, with
  `internalConstructionFailure`, `size_t.max`, and unchanged ownership;
- `OwnedByteResource.init` owns no resource and has byte length zero;
- `RasterView!T.init` and `WritableRasterView!T.init` are inert empty
  semantic capabilities;
- `RasterLease!T.init` must be a valid inert lifetime capability. Its
  fallible writable borrow fails cleanly. The API audit explicitly probes
  whether its read-only `view()` also yields `RasterView!T.init`.

Status: pending runtime gate.

## A5 — ownership and lifetime

`OwnedByteResource` is move-only and owns one release obligation.

`tryAdoptMallocResource` is `@system nothrow @nogc` because free-compatible
allocation ownership cannot be proven in safe code.

`tryImportOwnedRaster` is the public ownership transfer boundary. Pre-commit
failure preserves the source ownership token and leaves the destination lease
unchanged; successful import transfers ownership to the lease.

`RasterLease!T` is copyable retained ownership. `RasterView!T` and
`WritableRasterView!T` are lease-bound non-owning capabilities whose
DIP1000 borrows must not escape their owner.

A const lease must not recover writable capability.

Status: existing negative lifetime probes plus release API CI.

## A6 — failure and mutation

Checked read operations reset `out` values to their documented defaults on
failure.

Copy, transform and exact conversion perform structural/overlap validation
before the first destination write.

Neighbourhood performs structural/halo/overlap checks before the first
destination write.

Fill is intentionally different: every validated layout is semantically
supported, including non-injective mappings, because repeated writes of one
identical value are idempotent. Its only public false result is invalid plane
selection.

Status: covered by existing package tests; frozen wording reconciled with
Ddoc/API.md during sign-off.

## A7 — attributes and CTFE

The external positive API probe compiles ordinary operations from
`@safe nothrow @nogc` code where those attributes are part of the public
contract.

Region geometry is additionally required to remain `pure` and CTFE-capable.

Raw malloc adoption remains intentionally `@system`.

Owned import is `@safe` but is not promoted to a stronger `nothrow/@nogc`
contract without separate evidence because retained construction owns
allocation/resource-management work.

Status: pending DMD/LDC compile gate.

## A8 — numerical semantics

Frozen 0.1 numerical contracts include:

- exact sample-preserving same-type Copy;
- exact `ubyte -> float` conversion for all 256 source values;
- strict logical row-major `float -> double` reduction with one accumulator;
- point transform returns exactly the caller transform's `T` result for each
  logical source sample;
- 3x3 kernel receives nine source values in row-major order with center at
  index 4.

Compiler/ISA-specific execution remains private and may not change these
observable semantics.

Status: previously qualified by M2/M3 tests and release documentation.

## A9 — release blockers discovered by this audit

Pending automated API-gate results.

Any caller-visible correction discovered here is allowed on `release/0.1`
because the feature freeze permits API corrections exposed by the release
audit. No `freeze/api-0.1.0` tag exists yet.

## Completion criteria

The audit is complete only when:

- DMD 2.111 and LDC 1.41 pass the external positive API package;
- all unsupported direct/internal surfaces are compiler-rejected externally;
- ownership/lifetime negative probes pass;
- external retained-import link closure passes;
- supported template instantiations and rejected sample types are verified;
- default-state runtime probes pass;
- names/signatures/attributes are reconciled with source Ddoc and
  `docs/API.md`;
- all release-blocking API defects are resolved;
- the final API contract is recorded before creating `freeze/api-0.1.0`.
