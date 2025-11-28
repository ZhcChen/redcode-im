#!/bin/bash

# 生产环境运行脚本
# 使用生产环境配置运行 Flutter 应用

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 生产环境运行 Flutter 应用...${NC}"
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

# 运行应用（生产环境）
echo ""
echo -e "${GREEN}3. 运行应用（生产环境）...${NC}"
echo -e "   环境: production"
echo -e "   API:  https://api.chatlyme.com"
echo -e "${YELLOW}   ⚠️  调试日志已禁用${NC}"
echo ""

if [ -n "$DEVICE_ID" ]; then
    flutter run -d "$DEVICE_ID" \
        --dart-define=ENV=production \
        --dart-define=ENABLE_DEBUG_LOG=false
else
    flutter run \
        --dart-define=ENV=production \
        --dart-define=ENABLE_DEBUG_LOG=false
fi
