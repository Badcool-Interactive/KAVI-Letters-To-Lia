#!/usr/bin/env bash
# Renders the Graphics page pictures: every preset by day and in the evening,
# from the same Scenic View moment (0.8.34). Output: assets/ui/preset_<p>_<tod>.jpg
set -euo pipefail
cd "$(dirname "$0")/.."
FF="$(cd ../.. && pwd)/tools/bin/path/ffmpeg"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for p in low medium high extreme; do
  for tod in day evening; do
    VOLT_CAPTURE_ARGS="--presetpic --graphics=$p --tod=$tod" VOLT_TAIL=3 tools/capture.sh "$T/$p-$tod" >/dev/null 2>&1 || true
    "$FF" -v error -y -i "$T/$p-$tod/pic.png" -vf "crop=1280:720:100:250,scale=960:540" -q:v 3 "assets/ui/preset_${p}_${tod}.jpg"
    echo "preset_${p}_${tod}.jpg"
  done
done
