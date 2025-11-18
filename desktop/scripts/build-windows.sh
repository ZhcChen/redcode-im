#!/bin/bash
# 用法: ./scripts/build-windows.sh [channel]
set -euo pipefail
CHANNEL=${1:-${VITE_APP_CHANNEL:-stable-windows}}
VERSION=${VITE_APP_VERSION:-${APP_VERSION:-"1.0.0"}}
BUILD=${VITE_APP_BUILD:-${APP_BUILD:-"100"}}
EXPORT_DIR="dist/releases/windows/$CHANNEL"
mkdir -p "$EXPORT_DIR"
echo "==> 构建 Windows: CHANNEL=$CHANNEL VERSION=$VERSION BUILD=$BUILD"
export VITE_APP_CHANNEL="$CHANNEL"
export VITE_APP_VERSION="$VERSION"
export VITE_APP_BUILD="$BUILD"

# 检查并准备updater二进制
echo "==> 准备updater二进制"
cd src-tauri
TARGET="x86_64-pc-windows-msvc"
if [ ! -f "target/$TARGET/release/updater.exe" ]; then
    echo "==> 编译updater二进制"
    cargo build --release --bin updater --target "$TARGET"
else
    echo "==> 使用已存在的updater二进制"
fi

# 准备resources目录
mkdir -p resources
cp "target/$TARGET/release/updater.exe" resources/
cd ..

bunx tauri build --target x86_64-pc-windows-msvc
BUNDLE_ROOT="src-tauri/target/x86_64-pc-windows-msvc/release/bundle"
INSTALLER=$(find "$BUNDLE_ROOT" -maxdepth 3 -type f -name '*.exe' | head -n 1)
if [ -z "$INSTALLER" ]; then
  echo "[警告] 未找到安装程序文件" >&2
  exit 1
fi
BINARY_NAME=$(basename "$INSTALLER")
OUTPUT_NAME="${BINARY_NAME%.*}-${CHANNEL}-${VERSION}.exe"
cp "$INSTALLER" "$EXPORT_DIR/$OUTPUT_NAME"
echo "✅ 安装程序输出: $EXPORT_DIR/$OUTPUT_NAME"
