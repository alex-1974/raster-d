# raster-d v0.1.0 release readiness

Status: **FEATURE FROZEN — RELEASE QUALIFICATION IN PROGRESS**

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
- [ ] reference-XPS baseline run complete;
- [ ] benchmark archive SHA256 and recursive manifest retained;
- [ ] benchmark/provenance summary recorded in BENCHMARK.md or release record.

## R4 — public API audit

- [ ] every `import raster;` export inventoried;
- [ ] signatures, argument order and public parameter names audited;
- [ ] template constraints audited;
- [ ] `.init` semantics audited;
- [ ] ownership/lifetime and mutation semantics audited;
- [ ] failure/error/no-write semantics audited;
- [ ] numerical guarantees audited;
- [ ] public attributes and CTFE claims audited;
- [ ] unintended public/internal leakage rejected;
- [ ] `docs/API.md` reconciled with the accepted surface.

## R5 — documentation quality

- [ ] `docs/ddoc-style.md` applied to the release surface;
- [x] every supported public module has compliant module Ddoc;
- [x] every public DDox symbol page inventoried;
- [x] every required page has its own compiled/rendered Example;
- [x] every non-trivial private/package function has adjacent Ddoc;
- [x] important decision comments reviewed;
- [x] public-only DDox generation passes;
- [ ] generated DDox visually reviewed.

## R6 — API freeze

- [ ] all R4/R5 blockers resolved;
- [ ] annotated immutable `freeze/api-0.1.0` created;
- [ ] no public source-contract change after API freeze without reopening the
  release decision.

## R7 — release qualification

- [ ] full controlled compiler-generation release matrix passes;
- [ ] supported platform matrix passes;
- [ ] external archive/package consumer passes baseline DMD and LDC;
- [ ] README/package metadata/release docs agree with frozen API;
- [ ] CHANGELOG and v0.1.0 release notes complete;
- [ ] release candidate promoted to `main`;
- [ ] final annotated/signed `v0.1.0` tag created;
- [ ] GitHub Release published;
- [ ] DDox/GitHub Pages stable documentation verified;
- [ ] published DUB package verified from a fresh consumer.

## Release decision

Current decision: **DO NOT TAG YET**.

Feature freeze and the release documentation-quality gate are complete.
Reference benchmark qualification, public API audit/API freeze, release matrix,
external consumer and publication verification remain open.
