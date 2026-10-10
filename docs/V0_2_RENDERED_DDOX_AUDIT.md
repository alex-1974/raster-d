# v0.2 rendered DDox artifact inspection

**Evidence status:** preliminary rendered-output inspection, **not** final
release sign-off.

## Provenance

- Source: Release Documentation workflow from PR #221
- Workflow run: [38050778667](https://github.com/alex-1974/raster-d/actions/runs/38050778667), successful
- PR head SHA: `b57e8ed209af3ff4f450ad417876c96130e37012`
- Artifact: `raster-ddox-release-candidate` (GitHub Actions artifact ID
  `11669282483`)
- Inspected: 2026-10-10
- **Caveat:** the artifact is from the PR head, not the current, subsequently
  advanced `release/0.2` head. The final candidate must be inspected again.

## Inspection results

The downloaded ZIP contains 146 entries, including 124 HTML files.
Inspection of the HTML structure found:

| Check | Observed |
| --- | ---: |
| HTML pages | 124 |
| Package landing page (`raster.html`) | 1 |
| Public module pages | 25 |
| Public symbol pages | 97 |
| Symbol pages with a rendered `Example` | 97 |
| References to `raster.internal` in HTML | 0 |
| Broken local relative HTML/CSS/JS/image references in ZIP | 0 |

The link scan resolved relative paths against each originating page and
checked targets against the files present in the ZIP. It does not validate
external URLs or browser JavaScript behavior.

The rendered site uses the generic browser title **“API documentation”**
on its `index.html` page. This is a presentation issue to consider
when qualifying the public Pages landing experience; do not mistake it
for a wrong API version.

## What this evidence does not prove

- It does not confirm the final release-head artifact, published Pages
  routing, stable aliases or public links.
- It does not constitute an editorial line-by-line review of all 97
  example bodies or ownership/numerical prose.
- It does not verify HTTP links or JavaScript behavior in a browser.
- It does not finish the required exact-candidate release-content gate.

## Remaining release actions

Rebuild and re-inspect the DDox artifact from the **final candidate SHA**.
Review representative public pages and examples for semantic clarity,
confirm external links and versioned/stable Pages behavior, and attach
the qualifying exact-SHA evidence to [release issue #198](https://github.com/alex-1974/raster-d/issues/198).

## Follow-up independent ZIP inspection (PR #229)

- Workflow: [38056976055](https://github.com/alex-1974/raster-d/actions/runs/38056976055), Release Documentation — PASS.
- PR head SHA: `502bf0d0fdd14f59341958c2e197005723abc527`.
- Artifact: `raster-ddox-release-candidate`, ID `11671952718`.
- Inspected downloaded artifact ZIP on 2026-10-10 (not just its metadata).

| Check | Observed |
| --- | ---: |
| ZIP entries | 146 |
| HTML pages | 124 |
| Public module pages (under `raster/`) | 25 |
| Public symbol pages (nested beneath module paths) | 97 |
| Symbol pages containing `Example` | 97 / 97 |
| HTML pages mentioning `raster.internal` | 0 |
| Unresolved relative HTML `href` / `src` targets | 0 |
| Generic `index.html` browser title | `API documentation` |

The follow-up scan parsed every generated HTML page in the ZIP, resolved
non-external relative `href`/`src` targets against ZIP paths, counted
symbol-level Example mentions, and checked for literal internal-module
leakage. It **did not** establish external HTTP link health, rendered browser
layout, JavaScript behavior or editorial correctness of every example.

**Candidate limitation:** PR #229's inspected head preceded its squash merge
(`7ffc0334ad03cd24fec57c6c006435717f2dc521`) and subsequent candidate
qualification. This inspection is repeatable evidence of a successful PR
artifact, **not final-release-head DDox sign-off**. Do not mark issue #198's
final DDox/content gate complete from this artifact alone.


## Independent rendered ZIP inspection (PR #234)

- Inspected: 2026-10-10.
- Source: [Release Documentation workflow 38067809305](https://github.com/alex-1974/raster-d/actions/runs/38067809305), PASS (PR #234).
- PR head SHA: `d788febef6b2d1b91c001559d3ad155bef47fedb`.
- Downloaded artifact: `raster-ddox-release-candidate`, ID `11676420121`, size 268468 bytes.
- Corresponding subsequent squash merge to `release/0.2`:
  `3ab1b7831da590c7f25a9429d17c3c2face616ea`.

The archive was downloaded and its file contents independently inspected;
the result is not inferred from artifact metadata or the CI checkmark alone.

| Check | Observed |
| --- | ---: |
| Files | 146 |
| HTML pages | 124 |
| Public module pages | 25 |
| Public symbol pages | 97 |
| Public symbol pages containing `Example` | 97 / 97 |
| HTML files containing literal `raster.internal` | 0 |
| Unresolved relative HTML `href` / `src` references | 0 |

Representative page files were inspected: `raster.html`,
`raster/reduction/mean.html`, `raster/reduction/minMax.html`,
`raster/backing/RasterLease.html` and
`raster/convolution/convolveInto.html`. The `index.html` browser title is
still the generic `API documentation`.

**Limitations:** This is a **PR-head** HTML artifact and not a new
post-squash exact release-head documentation build. It does not certify
every example's editorial accuracy, external HTTP links, browser rendering
or JavaScript, deployed live GitHub Pages aliases, or the final candidate's
release-content gate. These requirements remain open in issue #198.
