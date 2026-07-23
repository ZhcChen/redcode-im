#!/bin/bash

# Flutter integration 测试入口。
# - smoke: 不访问真实 api，适合日常快速验证。
# - network: 访问本机 api，默认按目标设备生成 API/WS 地址。
# - auth: 访问真实 api，验证普通账号注册/登录链路。
# - device: 优先真机；默认真机未连接时切换本机 iOS Simulator。
# - device-reverse: Android USB 真机通过 adb reverse 访问本机 api。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

source "$SCRIPT_DIR/common.sh"

MODE="smoke"
DEVICE_ID=""
API_BASE_URL="${API_BASE_URL:-}"
WS_URL="${WS_URL:-}"
API_BASE_URL_EXPLICIT=0
WS_URL_EXPLICIT=0
TARGET=""

[ -n "$API_BASE_URL" ] && API_BASE_URL_EXPLICIT=1
[ -n "$WS_URL" ] && WS_URL_EXPLICIT=1

usage() {
    cat <<'USAGE'
用法：
  ./scripts/test_integration.sh [smoke|network|auth|device|device-reverse] [选项]

选项：
  --device DEVICE_ID       目标设备，默认 Pixel 8 Pro；未连接则回退本机 iOS Simulator
  --api-base-url URL       network/auth 非真机模式 API 地址，默认按设备生成
  --ws-url URL             network/auth 非真机模式 WS 地址，默认按设备生成
  --target FILE            覆盖 integration_test 目标文件
  -h, --help               显示帮助

说明：
  device 模式优先使用 Pixel 8 Pro；未连接时自动切换本机 iOS Simulator。
  真机执行时每次都会重新检测当前本机 LAN IP，并生成：
    API_BASE_URL=http://<LAN_IP>:8010
    WS_URL=ws://<LAN_IP>:8010/ws
  iOS Simulator 执行时使用：
    API_BASE_URL=http://127.0.0.1:8010
    WS_URL=ws://127.0.0.1:8010/ws
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

resolve_integration_device() {
    local requested_device_id="${DEVICE_ID:-${APP_TEST_DEVICE:-${FRONTEND_TEST_DEVICE:-}}}"

    if [ -n "$requested_device_id" ]; then
        echo "$requested_device_id"
        return 0
    fi

    resolve_app_acceptance_device "$DEFAULT_FLUTTER_DEVICE_ID"
}

configure_api_urls_for_device() {
    local device_id="$1"
    local lan_ip=""

    if is_real_mobile_device "$device_id"; then
        lan_ip="$(get_current_lan_ip)" || {
            echo "无法检测当前局域网 IP，请检查本机网络。" >&2
            exit 1
        }
        echo "📡 检测到当前局域网 IP: ${lan_ip}" >&2
        API_BASE_URL="http://${lan_ip}:8010"
        WS_URL="ws://${lan_ip}:8010/ws"
    elif is_android_emulator_device "$device_id"; then
        [ "$API_BASE_URL_EXPLICIT" -eq 1 ] || API_BASE_URL="http://10.0.2.2:8010"
        [ "$WS_URL_EXPLICIT" -eq 1 ] || WS_URL="ws://10.0.2.2:8010/ws"
    else
        [ "$API_BASE_URL_EXPLICIT" -eq 1 ] || API_BASE_URL="http://127.0.0.1:8010"
        [ "$WS_URL_EXPLICIT" -eq 1 ] || WS_URL="ws://127.0.0.1:8010/ws"
    fi
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
            API_BASE_URL_EXPLICIT=1
            shift 2
            ;;
        --ws-url)
            WS_URL="$2"
            WS_URL_EXPLICIT=1
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
        DEVICE_ID="$(resolve_integration_device)"
        show_and_verify_flutter_devices "$DEVICE_ID"
        flutter test -d "$DEVICE_ID" "$TARGET"
        ;;
    network)
        TARGET="${TARGET:-integration_test/network_connectivity_test.dart}"
        DEVICE_ID="$(resolve_integration_device)"
        configure_api_urls_for_device "$DEVICE_ID"
        echo "🌐 API_BASE_URL=${API_BASE_URL}" >&2
        echo "🌐 WS_URL=${WS_URL}" >&2
        show_and_verify_flutter_devices "$DEVICE_ID"
        flutter test -d "$DEVICE_ID" "$TARGET" \
            --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true \
            --dart-define=ENABLE_REAL_AUTH_INTEGRATION=true \
            --dart-define=API_BASE_URL="$API_BASE_URL" \
            --dart-define=WS_URL="$WS_URL"
        ;;
    auth)
        TARGET="${TARGET:-integration_test/auth_account_flow_test.dart}"
        DEVICE_ID="$(resolve_integration_device)"
        configure_api_urls_for_device "$DEVICE_ID"
        echo "🌐 API_BASE_URL=${API_BASE_URL}" >&2
        echo "🌐 WS_URL=${WS_URL}" >&2
        show_and_verify_flutter_devices "$DEVICE_ID"
        flutter test -d "$DEVICE_ID" "$TARGET" \
            --dart-define=ENABLE_REAL_AUTH_INTEGRATION=true \
            --dart-define=API_BASE_URL="$API_BASE_URL" \
            --dart-define=WS_URL="$WS_URL"
        ;;
    device)
        DEVICE_ID="$(resolve_integration_device)"
        TARGET="${TARGET:-integration_test/network_connectivity_test.dart}"
        echo "📱 目标设备: $(describe_flutter_device "$DEVICE_ID")" >&2
        configure_api_urls_for_device "$DEVICE_ID"
        echo "🌐 API_BASE_URL=${API_BASE_URL}" >&2
        echo "🌐 WS_URL=${WS_URL}" >&2

        show_and_verify_flutter_devices "$DEVICE_ID"
        flutter test -d "$DEVICE_ID" "$TARGET" \
            --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true \
            --dart-define=ENABLE_REAL_AUTH_INTEGRATION=true \
            --dart-define=API_BASE_URL="$API_BASE_URL" \
            --dart-define=WS_URL="$WS_URL"
        ;;
    device-reverse)
        DEVICE_ID="${DEVICE_ID:-${APP_TEST_DEVICE:-${FRONTEND_TEST_DEVICE:-$DEFAULT_FLUTTER_DEVICE_ID}}}"
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
            --dart-define=ENABLE_REAL_AUTH_INTEGRATION=true \
            --dart-define=API_BASE_URL="$API_BASE_URL" \
            --dart-define=WS_URL="$WS_URL"
        ;;
    *)
        echo "未知模式: $MODE" >&2
        usage
        exit 1
        ;;
esac
