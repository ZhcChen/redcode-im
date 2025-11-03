#!/bin/bash
# 构建和部署脚本
# 使用方法: ./deploy.sh

set -e

# 加载配置（如果存在）
if [ -f ".deploy.env" ]; then
    source .deploy.env
fi

# 配置变量（可通过环境变量或 .deploy.env 文件覆盖）
SSH_HOST="${SSH_HOST:-myServer}"
SERVER_PATH="${SERVER_PATH:-/opt/website/docker}"
BUILD_NAME="build.7z"

echo "=== 开始构建 ==="

# 确保在项目根目录
cd "$(dirname "$0")"

# 1. 构建 Nuxt 应用
echo "1. 构建 Nuxt 应用..."
bun run build

if [ ! -d ".output" ]; then
    echo "错误: 构建失败，未找到 .output 目录"
    exit 1
fi

echo "✓ 构建完成"

# 2. 检查 7z 是否安装
if ! command -v 7z &> /dev/null; then
    echo "错误: 未找到 7z 命令，请先安装 p7zip"
    echo "macOS: brew install p7zip"
    echo "Linux: apt-get install p7zip-full 或 yum install p7zip"
    exit 1
fi

# 3. 压缩构建产物
echo ""
echo "2. 压缩构建产物..."
TEMP_DIR=$(mktemp -d)

# 复制构建产物到临时目录
cp -r .output "$TEMP_DIR/"
cp -r public "$TEMP_DIR/"
cp nuxt.config.ts "$TEMP_DIR/"
cp package.json "$TEMP_DIR/"

# 使用 7z 压缩
cd "$TEMP_DIR"
7z a -t7z -mx=9 "$BUILD_NAME" . > /dev/null

# 移动压缩包到项目目录
mv "$BUILD_NAME" "$OLDPWD/"
cd "$OLDPWD"

# 清理临时目录
rm -rf "$TEMP_DIR"

echo "✓ 压缩完成: $BUILD_NAME"

# 4. 上传到服务器
echo ""
echo "3. 上传到服务器..."
echo "   SSH 快捷名称: $SSH_HOST"
echo "   路径: $SERVER_PATH"

# 检查 SSH 连接
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$SSH_HOST" exit 2>/dev/null; then
    echo "错误: 无法连接到服务器 $SSH_HOST"
    echo "请确保:"
    echo "  1. SSH 配置文件中已配置 $SSH_HOST"
    echo "  2. SSH 密钥已配置"
    echo "  3. 可以通过 SSH 访问服务器"
    exit 1
fi

# 创建远程目录（如果不存在）
ssh "$SSH_HOST" "mkdir -p $SERVER_PATH"

# 上传文件
scp "$BUILD_NAME" "$SSH_HOST:$SERVER_PATH/"

# 清理本地压缩包
rm -f "$BUILD_NAME"

echo "✓ 上传完成"

# 5. 提示部署
echo ""
echo "=== 部署完成 ==="
echo ""
echo "下一步操作（在服务器上）:"
echo "  cd $SERVER_PATH"
echo "  docker-compose up -d --build"
echo ""
echo "或者执行远程部署命令:"
echo "  ssh $SSH_HOST 'cd $SERVER_PATH && docker-compose up -d --build'"

