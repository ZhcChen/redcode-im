#!/bin/bash

# Flutter 构建脚本（读取 .env 配置）
#
# 使用方式:
#   ./scripts/build.sh                      # 使用 .env 配置构建
#   ./scripts/build.sh --env .env.prod      # 使用指定的配置文件
#   ./scripts/build.sh apk                  # 构建 APK
#   ./scripts/build.sh ipa                  # 构建 IPA
#   ./scripts/build.sh aab                  # 构建 AAB
#
# 配置优先级: 命令行参数 > .env 文件 > 默认值

set -e

# 切换到 frontend 根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 引入通用函数
source "$SCRIPT_DIR/common.sh"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 默认值
ENV_FILE=".env.development"
BUILD_TYPE=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --env|-e)
            ENV_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "使用方式: ./scripts/build.sh [选项] [构建类型]"
            echo ""
            echo "构建类型:"
            echo "  apk     构建 Android APK"
            echo "  aab     构建 Android AAB (App Bundle)"
            echo "  ipa     构建 iOS IPA"
            echo "  all     构建所有类型"
            echo ""
            echo "选项:"
            echo "  --env, -e FILE    指定配置文件 (默认: .env.development)"
            echo "  --help, -h        显示帮助信息"
            echo ""
            echo "示例:"
            echo "  ./scripts/build.sh apk                          # 构建 APK"
            echo "  ./scripts/build.sh --env .env.production ipa    # 使用生产配置构建 IPA"
            exit 0
            ;;
        apk|aab|ipa|all)
            BUILD_TYPE="$1"
            shift
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🔧 Flutter 构建脚本${NC}"
echo ""

# 显示配置信息
show_env_info "$ENV_FILE"
echo ""

# 加载 .env 配置
DART_DEFINES=$(load_env_as_dart_defines "$ENV_FILE")

# 如果没有指定构建类型，显示菜单
if [ -z "$BUILD_TYPE" ]; then
    echo -e "${BLUE}请选择构建类型:${NC}"
    echo "1. APK (Android 直接安装)"
    echo "2. AAB (Google Play 发布)"
    echo "3. IPA (iOS)"
    echo "4. 全部"
    echo "5. 退出"
    read -p "请选择 (1-5): " choice

    case $choice in
        1) BUILD_TYPE="apk" ;;
        2) BUILD_TYPE="aab" ;;
        3) BUILD_TYPE="ipa" ;;
        4) BUILD_TYPE="all" ;;
        5) exit 0 ;;
        *) echo -e "${RED}无效选择${NC}"; exit 1 ;;
    esac
fi

# 清理和获取依赖
echo -e "${GREEN}1. 清理之前的构建...${NC}"
flutter clean

echo -e "${GREEN}2. 获取依赖...${NC}"
flutter pub get

# 构建函数
build_apk() {
    echo -e "${YELLOW}🔨 构建 APK...${NC}"
    flutter build apk --release $DART_DEFINES

    APK_FILE="build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$APK_FILE" ]; then
        APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
        echo -e "${GREEN}✅ APK 构建成功！${NC}"
        echo -e "   📍 $APK_FILE"
        echo -e "   📏 $APK_SIZE"
    else
        echo -e "${RED}❌ APK 构建失败${NC}"
        return 1
    fi
}

build_aab() {
    echo -e "${YELLOW}🔨 构建 AAB...${NC}"
    flutter build appbundle --release $DART_DEFINES

    AAB_FILE="build/app/outputs/bundle/release/app-release.aab"
    if [ -f "$AAB_FILE" ]; then
        AAB_SIZE=$(du -h "$AAB_FILE" | cut -f1)
        echo -e "${GREEN}✅ AAB 构建成功！${NC}"
        echo -e "   📍 $AAB_FILE"
        echo -e "   📏 $AAB_SIZE"
    else
        echo -e "${RED}❌ AAB 构建失败${NC}"
        return 1
    fi
}

build_ipa() {
    echo -e "${YELLOW}🔨 构建 IPA...${NC}"

    # 安装 iOS 依赖
    echo -e "${YELLOW}   安装 CocoaPods 依赖...${NC}"
    cd ios && pod install && cd ..

    # 构建
    flutter build ios --release --no-codesign $DART_DEFINES

    # 打包 IPA
    IPA_DIR="build/ios/ipa"
    PAYLOAD_DIR="$IPA_DIR/Payload"

    rm -rf "$IPA_DIR"
    mkdir -p "$PAYLOAD_DIR"
    cp -r build/ios/iphoneos/Runner.app "$PAYLOAD_DIR/"

    cd "$IPA_DIR"
    zip -r runner.ipa Payload/
    cd ../../..

    if [ -f "$IPA_DIR/runner.ipa" ]; then
        IPA_SIZE=$(du -h "$IPA_DIR/runner.ipa" | cut -f1)
        echo -e "${GREEN}✅ IPA 构建成功！${NC}"
        echo -e "   📍 $IPA_DIR/runner.ipa"
        echo -e "   📏 $IPA_SIZE"
    else
        echo -e "${RED}❌ IPA 构建失败${NC}"
        return 1
    fi
}

# 执行构建
echo ""
echo -e "${GREEN}3. 开始构建...${NC}"
echo ""

case $BUILD_TYPE in
    apk)
        build_apk
        ;;
    aab)
        build_aab
        ;;
    ipa)
        build_ipa
        ;;
    all)
        build_apk
        echo ""
        build_aab
        echo ""
        build_ipa
        ;;
esac

echo ""
echo -e "${GREEN}🎉 构建完成！${NC}"
