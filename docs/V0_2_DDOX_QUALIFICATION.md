# v0.2 public Ddoc/DDox qualification status

**Status: in progress.** This is a checkpoint of the *existing* strict
documentation infrastructure, not a sign-off on the final release.

## Established checks

The release documentation workflow (`.github/workflows/release-docs.yml`)
runs the following against the PR/release source:

- `tools/validate-docs.sh`: required documentation, package metadata,
  frozen API symbols and candidate status consistency;
- `tools/build-docs.sh` with `VERIFY_CONTRACTS=1` and
  `INVENTORY_ONLY=0`: DMD-generated public-only DDox documentation,
  public module Ddoc structure, internal documentation checks,
  the complete symbol-page Example audit and a generated versioned site;
- compiler-checked documented examples under DMD 2.111.0 and LDC 1.41.0.

The per-symbol inventory is maintained in
[`public-api-example-audit.md`](public-api-example-audit.md).
The v0.2 frozen export contract is in [`API_0_2.md`](API_0_2.md).

These gates protect compiled examples and generated public coverage.
They do **not** establish that the documentation is understandable,
that the generated website has been visually inspected, or that the
published Pages/stable redirects are correct.

The [rendered DDox artifact inspection](V0_2_RENDERED_DDOX_AUDIT.md)
records independently downloaded and inspected PR-head outputs. Later
exact-release-branch evidence is recorded in issue #198. These are distinct
qualification events; none is a final-publication sign-off.

The [scoped public-contract source cross-check](V0_2_PUBLIC_CONTRACT_SOURCE_AUDIT.md)
records which source modules and caller-visible claims were inspected.
It is partial editorial evidence, not a final sign-off.

## Required remaining review

Before checking off the Ddoc/DDox items in issue #198, on the exact
release-candidate head:

1. Record the commit SHA and full Release Documentation workflow run
   with all constituent jobs passing.
2. Inspect the generated DDox artifact and module navigation,
   including public symbol-page examples and absence of internal modules.
3. Cross-check public contracts for ownership, borrowed lifetime,
   writable aliasing, layout/stride units, failure/no-write behavior
   and numerical order against the frozen API and the actual source.
4. Confirm Getting Started, How-to, Glossary and Accuracy guides
   make no unsupported claims and link to their real API pages.
5. Inspect versioned GitHub Pages output independently from the source
   build, then repeat the final release-content gate immediately before
   promotion and after publication.

A new candidate SHA invalidates earlier exact-head sign-off and requires
requalification. Do not mark the release checklist complete from a
historical passing PR alone.


## Independently inspectable staged Pages artifact

The Release Documentation workflow additionally uploads the complete staged
versioned site as `raster-pages-release-candidate` alongside the public-only
`raster-ddox-release-candidate` artifact. This makes the exact output of
`tools/build-versioned-docs.sh` inspectable without confusing a local
staging check with deployed GitHub Pages.

On the **exact candidate SHA**, retrieve and inspect both workflow artifacts.
Check the stable root against the latest published tagged version, the
`dev/raster.html` candidate, `versions.html` links and published tagged
subdirectories. Record artifact IDs, inspected SHA, counts and link results
in issue #198. An artifact produced from a PR head does not replace
qualification on the post-merge release-candidate commit. A staged Pages
artifact never establishes public HTTP/deployment success.


## Exact release-line build and editorial checkpoint (2026-10-10)

At release-line SHA `a8b09687c52f8004f9a0eb509c1b8b9e31c9bf03`,
[Release Documentation run 38068884101](https://github.com/alex-1974/raster-d/actions/runs/38068884101)
completed all three jobs: strict public DDox, compiled documented examples
(DMD 2.111.0), and compiled documented examples (LDC 1.41.0). The downloaded
DDox ZIP (artifact `11675448689`) had 97 symbol Example pages and no
unresolved relative links or literal internal-module references. The
versioned Pages staging ZIP (`11675748317`) had 89 stable-tagged files
byte-identical to the root counterparts and no broken relative links.
Both artifacts were inspected separately from the CI result; their
provenance is retained in issue #198.

### Editorial cross-check completed so far

The following source-level guides were read and compared with
`docs/API_0_2.md` and the named production entry points. The scope is
editorial correspondence, not a new runtime or browser test.

| Consumer document | Claims cross-checked | Finding |
| --- | --- | --- |
| `docs/understanding-rasters.md` and `docs/tutorial/getting-started.md` | Lease-owned storage, borrowed views, byte-oriented plane layouts, no image-domain semantics | No contradictory statement found in reviewed text. |
| `docs/how-to/inspect-roi.md` | Relative ROI, zero-copy samples, retained lifetime, 2 × 2 example summing to 280 | Consistent with published ROI and view contracts. |
| `docs/how-to/sum-raster.md` | `sum!ulong` on bytes, checked result, integer overflow, row-major semantics | Consistent with typed reduction contract. |
| `docs/how-to/convert-samples.md` | Exact `ubyte -> float`, explicit destination, byte strides, disjoint storage | Consistent with exact conversion contract. |
| `docs/how-to/neighbourhood-convolution.md` | Fixed 3 × 3 identity kernel, source-resident halo, no border synthesis | Consistent with convolution/neighbourhood declarations. |
| `docs/how-to/common-operations.md`, `docs/glossary.md`, `docs/accuracy-and-validation.md` | Ownership distinctions, byte versus element stride units, numerical ordering, non-exclusive writable capability | No contradiction found in reviewed text. |

**Still open:** an exhaustive editorial examination of all public Ddoc
comments and all rendered Example bodies; external links, interactive
browser layout, and independently accessible live Pages deployment; the
exact candidate content gate immediately before release promotion. This
checkpoint must be reassessed after any change to the release-line SHA.
