#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${DUAL_SOURCE_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
PATROL_BIN="${PATROL_BIN:-patrol}"
XCRUN_BIN="${XCRUN_BIN:-xcrun}"
RSYNC_BIN="${RSYNC_BIN:-rsync}"
LSOF_BIN="${LSOF_BIN:-lsof}"
ADB_BIN="${ADB_BIN:-$HOME/Library/Android/sdk/platform-tools/adb}"

DEVICE_A="${DUAL_DEVICE_A:-}"
DEVICE_B="${DUAL_DEVICE_B:-}"
ACCOUNT_A="${DUAL_ACCOUNT_A:-}"
ACCOUNT_B="${DUAL_ACCOUNT_B:-}"
PASSWORD="${DUAL_PASSWORD:-}"
TEST_TARGET="${DUAL_TEST_TARGET:-patrol_test/dual_device_chat_test.dart}"
IDENTITY_PREFIX="${DUAL_IDENTITY_PREFIX:-dual}"
COMPLETION_EVENT="${DUAL_COMPLETION_EVENT:-}"
API_BASE_URL="${DUAL_API_BASE_URL:-http://127.0.0.1:8010}"
WS_URL="${DUAL_WS_URL:-ws://127.0.0.1:8010/ws}"
API_BASE_URL_A="${DUAL_API_BASE_URL_A:-$API_BASE_URL}"
API_BASE_URL_B="${DUAL_API_BASE_URL_B:-$API_BASE_URL}"
WS_URL_A="${DUAL_WS_URL_A:-$WS_URL}"
WS_URL_B="${DUAL_WS_URL_B:-$WS_URL}"
NETWORK_CONTROL_URL="${DUAL_NETWORK_CONTROL_URL:-}"
PORT_A_TEST="${DUAL_PORT_A_TEST:-19081}"
PORT_A_APP="${DUAL_PORT_A_APP:-19082}"
PORT_B_TEST="${DUAL_PORT_B_TEST:-19083}"
PORT_B_APP="${DUAL_PORT_B_APP:-19084}"
READY_TIMEOUT="${DUAL_READY_TIMEOUT_SECONDS:-240}"
RUN_TIMEOUT="${DUAL_RUN_TIMEOUT_SECONDS:-480}"
MARKER="${DUAL_MARKER:-$(date +%s)-$$-$RANDOM}"
RESULT_ROOT="${DUAL_RESULT_ROOT:-$APP_DIR/build/patrol-dual}"
RUN_DIR="$RESULT_ROOT/$MARKER"
WORK_ROOT="${DUAL_WORK_ROOT:-${TMPDIR:-/tmp}/redcode-patrol-dual-$MARKER}"
PID_A=""
PID_B=""

fail() {
    echo "[patrol-dual] $*" >&2
    exit 1
}

signal_tree() {
    local pid="$1"
    local signal="$2"
    local child
    for child in $(pgrep -P "$pid" 2>/dev/null || true); do
        signal_tree "$child" "$signal"
    done
    kill "-$signal" "$pid" 2>/dev/null || true
}

terminate_tree() {
    local pid="${1:-}"
    [ -n "$pid" ] || return 0
    kill -0 "$pid" 2>/dev/null || return 0
    signal_tree "$pid" TERM
    local attempt
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        kill -0 "$pid" 2>/dev/null || return 0
        sleep 0.1
    done
    signal_tree "$pid" KILL
}

archive_results() {
    local role="$1"
    local work_dir="$2"
    mkdir -p "$RUN_DIR/$role"
    find "$work_dir/build" -maxdepth 1 -name 'ios_results_*.xcresult' -exec cp -R {} "$RUN_DIR/$role/" \; 2>/dev/null || true
}

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    terminate_tree "$PID_A"
    terminate_tree "$PID_B"
    archive_results a "$WORK_ROOT/a"
    archive_results b "$WORK_ROOT/b"
    local cleanup_attempt
    for cleanup_attempt in 1 2 3 4 5; do
        rm -rf "$WORK_ROOT" 2>/dev/null || true
        [ ! -e "$WORK_ROOT" ] && break
        sleep 0.2
    done
    [ ! -e "$WORK_ROOT" ] || echo "[patrol-dual] 临时目录仍在写入，保留于 $WORK_ROOT" >&2
    if [ "$status" -ne 0 ]; then
        echo "[patrol-dual] 失败，证据保留于 $RUN_DIR" >&2
    fi
    exit "$status"
}
trap cleanup EXIT INT TERM

