#!/bin/bash

# Flutter 运行脚本（读取 .env 配置）
#
# 使用方式:
#   ./scripts/run.sh                    # 使用 .env 配置运行
#   ./scripts/run.sh --env .env.local   # 使用指定的配置文件
#   ./scripts/run.sh iPhone             # 指定设备运行
#
# 配置优先级: 命令行参数 > .env 文件 > 默认值

set -e

# 切换到 frontend 根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 引入通用函数
source "$SCRIPT_DIR/common.sh"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 默认值
ENV_FILE=".env.development"
DEVICE_ID=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --env|-e)
            ENV_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "使用方式: ./scripts/run.sh [选项] [设备ID]"
            echo ""
            echo "选项:"
            echo "  --env, -e FILE    指定配置文件 (默认: .env.development)"
            echo "  --help, -h        显示帮助信息"
            echo ""
            echo "示例:"
            echo "  ./scripts/run.sh                            # 使用 .env.development 运行"
            echo "  ./scripts/run.sh --env .env.production     # 使用 .env.production 运行"
            echo "  ./scripts/run.sh iPhone               # 在 iPhone 上运行"
            exit 0
            ;;
        *)
            DEVICE_ID="$1"
            shift
            ;;
    esac
done

echo -e "${BLUE}🚀 Flutter 运行脚本${NC}"
echo ""

# 显示配置信息
show_env_info "$ENV_FILE"
echo ""

# 加载 .env 配置
DART_DEFINES=$(load_env_as_dart_defines "$ENV_FILE")

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

if [ -n "$DEVICE_ID" ]; then
    echo -e "${YELLOW}   设备: $DEVICE_ID${NC}"
    flutter run -d "$DEVICE_ID" $DART_DEFINES
else
    flutter run $DART_DEFINES
fi
