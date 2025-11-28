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

# 确保在正确的目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 获取依赖
echo -e "${GREEN}1. 获取依赖...${NC}"
flutter pub get

# 检查设备
echo ""
echo -e "${GREEN}2. 检查可用设备...${NC}"
flutter devices

# 默认设备 ID（可以通过参数覆盖）
DEVICE_ID="${1:-}"

# 运行应用（开发环境）
echo ""
echo -e "${GREEN}3. 运行应用（开发环境）...${NC}"
echo -e "   环境: development"
echo -e "   API:  http://10.137.203.83:8010"
echo ""

if [ -n "$DEVICE_ID" ]; then
    flutter run -d "$DEVICE_ID" \
        --dart-define=ENV=development \
        --dart-define=ENABLE_DEBUG_LOG=true
else
    flutter run \
        --dart-define=ENV=development \
        --dart-define=ENABLE_DEBUG_LOG=true
fi
