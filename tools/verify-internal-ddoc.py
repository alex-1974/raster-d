#!/usr/bin/env python3
from pathlib import Path
import re, sys

ROOT=Path("source/raster")
DECL_RE=re.compile(
    r"^\s*(?:(?P<explicit>private|package(?:\([^)]*\))?)\s+)?"
    r"(?:(?:static|final|const|pure|nothrow|@safe|@nogc)\s+)*"
    r"(?P<return>(?:const\([^)]*\)|immutable\([^)]*\)|shared\([^)]*\)|[A-Za-z_][A-Za-z0-9_!.]*)(?:\s*\*)?(?:\[[^\]]*\])?)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:!\([^)]*\))?\s*\("
)
SECTION_RE=re.compile(r"^\s*(?P<visibility>private|public|protected|package(?:\([^)]*\))?)\s*:\s*$")
PROTECTION_LINE_RE=re.compile(
    r"^\s*(?P<visibility>private|public|protected|package(?:\([^)]*\))?)\s*$"
)

def has_ddoc(lines,i):
    i-=1
    while i>=0:
        stripped=lines[i].strip()
        if not stripped:
            i-=1
            continue
        if PROTECTION_LINE_RE.match(lines[i]) and not stripped.endswith(":"):
            i-=1
            continue
        if stripped.startswith("@"):
            i-=1
            continue
        break
    if i<0: return False
    if lines[i].lstrip().startswith("///"): return True
    if lines[i].strip().endswith("+/") or lines[i].strip().endswith("*/"):
        while i>=0:
            if "/++" in lines[i] or "/**" in lines[i]: return True
            if "/*" in lines[i] or "/+" in lines[i]: return False
            i-=1
    return False

def delta(line):
    code=line.split("//",1)[0]
    return code.count("{")-code.count("}")

def audit(path):
    text=path.read_text()
    unittest_marker=text.find("version (unittest)")
    if unittest_marker>=0:
        text=text[:unittest_marker]
    lines=text.splitlines(); failures=[]; depth=0; module_package=False; sections={}; pending=None
    for i,line in enumerate(lines):
        s=SECTION_RE.match(line)
        if s:
            v=s.group("visibility")
            if depth==0 and v.startswith("package"): module_package=True
            else: sections[depth]=v
            pending=None
        p=PROTECTION_LINE_RE.match(line)
        if p and not line.strip().endswith(":"):
            pending=(depth,p.group("visibility"))
        m=DECL_RE.match(line)
        if m and m.group("return") in {"struct","class","union","enum","template","alias"}: m=None
        if m:
            v=m.group("explicit")
            if v is None and pending is not None and pending[0]==depth:
                v=pending[1]
            if v is None:
                v=sections.get(depth)
            if v is None and module_package and depth==0: v="package"
            internal=v is not None and (v=="private" or v.startswith("package"))
            if internal and not has_ddoc(lines,i):
                failures.append(f"{path}:{i+1}: internal function {m.group('name')} lacks Ddoc")
            pending=None
        elif line.strip() and not p and not line.lstrip().startswith(("@","/","*","+")):
            pending=None
        depth += delta(line)
        if depth<0: depth=0
        for d in list(sections):
            if d>depth: del sections[d]
    return failures

def main():
    if not ROOT.is_dir():
        print(f"error: missing source tree: {ROOT}",file=sys.stderr); raise SystemExit(1)
    failures=[]
    for p in sorted(ROOT.rglob("*.d")): failures.extend(audit(p))
    if failures:
        print("FAIL: internal Ddoc contract",file=sys.stderr)
        for f in failures: print(" ",f,file=sys.stderr)
        raise SystemExit(1)
    print("PASS: every production private/package function has adjacent Ddoc")

if __name__=="__main__": main()
