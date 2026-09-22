# raster-d Repository Pivot Plan

## Status

Active migration plan.

The architectural decision is recorded in
`docs/adr/0003-repository-pivot-to-raster-d.md`.

This document defines the implementation sequence for that decision.

## Baseline

The pivot starts from:

- repository: `alex-1974/imagery-d`;
- branch base: `main`;
- baseline commit:
  `45a30cae31074594b56b6b1fc0ff3dca8bbacada`;
- completed research: E3.1 through E3.3 / R0.3;
- production source unchanged by the R0.3 research merge;
- current CI and compiler-floor workflows green.

The migration must preserve the existing Git history.

## Target identity

The final generic raster library is:

```text
repository: raster-d
DUB package: raster-d
public D package: raster
```

The intended future dependency direction is:

```text
future imagery-d
        |
        v
     raster-d
```

The future `imagery-d` is not created by this migration.

## Production namespace migration

Current:

```text
source/imagery/raster/package.d
module imagery.raster

source/imagery/raster/view.d
module imagery.raster.view
```

Target:

```text
source/raster/package.d
module raster

source/raster/view.d
module raster.view
```

Therefore the mechanical namespace mapping is:

```text
imagery.raster            -> raster
imagery.raster.*          -> raster.*
package(imagery.raster)   -> package(raster)
source/imagery/raster/**  -> source/raster/**
```

## Root imagery module

`source/imagery/package.d` currently defines the otherwise empty root module:

```text
module imagery;
```

It is not renamed to `source/raster/package.d`.

The target `source/raster/package.d` comes from the existing
`source/imagery/raster/package.d`, because that file already defines the public
raster umbrella.

The old `source/imagery/package.d` is therefore removed during the namespace
pivot.

## DUB package migration

The repository root package changes from:

```text
imagery-d
```

to:

```text
raster-d
```

Its description must describe a generic raster library rather than a
geospatial image engine.

Path-based consumers inside this repository must change their dependency name
in the same atomic migration.

Known active consumers include:

- `experiments/r0_3_regions_streaming`;
- `tests/external/raster_import_link`.

The external regression package itself should also use a `raster-d`-based
identity so that its purpose remains obvious in build output.

## Active source consumers

The namespace migration includes maintained code that must continue to compile
against the current production library:

- production modules;
- R0.3 region/streaming experiments;
- external-consumer regression tests;
- compile-negative API/lifetime probes;
- maintained replay harnesses that reference current production paths.

These are active migration targets rather than historical evidence.

## Historical evidence

Files below historical `original/` evidence trees are immutable evidence.

They must not be modified merely to replace old repository or module names.

This includes historical source, generated LLVM IR, assembly, compiler output,
benchmark output and path captures.

Likewise, historical filenames containing `d-imagery` remain unchanged.

`SHA256SUMS` files protecting historical evidence remain unchanged.

## Historical replay compatibility

Some maintained replay harnesses compile preserved historical source against
the current production implementation.

The namespace pivot must not solve this by editing the historical source.

Where an old preserved source imports `imagery.raster`, the maintained replay
harness must instead create a temporary replay source and mechanically migrate
that temporary copy to the current `raster` namespace.

Requirements for such a bridge:

- the original file remains byte-identical;
- its historical hash remains valid;
- the transformed copy exists only below the replay temporary directory;
- transformation is limited to the namespace compatibility needed for replay;
- generated replay artifacts remain outside the repository;
- repository cleanliness remains a replay gate.

Maintained replay scripts may themselves be edited.

## Documentation classes

Documentation is not subject to a global textual replacement.

### Current raster architecture

Documents describing the present generic implementation should adopt
`raster-d` / `raster` terminology.

This includes current architecture documents for:

- raster construction;
- raster coordinate semantics;
- raster execution;
- external raster import;
- raster operations;
- raster core types;
- current compiler and memory-model contracts where the text refers to the
  present generic library.

### Mixed imagery/raster documents

