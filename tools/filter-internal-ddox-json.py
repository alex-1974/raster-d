#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, re
from pathlib import Path

MODULE_RE = re.compile(r"^\s*module\s+([A-Za-z_][A-Za-z0-9_.]*)\s*;")
SECTION_RE = re.compile(r"^\s*(private|public|protected|package(?:\([^)]*\))?)\s*:\s*$")
PROTECTION_LINE_RE = re.compile(
    r"^\s*(private|public|protected|package(?:\([^)]*\))?)\s*$"
)
DECL_RE = re.compile(
    r"^\s*(?:(?P<explicit>private|package(?:\([^)]*\))?|public|protected)\s+)?"
    r"(?:(?:static|final|const|pure|nothrow|@safe|@nogc)\s+)*"
    r"(?P<return>(?:const\([^)]*\)|immutable\([^)]*\)|shared\([^)]*\)|[A-Za-z_][A-Za-z0-9_!.]*)(?:\s*\*)?(?:\[[^\]]*\])?)\s+"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:!\([^)]*\))?\s*\("
)

def brace_delta(line: str) -> int:
    return line.split("//", 1)[0].count("{") - line.split("//", 1)[0].count("}")

def internal_declarations(source_root: Path) -> set[tuple[str,int]]:
    result=set()
    for path in sorted((source_root/"source"/"raster").rglob("*.d")):
        if "/internal/" in path.as_posix():
            continue
        lines=path.read_text().splitlines()
        module=None
        for line in lines:
            m=MODULE_RE.match(line)
            if m:
                module=m.group(1); break
        if module is None: continue
        depth=0; visibility_by_depth={}; pending_visibility=None
        for index,line in enumerate(lines):
            section=SECTION_RE.match(line)
            if section:
                visibility_by_depth[depth]=section.group(1)
                pending_visibility=None
            protection=PROTECTION_LINE_RE.match(line)
            if protection and not line.strip().endswith(":"):
                pending_visibility=(depth, protection.group(1))
            decl=DECL_RE.match(line)
            if decl:
                explicit=decl.group("explicit")
                pending=(
                    pending_visibility[1]
                    if pending_visibility is not None
                    and pending_visibility[0] == depth
                    else None
                )
                vis=explicit if explicit is not None else pending
                if vis is None:
                    vis=visibility_by_depth.get(depth)
                if vis=="private" or (vis is not None and vis.startswith("package")):
                    result.add((module,index+1))
                pending_visibility=None
            elif line.strip() and not protection and not line.lstrip().startswith(("@","/","*","+")):
                pending_visibility=None
            depth += brace_delta(line)
            for d in list(visibility_by_depth):
                if d>depth: del visibility_by_depth[d]
    return result

def module_name(node):
    if not isinstance(node,dict): return None
    name=node.get("name")
    return name if isinstance(name,str) and name.startswith("raster") else None

def filter_node(node,module,internal):
    removed=0
    if isinstance(node,list):
        kept=[]
        for item in node:
            im=module_name(item) or module
            line=item.get("line") if isinstance(item,dict) else None
            if im is not None and isinstance(line,int) and (im,line) in internal:
                removed += 1; continue
            removed += filter_node(item,im,internal); kept.append(item)
        node[:] = kept; return removed
    if not isinstance(node,dict): return 0
    current=module_name(node) or module
    for key in list(node):
        value=node[key]
        if isinstance(value,dict):
            vm=module_name(value) or current
            line=value.get("line")
            if vm is not None and isinstance(line,int) and (vm,line) in internal:
                del node[key]; removed += 1; continue
            removed += filter_node(value,vm,internal)
        elif isinstance(value,list):
            removed += filter_node(value,current,internal)
    return removed

def main():
    p=argparse.ArgumentParser()
    p.add_argument("json_file",type=Path); p.add_argument("source_root",type=Path)
    a=p.parse_args()
    internal=internal_declarations(a.source_root)
    data=json.loads(a.json_file.read_text())
    removed=filter_node(data,None,internal)
    a.json_file.write_text(json.dumps(data,separators=(",",":")))
    print(f"PASS: source-aware DDox filter removed {removed} internal declarations from {len(internal)} source-internal declarations")

if __name__=="__main__":
    main()
