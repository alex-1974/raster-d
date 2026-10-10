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