require_value() {
    local name="$1"
    local value="$2"
    [ -n "$value" ] || fail "缺少 $name"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "缺少命令: $1"
}

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || fail "无效端口: $port"
    if "$LSOF_BIN" -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        fail "端口已占用: $port"
    fi
}

validate_device() {
    local role="$1"
    local device="$2"
    if "$XCRUN_BIN" simctl list devices booted | grep -F "($device)" | grep -Fq '(Booted)'; then
        printf '%s' ios
        return 0
    fi
    if [ -x "$ADB_BIN" ] && "$ADB_BIN" devices | awk -v target="$device" '$1 == target && $2 == "device" { found = 1 } END { exit !found }'; then
        printf '%s' android
        return 0
    fi
    fail "$role 设备未启动或不是受支持的 iOS Simulator/Android Emulator: $device"
}

copy_workspace() {
    local role="$1"
    local destination="$WORK_ROOT/$role"
    mkdir -p "$destination"
    "$RSYNC_BIN" -a \
        --exclude '/build/' \
        --exclude '/.dart_tool/' \
        --exclude '/patrol_test/test_bundle.dart' \
        "$APP_DIR/" "$destination/"
}

run_role() {
    local role="$1"
    local device="$2"
    local account="$3"
    local peer="$4"
    local test_port="$5"
    local app_port="$6"
    local work_dir="$WORK_ROOT/$role"
    local log_file="$RUN_DIR/$role.log"
    local api_base_url="$API_BASE_URL_B"
    local ws_url="$WS_URL_B"
    if [ "$role" = a ]; then
        api_base_url="$API_BASE_URL_A"
        ws_url="$WS_URL_A"
    fi

    (
        cd "$work_dir"
        PATH="$HOME/Library/Android/sdk/platform-tools:$PATH" \
        JAVA_HOME="${JAVA_HOME:-}" \
        CC="${CC:-$SCRIPT_DIR/xcode_clang_probe_wrapper.sh}" \
        "$PATROL_BIN" test -t "$TEST_TARGET" \
            -d "$device" \
            --test-server-port "$test_port" \
            --app-server-port "$app_port" \
            --dart-define "DUAL_ROLE=$role" \
            --dart-define "DUAL_ACCOUNT=$account" \
            --dart-define "DUAL_PEER_ACCOUNT=$peer" \
            --dart-define "DUAL_PASSWORD=$PASSWORD" \
            --dart-define "DUAL_MARKER=$MARKER" \
            --dart-define "API_BASE_URL=$api_base_url" \
            --dart-define "WS_URL=$ws_url" \
            --dart-define "DUAL_NETWORK_CONTROL_URL=$NETWORK_CONTROL_URL"
    ) >"$log_file" 2>&1
}

wait_for_log() {
    local pid="$1"
    local log_file="$2"
    local expected="$3"
    local timeout="$4"
    local deadline=$((SECONDS + timeout))
    while [ "$SECONDS" -lt "$deadline" ]; do
        grep -Fq "$expected" "$log_file" 2>/dev/null && return 0
        kill -0 "$pid" 2>/dev/null || return 1
        sleep 1
    done
    return 124
}

wait_for_process() {
    local pid="$1"
    local timeout="$2"
    local deadline=$((SECONDS + timeout))
    while kill -0 "$pid" 2>/dev/null; do
        [ "$SECONDS" -lt "$deadline" ] || return 124
        sleep 1
    done
    wait "$pid"
}

for command in "$PATROL_BIN" "$XCRUN_BIN" "$RSYNC_BIN" "$LSOF_BIN"; do
    require_command "$command"
