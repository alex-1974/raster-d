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

## v0.2 package source modes

Issue #193 removes the package-wide DIP1000 dependency.

The retained backing owner no longer embeds Phobos `SafeRefCounted`.
`RasterLease` now uses a private raster-d control block whose copy,
assignment, destruction, and payload-borrow boundaries are owned by raster-d.

Package metadata is source-mode neutral:

```text
no package-wide -preview=dip1000
```

CI qualifies both modes separately:

```text
ordinary D source mode
explicit -preview=dip1000 mode
```

The archive consumer is built in both modes, and a retained benchmark is also
linked in both modes so separately compiled package/consumer symbols cannot
silently drift again.

This matches the workspace model already used by `containers-d`: preview
language modes are validation configurations, not consumer package policy.

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
