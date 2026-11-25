#!/usr/bin/env bash
# Runs the headless test suite with an isolated user-data directory.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-$(cd ../.. && pwd)/tools/bin/path/godot}"
ISO="$(mktemp -d /tmp/kavi-test-XXXXXX)"
export XDG_DATA_HOME="$ISO" KAVI_TEST_ISOLATED="$ISO"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
set +e
"$GODOT" --headless --path . --script res://tests/run_tests.gd
rc=$?
# Smoke: boot the real game (title + first-launch tutorial) and fail on any script error.
SMOKE="$("$GODOT" --headless --path . --quit-after 600 2>&1 || true)"
# (here-string, not `echo | grep -q`: with pipefail, grep -q closing the pipe early
# made a large error log count as "clean")
if grep -q "SCRIPT ERROR\|Parse Error" <<< "$SMOKE"; then
  echo "SMOKE FAIL: game boot produced script errors:"; grep -A2 "SCRIPT ERROR" <<< "$SMOKE" | head -20 || true; rc=1
else
  echo "smoke: game boots clean (600 frames)"
fi
rm -rf "$ISO"
exit $rc
