#!/bin/bash

# Flutter Android APK/AAB 构建脚本
# 用于生成发布版本的 Android 安装包
#
# 使用方式:
#   ./build_android.sh [环境]
#   环境参数: dev/development, staging, prod/production (默认: production)
#
# 示例:
#   ./build_android.sh           # 生产环境
#   ./build_android.sh dev       # 开发环境
#   ./build_android.sh staging   # 测试环境

set -e

# 切换到 frontend 根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 环境参数
ENV_ARG="${1:-production}"

# 标准化环境名称
case "$ENV_ARG" in
    dev|development)
        ENV="development"
        ENV_NAME="开发环境"
        ;;
    staging|stage|test)
        ENV="staging"
        ENV_NAME="测试环境"
        ;;
    prod|production|*)
        ENV="production"
        ENV_NAME="生产环境"
        ;;
esac

# 读取 Android 配置文件中的 Application ID（如存在）
ANDROID_CONFIG_FILE="config/android/app_config.properties"
APP_ID="com.chatlyme.app"

if [ -f "$ANDROID_CONFIG_FILE" ]; then
    PARSED_APP_ID=$(grep -E '^APPLICATION_ID=' "$ANDROID_CONFIG_FILE" | tail -n 1 | cut -d'=' -f2- | tr -d '[:space:]')
    if [ -n "$PARSED_APP_ID" ]; then
        APP_ID="$PARSED_APP_ID"
    fi
fi

# dart-define 参数
DART_DEFINES="--dart-define=ENV=$ENV"

echo -e "${BLUE}🌍 构建环境: $ENV_NAME ($ENV)${NC}"
echo -e "${BLUE}📱 当前 Application ID: $APP_ID${NC}"
echo ""

# 显示菜单
show_menu() {
    echo -e "${BLUE}🔧 Flutter Android 构建脚本${NC}"
    echo -e "${BLUE}================================${NC}"
    echo "1. 构建 APK (用于直接安装)"
    echo "2. 构建 AAB (用于 Google Play 发布)"
    echo "3. 构建 APK 和 AAB"
    echo "4. 退出"
    echo -e "${BLUE}================================${NC}"
}

# 构建 APK
build_apk() {
    echo -e "${GREEN}🚀 开始构建 Android APK...${NC}"

    # 更新应用名称
    echo -e "${YELLOW}🏷️ 更新应用名称...${NC}"
    ./scripts/update_app_name.sh

    # 清理之前的构建
    echo -e "${YELLOW}🧹 清理之前的构建文件...${NC}"
    flutter clean

    # 获取依赖
    echo -e "${YELLOW}📦 获取 Flutter 依赖...${NC}"
    flutter pub get

    # 构建 APK
    echo -e "${YELLOW}🔨 构建 APK (release 模式) - $ENV_NAME...${NC}"
    flutter build apk --release $DART_DEFINES

    # 验证 APK 文件
    APK_FILE="build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$APK_FILE" ]; then
        APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
        echo -e "${GREEN}✅ APK 构建成功！${NC}"
        echo -e "${GREEN}📍 文件位置: $APK_FILE${NC}"
        echo -e "${GREEN}📏 文件大小: $APK_SIZE${NC}"
        echo -e "${GREEN}📱 包名: $APP_ID${NC}"
        echo ""
        echo -e "${YELLOW}📤 可以将此 APK 文件直接安装到 Android 设备${NC}"
        echo -e "${YELLOW}📋 安装命令: adb install $APK_FILE${NC}"
    else
        echo -e "${RED}❌ APK 构建失败！${NC}"
        exit 1
    fi
}

# 构建 AAB
build_aab() {
    echo -e "${GREEN}🚀 开始构建 Android AAB...${NC}"

    # 更新应用名称
    echo -e "${YELLOW}🏷️ 更新应用名称...${NC}"
    ./scripts/update_app_name.sh

    # 清理之前的构建
    echo -e "${YELLOW}🧹 清理之前的构建文件...${NC}"
    flutter clean

    # 获取依赖
    echo -e "${YELLOW}📦 获取 Flutter 依赖...${NC}"
    flutter pub get
    
    # 构建 AAB
    echo -e "${YELLOW}🔨 构建 AAB (release 模式) - $ENV_NAME...${NC}"
    flutter build appbundle --release $DART_DEFINES

    # 验证 AAB 文件
    AAB_FILE="build/app/outputs/bundle/release/app-release.aab"
    if [ -f "$AAB_FILE" ]; then
        AAB_SIZE=$(du -h "$AAB_FILE" | cut -f1)
        echo -e "${GREEN}✅ AAB 构建成功！${NC}"
        echo -e "${GREEN}📍 文件位置: $AAB_FILE${NC}"
        echo -e "${GREEN}📏 文件大小: $AAB_SIZE${NC}"
        echo -e "${GREEN}📱 包名: $APP_ID${NC}"
        echo ""
        echo -e "${YELLOW}📤 可以将此 AAB 文件上传到 Google Play Console${NC}"
    else
        echo -e "${RED}❌ AAB 构建失败！${NC}"
        exit 1
    fi
}

# 构建两者
build_both() {
    echo -e "${GREEN}🚀 开始构建 Android APK 和 AAB...${NC}"
    
    # 清理之前的构建
    echo -e "${YELLOW}🧹 清理之前的构建文件...${NC}"
    flutter clean
    
    # 获取依赖
    echo -e "${YELLOW}📦 获取 Flutter 依赖...${NC}"
    flutter pub get
    
    # 构建 APK
    echo -e "${YELLOW}🔨 构建 APK (release 模式) - $ENV_NAME...${NC}"
    flutter build apk --release $DART_DEFINES

    # 构建 AAB
    echo -e "${YELLOW}🔨 构建 AAB (release 模式) - $ENV_NAME...${NC}"
    flutter build appbundle --release $DART_DEFINES

    # 验证文件
    APK_FILE="build/app/outputs/flutter-apk/app-release.apk"
    AAB_FILE="build/app/outputs/bundle/release/app-release.aab"
    
    echo ""
    echo -e "${BLUE}📋 构建结果:${NC}"
    
    if [ -f "$APK_FILE" ]; then
        APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
        echo -e "${GREEN}✅ APK: $APK_FILE ($APK_SIZE)${NC}"
    else
        echo -e "${RED}❌ APK 构建失败${NC}"
    fi
    
    if [ -f "$AAB_FILE" ]; then
        AAB_SIZE=$(du -h "$AAB_FILE" | cut -f1)
        echo -e "${GREEN}✅ AAB: $AAB_FILE ($AAB_SIZE)${NC}"
    else
        echo -e "${RED}❌ AAB 构建失败${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}📱 包名: $APP_ID${NC}"
    echo -e "${YELLOW}📤 APK 可直接安装，AAB 可上传到 Google Play${NC}"
}

# 主循环
while true; do
    show_menu
    read -p "请选择构建类型 (1-4): " choice
    echo ""
    
    case $choice in
        1)
            build_apk
            break
            ;;
        2)
            build_aab
            break
            ;;
        3)
            build_both
            break
            ;;
        4)
            echo -e "${YELLOW}👋 退出构建脚本${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 无效选择，请输入 1-4${NC}"
            echo ""
            ;;
    esac
done

echo -e "${GREEN}🎉 构建完成！${NC}"
