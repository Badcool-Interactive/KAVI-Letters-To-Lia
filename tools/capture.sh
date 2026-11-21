#!/usr/bin/env bash
# Scripted capture run: autopilot plays scripted beats and saves PNGs.
# Uses an isolated user-data dir and a private Xvfb display.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-$(cd ../.. && pwd)/tools/bin/path/godot}"
OUT="${1:-$PWD/captures/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUT"
ISO="$(mktemp -d /tmp/volt-cap-XXXXXX)"
DISP=":$((90 + RANDOM % 9))"
Xvfb "$DISP" -screen 0 1920x1080x24 >/dev/null 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null || true; rm -rf "$ISO"' EXIT
sleep 1
XDG_DATA_HOME="$ISO" DISPLAY="$DISP" WAYLAND_DISPLAY= timeout 480 "$GODOT" --path . --display-driver x11 \
  --resolution 1920x1080 ${VOLT_RENDER:+--rendering-driver $VOLT_RENDER} -- --capture="$OUT" 2>&1 | grep -v "^\s*at:" | tail -25
ls "$OUT"
