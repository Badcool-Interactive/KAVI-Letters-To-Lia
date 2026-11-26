#!/usr/bin/env bash
# Renders KAVI's music (scripts/synth.gd compose()) and encodes OGG loops into
# assets/music/. Deterministic: same code -> same songs.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(cd ../.. && pwd)"
GODOT="${GODOT_BIN:-$ROOT/tools/bin/path/godot}"
FFMPEG="${FFMPEG_BIN:-$ROOT/tools/bin/path/ffmpeg}"
TMP="$(mktemp -d /tmp/kavi-music-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
KAVI_MUSIC_TMP="$TMP" "$GODOT" --headless --path . --script res://tools/render_music.gd
for f in "$TMP"/*.wav; do
  name="$(basename "$f" .wav)"
  "$FFMPEG" -loglevel error -y -i "$f" -c:a libvorbis -q:a 2 "assets/music/$name.ogg"
done
ls -la assets/music/*.ogg
