# ADR 0012: Generic Canonical fill executor

## Status

Accepted and implemented (Issue #56 / PR #57, merged 2026-10-01).

## Context

The public fill operation validates plane selection and then performs checked
writes per logical coordinate. Unlike point transform, fill accepts valid
non-injective mappings because repeated writes assign the same exact value.
Research Issue #17 compares the complete pinned public consumer with generic
pointer and safe row-slice candidates, preserving both production modules,
eight inherited tests and the Universal path. XPS evidence is recorded in
BENCHMARK.md and research head `97ed8a11d86b42464a55aa90d69b8b8f7b778b52`,
including variance and paired tradeoffs.

## Decision

After unchanged plane selection and empty handling, sample stride one selects
one generic Canonical executor in `raster.internal.fill_dispatch`. It constructs
a bounded row slice and assigns the supplied value through a safe D slice
assignment. Signed, zero/repeated and overlapping row strides remain legal;
no destination injectivity or noalias requirement is added. Other sample
strides retain the original checked per-coordinate traversal.

The existing package entry remains internal; no public signature, parameter
name, attribute, numeric conversion, error or ownership change is made. No
compiler/version selector, manual SIMD, worker thread or zero-stride logical
work shortcut is introduced. Neighbourhood and transform remain unchanged.

## Trust and attributes

Only `writeFillRow` is trusted. Validated retained writable backing guarantees
coordinate representation, signed stride products and reachable addresses for
all samples below width. The resulting slice is scoped to the original borrow.
`fillCanonical` and the public operation remain safe, nothrow and nogc. The
safe assignment receives the same exact T value, including POD representation,
NaN payloads and signed zero. No operand escapes or ownership claim is created.

The pointer alternative needs a trusted complete write loop. Slice substantially
improves every large paired DMD ubyte XPS case and usually matches DMD float.
LDC results vary: padded float Slice is 3.6–15.8% slower in the three qualified
runs. Accept that observed disadvantage for a single generic source form with
narrower trust and a consistent large DMD ubyte benefit. No claim that Slice
wins every compiler/layout comparison is made.

## Verification

Production adds an independent coordinate-to-storage oracle for 30 public
float/ubyte/eight-byte-POD cases: contiguous/padded/signed rows, repeated and
overlapping rows, sample steps +2/-2 and zero strides. All allocated samples,
padding and guards are compared. Fifteen special float cases compare bits for
positive/negative zero, an explicit NaN payload and infinities over distinct,
repeated and overlapping rows. Existing invalid/empty/interleaved tests remain.

External compile-only visibility probes first compile a public import control,
then reject the package entry and both private helpers through root/direct
internal imports. Actual-source positive controls instantiate safe/nothrow/nogc
execution for float, ubyte and POD; changing trusted row formation to safe must
fail for the intended pointer/index/slice reason. Fast/Release CI run both.
DMD 2.111 and LDC 1.41 production tests and these probes pass locally.

## Limits

The library has no research dependency. Six XPS processes pass 70 cases and
bitwise/invalid/empty checks with matching output hashes, but timing variation
is substantial. Repeated rows are repeated logical writes, not independent
memory bandwidth. Tiny timer-resolution cases qualify correctness; precise
portable speedup promises and CI timing thresholds are unsupported. AArch64
performance and future compiler-specific/parallel tuning remain unqualified.
