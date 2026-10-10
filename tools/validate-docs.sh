#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required=(
  LICENSE
  README.md
  ROADMAP.md
  BENCHMARK.md
  DESIGN.md
  docs/API.md
  docs/API_0_2.md
  docs/ddoc-style.md
  docs/public-api-example-audit.md
  docs/README.md
  docs/tutorial/getting-started.md
  docs/how-to/common-operations.md
  docs/glossary.md
  docs/accuracy-and-validation.md
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

if grep -Eq '^[[:space:]]*dflags[[:space:]].*-preview=' "$repo/dub.sdl"; then
    echo "FAIL: published package exports a preview language flag" >&2
    exit 1
fi

grep -Fxq 'MIT License' "$repo/LICENSE" || {
    echo "FAIL: LICENSE text does not match MIT package metadata" >&2
    exit 1
}

grep -Fxq 'Copyright (c) 2026 Alexander Bernardi' "$repo/LICENSE" || {
    echo "FAIL: LICENSE copyright does not match package ownership metadata" >&2
    exit 1
}

v02_symbols=(
  isRasterSampleType isNumericRasterSample isExactConvertible
  OwnedByteResource tryAdoptMallocResource
  PlaneByteLayout PlaneDescriptor Region2D
  OwnedRasterImportError OwnedRasterImportResult
  OwnedRasterResourceDisposition tryImportOwnedRaster
  RasterLease RasterView WritableRasterView
  RasterSumError RasterSumResult RasterExtremaError RasterExtremaResult
  RasterMinMaxResult RasterMeanError RasterMeanResult
  sum min max minMax mean trySumFloatToDouble
  tryFillRasterPlane fill
  RasterTransformError tryTransformRasterPlane transformInto
  RasterZipTransformError zipTransformInto
  addInto subtractInto multiplyInto divideInto
  RasterAllocatedTransformError RasterAllocatedTransformResult
  tryTransformAllocated
  NeighbourhoodShape
  RasterBorderKind RasterValidBorder RasterConstantBorder
  RasterClampBorder RasterMirrorBorder RasterWrapBorder
  RasterNeighbourhood3x3Error tryApplyRasterNeighbourhood3x3
  RasterNeighbourhoodError applyNeighbourhoodInto
  FixedConvolutionKernel convolveInto
  RasterCopyError tryCopyRasterPlane copyInto
  RasterConversionPolicy RasterConversionError
  UbyteToFloatConversionError convertRasterInto
  tryConvertUbyteToFloatPlane
  RasterAllocatedConversionError RasterAllocatedConversionResult
  tryConvertAllocated
)

for symbol in "${v02_symbols[@]}"; do
    grep -q "$symbol" "$repo/docs/API_0_2.md" || {
        echo "FAIL: docs/API_0_2.md does not mention root-export symbol: $symbol" >&2
        exit 1
    }
done

echo "PASS: v0.2 release-candidate API inventory covers ${#v02_symbols[@]} root exports"

grep -q '^## 0.1.0 — 2026-10-05$' "$repo/CHANGELOG.md" || {
    echo "FAIL: CHANGELOG.md does not retain the finalized 0.1.0 entry" >&2
    exit 1
}

grep -q 'freeze/api-0.1.0' "$repo/README.md" || {
    echo "FAIL: README.md does not retain the frozen 0.1.0 API checkpoint" >&2
    exit 1
}

grep -q 'freeze/feature-0.2.0' "$repo/README.md" || {
    echo "FAIL: README.md does not identify the v0.2 feature freeze" >&2
    exit 1
}

grep -q 'freeze/api-0.2.0' "$repo/README.md" || {
    echo "FAIL: README.md does not identify the completed v0.2 API checkpoint" >&2
    exit 1
}

grep -q 'freeze/api-0.1.0' "$repo/docs/V0_1_RELEASE_NOTES.md" || {
    echo "FAIL: historical v0.1 release notes do not identify the API freeze" >&2
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



# A release candidate must not regress to the stale status that previously
# survived documentation updates. Check structural facts only; historical
# release notes may legitimately retain old wording.
grep -Eq '^v0[.]2[.]0 is a release candidate' "$repo/README.md" || {
    echo "FAIL: README.md must identify v0.2.0 as the release candidate" >&2
    exit 1
}

grep -q 'is frozen at `freeze/api-0.2.0`' "$repo/README.md" || {
    echo "FAIL: README.md must identify the completed v0.2 API freeze" >&2
    exit 1
}

if grep -Eiq 'the public API is being audited before|API freeze pending|freeze/api-0[.]2[.]0.*(to be created|will be created)' "$repo/README.md"; then
    echo "FAIL: README.md retains obsolete pre-API-freeze wording" >&2
    exit 1
fi

grep -q '^## 0.2.0 — Release candidate (unpublished)
 "$repo/CHANGELOG.md" || {
    echo "FAIL: CHANGELOG.md needs an explicitly unpublished v0.2.0 section" >&2
    exit 1
}

grep -q '^## 0.1.0 — 2026-10-05
 "$repo/CHANGELOG.md" || {
    echo "FAIL: CHANGELOG.md must retain historical v0.1.0 section" >&2
    exit 1
}

[[ -f "$repo/docs/V0_2_FINAL_RELEASE_CONTENT_GATE.md" ]] || {
    echo "FAIL: mandatory final release-content gate documentation is absent" >&2
    exit 1
}

echo "PASS: candidate release status and API-freeze facts agree"

echo "PASS: release documentation structure and metadata are synchronized"
