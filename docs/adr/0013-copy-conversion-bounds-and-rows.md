# ADR 0013: Checked copy/conversion bounds and approved row execution

## Status

Accepted for M3.5 implementation review (Issue #60).

## Context

Complete public Copy and exact ubyte-to-float conversion spend substantial time
in exact affine relation scans and checked per-sample traversal outside the
existing flat-copy route. Research PR #23 independently compares bounds-only,
execution-only and combined complete consumers against production 1671fb2.
Reference XPS evidence at research head
`9b3e709111364276d1f7383b6f14326327f6f21f` confirms the large directional
benefit; its collector source is pinned at 85e1614. BENCHMARK.md records the
full scope, remaining execution gaps and high short-Copy spread.

## Decision

Copy delegates its operation-local physical relation to the existing checked
same-type bounds wrapper. Conversion adds a package-internal one-/four-byte
wrapper using the same checked envelope arithmetic. Only provably disjoint
envelopes return early. Overlapping or unrepresentable envelopes invoke the
original exact classifier, including arithmeticFailure; operation-local
pairwise defensive fallbacks remain unchanged. No pointer is accessed in the
bounds layer and no persistent noalias capability is introduced.

After unchanged plane/shape/empty, injectivity and exact sample-byte relation
checks, unit sample strides select safe scoped row execution. Same-type Copy
uses slice assignment; ubyte-to-float conversion uses exact numeric casts in a
safe row loop. Signed and repeated source rows remain legal. Other sample
strides retain the checked semantic traversal. Existing checked flat-copy
memcpy is unchanged; already-approved flat conversion uses the same row loop.
Legacy internal contiguous conversion primitives are retained.

## Safety and compatibility

Only readApprovedRow/writeApprovedRow pointer arithmetic and bounded slice
formation are trusted. Validated retained geometry bounds signed row products
and reachable width-sample rows. Global sample-byte disjointness and destination
injectivity have been resolved before entry; source may self-alias. Row borrows
remain local and do not escape. Assignments/conversion execute under
safe/pure/nothrow/nogc. The public operation retains its original safe/nothrow/
nogc attributes, signatures, parameter names, error ordering, empty and no-write
semantics. Copy sample constraints still include plain POD static arrays.

The production helpers are private to their operation modules. Actual-source
controls instantiate ubyte, float, eight-byte POD, static-array Copy and exact
conversion; removing row trust must fail for pointer/slice formation on both
compilers. External imports reject all helpers and the cross-type wrapper.
These compiler challenges supplement, rather than replace, the safety proof.

## Verification and limitations

Both DMD/LDC pass the existing 41 unittest modules, including inherited
operation tests. Both full dispatch modules match the qualified Combined
source token-for-token after normalizing internal/module names, comments and
whitespace. Public modules remain unchanged.
The bounds module adds an independent 5,000-case cross-type byte oracle,
integer-limit/exact-original comparisons and CTFE control, alongside the
existing 5,000-case same-type oracle. The integration runner sets up validated
package-local fixtures, then calls the public API for 120 independent full
backing cases (four Copy sample types plus exact conversion, eight layouts,
three sizes). It preserves float bits, all-256 byte conversion, source/target
padding and guards; shared sparse and Canonical backing with overlapping
envelopes forces exact fallback before execution. Invalid/error order, shape,
non-injectivity, actual overlap/no-write and null/extreme-stride empty controls
remain. Fast and Release CI run public backing, visibility and trust checks.

This promotes an intermediate improvement, not family-wide C++ parity.
C++ reference omits validation and adds a separate ABI call. XPS DMD padded
conversion remains 3.953–4.065x slower; signed negative-both LDC remains
1.542–1.848x slower. Research Issue #22 continues actual public codegen and
controlled candidate work. Short Copy timings are noisy; no small Flat-Copy
speedup/regression is inferred. Production tests validate the transferred
implementation; XPS times belong to the pinned complete research candidates,
not a new measurement of the final production binary.

No compiler/version specialization, manual SIMD, fast-math, contraction,
threading, API expansion or AArch64 performance claim is introduced. The
standalone checkout has no .workspace hardlinks; supplied canonical policy and
tracked repository documents provide the engineering context.
