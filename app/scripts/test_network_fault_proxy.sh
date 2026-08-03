#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_PORT="${NETWORK_PROXY_TEST_UPSTREAM_PORT:-19110}"
PROXY_PORT="${NETWORK_PROXY_TEST_PORT:-19111}"
CONTROL_PORT="${NETWORK_PROXY_TEST_CONTROL_PORT:-19112}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/redcode-network-proxy-test.XXXXXX")"
UPSTREAM_PID=""
PROXY_PID=""

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    [ -z "$PROXY_PID" ] || kill "$PROXY_PID" 2>/dev/null || true
    [ -z "$UPSTREAM_PID" ] || kill "$UPSTREAM_PID" 2>/dev/null || true
    for _ in $(seq 1 20); do
        if { [ -z "$PROXY_PID" ] || ! kill -0 "$PROXY_PID" 2>/dev/null; } && \
            { [ -z "$UPSTREAM_PID" ] || ! kill -0 "$UPSTREAM_PID" 2>/dev/null; }; then
            break
        fi
        sleep 0.1
    done
    [ -z "$PROXY_PID" ] || kill -9 "$PROXY_PID" 2>/dev/null || true
    [ -z "$UPSTREAM_PID" ] || kill -9 "$UPSTREAM_PID" 2>/dev/null || true
    wait "$PROXY_PID" 2>/dev/null || true
    wait "$UPSTREAM_PID" 2>/dev/null || true
    rm -rf "$TMP_DIR"
    exit "$status"
}
trap cleanup EXIT INT TERM

for port in "$UPSTREAM_PORT" "$PROXY_PORT" "$CONTROL_PORT" "$((CONTROL_PORT + 1))"; do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "测试端口已占用: $port" >&2
        exit 1
    fi
done

dart run "$SCRIPT_DIR/network_fault_proxy.dart" \
    "$UPSTREAM_PORT" "$((CONTROL_PORT + 1))" 127.0.0.1 9 \
    >"$TMP_DIR/upstream.log" 2>&1 &
UPSTREAM_PID=$!
dart run "$SCRIPT_DIR/network_fault_proxy.dart" \
    "$PROXY_PORT" "$CONTROL_PORT" 127.0.0.1 "$((CONTROL_PORT + 1))" \
    >"$TMP_DIR/proxy.log" 2>&1 &
PROXY_PID=$!

for _ in $(seq 1 50); do
    curl -fsS "http://127.0.0.1:$CONTROL_PORT/status" >/dev/null 2>&1 && \
        curl -fsS "http://127.0.0.1:$((CONTROL_PORT + 1))/status" >/dev/null 2>&1 && break
    sleep 0.1
done

curl -fsS "http://127.0.0.1:$PROXY_PORT/status" | grep -Fq '"enabled":true'
curl -fsS "http://127.0.0.1:$CONTROL_PORT/disable" | grep -Fq '"enabled":false'
if curl -fsS --max-time 1 "http://127.0.0.1:$PROXY_PORT/status" >/dev/null 2>&1; then
    echo '禁用后代理仍接受连接' >&2
    exit 1
fi
curl -fsS "http://127.0.0.1:$CONTROL_PORT/enable" | grep -Fq '"enabled":true'
curl -fsS "http://127.0.0.1:$PROXY_PORT/status" | grep -Fq '"enabled":true'
echo 'ok - 网络故障代理支持转发、中断和恢复'
