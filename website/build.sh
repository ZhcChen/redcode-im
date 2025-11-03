#!/bin/bash
# 本地构建打包脚本（仅打包，不上传）
# 使用方法: ./build.sh

set -e

echo "开始构建..."

# 构建 Nuxt 应用
cd "$(dirname "$0")"
bun run build

if [ ! -d ".output" ]; then
    echo "错误: 构建失败，未找到 .output 目录"
    exit 1
fi

echo "打包构建产物..."

# 检查 7z 是否安装
if ! command -v 7z &> /dev/null; then
    echo "警告: 未找到 7z 命令，使用 tar.gz 格式"
    USE_7Z=false
else
    USE_7Z=true
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
BUILD_NAME="website-build-$(date +%Y%m%d-%H%M%S)"

# 复制构建产物到临时目录
mkdir -p "$TEMP_DIR"
cp -r .output "$TEMP_DIR/"
cp -r public "$TEMP_DIR/"
cp nuxt.config.ts "$TEMP_DIR/"
cp package.json "$TEMP_DIR/"

# 压缩
cd "$TEMP_DIR"
if [ "$USE_7Z" = true ]; then
    BUILD_NAME="${BUILD_NAME}.7z"
    7z a -t7z -mx=9 "../$BUILD_NAME" . > /dev/null
else
    BUILD_NAME="${BUILD_NAME}.tar.gz"
    tar -czf "../$BUILD_NAME" .
fi
cd - > /dev/null

# 清理临时目录
rm -rf "$TEMP_DIR"

echo "构建完成: $BUILD_NAME"
echo ""
echo "部署步骤:"
echo "1. 上传 $BUILD_NAME 到服务器的 website/docker 目录"
if [ "$USE_7Z" = true ]; then
    echo "2. 重命名为 build.7z: mv $BUILD_NAME build.7z"
else
    echo "2. 重命名为 build.tar.gz: mv $BUILD_NAME build.tar.gz"
fi
echo "3. 在 docker 目录下构建和运行:"
echo "   cd website/docker"
echo "   docker-compose up -d --build"

