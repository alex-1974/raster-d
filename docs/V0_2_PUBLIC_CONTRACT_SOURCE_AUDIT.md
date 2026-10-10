# v0.2 public-contract source cross-check (partial editorial audit)

**Status:** Source-level checkpoint; **not** final Ddoc/DDox or release sign-off.
**Reviewed:** 2026-10-10, on the `release/0.2` line following PR #230
(`12ce83d5c3448d95e7bbb3534b4d5d69bc475cc4`).
**Scope:** compare documented public contracts to the corresponding
production source declarations and Ddoc. No API or implementation changes
are proposed by this review.

## Checked correspondence

| Public claim | Source inspected | Finding |
| --- | --- | --- |
| Supported aggregate `import raster;` and root exports | `source/raster/package.d` | Explicit public imports provide the audited root surface. Implementation modules remain separate. |
| `RasterLease` retains backing; views only borrow it | `source/raster/backing.d`, `source/raster/view.d` | Module and lease Ddoc distinguish retained backing from non-owning views. |
| Lease ownership reference count is not atomic | `source/raster/backing.d` | Control-block documentation explicitly identifies non-atomic shared ownership; concurrent handle mutation is not promised. |
| Writable permission does not imply exclusivity or alias freedom | `source/raster/writable_view.d` | Public module Ddoc expressly excludes uniqueness, non-aliasing and thread exclusivity. |
| External `PlaneByteLayout` strides are **bytes** | `source/raster/byte_layout.d` | Public fields are `rowStrideBytes` and `sampleStrideBytes`; validated internal descriptors use element strides. |
| Strict generic sum has checked overflow and an unsuccessful default result | `source/raster/reduction.d` | `RasterSumError.accumulatorOverflow` is public; `RasterSumResult` initializes with `invalidPlane` and `ok == false`. |
| Root contract states borrowed lifetime, numerical order and no hidden scheduling | `docs/API_0_2.md` | The source-owned concepts above are represented in the frozen contract; this is a targeted cross-check, **not** comprehensive behavioral validation. |
| Copy rejects actual source/destination byte overlap before writes | `source/raster/copy.d` | Public Ddoc explicitly rejects overlap, identifies `sourceDestinationOverlap`, and excludes snapshot/memmove semantics. |
| Generic exact conversion has only structural failure channels | `source/raster/conversion.d` | `RasterConversionError` declares structural failures; public Ddoc states no per-sample numerical failure for `exact`. |
| Generic neighbourhood requires resident halo | `source/raster/neighbourhood_into.d` | `RasterNeighbourhoodError.unsatisfiedNeighbourhood` is exposed; Ddoc places structural checks before writes. |



The root contract and the reviewed Ddoc contain no contradiction in
these *selected* areas. The public documentation remains the caller-facing
specification; source comments do not by themselves constitute runtime
qualification. Existing compiler, safety and archive-consumer gates are
separate evidence.

## Limits and next required checks

- This is **not** a line-by-line audit of all public declarations, all
  output/error paths, or the 97 rendered symbol examples.
- Verify selected representative public methods and reduction/conversion/
  neighbourhood implementations against actual tests and generated pages.
- Rebuild and independently inspect the **final release-head** DDox artifact,
  including links, public-only navigation and representative rendered prose.
- Independently confirm live Pages URL, current/stable navigation and version
  aliases. CI verification of staged output is not a live Pages check.
- Repeat the full content gate on the exact SHA immediately before promotion;
  document findings in issue #198. Until then the associated checkboxes remain
  open.

