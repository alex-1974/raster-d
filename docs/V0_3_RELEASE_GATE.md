# raster-d v0.3.0 release qualification and publication gate

**Status:** Feature/API freezes and initial exact-head qualification complete
on `fdea765a271893b25d5f8af1f29087b40caa5dc7`. The publication-neutral
documentation transition requires a **fresh exact-head CI sign-off** before
promotion to `main`. Publication is not established by a changelog date or
completed source CI. Record final evidence in
[issue #254](https://github.com/alex-1974/raster-d/issues/254).

## Scope

Release branch `release/0.3` starts from `develop` commit
`c7aff5d1c8ccb25e8741e940dfb69c1439a51541`.
The published `v0.2.0` source and `freeze/*-0.2.0` tags remain immutable.

Signed annotated checkpoint tags, verified against remote refs:
- `freeze/feature-0.3.0` -> `c7aff5d1c8ccb25e8741e940dfb69c1439a51541`.
- `freeze/api-0.3.0` -> `fdea765a271893b25d5f8af1f29087b40caa5dc7`.

Original checkpoint exact-head GitHub CI passed: Release Gate 15/15,
Compiler Floor 8/8, Release Documentation 3/3, Archive Consumer 2/2 and
API-documentation build. The independent DDox audit rendered 111/111
public Example pages. On the same source commit an XPS LDC 1.42.0 release
smoke verified count results and measured five-round median throughput
of 776.6 MiB/s for `histogram256` and 219.4 MiB/s for `histogramInto`.
This is not a comparative C++/SIMD claim.

## Prepromotion checks

- [x] Release candidate SHA and immutable `freeze/feature-0.3.0` checkpoint recorded.
- [x] Public import/export inventory checked against `source/raster/package.d`
      and `docs/API_0_3.md` (66 retained v0.2 exports + 6 histogram exports).
- [x] Contract audit covers histogram interval inclusivity, float and 64-bit
      integer behaviour, failure/no-partial-output, empty, ROI, layout,
      per-bin count overflow and window composition.
- [x] Immutable `freeze/api-0.3.0` checkpoint recorded **after** API audit.
- [x] Full `Release Gate` workflow PASS: supported compiler generations,
      compiler-floor checks, supported platform matrix, DIP1000, negative
      compile and clean archive consumers.
- [x] `Release Documentation` workflow PASS: strict public-only DDox,
      complete compiled public Example inventory, versioned Pages staging.
- [x] Candidate DDox module navigation, rendered examples and staged Pages
      independently inspected against the same commit.
- [x] New histogram throughput has been smoke-checked on a representative
      consumer path if necessary; no unsupported C++/SIMD performance
      superiority claim.
- [ ] Final README, CHANGELOG, release notes and tutorials are consistent,
      publication-neutral, and pass full exact-head release qualification.
- [x] Actual source/consumer archive and metadata/licence verified.
- [ ] Pull request from `release/0.3` to `main` reviewed and release-head
      SHA confirmed; any correction invalidates prior exact-head sign-off.

## Deliberate publication, after all gates

1. Merge qualified release branch to `main` using a merge commit.
2. Create a signed, annotated `v0.3.0` tag on the intended `main`
   release commit; do not move old checkpoint or version tags.
3. Observe `Publish release` GitHub Actions, which checks tag reachability
   from `main` and the `## 0.3.0` changelog entry, then creates a
   GitHub Release. Confirm it is the intended tag, not an unrelated tag.
4. Verify generated `/v0.3.0/` and stable-root Pages documentation, plus
   the still-accessible historical `/v0.2.0/` version.
5. Verify `raster-d@0.3.0` can actually be resolved by DUB registry and
   run a fresh **published version** consumer under both DMD and LDC.
6. Forward-integrate release-only changes to `develop` through a PR.
7. Open a separate `imagery-d` PR to update `~>0.2.0` to `~>0.3.0`
   and reconcile pinned CI source, with its own tests.

## Historical note

The postpublication retrospective v0.2 documentation gap remains tracked
as historical evidence in #198. Do not rewrite it as a successful
prepublication gate.
