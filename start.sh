#!/bin/sh
set -eu

: "${PORT:=8080}"
: "${PORT_HEALTH:=8081}"

READY_FILE="/tmp/llama_ready"

# Minimal HTTP server for GET /ping
# - 204 until READY_FILE exists
# - 200 after READY_FILE exists
ping_server() {
  while true; do
    # listen on PORT_HEALTH, handle one connection, then loop
    /bin/busybox nc -l -p "${PORT_HEALTH}" -q 1 < /dev/null | {
      # Read the request line: "GET /ping HTTP/1.1"
      read -r REQ || exit 0
      PATH_REQ=$(echo "$REQ" | awk '{print $2}')

      if [ "$PATH_REQ" = "/ping" ]; then
        if [ -f "$READY_FILE" ]; then
          printf "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
        else
          printf "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n"
        fi
      else
        printf "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
      fi
    }
  done
}

mkdir -p "${LLAMA_CACHE:-/workspace/llama-cache}" "${HF_HOME:-/workspace/hf}" || true

# Start ping server in background
ping_server &

# Start llama-server in background so we can mark READY_FILE when it's healthy
llama-server --host 0.0.0.0 --port "${PORT}" "$@" &
LLAMA_PID=$!

# Wait for llama-server health to turn OK
# llama.cpp server provides /health while model loads then becomes ready. :contentReference[oaicite:6]{index=6}
deadline=$(( $(date +%s) + 900 ))  # 15 minutes
while [ "$(date +%s)" -lt "$deadline" ]; do
  if ! kill -0 "$LLAMA_PID" 2>/dev/null; then
    echo "llama-server exited"
    exit 1
  fi
  if /bin/busybox wget -qO- "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
    touch "$READY_FILE"
    break
  fi
  sleep 1
done

# Forward signals and keep container alive as long as llama-server runs
wait "$LLAMA_PID"
