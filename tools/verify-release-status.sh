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
    # Do not ship user-facing pages that still advertise the unreleased
    # candidate. These assertions are scoped to release-facing documents;
    # historical audit/checkpoint records are intentionally excluded.
    for published_doc in \
        "$repo/docs/README.md" \
        "$repo/docs/tutorial/getting-started.md" \
        "$repo/docs/V0_2_RELEASE_NOTES.md"; do
        [[ -f "$published_doc" ]] || {
            echo "FAIL: missing published documentation: $published_doc" >&2
            exit 1
        }
        if grep -Eiq 'not yet published|DRAFT / NOT PUBLISHED|release notes — candidate|v0[.]2[.]0 release candidate|v0[.]2 candidate release notes' "$published_doc"; then
            echo "FAIL: stale v0.2 candidate wording: $published_doc" >&2
            exit 1
        fi
    done
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
