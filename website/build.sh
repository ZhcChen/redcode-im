#!/bin/bash
# 本地构建打包脚本
# 使用方法: ./build.sh

set -e

echo "开始构建..."

# 构建 Nuxt 应用
cd "$(dirname "$0")/.."
bun run build

echo "打包构建产物..."

# 创建临时目录
TEMP_DIR=$(mktemp -d)
BUILD_NAME="website-build-$(date +%Y%m%d-%H%M%S).tar.gz"

# 复制构建产物到临时目录
mkdir -p "$TEMP_DIR"
cp -r .output "$TEMP_DIR/"
cp -r public "$TEMP_DIR/"
cp nuxt.config.ts "$TEMP_DIR/"
cp package.json "$TEMP_DIR/"

# 压缩
cd "$TEMP_DIR"
tar -czf "../$BUILD_NAME" .
cd - > /dev/null

# 清理临时目录
rm -rf "$TEMP_DIR"

echo "构建完成: $BUILD_NAME"
echo ""
echo "部署步骤:"
echo "1. 上传 $BUILD_NAME 到服务器的 website/docker 目录"
echo "2. 重命名为 build.tar.gz: mv $BUILD_NAME build.tar.gz"
echo "3. 在 docker 目录下构建和运行:"
echo "   cd website/docker"
echo "   docker-compose up -d --build"

