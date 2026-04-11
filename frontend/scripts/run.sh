#!/bin/bash

# Flutter 运行脚本（读取 .env 配置）
#
# 使用方式:
#   ./scripts/run.sh                    # 使用 .env 配置 + 默认真机运行
#   ./scripts/run.sh --env .env.local   # 使用指定的配置文件
#   ./scripts/run.sh 3A091FDJG001DN     # 指定设备运行
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
DEVICE_ID="$DEFAULT_FLUTTER_DEVICE_ID"

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
            echo "  ./scripts/run.sh                            # 使用 .env.development + 默认真机运行"
            echo "  ./scripts/run.sh --env .env.production     # 使用 .env.production + 默认真机运行"
            echo "  ./scripts/run.sh 3A091FDJG001DN           # 在 Pixel 8 Pro 上运行"
            echo "  ./scripts/run.sh emulator-5554             # 覆盖为 Android 模拟器"
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

ENV_NAME="$(get_env_value "ENV" "development" "$ENV_FILE")"
if [ "$ENV_NAME" = "development" ]; then
    LOCAL_BACKEND_DEFINES="$(build_local_backend_dart_defines "$DEVICE_ID")"
    DART_DEFINES="$DART_DEFINES$LOCAL_BACKEND_DEFINES"
fi

# 获取依赖
echo -e "${GREEN}1. 获取依赖...${NC}"
flutter pub get

# 检查设备
echo ""
echo -e "${GREEN}2. 检查可用设备...${NC}"
show_and_verify_flutter_devices "$DEVICE_ID"

# 运行应用
echo ""
echo -e "${GREEN}3. 运行应用...${NC}"
echo -e "${YELLOW}   设备: $(describe_flutter_device "$DEVICE_ID")${NC}"
if [ "$ENV_NAME" = "development" ] && is_real_mobile_device "$DEVICE_ID"; then
    echo -e "${YELLOW}   已为真机自动注入当前局域网 API/WS 地址${NC}"
fi
flutter run -d "$DEVICE_ID" $DART_DEFINES
