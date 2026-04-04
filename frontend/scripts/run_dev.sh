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
DEVICE_ID="${1:-$DEFAULT_FLUTTER_DEVICE_ID}"
DEVICE_LABEL="$(describe_flutter_device "$DEVICE_ID")"
show_and_verify_flutter_devices "$DEVICE_ID"

# 默认设备为测试真机 Mi MIX 2S（2b252911），可以通过参数覆盖

# 运行应用（开发环境）
echo ""
echo -e "${GREEN}3. 运行应用（开发环境）...${NC}"
echo -e "   环境: development"
echo -e "   API:  http://10.137.203.83:8010"
echo -e "   设备: $DEVICE_LABEL"
echo ""
flutter run -d "$DEVICE_ID" \
    --dart-define=ENV=development \
    --dart-define=ENABLE_DEBUG_LOG=true
