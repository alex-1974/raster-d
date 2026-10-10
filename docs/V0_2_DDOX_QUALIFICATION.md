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
