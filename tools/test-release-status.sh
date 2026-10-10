#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/docs"
touch "$fixture/docs/V0_2_FINAL_RELEASE_CONTENT_GATE.md"

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

echo 'PASS: v0.2 publication-status positive and negative regressions'
