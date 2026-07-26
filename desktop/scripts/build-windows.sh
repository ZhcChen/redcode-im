#!/bin/bash
# 用法: ./scripts/build-windows.sh [channel]
set -euo pipefail

# 检查运行环境，支持macOS交叉编译
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "==> 检测到macOS环境，将使用cargo-xwin进行交叉编译"
    USE_CROSS_COMPILE=true
    # 确保PATH包含llvm
    export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
else
    echo "==> 检测到非macOS环境，使用原生构建"
    USE_CROSS_COMPILE=false
fi

CHANNEL=${1:-${VITE_APP_CHANNEL:-stable}}
VERSION=${VITE_APP_VERSION:-${APP_VERSION:-"2.0.0"}}
BUILD=${VITE_APP_BUILD:-${APP_BUILD:-"100"}}
EXPORT_DIR="dist/releases/windows/$CHANNEL"
mkdir -p "$EXPORT_DIR"
echo "==> 创建输出目录: $EXPORT_DIR"
echo "==> 构建 Windows: CHANNEL=$CHANNEL VERSION=$VERSION BUILD=$BUILD"
export VITE_APP_CHANNEL="$CHANNEL"
export VITE_APP_VERSION="$VERSION"
export VITE_APP_BUILD="$BUILD"

# 检查并准备updater二进制
echo "==> 准备updater二进制"
cd src-tauri

# 先创建resources目录和占位文件，避免编译时找不到文件
mkdir -p resources
touch "resources/updater-x86_64-pc-windows-msvc.exe"

TARGET="x86_64-pc-windows-msvc"
if [ ! -f "target/$TARGET/release/updater.exe" ]; then
    echo "==> 编译updater二进制"
    if [ "$USE_CROSS_COMPILE" = true ]; then
        echo "==> 使用cargo-xwin进行交叉编译"
        cargo xwin build --release --bin updater --target "$TARGET"
    else
        cargo build --release --bin updater --target "$TARGET"
    fi
else
    echo "==> 使用已存在的updater二进制"
fi

# 复制updater二进制到resources目录
cp "target/$TARGET/release/updater.exe" "resources/updater-x86_64-pc-windows-msvc.exe"
echo "==> 复制updater二进制完成，检查文件是否存在："
ls -la resources/
cd ..

if [ "$USE_CROSS_COMPILE" = true ]; then
    echo "==> 使用cargo-xwin构建tauri应用"
    bunx tauri build --runner cargo-xwin --target x86_64-pc-windows-msvc
else
    bunx tauri build --target x86_64-pc-windows-msvc
fi
BUNDLE_ROOT="src-tauri/target/x86_64-pc-windows-msvc/release/bundle"
INSTALLER=$(find "$BUNDLE_ROOT" -maxdepth 3 -type f -name '*.exe' | head -n 1)
if [ -z "$INSTALLER" ]; then
  echo "[警告] 未找到安装程序文件" >&2
  exit 1
fi
BINARY_NAME=$(basename "$INSTALLER")
OUTPUT_NAME="${BINARY_NAME%.*}-${CHANNEL}-${VERSION}.exe"

# 确保目标目录存在
mkdir -p "$EXPORT_DIR"

cp "$INSTALLER" "$EXPORT_DIR/$OUTPUT_NAME"
echo "✅ 安装程序输出: $EXPORT_DIR/$OUTPUT_NAME"
