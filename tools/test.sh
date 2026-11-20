#!/usr/bin/env bash
# Runs the headless test suite with an isolated user-data directory.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-$(cd ../.. && pwd)/tools/bin/path/godot}"
ISO="$(mktemp -d /tmp/volt-test-XXXXXX)"
export XDG_DATA_HOME="$ISO" VOLT_TEST_ISOLATED="$ISO"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tests/run_tests.gd
rc=$?
rm -rf "$ISO"
exit $rc
