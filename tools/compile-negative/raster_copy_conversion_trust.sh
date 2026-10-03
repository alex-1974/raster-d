#!/usr/bin/env bash
set -euo pipefail
compiler="${1:-${DC:-dmd}}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_tmp="$(mktemp -d)"
trap 'rm -rf "$task_tmp"' EXIT
python3 - "$repo_root" "$task_tmp" <<'PROBE'
from pathlib import Path
import sys
repo,tmp=map(Path,sys.argv[1:])
for op in ['copy','conversion']:
 source=(repo/f'source/raster/internal/{op}_dispatch.d').read_text()
 helpers=source[source.index('/++\n    Safety: callers'):]
 prefix='module probe;\nstruct Pod { uint a; ushort b; ubyte c; ubyte d; }\n'
 control="""
@safe pure nothrow @nogc void attributeControl()
{
    ubyte[4] a, b; float[4] c, d; Pod[4] e, f; uint[2][4] g, h;
    executeApprovedRows(a.ptr, 2, b.ptr, 2, 2, 2);
    executeApprovedRows(c.ptr, 2, d.ptr, 2, 2, 2);
    executeApprovedRows(e.ptr, 2, f.ptr, 2, 2, 2);
    executeApprovedRows(a.ptr, 2, c.ptr, 2, 2, 2);
    executeApprovedRows(g.ptr, 2, h.ptr, 2, 2, 2);
}
"""
 (tmp/f'{op}-control.d').write_text(prefix+helpers+control)
 (tmp/f'{op}-safe.d').write_text(prefix+helpers.replace('@trusted','@safe')+control)
PROBE
for op in copy conversion; do
    "$compiler" -c -preview=dip1000 -of="$task_tmp/$op-control.o" "$task_tmp/$op-control.d"
    echo "PASS $op actual-source safe/pure/nothrow/nogc controls: ubyte, float, POD, static array, exact conversion"
    if "$compiler" -c -preview=dip1000 -of="$task_tmp/$op-safe.o" "$task_tmp/$op-safe.d" > "$task_tmp/$op-safe.log" 2>&1; then
        echo "FAIL redundant $op row trust"; exit 1
    fi
    if ! grep -Ei '(pointer|index|slice).*(@safe|safe function)' "$task_tmp/$op-safe.log" >/dev/null; then
        cat "$task_tmp/$op-safe.log"; exit 1
    fi
    echo "PASS $op actual-source safe challenge: scoped row formation requires trust"
done
