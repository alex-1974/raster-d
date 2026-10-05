#!/usr/bin/env python3
from __future__ import annotations
import re, sys
from pathlib import Path

REQUIRED=("Authors:","Copyright:","License:","Date:")
NAMED=re.compile(r"(?m)^\s*\*?\s*[A-Za-z][A-Za-z_ ]*:\s*$")

def prose(doc):
    m=NAMED.search(doc); text=doc[:m.start()] if m else doc
    lines=[]
    for raw in text.splitlines():
        line=re.sub(r"^\s*\*?\s?","",raw).strip()
        if line.startswith("---"): continue
        lines.append(line)
    return [" ".join(x.split()) for x in re.split(r"\n\s*\n","\n".join(lines)) if x.strip()]

def main():
    root=Path(sys.argv[1] if len(sys.argv)>1 else ".").resolve()
    source=root/"source"/"raster"
    sources=sorted(p for p in source.rglob("*.d") if "internal" not in p.relative_to(source).parts)
    failures=[]
    for path in sources:
        text=path.read_text()
        mm=re.search(r"(?m)^module\s+[A-Za-z_][\w.]*\s*;",text)
        if not mm:
            failures.append(f"{path.relative_to(root)}: missing module declaration"); continue
        prefix=text[:mm.start()]
        dm=re.search(r"/\+\+([\s\S]*?)\+\/\s*$",prefix) or re.search(r"/\*\*([\s\S]*?)\*/\s*$",prefix)
        if not dm:
            failures.append(f"{path.relative_to(root)}: missing module Ddoc immediately before module declaration"); continue
        doc=dm.group(1)
        missing=[s for s in REQUIRED if s not in doc]
        if missing: failures.append(f"{path.relative_to(root)}: missing module Ddoc sections: {', '.join(missing)}")
        ps=prose(doc)
        if not ps: failures.append(f"{path.relative_to(root)}: missing module Ddoc summary")
        elif len(ps)<2: failures.append(f"{path.relative_to(root)}: missing substantive module Ddoc description after summary")
    if failures:
        for f in failures: print("error:",f,file=sys.stderr)
        raise SystemExit(1)
    print(f"PASS: public module Ddoc contract covers {len(sources)} modules")

if __name__=="__main__": main()
