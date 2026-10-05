# raster-d v0.1.0 documentation audit

Status: **COMPLETE FOR THE DOCUMENTATION GATE**

This document records release-facing documentation decisions. It is not itself
the public API contract.

## 1. README.md

README is the repository entry page.

Before release it must state:

- what raster-d is;
- supported 0.1 capability families;
- responsibility boundary versus imagery-d;
- installation;
- one representative root-import example;
- links to API, benchmark, architecture and detailed documentation;
- release status.

Implementation history and research narrative belong elsewhere.

## 2. docs/API.md

`docs/API.md` is the stable 0.1 public source-contract document after the API
freeze.

It must cover root exports, ownership/lifetime, layout/stride semantics,
default states, failure/no-write behavior, numerical contracts, allocation,
attributes and explicit non-public boundaries.

## 3. ROADMAP.md

ROADMAP remains current planning, not historical release notes.

M3 x86-64 qualification is complete; AArch64, parallelism and GPU remain future
work rather than 0.1 blockers.

## 4. BENCHMARK.md

BENCHMARK.md owns qualified performance evidence and reference-machine context.
Public Ddoc must not duplicate detailed benchmark history.

## 5. ADRs and architecture

ADRs preserve durable architectural/numerical/performance decisions.
Architecture documents explain current subsystem contracts.

Ordinary consumer behavior must still be understandable from Ddoc/API.md
without reading an ADR.

## 6. Release notes

v0.1.0 receives a dedicated historical release-note document:

~~~text
docs/V0_1_RELEASE_NOTES.md
~~~

## 7. Documentation tooling

The release line adopts:

- public-only DDox generation;
- public module Ddoc verification;
- internal function Ddoc verification;
- strict per-symbol Example inventory/verification;
- human generated-site review;
- GitHub Pages deployment from `main`.

## Sign-off

Release-facing structure: **defined**.

Content remediation and generated-DDox review: **complete**.

The generated site was reviewed from the strict workflow artifact. Navigation
contains only the root-exported release documentation surface, with no
raster.internal or package-only infrastructure modules. Representative
ownership/import, lifetime/view and operation pages were inspected for readable
contracts and rendered Examples.
