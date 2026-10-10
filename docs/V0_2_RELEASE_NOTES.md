# raster-d v0.2.0 release notes — candidate

**Status: DRAFT / NOT PUBLISHED.** This text describes the frozen v0.2
release candidate. Do not present it as an actual GitHub Release or a
published DUB package until the final content gate, tag, publication,
and post-publication verification have passed.

## Overview

v0.2 extends the original generic raster-core library with a broader
checked operation family while preserving its independent raster domain.
A raster is a grid of sampled values such as heights, temperatures,
measurements or image samples. The library supplies layout, region,
ownership, borrowing and numerical processing primitives without
requiring image colour semantics or built-in task scheduling.

The supported consumer import remains:

~~~d
import raster;
~~~

## Public API and compatibility

The frozen v0.2 public contract is described in
[`docs/API_0_2.md`](API_0_2.md). The feature and API checkpoints are
`freeze/feature-0.2.0` and `freeze/api-0.2.0`.

Compared to the frozen v0.1 API, all 23 v0.1 root exports remain and
v0.2 adds 43 root exports. Existing compatibility entry points remain
available alongside the newer generic and destination-oriented forms.
The new release does not silently guarantee direct imports of
implementation submodules outside the supported `import raster;` surface.

### Processing families

- Checked reduction families: typed sum, minima, maxima and mean.
- Destination-oriented fill, copy, point transforms, binary arithmetic,
  generic conversion and associated result/error contracts.
- Allocating conversion and transform entry points with explicit
  caller-visible results.
- General neighbourhood execution and compile-time fixed floating
  convolution kernels, with explicit resident-halo requirements.
- Explicit border-policy vocabulary; fixed convolution does not silently
  synthesize missing edge samples.

### Ownership and layouts

`RasterLease` retains owned backing resources; read-only and writable
views borrow that retained lifetime. Writable access is not a promise
of exclusive storage, absence of aliases or thread synchronization.
Plane byte-layout strides must not be confused with internal
element-stride representations.

## Performance qualification

The completed M5 evidence and benchmark contracts are documented in
the repository's performance records, including `BENCHMARK.md`.
Execution strategies are implementation details, not public
compiler, ISA or kernel selectors. No new source-facing performance
numbers are claimed by these notes.

## Documentation

The v0.2 documentation includes an introduction for readers new to
raster data, a getting-started tutorial, and how-to guides for
zero-copy regions, checked sums, exact numeric conversion and
neighbourhood/halo processing.

The public DDox example audit inventories 97 symbol pages. This count
describes the audited generated surface, not the number of root exports.
The strict documentation workflow compiles documented examples,
checks public-only generated pages and builds a versioned site.

## Release qualification evidence (2026-10-10)

All results below apply to candidate commit
`3a2dd4e8acb102cf85a6770947471022ba38c625`:

| Gate | Result | GitHub Actions run |
| --- | --- | --- |
| Compiler generation | 6/6 PASS | [38054572790](https://github.com/alex-1974/raster-d/actions/runs/38054572790) |
| Platform matrix | 9/9 PASS | [38054572790](https://github.com/alex-1974/raster-d/actions/runs/38054572790) |
| Compiler floor | 8/8 PASS | [38055319067](https://github.com/alex-1974/raster-d/actions/runs/38055319067) |
| External archive consumers | 2/2 PASS | [38055321548](https://github.com/alex-1974/raster-d/actions/runs/38055321548) |

The experimental Windows ARM64/LDC matrix job passed; this does not
silently change the supported-platform contract.

A later exact-release-branch documentation checkpoint at
`a8b09687c52f8004f9a0eb509c1b8b9e31c9bf03` completed
[Release Documentation run 38068884101](https://github.com/alex-1974/raster-d/actions/runs/38068884101):
strict public-only DDox plus compiled DMD 2.111.0/LDC 1.41.0 examples,
all PASS. The DDox ZIP (`11675448689`) and staged versioned Pages ZIP
(`11675748317`) were downloaded and independently inspected; their
public-only page inventories and stable-root byte comparisons passed.

Subsequent documentation-only PRs advanced `release/0.2` beyond that
checkpoint; the artifact does **not** qualify a newer final SHA or prove live
Pages deployment. Any final content sign-off must be repeated on the actual
candidate being promoted.

## Release blockers still open

The tutorial/how-to/glossary/accuracy source-level editorial cross-check is
complete in [issue #198](https://github.com/alex-1974/raster-d/issues/198),
including the IEEE exceptional-value correction to the identity-style
convolution guide in PR #239. This does not independently verify browser
rendering or all public declaration comments.

Do not publish v0.2.0 until the full public Ddoc editorial audit,
live published Pages behavior, and exact-head final release-content gate
are complete. After publication,
verify GitHub Release, stable/versioned docs and DUB, then reconcile
release-only corrections back to `develop`.

The final release date, immutable release tag SHA, published URLs and
post-publication status must be recorded only when verified. See
[release issue #198](https://github.com/alex-1974/raster-d/issues/198)
for the release decision.
