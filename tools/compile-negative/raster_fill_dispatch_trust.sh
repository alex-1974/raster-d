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
source=(repo/'source/raster/internal/fill_dispatch.d').read_text()
helpers=source[source.index('/++\n    Safety:'):]
prefix='module probe;\nstruct Pod { uint a; ushort b; ubyte c; ubyte d; }\n'
main="""
@safe nothrow @nogc void attributeControl()
{
    float[4] a; ubyte[4] b; Pod[4] c;
    fillCanonical(a.ptr,2,2,2,1.5f);
    fillCanonical(b.ptr,2,2,2,cast(ubyte)7);
    fillCanonical(c.ptr,2,2,2,Pod(7,11,13,17));
}
"""
(tmp/'control.d').write_text(prefix+helpers+main)
(tmp/'safe.d').write_text(prefix+helpers.replace('@trusted','@safe')+main)
PROBE
"$compiler" -c -preview=dip1000 -of="$task_tmp/control.o" "$task_tmp/control.d"
echo 'PASS actual-source safe/nothrow/nogc controls: float, ubyte, POD'
if "$compiler" -c -preview=dip1000 -of="$task_tmp/safe.o" "$task_tmp/safe.d" > "$task_tmp/safe.log" 2>&1; then
    echo 'FAIL redundant trust'; exit 1
fi
if ! grep -Ei '(pointer|index|slice).*(@safe|safe function)' "$task_tmp/safe.log" >/dev/null; then
    cat "$task_tmp/safe.log"; exit 1
fi
echo 'PASS actual-source safe challenge: row formation requires trust'
