# ADR 0010: Checked affine bounds prefilter for validated consumers

## Status

Accepted (M3.2a, Issue #52).

## Context

The exact finite affine sample-byte classifier remains the authority for shared
backing and signed/sample-strided layouts. Relation classification can dominate
otherwise inexpensive transform and neighbourhood execution when distinct
allocations or regions have provably disjoint physical bounds.

Research Issue #15 qualified a checked conservative envelope test independently
of executor changes: bounded byte enumeration, integer/address-limit fixtures,
relation measurements, then actual pinned production consumer A/B measurements.
Three independent XPS processes per DMD 2.111 and LDC 1.41 passed complete output
and padding checks. Provenance and measured scope are recorded in BENCHMARK.md;
the accepted research head is `59dcdbb8098e070f3ae2d8c75c8de1a766889f0e`.

## Decision

Add `raster.internal.validated_affine_relation` with two `package(raster)`
wrappers for equal and differently shaped same-type rectangles. Only point
transform and 3x3 neighbourhood use them in this slice. Rectangles originate
from each consumer's existing validated view geometry; bases identify logical
(0,0), and strides count sample elements. The neighbourhood rectangle includes
all required halo samples, not merely its output centers.

The private bounds calculation checks axis coordinate multiplication, signed
axis-offset addition, offset-to-byte multiplication, base plus/minus offset and
the upper half-open sample end. It handles `ptrdiff_t.min` without negating it.
It neither dereferences pointers nor allocates; it remains `@safe pure nothrow
@nogc` and requires no compiler capability or unchecked arithmetic shortcut.

Only two representable disjoint half-open bounds return `disjoint` early.
Overlapping envelopes are inconclusive: sparse interleaved bytes can still be
disjoint. Unrepresentable bounds are likewise inconclusive. Both cases invoke
the unchanged exact classifier with the original arguments. Its result,
including `arithmeticFailure`, is returned unchanged, preserving each consumer's
existing exact enumeration fallback. Empty rectangles preserve zero-work
semantics; a non-empty zero sample size still reaches the exact error result.

## Contract preservation

No public exports, error ordering, injectivity checks, write capability,
executor selection, kernel expression or floating-point behavior changes.
A successful invocation-local disjointness proof creates no persistent noalias,
exclusive ownership or allocation-identity claim. The production package does
not depend on the research repository.

## Verification

Production unit tests add 12 architecture-neutral integer-limit fixtures and
5,000 deterministic bounded cases checked against an independent signed
byte-distance oracle and the exact classifier, including symmetry and coverage
of both prefilter and fallback. Sparse shared-backing consumer tests cover
transform and the complete neighbourhood halo. Existing overlap-before-write,
layout, empty and failure tests remain in force.

Compile-only external probes first compile a supported public import, then
require visibility/name rejection of both wrapper symbols and private bounds
machinery through root and direct internal imports. Fast and Release CI run
these probes without interpreting undefined-symbol link failures as success.

## Deferred scope

Copy and cross-type relations retain their existing implementation. No Canonical
transform executor, SIMD, threading, compiler workaround or compiler floor
change is admitted here. XPS timing evidence does not qualify AArch64 performance
or impose a portable timing threshold.
