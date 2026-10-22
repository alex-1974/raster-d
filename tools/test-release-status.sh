#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/docs"
touch "$fixture/docs/V0_2_FINAL_RELEASE_CONTENT_GATE.md"
mkdir -p "$fixture/docs/tutorial"
printf "v0.2 documentation\\n" > "$fixture/docs/README.md"
printf "Getting started with v0.2\\n" > "$fixture/docs/tutorial/getting-started.md"
printf "raster-d v0.2 release notes\\n" > "$fixture/docs/V0_2_RELEASE_NOTES.md"

make_readme() {
    printf 'v0.2.0 is %s\nIts public API\nis frozen at `freeze/api-0.2.0`.\n%s\n' "$1" "$2" > "$fixture/README.md"
}
make_changelog() {
    printf '%s\n## 0.1.0 — 2026-10-05\n' "$1" > "$fixture/CHANGELOG.md"
}
expect_pass() {
    if ! bash "$root/tools/verify-release-status.sh" "$fixture" >/dev/null; then
        echo "FAIL: expected publication status PASS: $1" >&2
        exit 1
    fi
}
expect_fail() {
    if bash "$root/tools/verify-release-status.sh" "$fixture" >/dev/null 2>&1; then
        echo "FAIL: expected publication status rejection: $1" >&2
        exit 1
    fi
}

make_readme 'a release candidate' 'v0.2.0 is not yet published'
make_changelog '## 0.2.0 — Release candidate (unpublished)'
expect_pass 'valid candidate'

make_readme 'released' 'v0.2.0 is published'
make_changelog '## 0.2.0 — 2026-10-10'
expect_pass 'valid published'

make_readme 'released' 'v0.2.0 is published'
make_changelog '## 0.2.0 — 2026-10-10'
printf 'The latest published stable package is v0.1.0; v0.2.0 is not yet published\\n' > "$fixture/docs/tutorial/getting-started.md"
expect_fail 'published release cannot retain candidate tutorial'
printf 'Getting started with v0.2\\n' > "$fixture/docs/tutorial/getting-started.md"
printf '# raster-d v0.2.0 release notes — candidate\\n' > "$fixture/docs/V0_2_RELEASE_NOTES.md"
expect_fail 'published release cannot retain draft release notes'
printf 'raster-d v0.2 release notes\\n' > "$fixture/docs/V0_2_RELEASE_NOTES.md"
printf -- '- [v0.2 candidate release notes (not yet published)]\\n' > "$fixture/docs/README.md"
expect_fail 'published release cannot retain draft docs index'
printf 'v0.2 documentation\\n' > "$fixture/docs/README.md"

make_readme 'a release candidate' 'v0.2.0 is not yet published'
make_changelog '## 0.2.0 — 2026-10-10'
expect_fail 'candidate README with published changelog'

make_readme 'released' 'v0.2.0 is published'
make_changelog '## 0.2.0 — Release candidate (unpublished)'
expect_fail 'published README with candidate changelog'

make_readme 'a release candidate' 'v0.2.0 is not yet published'
make_changelog '## 0.2.0 — Release candidate (unpublished)'
sed -i 's/freeze\/api-0.2.0/freeze\/api-0.1.0/' "$fixture/README.md"
expect_fail 'missing completed v0.2 API freeze'

make_readme 'a release candidate' 'v0.2.0 is not yet published'
printf '%s\n' 'the public API is being audited before freeze/API' >> "$fixture/README.md"
expect_fail 'obsolete pending audit claim'

# A new minor candidate must not invalidate already-published v0.2.
make_readme 'released' 'v0.2.0 is published'
printf 'v0.3.0 is a release candidate\n' >> "$fixture/README.md"
make_changelog $'## 0.3.0 — Release candidate (unpublished)\n## 0.2.0 — 2026-10-10'
printf 'NOT PUBLISHED: v0.3.0 is still a candidate\n' > "$fixture/docs/V0_3_RELEASE_NOTES.md"
expect_pass 'v0.3 candidate alongside published v0.2'

# Historical v0.2 candidate notes are allowed only with a retrospective caveat.
printf 'Postpublication update: historical prepublication evidence. DRAFT / NOT PUBLISHED\n' > "$fixture/docs/V0_2_RELEASE_NOTES.md"
expect_pass 'historical candidate notes explicitly marked retrospective'
printf 'v0.2.0 release notes — candidate\n' > "$fixture/docs/V0_2_RELEASE_NOTES.md"
expect_fail 'uncaveated historical release notes still rejected'
printf 'raster-d v0.2 release notes\n' > "$fixture/docs/V0_2_RELEASE_NOTES.md"

printf 'PUBLISHED: incorrectly claiming v0.3 release\n' > "$fixture/docs/V0_3_RELEASE_NOTES.md"
expect_fail 'v0.3 candidate cannot claim publication'
printf 'NOT PUBLISHED: v0.3.0 is still a candidate\n' > "$fixture/docs/V0_3_RELEASE_NOTES.md"

make_changelog $'## 0.3.0 — 2026-10-22\n## 0.2.0 — 2026-10-10'
expect_fail 'v0.3 candidate requires an unpublished changelog'

echo 'PASS: v0.2 publication history and v0.3 candidate status positive/negative regressions'
