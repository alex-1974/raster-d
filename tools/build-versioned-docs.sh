#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

work_dir="$root/build/versioned-docs"
archives_dir="$work_dir/archives"
staging_dir="$work_dir/staging"
output_dir="$work_dir/output"
site_dir="$work_dir/site"

rm -rf "$work_dir"
mkdir -p "$archives_dir" "$staging_dir" "$output_dir" "$site_dir"

mapfile -t versions < <(
    git tag --list 'v[0-9]*' --sort=v:refname
)

for version in "${versions[@]}"; do
    echo "=== $version ==="

    git rev-parse --verify --quiet "$version^{commit}" >/dev/null || {
        echo "error: invalid release tag: $version" >&2
        exit 1
    }

    archive_dir="$archives_dir/$version"
    version_output="$output_dir/$version"
    version_site="$site_dir/$version"

    mkdir -p "$archive_dir" "$version_site"

    git archive "$version" \
        | tar -x -C "$archive_dir"

    SOURCE_ROOT="$archive_dir" \
    TOOL_ROOT="$root" \
    VERIFY_CONTRACTS=0 \
    INVENTORY_ONLY=1 \
    OUTPUT_ROOT="$version_output" \
        bash "$root/tools/build-docs.sh"

    cp -a "$version_output/build/ddox/site/." "$version_site/"

    test -f "$version_site/raster.html"
done

current_output="$output_dir/current"

SOURCE_ROOT="$root" \
TOOL_ROOT="$root" \
VERIFY_CONTRACTS=1 \
INVENTORY_ONLY=0 \
OUTPUT_ROOT="$current_output" \
    bash "$root/tools/build-docs.sh"

mkdir -p "$site_dir/dev"
cp -a "$current_output/build/ddox/site/." "$site_dir/dev/"

# Root URLs serve the latest published stable release, never the moving
# release candidate or development checkout. Preserve tagged copies separately.
if (("${#versions[@]}" > 0)); then
    latest="${versions[${#versions[@]}-1]}"
    cp -a "$site_dir/$latest/." "$site_dir/"
else
    echo "error: no published release tags for stable Pages root" >&2
    exit 1
fi

{
    cat <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>raster-d API documentation versions</title>
</head>
<body>
<h1>raster-d API documentation</h1>
<p>The root documentation follows the latest published stable release.</p>
<ul>
<li><a href="./raster.html">latest stable (root)</a></li>
<li><a href="./dev/raster.html">development / unreleased</a></li>
HTML

    if (("${#versions[@]}" > 0)); then
        latest="${versions[${#versions[@]}-1]}"

        for version in "${versions[@]}"; do
            suffix=""
            if [[ "$version" == "$latest" ]]; then
                suffix=" — latest stable release"
            fi
            printf '<li><a href="./%s/raster.html">%s%s</a></li>\n' \
                "$version" "$version" "$suffix"
        done
    fi

    cat <<'HTML'
</ul>
</body>
</html>
HTML
} > "$site_dir/versions.html"

test -f "$site_dir/raster.html"
test -f "$site_dir/versions.html"

python3 "$root/tools/verify-versioned-pages.py" "$site_dir"

echo "PASS: versioned raster-d documentation site built"
