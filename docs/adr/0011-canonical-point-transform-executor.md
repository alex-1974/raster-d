# ADR 0011: Generic Canonical point-transform executor

## Status

Accepted for M3.2b implementation review (Issue #54).

## Context

After the checked affine bounds prefilter, the public point-transform traversal
still performs checked per-sample access. Research Issue #14 compares the pinned
production consumer against generic row/pointer and safe row-slice executors,
changing only execution after validation and relation checks. XPS qualification
at research head `e88443926f87dfd7c1068369bf9f5035bb6156e6` selects pointer:
all large paired DMD cases favor it, while LDC shows no stable material slice
advantage. BENCHMARK.md records provenance, ratios and substantial variance.

## Decision

Introduce `raster.internal.transform_dispatch` with a `package(raster)` entry
point. The public consumer calls it only after matching non-empty shapes,
retained backing, destination injectivity and physical disjointness have been
validated. Both sample strides must be one. Otherwise the entry returns false
before any access or transform invocation, retaining the original Universal
traversal. Signed row strides and padding require no separate executor.

The private generic pointer kernel forms each logical row and invokes the same
value expression for each sample. It does not introduce compiler capability
selection, manual SIMD, threading, persistent noalias or ownership claims.
The existing exact relation classifier and arithmetic-failure fallback remain
authoritative. Public exports, error ordering, empty/overlap handling and
neighbourhood execution remain unchanged.

## Trust and attributes

The pointer kernel is `@trusted pure nothrow @nogc`. Its complete bounded
read/write loop needs trust because indexed pointer access is not safe D.
Validated coordinate products and reachable sample addresses justify signed
row offsets and indices below width; pointers are scoped and do not escape.
The alternative safe row-slice loop has a smaller trusted pointer-formation
boundary but loses materially under DMD in the qualified consumer comparison.

A separate `@safe pure nothrow @nogc` value helper invokes the caller's alias.
This prevents the trusted kernel from admitting a system or impure transform.
The dispatch entry and public operation retain those same attributes. Floating
point expressions, NaN payloads and signed zero are not rewritten.

## Verification

Production adds 48 public layout cases across float, ubyte and an eight-byte
POD: both row signs independently, unit/double sample steps and both sample
signs. Full destination padding and source preservation are checked. Special
float identity checks compare bits, including NaN payload and negative zero.
A null-pointer Universal decline fixture proves no access or invocation.
Existing validation, overlap-before-write and sparse backing tests remain.

External compile-only probes use a positive public import control, then require
visibility rejection of entry and private helpers through root and direct
imports. Actual-source probes first compile the real kernel, then require
rejection when its trusted boundary is changed to safe, when the alias is
system, and when the alias is impure. Fast and Release CI run both probes.
DMD 2.111 and LDC 1.41 production unit tests and these probes pass locally.

## Consequences and limits

The production library has no research dependency and supports generic sample
values, rather than only measured scalar types. Correctness and portability
remain blocking; hosted-runner timings do not gate CI. XPS evidence supports
this executor choice but supplies neither exact portable speedup guarantees nor
AArch64 performance qualification. Other consumers and cross-type operations
require their own qualification.
