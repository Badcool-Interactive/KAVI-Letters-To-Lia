#!/usr/bin/env bash
# Play the LOCAL web build (build/web) in your browser before anything is pushed.
# Serves it at http://localhost:8060 (this computer only) and opens the page.
# If a server is already running on that port, it just opens the page again
# (the running server always serves the newest build from disk). Ctrl+C stops it.
set -euo pipefail
cd "$(dirname "$0")/../build/web"
URL="http://localhost:8060/"
if python3 -c "import socket,sys; s=socket.socket(); sys.exit(0 if s.connect_ex(('127.0.0.1', 8060)) == 0 else 1)"; then
  echo "KAVI web build is already being served: $URL  (refresh with Ctrl+Shift+R)"
  xdg-open "$URL" >/dev/null 2>&1 || true
  exit 0
fi
( sleep 1; xdg-open "$URL" >/dev/null 2>&1 || true ) &
echo "KAVI web build: $URL  (Ctrl+C to stop)"
exec python3 -m http.server 8060 --bind 127.0.0.1
