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
