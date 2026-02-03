#!/bin/sh
set -eu

: "${PORT:=8080}"
: "${PORT_HEALTH:=8081}"

# Serve /ping with HTTP 200 on the health port
mkdir -p /pingroot
printf "OK\n" > /pingroot/ping
/bin/busybox httpd -f -p "${PORT_HEALTH}" -h /pingroot &

# Start llama-server on the main port; your template dockerStartCmd provides the args
exec llama-server --host 0.0.0.0 --port "${PORT}" "$@"
