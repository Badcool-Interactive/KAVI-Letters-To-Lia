#!/usr/bin/env bash
# Builds the Web export and publishes it to GitHub Pages (gh-pages branch).
# Live at https://singh679.github.io/volt-run-luminous/
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(cd ../.. && pwd)"
S="$ROOT/sandbox/godot-userdata"
mkdir -p build/web
XDG_DATA_HOME="$S/android-export" XDG_CONFIG_HOME="$S/android-export-config" \
  "$ROOT/tools/bin/path/godot" --headless --path . --export-release "Web" "$PWD/build/web/index.html"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
cp -r build/web/. "$D/"; touch "$D/.nojekyll"
cd "$D" && git init -q -b gh-pages && git add -A && git commit -qm "Web build $(date -u +%F)"
git push -q -f https://github.com/singh679/volt-run-luminous.git gh-pages
echo "Deployed: https://singh679.github.io/volt-run-luminous/"