Related evidence:
[API inventory](API_0_2.md),
[DDox qualification](V0_2_DDOX_QUALIFICATION.md),
[rendered artifact inspection](V0_2_RENDERED_DDOX_AUDIT.md),
[release issue #198](https://github.com/alex-1974/raster-d/issues/198).


## Follow-up source cross-check: reductions and allocating families

**Reviewed:** 2026-10-10; baseline `release/0.2` at
`aaf32ba0eb42dea9ec010e1807a1a12c91e3a18a` (PR #231).
**Scope:** source/Ddoc correspondence only; no new runtime or rendered-DDox
qualification is claimed by this follow-up.

| Frozen public claim | Implementation and test evidence inspected | Finding |
| --- | --- | --- |
| `mean` uses the selected `sum!Accumulator` result and checks count before reduction | `source/raster/reduction.d`: `isSupportedRasterMeanTriple`, `mean`, and `RasterMeanResult` | Exact supported triples are constrained at compile time. The implementation checks invalid plane, empty input and `size_t` count overflow before `sum`, maps sum overflow, then casts numerator/count to the declared result type and divides. Failed results have `ok == false` and value +0. |
| `min`/`max`/`minMax` propagate any NaN and select signed-zero extrema independent of encounter order | `source/raster/reduction.d` public wrappers and `source/raster/internal/extrema.d` `executeExtrema` | NaN returns a successful NaN result. For equal zero comparisons, `signbit` selects -0 for minimum and +0 for maximum. `minMax` uses the same single-pass mechanism. Invalid plane and valid empty input remain distinct failures. |
| Unary point transform checks structure and overlap before writing | `source/raster/transform.d` `tryTransformRasterPlane` | Plane selection, shape, empty case, injective destination and physical sample-overlap tests precede canonical dispatch and fallback writes; the callback's `@safe pure nothrow @nogc` callability is checked by instantiation. |
| Zip transform allows input/input overlap but rejects input/destination overlap | `source/raster/zip_transform_into.d` public declaration and validation prefix | The two read-only inputs are allowed to alias each other; destination must be injective and disjoint from both input sample sets. This check is a source-contract correspondence, not a new exhaustive alias stress test. |
| Arithmetic wrappers have distinct integer modulo and floating IEEE semantics | `source/raster/arithmetic_into.d` | Add/subtract/multiply explicitly cast integer results to T modulo 2^N; integer `divideInto` is not provided. Floating divide uses ordinary T arithmetic. Wrappers delegate execution to the zip family. |
| Allocating transform and conversion produce independent compact retained leases, not another execution kernel | `source/raster/transform_allocated.d`, `source/raster/conversion_allocated.d` | Both check source selection, allocate a compact retained destination, obtain writable access, invoke the existing Into operation and move the completed lease into the result. Failed result carriers retain a failing `.init`; `lease()` returns an inert lease on failure. |
| Convolution uses fixed compile-time coefficients and declared accumulation | `source/raster/convolution.d` `FixedConvolutionKernel`, `evaluateFixedConvolution`, `convolveInto` and local unittests | Coefficients/shape are compile-time values; term order is row-major; accumulator/output combinations are constrained; one final cast to T is visible; spatial execution delegates to `applyNeighbourhoodInto`. This does not newly qualify every floating rounding mode or hardware backend. |
| Border types describe policies but do not enable sample synthesis | `source/raster/border_policy.d` and `source/raster/convolution.d` | Policy kinds and zero-extent restrictions are documented; valid resident halo remains the only execution behavior of v0.2 neighbourhood/convolution APIs. |

**Limits:** This follow-up does not certify all negative compilation probes,
all error branches at runtime, generated example semantics, final-head DDox,
live Pages, or release readiness. A passing historical PR workflow does not
substitute for exact-final-SHA release qualification. Keep issue #198 release
and Ddoc/DDox checkboxes open until the required independent gates pass.


## Follow-up: region, layout, writable view and border Ddoc

**Reviewed:** 2026-10-10, starting from `release/0.2` at
`7a1da109e11bd401b2e5263b5ef200195370d47a`.
This is a focused read of public declarations, their Ddoc and corresponding
source logic, not a newly executed test or complete Ddoc sign-off.

| Caller-visible contract | Inspected source | Finding |
| --- | --- | --- |
| A `Region2D` child is relative to the parent; `containsRelative` handles subtraction-based bounds without width addition overflow | `source/raster/region.d`: `containsRelative` | Ddoc and checked comparisons agree; empty regions remain representable. |
| `tryResolveRelative` resets its `out` value on failure and checks translated-origin overflow | `source/raster/region.d`: `tryResolveRelative` | The implementation initializes `resolved = Region2D.init`, validates containment, then guards origin additions. |
| `PlaneDescriptor` strides are signed **elements**, not external bytes | `source/raster/descriptor.d` | Ddoc and fields (`rowStrideElements`, `sampleStrideElements`) agree, distinct from `PlaneByteLayout` byte strides. |
| A writable view is not an exclusive or no-alias capability | `source/raster/writable_view.d` public module Ddoc and inspection helpers | Wording explicitly excludes uniqueness, thread exclusivity and implicit mutation permission from read-only access. |
| Exposed stride information is in signed sample elements; invalid requests reset both stride outputs | `source/raster/writable_view.d`: `tryExecutionPlaneStrides` | Ddoc and assignments agree. This helper is package-internal execution plumbing and is **not** a new root-export promise. |
| Border policy types are semantic vocabulary; mirror is edge-inclusive, wrap uses Euclidean modulo and both need nonzero extent | `source/raster/border_policy.d` | Public type descriptions agree with the frozen `docs/API_0_2.md` wording. Their existence does not prove any border-synthesis executor. |

No contradiction was found in these inspected source/Ddoc pairs. In
particular, this check does not promote implementation-only helpers into the
public compatibility surface.

**Remaining limits:** not every public Ddoc comment or all 97 rendered Example
bodies was editorially read; this does not establish live Pages behavior or
the release content gate. Other module families, edge-case claims and complete
rendered prose still require coverage before checking off issue #198.
