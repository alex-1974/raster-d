# raster-d Research

Experimental work and raw evidence live in the separate
`raster-d-research` repository:

https://github.com/alex-1974/raster-d-research

The production `raster-d` repository keeps only what is needed to build,
verify, document, and release the library.

## Boundary

`raster-d` keeps:

- production source and public contracts;
- correctness and external-consumer tests;
- maintained benchmark harnesses used to qualify production behavior;
- architecture decision records;
- architecture and user documentation;
- CI and release tooling;
- concise evidence summaries needed to understand accepted decisions.

`raster-d-research` keeps:

- disposable prototypes and experiments;
- raw benchmark runs;
- large evidence archives;
- compiler and code-generation investigations;
- research reports;
- rejected or exploratory implementations whose history remains useful.

A maintained benchmark harness may stay in `raster-d` when release
qualification depends on rerunning it. Its raw runs and large archives still
belong outside the production repository.

Research findings enter production through an explicit promotion step. The
supporting evidence does not move merely because the decision was accepted.

Historical `raster-d` commits remain part of Git history.

## Consumer package

Repository evidence is not consumer payload.

The production archive uses `.gitattributes` to exclude benchmarks, tests,
tools, engineering documentation, CI files, and other repository-only material.
Release CI builds a real `git archive`, checks the boundary, and compiles an
external consumer from that archive.

## Initial research snapshot

Source repository: `alex-1974/raster-d`

Source commit:

```text
91fd96dceb70886f2cf33f7af8a6cce30f78168a
```

Initial research snapshot commit:

```text
dee2e0097a335139362d936b4c8bd47c2d21af17
```

Verified snapshot:

- 228 files;
- 2,840,033 bytes;
- identical relative paths;
- identical Git file modes;
- identical Git blob identities.

Further provenance is recorded in `PROVENANCE.md` in `raster-d-research`.
