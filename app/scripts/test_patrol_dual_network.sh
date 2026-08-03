#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_PORT="${DUAL_NETWORK_PROXY_PORT:-19100}"
CONTROL_PORT="${DUAL_NETWORK_CONTROL_PORT:-19101}"
UPSTREAM_HOST="${DUAL_NETWORK_UPSTREAM_HOST:-127.0.0.1}"
UPSTREAM_PORT="${DUAL_NETWORK_UPSTREAM_PORT:-8010}"
PROXY_PID=""
PROXY_LOG="${TMPDIR:-/tmp}/redcode-network-fault-proxy-$$.log"

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    if [ -n "$PROXY_PID" ] && kill -0 "$PROXY_PID" 2>/dev/null; then
        kill "$PROXY_PID" 2>/dev/null || true
        for _ in $(seq 1 20); do
            kill -0 "$PROXY_PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -9 "$PROXY_PID" 2>/dev/null || true
        wait "$PROXY_PID" 2>/dev/null || true
    fi
    rm -f "$PROXY_LOG"
    exit "$status"
}
trap cleanup EXIT INT TERM

for port in "$PROXY_PORT" "$CONTROL_PORT"; do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "[patrol-network] 端口已占用: $port" >&2
        exit 1
    fi
done

dart run "$SCRIPT_DIR/network_fault_proxy.dart" \
    "$PROXY_PORT" "$CONTROL_PORT" "$UPSTREAM_HOST" "$UPSTREAM_PORT" \
    >"$PROXY_LOG" 2>&1 &
PROXY_PID=$!

for _ in $(seq 1 50); do
    curl -fsS "http://127.0.0.1:$CONTROL_PORT/status" >/dev/null 2>&1 && break
    kill -0 "$PROXY_PID" 2>/dev/null || { cat "$PROXY_LOG" >&2; exit 1; }
    sleep 0.1
done
curl -fsS "http://127.0.0.1:$CONTROL_PORT/status" >/dev/null

DUAL_TEST_TARGET=patrol_test/network_recovery_test.dart \
DUAL_COMPLETION_EVENT=DUAL_NETWORK_RECOVERY_COMPLETE \
DUAL_API_BASE_URL_A="http://127.0.0.1:$PROXY_PORT" \
DUAL_WS_URL_A="ws://127.0.0.1:$PROXY_PORT/ws" \
DUAL_API_BASE_URL_B="http://127.0.0.1:$UPSTREAM_PORT" \
DUAL_WS_URL_B="ws://127.0.0.1:$UPSTREAM_PORT/ws" \
DUAL_NETWORK_CONTROL_URL="http://127.0.0.1:$CONTROL_PORT" \
    "$SCRIPT_DIR/test_patrol_dual_device.sh"
