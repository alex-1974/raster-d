# raster-d v0.3.0 release gate — candidate

**Status:** Open. Do not promote to `main` or tag `v0.3.0` until every
applicable prepromotion check below is backed by evidence from the **same
exact release-head commit**. Record evidence in [issue #254](https://github.com/alex-1974/raster-d/issues/254).

## Scope

Release branch `release/0.3` starts from `develop` commit
`c7aff5d1c8ccb25e8741e940dfb69c1439a51541`.
The published `v0.2.0` source and `freeze/*-0.2.0` tags remain immutable.

## Prepromotion checks

- [ ] Release candidate SHA and immutable `freeze/feature-0.3.0` checkpoint recorded.
- [ ] Public import/export inventory checked against `source/raster/package.d`
      and `docs/API_0_3.md` (66 retained v0.2 exports + 6 histogram exports).
- [ ] Contract audit covers histogram interval inclusivity, float and 64-bit
      integer behaviour, failure/no-partial-output, empty, ROI, layout,
      per-bin count overflow and window composition.
- [ ] Immutable `freeze/api-0.3.0` checkpoint recorded **after** API audit.
- [ ] Full `Release Gate` workflow PASS: supported compiler generations,
      compiler-floor checks, supported platform matrix, DIP1000, negative
      compile and clean archive consumers.
- [ ] `Release Documentation` workflow PASS: strict public-only DDox,
      complete compiled public Example inventory, versioned Pages staging.
- [ ] Candidate DDox module navigation, rendered examples and staged Pages
      independently inspected against the same commit.
- [ ] New histogram throughput has been smoke-checked on a representative
      consumer path if necessary; no unsupported C++/SIMD performance
      superiority claim.
- [ ] README, CHANGELOG, release notes and tutorials consistently describe
      v0.2.0 as published and v0.3.0 as **unpublished**.
- [ ] Actual source/consumer archive and metadata/licence verified.
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
