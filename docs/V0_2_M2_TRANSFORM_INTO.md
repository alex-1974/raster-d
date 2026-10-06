# raster-d v0.2 M2.1 — transformInto

Status: implementation candidate; representative reference-machine timing still required before #95 closes.

Baseline develop commit:

    e5b8039342d41af81bb7ab1ef4416e8064796874

Issue:

    #95 — M2.1 Generalize transformInto

## 1. Historical milestone naming

The tracked repository ROADMAP.md already uses M2 for the completed historical
fundamental-processing milestone and calls the existing point-transform slice
M2.2.

The v0.2 GitHub milestone reuses M2 for a new API-family phase (#95-#99).

This change therefore uses the explicit name "v0.2 M2.1" and does not reinterpret
or rewrite the historical milestone evidence.

## 2. Selected implementation step

The v0.2 API adds one free function:

    transformInto!transform(
        source,
        sourcePlaneIndex,
        destination,
        destinationPlaneIndex,
        error
    )

The semantic source is first, so UFCS is:

    source.transformInto!transform(
        sourcePlaneIndex,
        destination,
        destinationPlaneIndex,
        error
    )

The function delegates directly to the existing qualified
tryTransformRasterPlane!transform implementation.

No second transform kernel, dispatch family, alias checker or fallback path is
introduced.

## 3. Why plane indices remain in this first production slice

The M1.3 design selected RasterPlaneView and WritableRasterPlaneView as the
eventual ergonomic subjects.

Those types are not yet production code.

Creating a second implementation only to mimic the final spelling would violate
the implementation-sharing goal. Instead, the first v0.2 production form keeps
the existing explicit plane indices while exposing the final destination-oriented
verb.

A future plane-view overload can delegate to the same engine and remove the
index plumbing without invalidating this semantic contract.

## 4. Callable contract

The callable remains a compile-time alias.

It must be usable as:

    @safe pure nothrow @nogc T -> T

This preserves the existing optimizer-friendly and safety-qualified contract.

Runtime-selected/stateful transforms, cross-type transforms, string mixins and
mixin-template-generated API families are not introduced by #95.

## 5. Semantic contract

The new API inherits the existing point-transform contract exactly:

- same source/destination sample type T;
- equal logical source/destination shape;
- selected source/destination planes must exist;
- matching empty shapes succeed without invoking transform;
- destination mapping must be injective;
- actual source/destination sample-byte overlap is rejected before writing;
- every validated signed affine resident layout is supported;
- all structural failure occurs before the first destination write;
- no numeric conversion, clamping, saturation or image semantics;
- no allocation;
- no retained operand;
- no scheduling or hidden parallelism.

## 6. Compatibility

tryTransformRasterPlane remains exported and unchanged as the v0.1 compatibility
surface.

transformInto is additive.

The new function does not duplicate algorithm implementation; it is a semantic
API bridge to the existing engine.

## 7. Executable evidence

The new module tests:

- ordinary-call versus UFCS equality;
- contiguous semantic equality;
- signed row/sample-stride equality against the legacy API;
- inherited pre-write non-injective-destination failure behavior;
- root-package UFCS import.

Existing tryTransformRasterPlane tests and compile-negative probes continue to
qualify:

- POD samples;
- padded/interleaved/signed layouts;
- overlap rejection;
- empty behavior;
- invalid callable attributes;
- DMD/LDC trust and visibility boundaries.

## 8. Allocation

transformInto performs no allocation of its own.

The wrapper forwards arguments directly to the existing @safe nothrow @nogc
operation.

Any future allocating convenience belongs to #96 and must delegate to the same
semantic transform family.

## 9. Performance qualification

Existing reference-XPS evidence for the underlying engine is retained in
BENCHMARK.md.

The v0.1.0 padded float point-transform release baseline is:

    DMD 2.111   1.040911 ns/pixel
    LDC 1.41    0.202841 ns/pixel

These are reference-machine measurements, not portable guarantees.

#95 additionally requires evidence that the new public call surface adds no
material wrapper overhead.

benchmark/v0_2_transform_into therefore compares, in one fixed release binary:

    tryTransformRasterPlane!pointTransform
    source.transformInto!pointTransform

using the same 2048 x 512 padded float workload, checksums, compiler versions and
CPU-pinned multi-process style used by repository performance qualification.

GitHub-hosted CI is not treated as stable performance evidence.

## 10. #95 completion gate

Code/semantic gates:

- transformInto exported from root package;
- ordinary and UFCS forms compile;
- semantic/layout equivalence tests pass;
- DMD 2.111 and LDC 1.41 Fast CI pass;
- no new allocation or execution engine.

Performance gate:

- run benchmark/v0_2_transform_into/run_xps.sh on the reference XPS;
- retain DMD and LDC summaries plus archive checksum;
- confirm checksum equality;
- record the measured legacy/new ratio in BENCHMARK.md.

Until that measurement is recorded, #95 remains open.
