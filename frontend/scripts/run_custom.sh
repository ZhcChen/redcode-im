#!/bin/bash

# 自定义 API 地址运行脚本
# 使用自定义 API 地址运行 Flutter 应用

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 默认值
DEFAULT_API_URL="http://10.137.203.83:8010"

# 参数处理
API_BASE_URL="${1:-$DEFAULT_API_URL}"
DEVICE_ID="${2:-}"

# 从 API URL 生成 WS URL
if [[ "$API_BASE_URL" == https://* ]]; then
    WS_URL="${API_BASE_URL/https:\/\//wss://}/ws"
else
    WS_URL="${API_BASE_URL/http:\/\//ws://}/ws"
fi

echo -e "${BLUE}🚀 自定义配置运行 Flutter 应用...${NC}"
echo ""
echo -e "使用方式:"
echo -e "  ./run_custom.sh [API_URL] [DEVICE_ID]"
echo ""
echo -e "示例:"
echo -e "  ./run_custom.sh http://192.168.1.100:8010"
echo -e "  ./run_custom.sh http://192.168.1.100:8010 iPhone"
echo ""

# 切换到 frontend 根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 获取依赖
echo -e "${GREEN}1. 获取依赖...${NC}"
flutter pub get

# 检查设备
echo ""
echo -e "${GREEN}2. 检查可用设备...${NC}"
flutter devices

# 运行应用
echo ""
echo -e "${GREEN}3. 运行应用...${NC}"
echo -e "   API:  $API_BASE_URL"
echo -e "   WS:   $WS_URL"
echo ""

if [ -n "$DEVICE_ID" ]; then
    flutter run -d "$DEVICE_ID" \
        --dart-define=ENV=development \
        --dart-define=API_BASE_URL="$API_BASE_URL" \
        --dart-define=WS_URL="$WS_URL" \
        --dart-define=ENABLE_DEBUG_LOG=true
else
    flutter run \
        --dart-define=ENV=development \
        --dart-define=API_BASE_URL="$API_BASE_URL" \
        --dart-define=WS_URL="$WS_URL" \
        --dart-define=ENABLE_DEBUG_LOG=true
fi
