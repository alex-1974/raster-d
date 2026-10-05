# raster-d v0.1.0 release readiness

Status: **PRE-TAG — RELEASE CANDIDATE QUALIFIED; PUBLICATION ACTIONS REMAIN**

Feature-freeze checkpoint:

~~~text
freeze/feature-0.1.0
d8cbcb270d24a344f59c4a7f1880848add38c975
~~~

Release branch:

~~~text
release/0.1
~~~

No v0.1.0 tag or publication is authorized until every mandatory gate below is
complete.

## R1 — scope

Included:

- retained raster ownership/view foundation;
- public writable view;
- strict reduction;
- same-type Copy;
- Fill;
- point transform;
- fixed 3x3 neighbourhood;
- exact ubyte-to-float conversion;
- qualified x86-64 DMD/LDC execution strategies;
- release documentation and verification tooling.

Excluded:

- new public capability after feature freeze;
- AArch64/NEON performance qualification;
- caller-owned parallel scheduling policy;
- GPU execution;
- image-domain functionality owned by imagery-d.

## R2 — feature freeze

- [x] `freeze/feature-0.1.0` created and verified;
- [x] `release/0.1` cut from the same commit;
- [x] only defects, tests, validation, benchmark, documentation, CI and
  release-hardening changes are allowed.

## R3 — release benchmark

- [x] public root-import benchmark harness added and compiler-smoked;
- [x] reference-XPS baseline run complete;
- [x] benchmark archive SHA256 and recursive manifest retained;
- [x] benchmark/provenance summary recorded in BENCHMARK.md or release record.

## R4 — public API audit

- [x] every `import raster;` export inventoried;
- [x] signatures, argument order and public parameter names audited;
- [x] template constraints audited;
- [x] `.init` semantics audited;
- [x] ownership/lifetime and mutation semantics audited;
- [x] failure/error/no-write semantics audited;
- [x] numerical guarantees audited;
- [x] public attributes and CTFE claims audited;
- [x] unintended public/internal leakage rejected;
- [x] `docs/API.md` reconciled with the accepted surface.

## R5 — documentation quality

- [x] `docs/ddoc-style.md` applied to the release surface;
- [x] every supported public module has compliant module Ddoc;
- [x] every public DDox symbol page inventoried;
- [x] every required page has its own compiled/rendered Example;
- [x] every non-trivial private/package function has adjacent Ddoc;
- [x] important decision comments reviewed;
- [x] public-only DDox generation passes;
- [x] generated DDox visually reviewed.

## R6 — API freeze

- [x] all R4/R5 blockers resolved;
- [x] annotated immutable `freeze/api-0.1.0` created;
- [x] no public source-contract change after API freeze without reopening the
  release decision.

## R7 — release qualification

- [x] full controlled compiler-generation release matrix passes;
- [x] supported platform matrix passes;
- [x] external archive/package consumer passes baseline DMD and LDC;
- [x] README/package metadata/release docs agree with frozen API;
- [x] CHANGELOG and v0.1.0 release notes complete;
- [ ] release candidate promoted to `main`;
- [ ] final annotated/signed `v0.1.0` tag created;
- [ ] GitHub Release published;
- [ ] DDox/GitHub Pages stable documentation verified;
- [ ] published DUB package verified from a fresh consumer.

## Release decision

Current decision: **DO NOT TAG YET**.

The release candidate is qualified through feature freeze, API freeze,
documentation quality, reference-XPS benchmark evidence, compiler-generation
matrix, supported platform matrix, compiler floors and clean external
git-archive consumers.

The remaining actions are deliberate publication actions:

1. promote `release/0.1` to `main` with the required release-branch merge;
2. verify the main-branch release/documentation gates and GitHub Pages build;
3. create the annotated/signed `v0.1.0` tag;
4. publish the GitHub Release and stable/versioned documentation;
5. publish/verify the DUB package from a fresh external consumer.
