# v0.2 final release-content gate

> **Historical gate status (recorded after publication, 2026-10-10):**
> v0.2.0 was published and its GitHub Release, DUB archive/consumer and
> stable/versioned Pages were independently verified. The exact-head
> **prepromotion** content sign-off required below was not completed before
> publication, and the complete public Ddoc editorial audit remains open.
> Do not convert retrospective checks into a historical prepromotion PASS.
> See [issue #198](https://github.com/alex-1974/raster-d/issues/198).


**Required — not yet passed.** Run this audit on the exact release candidate SHA immediately before promotion to main. Record evidence in issue #198.

## Objective

Previous releases left README and documentation on pre-release wording. v0.2.0 must not ship with stale status, version or links.

Before publication, v0.1.0 remains the published stable version. v0.2.0 is a release candidate until its tag, GitHub Release, documentation and DUB publication are verified. Do not claim publication prematurely.

## Required surfaces

- README.md: introduction, current version, status and links.
- docs/README.md, Getting Started, how-to guides, glossary and accuracy: examples and cross-links agree with the exact v0.2 API.
- docs/API_0_2.md and docs/API.md: v0.2 current candidate contract versus v0.1 historical baseline are clearly distinguished.
- CHANGELOG.md and release notes: complete v0.2 release section and correct scope.
- Public Ddoc and rendered DDox: public declarations, module summaries, examples, generated links and version headings.
- GitHub Pages: versioned v0.2 navigation and stable/default pointer, without replacing v0.1 stable before publication.
- DUB package and archive consumer: package metadata, archive contents and external consumer match the exact candidate.
- Release notes and release target SHA: consistent with the candidate.

Search all occurrences of 'develop', 'release/0.2', 'feature freeze', 'API freeze pending', 'pre-release', 'upcoming', 'not yet released', 'v0.1.0', 'v0.2.0', 'latest' and 'stable'. Hits are review triggers, not automatic failures: historical or labelled development statements can be correct.

Suggested reproducible inspection:

~~~sh
git rev-parse HEAD
git grep -nEi 'pre.?release|not yet released|upcoming|release/0[.]2|API freeze pending|feature freeze|v0[.]1[.]0|v0[.]2[.]0|latest|stable' -- README.md CHANGELOG.md docs
~~~

Grep is never sufficient alone. Read all relevant content and inspect rendered DDox, Pages and external publication status.

## Two checkpoints

**Pre-promotion PASS:** On the exact qualifying candidate SHA, confirm every surface is consistent with a not-yet-published v0.2.0. Record checked SHA, review time, CI and evidence links in issue #198. Any contradiction blocks promotion to main.

**Post-publication PASS:** After publishing, verify actual v0.2.0 tag, GitHub Release, versioned/stable Pages, DUB registry and a fresh external consumer. Record the verified result in #198. Publication claims become true only after they are verified.

If documentation is corrected after the audit, repeat the gate on the new candidate SHA and rerun affected release checks. Immutable freeze tags remain unchanged.

## Evidence template

~~~text
Version: v0.2.0
Candidate SHA:
Checked UTC time:
README and documentation navigation: PASS/FAIL
Tutorial/how-to/glossary/accuracy: PASS/FAIL
v0.2 versus historical v0.1 API wording: PASS/FAIL
Changelog and release notes: PASS/FAIL
Public Ddoc and rendered DDox: PASS/FAIL
Versioned Pages and stable pointer: PASS/FAIL
DUB/archive and external consumer: PASS/FAIL
Pre-promotion: PASS/BLOCKED
Post-publication: PENDING/PASS/FAIL
Evidence links:
~~~