Repository-root documents such as `README.md`, `DESIGN.md`, `ROADMAP.md` and
`BENCHMARK.md` contain both generic raster architecture and future image-engine
requirements.

They must be rewritten deliberately.

Generic raster content remains with `raster-d`.

Forward-looking image-domain requirements remain identifiable as requirements
for a future higher-level `imagery-d`, rather than being silently reclassified
as generic raster functionality.

### Historical ADRs

ADR 0002 remains historical imagery policy.

ADR 0003 retains the old names where they are necessary to explain why and how
the repository pivot was decided.

Historical statements are not rewritten merely to make every occurrence use
the new name.

## Workspace documents

`.workspace` files are shared workspace context and are hard-linked across
multiple repositories.

They are not modified during the initial code/package namespace migration.

After the repository pivot is technically stable, the workspace documentation
must be updated as a coordinated cross-repository change so that it records:

- `raster-d` as the active generic raster library;
- `imagery-d` as a future higher-level image-engine consumer;
- the extraction gate as satisfied;
- the old prohibition on a parallel speculative `raster-d` as superseded by
  ADR 0003.

## CI and regression gates

The namespace/package migration must preserve:

- root DMD tests;
- root LDC tests;
- compiler-floor CI;
- architecture CI;
- compile-negative lifetime and API probes;
- external retained-import link closure;
- R0.3 region/streaming tests;
- durable E4/E5 replay integrity;
- a clean working tree after tests.

No production semantic change is intended by the namespace pivot.

## Migration phases

### P1 — Package and D namespace

Perform one coherent technical migration:

- rename the DUB package to `raster-d`;
- move `source/imagery/raster/**` to `source/raster/**`;
- remove the obsolete root `module imagery`;
- change production modules and imports to `raster` / `raster.*`;
- change `package(imagery.raster)` to `package(raster)`;
- update active consumers and compile probes;
- update maintained replay harnesses without modifying historical originals.

The repository still remains hosted as `alex-1974/imagery-d` during this phase.

### P2 — Repository documentation

Rewrite current project documentation for `raster-d`.

Keep historical evidence and historical explanations intact.

### P3 — Full technical validation

Run all current compiler, architecture, external-consumer, R0.3 and durable
replay gates.

Audit remaining old-name occurrences and classify every remaining occurrence as
historical, future-imagery, workspace-deferred or erroneous.

### P4 — Merge code pivot

Merge the tested code/package/documentation pivot while GitHub still owns the
repository under its old `imagery-d` name.

This keeps repository-hosting changes separate from source/package changes.

### P5 — Repository identity pivot

After the merged code state is green:

- rename the GitHub repository from `imagery-d` to `raster-d`;
- update the explicit local `origin` URL;
- rename the local repository directory;
- verify all Git worktrees before moving filesystem paths;
- verify branches, remotes and GitHub Actions again.

No assumption should be made that redirect behaviour is a sufficient permanent
configuration.

### P6 — Workspace identity update

Update shared workspace documentation in a coordinated workspace change.

Do not edit the hard-linked workspace documents casually from only one
repository.

### P7 — Future imagery-d

Only after `raster-d` is stable should a new higher-level `imagery-d`
repository be created.

It will consume `raster-d` rather than reimplementing raster ownership, views,
layout, execution or generic raster operations.

## Explicit exclusions

The pivot does not:

- introduce new raster functionality;
- promote R0.3 research APIs into production;
- create the future image engine;
- change raster numerical semantics;
- change lifetime or ownership contracts;
- rewrite historical evidence;
- regenerate historical hashes;
- perform a blind repository-wide `imagery -> raster` substitution.

## Completion criterion

The pivot is complete when:

1. the library is named `raster-d`;
2. its public D namespace is `raster`;
3. active tests and consumers use the new identity;
4. historical evidence remains intact and replayable;
5. CI and compiler-floor gates pass;
6. GitHub and local repository identities are `raster-d`;
7. workspace documentation reflects the new ownership boundary;
8. no unexplained active `imagery-d` or `imagery.raster` dependency remains.
