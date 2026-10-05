#!/usr/bin/env python3
from __future__ import annotations
import argparse,re,sys
from pathlib import Path

ROW_RE=re.compile(r"^\| `(?P<page>raster(?:\.[A-Za-z0-9_]+)+)` \| (?P<status>existing|add) \| (?P<family>[^|]+?) \|$")

def fail(msg): print("error:",msg,file=sys.stderr); raise SystemExit(1)

def args():
    p=argparse.ArgumentParser()
    p.add_argument("site",type=Path)
    p.add_argument("audit",type=Path,nargs="?")
    p.add_argument("--source-root",type=Path,default=Path("."))
    p.add_argument("--inventory-only",action="store_true")
    p.add_argument("--require-complete",action="store_true")
    return p.parse_args()

def module_pages(site,source_root):
    pages={site/"raster.html"}
    src=source_root/"source"/"raster"
    for source in src.rglob("*.d"):
        rel=source.relative_to(src)
        if "internal" in rel.parts or rel.name=="package.d": continue
        pages.add(site/"raster"/rel.with_suffix(".html"))
    return pages

def page_name(site,page):
    return ".".join(page.relative_to(site).with_suffix("").parts)

def rendered(site,source_root):
    excluded={site/"index.html",*module_pages(site,source_root)}
    return {page_name(site,p):p for p in site.rglob("*.html") if p not in excluded}

def documented_count(root):
    src=root/"source"/"raster"; count=0
    legacy=re.compile(r"^[ \t]*\*[ \t]+Example:[ \t]*$",re.MULTILINE)
    docunit=re.compile(r"^[ \t]*///[^\n]*\n(?:[ \t]*@[A-Za-z_][A-Za-z0-9_]*(?:\([^\n]*\))?[ \t]+)*unittest\b",re.MULTILINE)
    for p in sorted(src.rglob("*.d")):
        if "internal" in p.relative_to(src).parts: continue
        text=p.read_text()
        if legacy.search(text): fail(f"legacy inline Example block remains: {p}")
        count += len(docunit.findall(text))
    return count

def parse_audit(path):
    rows={}
    if path is None or not path.is_file(): return rows
    for line in path.read_text().splitlines():
        m=ROW_RE.match(line)
        if m: rows[m.group("page")]=(m.group("status"),m.group("family").strip())
    return rows

def main():
    a=args()
    if not a.site.is_dir(): fail(f"DDox site missing: {a.site}")
    pages=rendered(a.site,a.source_root)
    print("PUBLIC_DDOX_INVENTORY_BEGIN")
    for name in sorted(pages): print(name)
    print("PUBLIC_DDOX_INVENTORY_END")
    if a.inventory_only:
        print(f"PASS: inventoried {len(pages)} public DDox symbol pages"); return
    rows=parse_audit(a.audit)
    missing=sorted(set(pages)-set(rows)); stale=sorted(set(rows)-set(pages))
    if missing: fail("public DDox pages missing from audit:\n  "+"\n  ".join(missing))
    if stale: fail("audit rows without public DDox pages:\n  "+"\n  ".join(stale))
    compiled=documented_count(a.source_root)
    existing=add=0
    for name,page in sorted(pages.items()):
        status,_=rows[name]
        if status=="existing":
            existing += 1
            if ">Example<" not in page.read_text(errors="replace"):
                fail(f"expected rendered Example missing: {name}")
        else: add += 1
    if compiled != existing:
        fail(f"documented unittest count {compiled} != existing audit rows {existing}")
    if a.require_complete and add:
        fail(f"{add} public pages still require examples")
    print(f"PASS: public API example audit covers {len(pages)} pages (existing={existing} compiled, add={add})")

if __name__=="__main__": main()
