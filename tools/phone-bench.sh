#!/usr/bin/env bash
# usage: tools/phone-bench.sh NAME ARGS...  e.g. tools/phone-bench.sh high --quality=high
# Runs one benchmark on a USB-connected Android phone (debug build installed).
# The request goes in user://bench_request.txt (Android launchers drop CLI args);
# the game runs it in save-isolated mode and writes user://bench_NAME.json.
ADB="/home/BADCOOL-242/Documents/Codex/2026-11-17/referenced-chatgpt-conversation-this-is-an/work/android-tools/sdk/platform-tools/adb"
PKG=studio.badcool.voltrun
NAME=$1; shift
REQ="--bench=user://bench_$NAME.json"
for a in "$@"; do REQ="$REQ\n$a"; done
timeout 15 "$ADB" shell am force-stop $PKG
timeout 15 "$ADB" shell "run-as $PKG rm -f files/bench_$NAME.json"
timeout 15 "$ADB" shell "run-as $PKG sh -c 'printf \"$REQ\n\" > files/bench_request.txt'"
timeout 15 "$ADB" shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
for i in $(seq 1 60); do
  sleep 1.5
  out=$(timeout 10 "$ADB" shell "run-as $PKG cat files/bench_$NAME.json" 2>/dev/null)
  if echo "$out" | grep -q fps_avg; then echo "$out" > /tmp/phone_bench_$NAME.json; break; fi
done
timeout 15 "$ADB" shell am force-stop $PKG
[ -s /tmp/phone_bench_$NAME.json ] && python3 -c "
import json;d=json.load(open('/tmp/phone_bench_$NAME.json'))
print('$NAME', d.get('device'), '| fps avg', d['fps_avg'], '1% low', d['fps_1pct_low'], '0.1% low', d['fps_01pct_low'], '| frame ms', d['frames'], '| gpu ms', d.get('gpu'), '| draw ms', d['script'], '| draws', d['draws']['avg'], '| max draw ms', d.get('script_max'))" || echo "$NAME: no result"
