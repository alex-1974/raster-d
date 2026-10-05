#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  README.md
  ROADMAP.md
  BENCHMARK.md
  DESIGN.md
  docs/API.md
  docs/ddoc-style.md
  docs/public-api-example-audit.md
  docs/V0_1_RELEASE_READINESS.md
  docs/V0_1_DOCUMENTATION_AUDIT.md
  docs/V0_1_DOCUMENTATION_QUALITY_AUDIT.md
  docs/V0_1_CODE_DOCUMENTATION_AUDIT.md
  docs/V0_1_RELEASE_NOTES.md
  CHANGELOG.md
)

for f in "${required[@]}"; do
    [[ -f "$repo/$f" ]] || {
        echo "FAIL missing documentation file: $f" >&2
        exit 1
    }
done

grep -q '^name "raster-d"' "$repo/dub.sdl" || {
    echo "FAIL: unexpected DUB package identity" >&2
    exit 1
}

grep -q '^license "MIT"' "$repo/dub.sdl" || {
    echo "FAIL: DUB package license is not MIT" >&2
    exit 1
}

for symbol in     Region2D PlaneDescriptor PlaneByteLayout     OwnedByteResource tryAdoptMallocResource     OwnedRasterImportError OwnedRasterImportResult tryImportOwnedRaster     RasterLease RasterView WritableRasterView     trySumFloatToDouble tryFillRasterPlane     RasterTransformError tryTransformRasterPlane     RasterNeighbourhood3x3Error tryApplyRasterNeighbourhood3x3     RasterCopyError tryCopyRasterPlane     UbyteToFloatConversionError tryConvertUbyteToFloatPlane; do
    grep -q "$symbol" "$repo/docs/API.md" || {
        echo "FAIL: docs/API.md does not mention root-export family: $symbol" >&2
        exit 1
    }
done

echo "PASS: release documentation structure and API-family inventory"


grep -q '^## 0.1.0 — 2026-10-05$' "$repo/CHANGELOG.md" || {
    echo "FAIL: CHANGELOG.md does not contain the finalized 0.1.0 entry" >&2
    exit 1
}

grep -q 'freeze/api-0.1.0' "$repo/README.md" || {
    echo "FAIL: README.md does not identify the frozen 0.1.0 API checkpoint" >&2
    exit 1
}

grep -q 'v0.1.0 release candidate' "$repo/README.md" || {
    echo "FAIL: README.md release status is not synchronized" >&2
    exit 1
}

grep -q 'freeze/api-0.1.0' "$repo/docs/V0_1_RELEASE_NOTES.md" || {
    echo "FAIL: release notes do not identify the API freeze" >&2
    exit 1
}

grep -q '^description "High-performance raster engine for large and streamed raster data"$' "$repo/dub.sdl" || {
    echo "FAIL: unexpected DUB package description" >&2
    exit 1
}

grep -q '^authors "Alexander Bernardi"$' "$repo/dub.sdl" || {
    echo "FAIL: unexpected DUB package author metadata" >&2
    exit 1
}

echo "PASS: v0.1.0 release-facing metadata is synchronized"
