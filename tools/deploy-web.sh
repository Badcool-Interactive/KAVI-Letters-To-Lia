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
# Page title and link previews say KAVI (project config/name stays VOLT/RUN on
# purpose: it names the desktop save folder).
URL="https://singh679.github.io/volt-run-luminous/"
sed -i "s|<title>[^<]*</title>|<title>KAVI: Letters to Lia</title><meta name=\"description\" content=\"A cozy 2D runner: Kavi, a little courier robot, carries letters across Europe to his friend Lia. Play free in your browser.\"><meta property=\"og:title\" content=\"KAVI: Letters to Lia\"><meta property=\"og:description\" content=\"A cozy 2D runner. Play free in your browser.\"><meta property=\"og:image\" content=\"${URL}index.png\"><meta property=\"og:url\" content=\"${URL}\">|" "$D/index.html"
cd "$D" && git init -q -b gh-pages && git add -A && git commit -qm "Web build $(date -u +%F)"
git push -q -f https://github.com/singh679/volt-run-luminous.git gh-pages
echo "Deployed: https://singh679.github.io/volt-run-luminous/"
