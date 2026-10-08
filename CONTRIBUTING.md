# Contributing to raster-d

`raster-d` is part of the d-geospatial workspace. Repository-local rules live
in `AGENTS.md`; shared engineering rules are available under `.workspace/`
inside the workspace checkout.

## Branches

Normal work starts from `develop` and returns through a pull request.

Use short-lived branches such as:

- `feat/*`
- `fix/*`
- `docs/*`
- `perf/*`
- `test/*`
- `ci/*`

Experimental work normally belongs on `research-integration` or in the
separate `raster-d-research` repository. Accepted research is promoted
selectively; raw experimental history is not merged wholesale into production.

`main` is the qualified release line.

## Before opening a pull request

Run the checks that match your change. At minimum:

```bash
dub build
dub test
```

Changes to public API, lifetimes, numerical behavior, performance, packaging or
release machinery need the corresponding contract or benchmark gates described
in the workspace documents.

Performance claims need reproducible evidence. Record compiler versions,
platform, workload, warm-up, samples, affinity where relevant, and the baseline
commit.

## Public API

Prefer the smallest public surface that solves a demonstrated consumer need.

Document new or changed public API in the same change. Preserve ownership,
lifetime, failure, allocation and numerical semantics. Do not expose compiler,
ISA, thread-count or scheduler policy as public switches merely to optimize one
platform.

## Documentation

Write for the reader. Use plain English, active verbs and short sentences.
Explain caller-visible meaning before implementation detail. Put historical
research and performance evidence in ADRs, benchmark records or
`raster-d-research`, not in ordinary user instructions.

## Pull requests

PR titles use Conventional Commit form, for example:

```text
feat(view): add ...
fix(copy): preserve ...
perf(convolution): specialize ...
docs(api): explain ...
```

Use `Closes #N` when the PR fully resolves an issue and `Refs #N` when it is
only one part of the work.
