# raster-d 0.1 public API

This document defines the supported public API baseline being qualified for
`raster-d 0.1.0`.

The contract is not frozen until the 0.1 API audit is complete and the
`freeze/api-0.1.0` checkpoint is created. Until then, this document is the
working release contract.

## Aggregate import

~~~d
import raster;
~~~

`source/raster/package.d` is the intended supported aggregation surface for
0.1. The API audit must classify every root-exported declaration and verify
that package/internal implementation machinery remains inaccessible.

## Sample policy

`isRasterSampleType!T` defines the supported sample-type policy used by public
raster templates.

The 0.1 audit must document the exact accepted type family and whether this
trait itself is intended as stable public source API.

## Geometry and physical layout

Public geometry/layout types:

~~~text
Region2D
PlaneDescriptor
PlaneByteLayout
~~~

The 0.1 contract distinguishes:

- logical region coordinates;
- descriptor coordinate (0, 0);
- physical resource byte ranges;
- signed row stride;
- signed sample stride.

Signed strides are part of the represented layout. Internal execution-layout
classification is not public API.

## Resource ownership and import

Public ownership/import surface:

~~~text
OwnedByteResource
tryAdoptMallocResource

OwnedRasterResourceDisposition
OwnedRasterImportError
OwnedRasterImportResult
tryImportOwnedRaster
~~~

The release audit must make explicit:

- ownership transfer conditions;
- release behavior;
- failure disposition;
- whether a failed import leaves ownership with the caller or consumes it;
- byte-layout validation;
- alignment/sample-size requirements;
- multi-plane behavior;
- `.init` semantics.

## Retained raster lifetime

Public retained-view surface:

~~~text
RasterLease<T>
RasterView<T>
WritableRasterView<T>
~~~

A `RasterLease!T` retains the physical resources required by its validated
raster. Views borrow from the retained lifetime and must not outlive the lease
or other required owner.

The API audit must freeze the exact construction/access patterns and lifetime
attributes exposed to consumers.

Mutable raw execution pointers, execution-layout classification, internal
targets and Mir adapters remain implementation details.

## Strict reduction

~~~d
bool trySumFloatToDouble(
    scope const RasterView!float source,
    size_t sourcePlane,
    out double sum);
~~~

The accepted numerical contract is strict logical row-major accumulation into
one `double` accumulator.

Compiler-specific Canonical execution is internal and does not change that
semantic graph.

## Fill

~~~text
tryFillRasterPlane
~~~

Fill writes one selected destination plane over its logical region using the
provided sample value.

The 0.1 contract must state empty-region behavior, writable/injective backing
requirements, failure behavior and allocation policy.

## Point transform

~~~text
RasterTransformError
tryTransformRasterPlane!transform
~~~

The transform is selected at compile time and applied pointwise from one source
plane to one destination plane.

The audit must freeze the callable contract for `transform`, error categories,
overlap policy, no-write behavior and attributes.

## 3x3 neighbourhood

~~~text
RasterNeighbourhood3x3Error
tryApplyRasterNeighbourhood3x3!kernel
~~~

The public operation evaluates a compile-time 3x3 kernel over a caller-selected
source/output region and writes one destination plane.

The audit must document neighbourhood ordering, required source context,
destination geometry, overlap/alias semantics, failure behavior and absence of
hidden scheduling/threading.

## Same-type copy

~~~text
RasterCopyError
tryCopyRasterPlane
~~~

Copy preserves logical sample values between selected planes and supports the
qualified public overlap semantics.

Fast memcpy, row-slice, affine-prefilter and Universal execution choices are
private implementation details.

## Exact ubyte-to-float conversion

~~~text
UbyteToFloatConversionError
tryConvertUbyteToFloatPlane
~~~

Each `ubyte` source sample is converted exactly to its corresponding
`float` value.

The public result is independent of the internal compiler-specific x86-64
execution path. DMD SSE2 and LDC negative-source optimizer boundaries are
implementation details qualified by ADR 0014.

## Deliberately non-public execution machinery

The supported 0.1 contract excludes implementation-only facilities including:

- internal execution-layout classifiers;
- mutable raw execution pointers;
- Mir adapters;
- checked affine relation helpers;
- checked-wide address arithmetic;
- residency stores and block-resolution orchestration;
- internal transform/fill/neighbourhood/conversion dispatch;
- compiler-specific SIMD helpers;
- scheduler/worker/parallel-execution policy.

The API audit must verify that these remain inaccessible through
`import raster;` and through direct external imports where package/private
protection is intended.

## Performance and scheduling policy

The 0.1 public API does not expose compiler, ISA, worker-count, SMT, affinity,
cache replacement or scheduler policy.

Qualified DMD/LDC/x86-64 execution strategies are private implementation
choices recorded in ADRs and BENCHMARK.md.

No hidden parallel execution is part of the 0.1 contract.

## Compatibility baseline

When `freeze/api-0.1.0` is created, the audited source contract will include,
where applicable:

- public names;
- signatures and overload shapes;
- argument order;
- public parameter names used by named arguments;
- template constraints;
- aggregate `import raster;` exports;
- `.init` semantics;
- ownership/lifetime behavior;
- error enums and checked failure channels;
- documented allocation and no-write guarantees;
- documented numerical semantics.

Any later breaking change to that frozen baseline requires an explicit
compatibility/versioning decision.

## Verification

The release documentation gate will compile consumer examples through
`import raster;`, generate public-only DDox, verify the per-symbol example
inventory, check public module Ddoc, audit internal function Ddoc and inspect
the generated documentation site.

The final API-freeze tag is created only after those checks and the human API
review pass.
