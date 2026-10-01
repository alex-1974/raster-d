#!/usr/bin/env bash
set -euo pipefail
compiler="${1:-${DC:-dmd}}"
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
python3 - "$repo_root" "$tmp_dir" <<'PY'
from pathlib import Path
import sys
repo,tmp=map(Path,sys.argv[1:])
source=(repo/'source/raster/internal/transform_dispatch.d').read_text().split('version (unittest)',1)[0]
source=source.replace('module raster.internal.transform_dispatch;','module raster.probe_transform;')
main='''
void main() { float[4] a,b;
    executeApprovedCanonicalPointTransform!probe(a.ptr,2,1,2,2,b.ptr,2,1); }
'''
good='float probe(float value) @safe pure nothrow @nogc { return value; }\n'
(tmp/'control.d').write_text(source+good+main)
(tmp/'safe_challenge.d').write_text(source.replace('@trusted','@safe')+good+main)
(tmp/'unsafe_alias.d').write_text(source+'float probe(float value) @system pure nothrow @nogc { return value; }\n'+main)
(tmp/'impure_alias.d').write_text(source+'uint counter; float probe(float value) @safe nothrow @nogc { ++counter; return value; }\n'+main)
PY
"$compiler" -c -preview=dip1000 -of="$tmp_dir/control.o" "$tmp_dir/control.d"
echo 'PASS actual-source control'
for probe in safe_challenge unsafe_alias impure_alias; do
    if "$compiler" -c -preview=dip1000 -of="$tmp_dir/$probe.o" \
        "$tmp_dir/$probe.d" > "$tmp_dir/$probe.log" 2>&1; then
        echo "FAIL expected rejection: $probe"
        exit 1
    fi
    case "$probe" in
        safe_challenge) pattern='pointer arithmetic.*@safe' ;;
        unsafe_alias) pattern='cannot call.*@system' ;;
        impure_alias) pattern='cannot call impure' ;;
    esac
    if ! grep -E "$pattern" "$tmp_dir/$probe.log" >/dev/null; then
        cat "$tmp_dir/$probe.log"
        exit 1
    fi
    echo "PASS expected rejection: $probe"
done
