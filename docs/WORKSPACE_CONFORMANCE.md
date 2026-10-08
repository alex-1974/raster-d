# Workspace conformance

Status: current repository state for v0.2 hardening.

This note records repository-specific facts where the checked repository has
moved beyond the transitional status table in the workspace documents.

## Git workflow

The current repository has crossed the workspace migration boundary in
practice:

- `develop` is the default integration branch;
- `develop` is protected and requires the Fast DMD/LDC checks;
- `main` is protected and remains the qualified release line;
- `research-integration` exists for experimental integration;
- normal accepted work reaches `develop` through pull requests;
- merged short-lived branches are deleted automatically;
- release qualification on `main` uses the broader compiler, platform,
  archive-consumer, and documentation gates.

The workspace transition table dated 2026-09-26 still lists `raster-d` as
“NOT MIGRATED” because `research/r0_4e-persistent-workers` was active at that
checkpoint. That table is stale relative to the repository.

This repository does not rewrite the shared workspace document. The workspace
copy is managed outside this repository.

## Grandfathered branches

Pre-migration research branches remain valid historical evidence.

In particular, referenced research branches such as
`research/r0_4e-persistent-workers` and `research/r0_5-cpu-simd` are not
renamed, rebased, or deleted merely to match current branch naming.

Unreferenced short-lived branches may be removed after their work is merged or
abandoned. Evidence-bearing branches are preserved while repository documents,
issues, or retained results refer to them.

## Production/research split

`raster-d-research` stores experimental work, raw runs, large evidence, and
compiler investigations.

`raster-d` may keep small maintained benchmark harnesses when they are part of
production qualification. Consumer archives exclude those harnesses and other
repository-only material.

## Known v0.2 package-mode deviation

The current package still declares:

```text
dflags "-preview=dip1000"
```

This does not match the workspace target for published package metadata.

The hardening pass attempted to remove the flag. That exposed a real
source/ABI-mode dependency in `RasterLease` / `SafeRefCounted` ownership
code:

- ordinary library build without the flag succeeds;
- full unittests without DIP1000 fail at `@safe` destructor/assignment
  boundaries;
- DMD separately compiled retained benchmarks can fail to link because
  `SafeRefCounted` special-member symbols differ across the modes.

Issue #193 tracks the required correction. It is a v0.2 API-freeze/release
blocker. The flag is retained temporarily to preserve the already-qualified
build and benchmark behavior while that ownership/toolchain question is solved
with dedicated tests.

The consumer-archive size/boundary work in this hardening pass is independent
of that blocker.

## Documentation

User documentation follows this path:

```text
README.md
    -> docs/README.md
        -> docs/tutorial/
        -> docs/how-to/
        -> docs/glossary.md
        -> docs/accuracy-and-validation.md
        -> generated Ddoc/DDox
```

ADRs, architecture notes, benchmark summaries, and release audits remain
maintainer evidence rather than the primary user path.

## Writing style

User-facing documentation follows four rules:

1. use plain, concrete English;
2. prefer active verbs to noun-heavy phrases;
3. omit words that do not change meaning;
4. separate user instructions from engineering evidence.

Technical terms remain when the contract needs them. Precision is not traded
for informality.
