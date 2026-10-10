#!/usr/bin/env bash
set -euo pipefail
repo="${1:?usage: verify-release-status.sh REPO_ROOT}"

# Two explicit states: unpublished release candidate and published v0.2.0.
# Both must describe the already-completed API freeze. Do not force
# pre-release wording onto main after actual v0.2.0 publication.
if grep -Eq '^v0[.]2[.]0 is a release candidate' "$repo/README.md"; then
    grep -Fqx '## 0.2.0 — Release candidate (unpublished)' "$repo/CHANGELOG.md" || {
        echo "FAIL: candidate README requires unpublished v0.2.0 changelog" >&2
        exit 1
    }
    grep -q 'not yet published' "$repo/README.md" || {
        echo "FAIL: candidate README must not imply publication" >&2
        exit 1
    }
    echo "PASS: unpublished v0.2.0 candidate status is consistent"
elif grep -Eq '^v0[.]2[.]0 is released' "$repo/README.md"; then
    grep -Eq '^## 0[.]2[.]0 — [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$repo/CHANGELOG.md" || {
        echo "FAIL: published v0.2.0 README requires dated changelog heading" >&2
        exit 1
    }
    if grep -Fq 'Release candidate (unpublished)' "$repo/CHANGELOG.md"; then
        echo "FAIL: published v0.2.0 cannot retain unpublished changelog status" >&2
        exit 1
    fi
    echo "PASS: published v0.2.0 status is consistent"
else
    echo "FAIL: README.md must explicitly identify candidate or published v0.2.0 status" >&2
    exit 1
fi

grep -q 'is frozen at `freeze/api-0.2.0`' "$repo/README.md" || {
    echo "FAIL: README.md must identify the completed v0.2 API freeze" >&2
    exit 1
}

if grep -Eiq 'the public API is being audited before|API freeze pending|freeze/api-0[.]2[.]0.*(to be created|will be created)' "$repo/README.md"; then
    echo "FAIL: README.md retains obsolete pre-API-freeze wording" >&2
    exit 1
fi

grep -Fqx '## 0.1.0 — 2026-10-05' "$repo/CHANGELOG.md" || {
    echo "FAIL: CHANGELOG.md must retain historical v0.1.0 section" >&2
    exit 1
}

[[ -f "$repo/docs/V0_2_FINAL_RELEASE_CONTENT_GATE.md" ]] || {
    echo "FAIL: mandatory final release-content gate documentation is absent" >&2
    exit 1
}

echo "PASS: v0.2 release status verified"
