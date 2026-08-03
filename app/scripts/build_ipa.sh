#!/bin/bash

# Flutter iOS IPA 构建脚本
# 用于生成无签名的 IPA 文件，供超级签名服务使用
#
# 使用方式:
#   ./build_ipa.sh [环境]
#   环境参数: dev/development, staging, prod/production (默认: production)
#
# 示例:
#   ./build_ipa.sh           # 生产环境
#   ./build_ipa.sh dev       # 开发环境
#   ./build_ipa.sh staging   # 测试环境

set -e

# 切换到 Flutter app 根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source "$SCRIPT_DIR/common.sh"

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

# dart-define 参数
DART_DEFINES="--dart-define=ENV=$ENV"

echo -e "${BLUE}🌍 构建环境: $ENV_NAME ($ENV)${NC}"
echo ""
echo -e "${GREEN}🚀 开始构建 iOS IPA 文件...${NC}"

# 设置环境变量
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# 清理之前的构建
echo -e "${YELLOW}🧹 清理之前的构建文件...${NC}"
flutter clean

# 获取依赖
echo -e "${YELLOW}📦 获取 Flutter 依赖...${NC}"
flutter pub get

# 安装 iOS 依赖
echo -e "${YELLOW}📱 安装 CocoaPods 依赖...${NC}"
cd ios && pod install && cd ..

# 构建 iOS 应用（无签名）
echo -e "${YELLOW}🔨 构建 iOS 应用（无签名）- $ENV_NAME...${NC}"
flutter build ios --release --no-codesign $DART_DEFINES

# 创建 IPA 目录结构
echo -e "${YELLOW}📁 创建 IPA 目录结构...${NC}"
IPA_DIR="build/ios/ipa"
PAYLOAD_DIR="$IPA_DIR/Payload"

rm -rf "$IPA_DIR"
mkdir -p "$PAYLOAD_DIR"

# 复制 .app 文件到 Payload 目录
echo -e "${YELLOW}📋 复制应用文件到 Payload 目录...${NC}"
cp -r build/ios/iphoneos/Runner.app "$PAYLOAD_DIR/"

# 创建 IPA 文件
echo -e "${YELLOW}📦 打包 IPA 文件...${NC}"
cd "$IPA_DIR"
zip -r runner.ipa Payload/
cd ../../..

# 验证 IPA 文件
echo -e "${YELLOW}🔍 验证 IPA 文件...${NC}"
if [ -f "$IPA_DIR/runner.ipa" ]; then
    IPA_SIZE=$(du -h "$IPA_DIR/runner.ipa" | cut -f1)
    echo -e "${GREEN}✅ IPA 构建成功！${NC}"
    echo -e "${GREEN}📍 文件位置: $IPA_DIR/runner.ipa${NC}"
    echo -e "${GREEN}📏 文件大小: $IPA_SIZE${NC}"
    echo -e "${GREEN}📱 包名: com.chatlyme.app${NC}"
    echo ""
    echo -e "${YELLOW}📤 可以将此 IPA 文件上传到超级签名平台进行签名${NC}"
else
    echo -e "${RED}❌ IPA 构建失败！${NC}"
    exit 1
fi

# 显示 IPA 文件信息
echo -e "${YELLOW}📋 IPA 文件信息:${NC}"
unzip -l "$IPA_DIR/runner.ipa" | head -10

echo -e "${GREEN}🎉 构建完成！${NC}"
