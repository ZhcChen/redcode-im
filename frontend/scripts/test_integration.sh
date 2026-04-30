#!/bin/bash

# Flutter integration 测试入口。
# - smoke: 不访问真实 backend，适合日常快速验证。
# - network: 访问本机 backend，默认使用 127.0.0.1。
# - device: 访问本机 backend，自动检测当前 LAN IP 并注入到真机。
# - device-reverse: Android USB 真机通过 adb reverse 访问本机 backend。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

source "$SCRIPT_DIR/common.sh"

MODE="smoke"
DEVICE_ID=""
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:8010}"
WS_URL="${WS_URL:-ws://127.0.0.1:8010/ws}"
TARGET=""

usage() {
    cat <<'USAGE'
用法：
  ./scripts/test_integration.sh [smoke|network|device|device-reverse] [选项]

选项：
  --device DEVICE_ID       device 模式目标设备，默认 Pixel 8 Pro
  --api-base-url URL       network 模式 API 地址，默认 http://127.0.0.1:8010
  --ws-url URL             network 模式 WS 地址，默认 ws://127.0.0.1:8010/ws
  --target FILE            覆盖 integration_test 目标文件
  -h, --help               显示帮助

说明：
  device 模式每次都会重新检测当前本机 LAN IP，并生成：
    API_BASE_URL=http://<LAN_IP>:8010
    WS_URL=ws://<LAN_IP>:8010/ws
  device-reverse 模式使用 adb reverse tcp:8010 tcp:8010，并生成：
    API_BASE_URL=http://127.0.0.1:8010
    WS_URL=ws://127.0.0.1:8010/ws
USAGE
}

find_adb() {
    if command -v adb >/dev/null 2>&1; then
        command -v adb
        return 0
    fi

    for candidate in \
        "${ANDROID_HOME:-}/platform-tools/adb" \
        "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
        "$HOME/Library/Android/sdk/platform-tools/adb"
    do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

if [[ $# -gt 0 && "$1" != --* ]]; then
    MODE="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            DEVICE_ID="$2"
            shift 2
            ;;
        --api-base-url)
            API_BASE_URL="$2"
            shift 2
            ;;
        --ws-url)
            WS_URL="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "未知参数: $1" >&2
            usage
            exit 1
            ;;
    esac
done

case "$MODE" in
    smoke)
        TARGET="${TARGET:-integration_test/smoke_test.dart}"
        DEVICE_ID="${DEVICE_ID:-${FRONTEND_TEST_DEVICE:-macos}}"
        show_and_verify_flutter_devices "$DEVICE_ID"
        flutter test -d "$DEVICE_ID" "$TARGET"
        ;;
    network)
        TARGET="${TARGET:-integration_test/network_connectivity_test.dart}"
        DEVICE_ID="${DEVICE_ID:-${FRONTEND_TEST_DEVICE:-macos}}"
        show_and_verify_flutter_devices "$DEVICE_ID"
        flutter test -d "$DEVICE_ID" "$TARGET" \
            --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true \
            --dart-define=API_BASE_URL="$API_BASE_URL" \
            --dart-define=WS_URL="$WS_URL"
        ;;
    device)
        DEVICE_ID="${DEVICE_ID:-$DEFAULT_FLUTTER_DEVICE_ID}"
        TARGET="${TARGET:-integration_test/network_connectivity_test.dart}"
        lan_ip="$(get_current_lan_ip)" || {
            echo "无法检测当前局域网 IP，请检查本机网络。" >&2
            exit 1
        }
        API_BASE_URL="http://${lan_ip}:8010"
        WS_URL="ws://${lan_ip}:8010/ws"

        echo "📡 检测到当前局域网 IP: ${lan_ip}" >&2
        echo "📱 目标设备: $(describe_flutter_device "$DEVICE_ID")" >&2
        echo "🌐 API_BASE_URL=${API_BASE_URL}" >&2
        echo "🌐 WS_URL=${WS_URL}" >&2

        show_and_verify_flutter_devices "$DEVICE_ID"
        flutter test -d "$DEVICE_ID" "$TARGET" \
            --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true \
            --dart-define=API_BASE_URL="$API_BASE_URL" \
            --dart-define=WS_URL="$WS_URL"
        ;;
    device-reverse)
        DEVICE_ID="${DEVICE_ID:-$DEFAULT_FLUTTER_DEVICE_ID}"
        TARGET="${TARGET:-integration_test/network_connectivity_test.dart}"
        adb_bin="$(find_adb)" || {
            echo "缺少 adb，无法配置 Android USB 端口反向代理。" >&2
            exit 1
        }
        API_BASE_URL="http://127.0.0.1:8010"
        WS_URL="ws://127.0.0.1:8010/ws"

        echo "📱 目标设备: $(describe_flutter_device "$DEVICE_ID")" >&2
        echo "🔁 adb reverse: tcp:8010 -> tcp:8010" >&2
        "$adb_bin" -s "$DEVICE_ID" reverse tcp:8010 tcp:8010
        "$adb_bin" -s "$DEVICE_ID" reverse --list >&2 || true
        echo "🌐 API_BASE_URL=${API_BASE_URL}" >&2
        echo "🌐 WS_URL=${WS_URL}" >&2

        show_and_verify_flutter_devices "$DEVICE_ID"
        flutter test -d "$DEVICE_ID" "$TARGET" \
            --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true \
            --dart-define=API_BASE_URL="$API_BASE_URL" \
            --dart-define=WS_URL="$WS_URL"
        ;;
    *)
        echo "未知模式: $MODE" >&2
        usage
        exit 1
        ;;
esac
