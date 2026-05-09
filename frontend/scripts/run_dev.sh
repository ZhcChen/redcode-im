#!/bin/bash

# 开发环境运行脚本
# 使用开发环境配置运行 Flutter 应用

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 开发环境运行 Flutter 应用...${NC}"
echo ""

# 切换到 frontend 根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source "$SCRIPT_DIR/common.sh"

# 获取依赖
echo -e "${GREEN}1. 获取依赖...${NC}"
flutter pub get

# 检查设备
echo ""
echo -e "${GREEN}2. 检查可用设备...${NC}"
if [ -n "${1:-}" ]; then
    DEVICE_ID="$1"
else
    DEVICE_ID="$(resolve_frontend_acceptance_device "$DEFAULT_FLUTTER_DEVICE_ID")"
fi
DEVICE_LABEL="$(describe_flutter_device "$DEVICE_ID")"
show_and_verify_flutter_devices "$DEVICE_ID"

LOCAL_BACKEND_DEFINES="$(build_local_backend_dart_defines "$DEVICE_ID")"
LAN_IP=""
if is_real_mobile_device "$DEVICE_ID"; then
    LAN_IP="$(get_current_lan_ip)"
fi

# 默认验收设备优先 Pixel 8 Pro，未连接时回退本机 iOS Simulator；可以通过参数覆盖。

# 运行应用（开发环境）
echo ""
echo -e "${GREEN}3. 运行应用（开发环境）...${NC}"
echo -e "   环境: development"
if is_real_mobile_device "$DEVICE_ID"; then
    echo -e "   API:  http://${LAN_IP}:8010"
    echo -e "   WS:   ws://${LAN_IP}:8010/ws"
else
    echo -e "   API:  使用默认开发配置"
fi
echo -e "   设备: $DEVICE_LABEL"
echo ""
flutter run -d "$DEVICE_ID" \
    --dart-define=ENV=development \
    $LOCAL_BACKEND_DEFINES \
    --dart-define=ENABLE_DEBUG_LOG=true