done
require_value DUAL_DEVICE_A "$DEVICE_A"
require_value DUAL_DEVICE_B "$DEVICE_B"
require_value DUAL_ACCOUNT_A "$ACCOUNT_A"
require_value DUAL_ACCOUNT_B "$ACCOUNT_B"
require_value DUAL_PASSWORD "$PASSWORD"
[[ "$IDENTITY_PREFIX" =~ ^[a-z0-9-]+$ ]] || fail "无效身份前缀: $IDENTITY_PREFIX"
[[ -z "$COMPLETION_EVENT" || "$COMPLETION_EVENT" =~ ^[A-Z0-9_]+$ ]] || fail "无效完成事件: $COMPLETION_EVENT"
[[ "$TEST_TARGET" == patrol_test/*.dart ]] && [[ "$TEST_TARGET" != *..* ]] || fail "无效测试目标: $TEST_TARGET"
[ -f "$APP_DIR/$TEST_TARGET" ] || fail "测试目标不存在: $TEST_TARGET"
[ "$DEVICE_A" != "$DEVICE_B" ] || fail "A/B 必须使用两个不同的设备"
[ "$ACCOUNT_A" != "$ACCOUNT_B" ] || fail "A/B 必须使用两个不同的账号"

ports=("$PORT_A_TEST" "$PORT_A_APP" "$PORT_B_TEST" "$PORT_B_APP")
[ "$(printf '%s\n' "${ports[@]}" | sort -u | wc -l | tr -d ' ')" = 4 ] || fail "四个 Patrol 端口必须互不相同"
for port in "${ports[@]}"; do validate_port "$port"; done
DEVICE_PLATFORM_A="$(validate_device A "$DEVICE_A")"
DEVICE_PLATFORM_B="$(validate_device B "$DEVICE_B")"

mkdir -p "$RUN_DIR"
printf '%s\n' "$MARKER" >"$RUN_DIR/marker.txt"
printf 'marker=%s\ndevice_a=%s\ndevice_b=%s\nplatform_a=%s\nplatform_b=%s\ntest_target=%s\nidentity_prefix=%s\napi_base_url_a=%s\napi_base_url_b=%s\nws_url_a=%s\nws_url_b=%s\n' \
    "$MARKER" "$DEVICE_A" "$DEVICE_B" "$DEVICE_PLATFORM_A" "$DEVICE_PLATFORM_B" "$TEST_TARGET" "$IDENTITY_PREFIX" \
    "$API_BASE_URL_A" "$API_BASE_URL_B" "$WS_URL_A" "$WS_URL_B" >"$RUN_DIR/run.env"
echo "[patrol-dual] marker=$MARKER results=$RUN_DIR"

copy_workspace a
copy_workspace b

run_role b "$DEVICE_B" "$ACCOUNT_B" "$ACCOUNT_A" "$PORT_B_TEST" "$PORT_B_APP" &
PID_B=$!
expected_b="DUAL_READY role=b account=$ACCOUNT_B marker=$MARKER"
wait_for_log "$PID_B" "$RUN_DIR/b.log" "$expected_b" "$READY_TIMEOUT" || fail "B 未在限时内进入等待状态"

run_role a "$DEVICE_A" "$ACCOUNT_A" "$ACCOUNT_B" "$PORT_A_TEST" "$PORT_A_APP" &
PID_A=$!
wait_for_process "$PID_A" "$RUN_TIMEOUT" || fail "A 执行失败或超时"
PID_A=""
if [ -n "$COMPLETION_EVENT" ]; then
    expected_b_complete="$COMPLETION_EVENT role=b marker=$MARKER"
    wait_for_log "$PID_B" "$RUN_DIR/b.log" "$expected_b_complete" "$RUN_TIMEOUT" || fail "B 未在限时内完成业务断言"
    terminate_tree "$PID_B"
    PID_B=""
else
    wait_for_process "$PID_B" "$RUN_TIMEOUT" || fail "B 执行失败或超时"
    PID_B=""
fi

for role in a b; do
    if [ "$role" = a ]; then account="$ACCOUNT_A"; else account="$ACCOUNT_B"; fi
    expected="DUAL_IDENTITY role=$role account=$account marker=$MARKER prefix=$IDENTITY_PREFIX-$role-"
    first_identity="$(grep -F 'DUAL_IDENTITY role=' "$RUN_DIR/$role.log" | head -1 || true)"
    [[ "$first_identity" == *"$expected"* ]] || fail "$role 身份或消息前缀验证失败"
done

if [ -n "$COMPLETION_EVENT" ]; then
    for role in a b; do
        expected_complete="$COMPLETION_EVENT role=$role marker=$MARKER"
        grep -Fq "$expected_complete" "$RUN_DIR/$role.log" || fail "$role 缺少业务完成标记"
    done
fi

echo "[patrol-dual] PASS marker=$MARKER results=$RUN_DIR"
