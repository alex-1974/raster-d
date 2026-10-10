#!/usr/bin/env python3
"""Check local version navigation in a staged raster-d Pages site."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: verify-versioned-pages.py SITE_DIR", file=sys.stderr)
        return 2

    site = Path(sys.argv[1])
    page = site / "versions.html"
    root = site / "raster.html"
    if not page.is_file() or not root.is_file():
        print("FAIL: versions.html or current raster.html missing", file=sys.stderr)
        return 1

    html = page.read_text(encoding="utf-8")
    if 'href="./raster.html"' not in html:
        print("FAIL: stable root documentation link missing", file=sys.stderr)
        return 1
    if 'href="./dev/raster.html"' not in html or not (site / "dev" / "raster.html").is_file():
        print("FAIL: development documentation link/page missing", file=sys.stderr)
        return 1
    if "The root documentation follows the latest published stable release." not in html:
        print("FAIL: navigation does not identify stable root", file=sys.stderr)
        return 1

    tagged = sorted(
        (p.name for p in site.iterdir()
         if p.is_dir() and re.fullmatch(r"v[0-9]+\.[0-9]+\.[0-9]+", p.name)),
        key=lambda s: tuple(map(int, s[1:].split("."))),
    )

    for tag in tagged:
        if not (site / tag / "raster.html").is_file():
            print(f"FAIL: missing documentation page for {tag}", file=sys.stderr)
            return 1
        if f'href="./{tag}/raster.html"' not in html:
            print(f"FAIL: missing version-navigation link for {tag}", file=sys.stderr)
            return 1

    labeled = re.findall(
        r'<li><a href="./(v[0-9]+\.[0-9]+\.[0-9]+)/raster.html">'
        r'[^<]* — latest stable release</a></li>',
        html,
    )
    if not tagged:
        print("FAIL: stable Pages root has no published version", file=sys.stderr)
        return 1
    # Reject a mixed site where the root landing page is stable but its
    # module/symbol pages or assets were copied from an unreleased checkout.
    stable_dir = site / tagged[-1]
    for stable_file in stable_dir.rglob("*"):
        if not stable_file.is_file():
            continue
        root_file = site / stable_file.relative_to(stable_dir)
        if not root_file.is_file() or root_file.read_bytes() != stable_file.read_bytes():
            print(
                f"FAIL: root differs from latest stable tag: "
                f"{stable_file.relative_to(stable_dir)}",
                file=sys.stderr,
            )
            return 1

    if tagged and labeled != [tagged[-1]]:
        print(
            f"FAIL: latest stable label {labeled!r} does not match "
            f"highest published release tag {tagged[-1]}",
            file=sys.stderr,
        )
        return 1
    if not tagged and labeled:
        print("FAIL: latest stable label without release tags", file=sys.stderr)
        return 1

    # Ensure every relative href in this hand-authored navigation page resolves.
    for href in re.findall(r'href="(\./[^"]+)"', html):
        if not (site / href[2:]).is_file():
            print(f"FAIL: broken navigation link {href}", file=sys.stderr)
            return 1

    print(
        "PASS: versioned Pages navigation: "
        f"stable root, dev and {len(tagged)} tagged release(s); "
        f"stable={tagged[-1] if tagged else 'none'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
