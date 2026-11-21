#!/usr/bin/env bash
# Rendering/CPU benchmark (autopilot, chapter 2) under Xvfb with an isolated user dir.
# Usage: tools/bench.sh [out.json] [extra godot user args...]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-$(cd ../.. && pwd)/tools/bin/path/godot}"
OUT="${1:-/tmp/volt-bench.json}"; shift || true
ISO="$(mktemp -d /tmp/volt-bench-XXXXXX)"
DISP=":$((90 + RANDOM % 9))"
Xvfb "$DISP" -screen 0 1920x1080x24 >/dev/null 2>&1 &
XPID=$!
trap 'kill $XPID 2>/dev/null || true; rm -rf "$ISO"' EXIT
sleep 1
XDG_DATA_HOME="$ISO" DISPLAY="$DISP" WAYLAND_DISPLAY= timeout 120 "$GODOT" --path . --display-driver x11 \
  --resolution 1920x1080 ${VOLT_RENDER:+--rendering-method $VOLT_RENDER} -- --bench="$OUT" "$@" 2>&1 | grep -E "bench:|SCRIPT ERROR|Parse Error" | head -5 || true
