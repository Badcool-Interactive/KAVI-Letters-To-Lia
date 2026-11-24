#!/usr/bin/env bash
# Play the LOCAL web build (build/web) in your browser before anything is pushed.
# Serves it at http://localhost:8060 (this computer only) and opens the page.
# Stop with Ctrl+C.
set -euo pipefail
cd "$(dirname "$0")/../build/web"
( sleep 1; xdg-open "http://localhost:8060/" >/dev/null 2>&1 || true ) &
echo "KAVI web build: http://localhost:8060/  (Ctrl+C to stop)"
exec python3 -m http.server 8060 --bind 127.0.0.1
