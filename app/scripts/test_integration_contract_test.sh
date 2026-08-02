#!/bin/bash

# test_integration.sh 的轻量契约测试：用 stub 命令验证设备选择与 API/WS 注入。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/redcode-app-script-test.XXXXXX")"
BIN_DIR="$TMP_DIR/bin"
LOG_FILE="$TMP_DIR/flutter.log"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$BIN_DIR"

cat >"$BIN_DIR/flutter" <<'STUB'
#!/bin/bash
set -euo pipefail

if [ "${1:-}" = "devices" ]; then
    cat <<DEVICES
Found 5 connected devices:
  Pixel 8 Pro (mobile)     • 3A091FDJG001DN • android-arm64 • Android 17 (API 37)
  App Device (mobile)      • app-device     • android-arm64 • Android 17 (API 37)
  Front Device (mobile)    • front-device   • android-arm64 • Android 17 (API 37)
  Android SDK (mobile)     • emulator-5554  • android-x64   • Android 17 (API 37) (emulator)
  iPhone 17 Pro (mobile)   • EE1B44A0-0924-49D8-8CE7-E15FE2555AC9 • ios           • com.apple.CoreSimulator.SimRuntime.iOS-26-4 (simulator)
DEVICES
    exit 0
fi

if [ "${1:-}" = "test" ]; then
    {
        printf 'flutter test'
        shift
        for arg in "$@"; do
            printf ' %s' "$arg"
        done
        printf '\n'
    } >>"${FLUTTER_STUB_LOG:?}"
    exit 0
fi

echo "unexpected flutter command: $*" >&2
exit 64
STUB

cat >"$BIN_DIR/route" <<'STUB'
#!/bin/bash
cat <<ROUTE
   route to: default
interface: en0
ROUTE
STUB

cat >"$BIN_DIR/ipconfig" <<'STUB'
#!/bin/bash
if [ "${1:-}" = "getifaddr" ]; then
    echo "192.0.2.10"
    exit 0
fi
exit 64
STUB

chmod +x "$BIN_DIR/flutter" "$BIN_DIR/route" "$BIN_DIR/ipconfig"

run_case() {
    local name="$1"
    shift
    : >"$LOG_FILE"
    (
        cd "$APP_DIR"
        PATH="$BIN_DIR:$PATH" FLUTTER_STUB_LOG="$LOG_FILE" "$@"
    )
    echo "ok - $name"
}

assert_log_contains() {
    local expected="$1"
    if ! grep -Fq -- "$expected" "$LOG_FILE"; then
        echo "期望日志包含: $expected" >&2
        echo "实际日志:" >&2
        cat "$LOG_FILE" >&2
        exit 1
    fi
}

assert_text_contains() {
    local haystack="$1"
    local expected="$2"
    if [[ "$haystack" != *"$expected"* ]]; then
        echo "期望输出包含: $expected" >&2
        echo "实际输出:" >&2
        printf '%s\n' "$haystack" >&2
        exit 1
    fi
}

run_case "APP_TEST_DEVICE 优先于 FRONTEND_TEST_DEVICE" \
    env APP_TEST_DEVICE=app-device FRONTEND_TEST_DEVICE=front-device \
    ./scripts/test_integration.sh smoke
assert_log_contains "-d app-device"

run_case "保留 FRONTEND_TEST_DEVICE 兼容 fallback" \
    env APP_TEST_DEVICE= FRONTEND_TEST_DEVICE=front-device \
    ./scripts/test_integration.sh smoke
assert_log_contains "-d front-device"

run_case "未指定设备时默认 iOS Simulator" \
    env APP_TEST_DEVICE= FRONTEND_TEST_DEVICE= \
    ./scripts/test_integration.sh smoke
assert_log_contains "-d EE1B44A0-0924-49D8-8CE7-E15FE2555AC9"

run_case "iOS Simulator 默认使用 127.0.0.1 生成 API/WS" \
    env APP_TEST_DEVICE= FRONTEND_TEST_DEVICE= \
    ./scripts/test_integration.sh network
assert_log_contains "-d EE1B44A0-0924-49D8-8CE7-E15FE2555AC9"
assert_log_contains "--dart-define=API_BASE_URL=http://127.0.0.1:8010"
assert_log_contains "--dart-define=WS_URL=ws://127.0.0.1:8010/ws"

run_case "contract 模式启用真实 API 合同测试开关" \
    env APP_TEST_DEVICE= FRONTEND_TEST_DEVICE= \
    ./scripts/test_integration.sh contract
assert_log_contains "-d EE1B44A0-0924-49D8-8CE7-E15FE2555AC9"
assert_log_contains "integration_test/api_contract_flow_test.dart"
assert_log_contains "--dart-define=ENABLE_REAL_CONTRACT_INTEGRATION=true"
assert_log_contains "--dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true"
assert_log_contains "--dart-define=ENABLE_REAL_AUTH_INTEGRATION=true"
assert_log_contains "--dart-define=API_BASE_URL=http://127.0.0.1:8010"
assert_log_contains "--dart-define=WS_URL=ws://127.0.0.1:8010/ws"

run_case "Android 真机忽略显式旧地址并使用当前 LAN IP" \
    env APP_TEST_DEVICE=3A091FDJG001DN API_BASE_URL=http://198.51.100.9:8010 WS_URL=ws://198.51.100.9:8010/ws \
    ./scripts/test_integration.sh network
assert_log_contains "-d 3A091FDJG001DN"
assert_log_contains "--dart-define=API_BASE_URL=http://192.0.2.10:8010"
assert_log_contains "--dart-define=WS_URL=ws://192.0.2.10:8010/ws"

run_case "Android Emulator 使用 10.0.2.2" \
    env APP_TEST_DEVICE=emulator-5554 FRONTEND_TEST_DEVICE= \
    ./scripts/test_integration.sh network
assert_log_contains "-d emulator-5554"
assert_log_contains "--dart-define=API_BASE_URL=http://10.0.2.2:8010"
assert_log_contains "--dart-define=WS_URL=ws://10.0.2.2:8010/ws"

dry_run="$(make -n -C "$APP_DIR/.." app.test.integration.network FRONTEND_TEST_DEVICE=front-device)"
assert_text_contains "$dry_run" 'APP_TEST_DEVICE="front-device"'
assert_text_contains "$dry_run" './scripts/test_integration.sh network'
echo "ok - Makefile network 入口保留 FRONTEND_TEST_DEVICE 兼容"

dry_run="$(make -n -C "$APP_DIR/.." app.test.integration.device APP_TEST_DEVICE=app-device)"
assert_text_contains "$dry_run" 'APP_TEST_DEVICE="app-device"'
assert_text_contains "$dry_run" './scripts/test_integration.sh device'
echo "ok - Makefile device 入口支持 APP_TEST_DEVICE"

dry_run="$(make -n -C "$APP_DIR/.." app.test.integration.contract APP_TEST_DEVICE=app-device)"
assert_text_contains "$dry_run" 'APP_TEST_DEVICE="app-device"'
assert_text_contains "$dry_run" './scripts/test_integration.sh contract'
echo "ok - Makefile contract 入口支持 APP_TEST_DEVICE"

dry_run="$(make -n -C "$APP_DIR/.." app.test.integration.device.contract APP_TEST_DEVICE=app-device)"
assert_text_contains "$dry_run" 'APP_TEST_DEVICE="app-device"'
assert_text_contains "$dry_run" './scripts/test_integration.sh contract'
echo "ok - Makefile device contract 入口支持 APP_TEST_DEVICE"
