#!/bin/bash
# 用法: ./scripts/build-macos.sh [intel|arm64] [channel]
set -euo pipefail
ARCH=${1:-arm64}
CHANNEL_OVERRIDE=${2:-}
case "$ARCH" in
  arm64|aarch64)
    TARGET="aarch64-apple-darwin"
    DEFAULT_CHANNEL="stable-macos-arm64"
    ;;
  intel|x64|x86_64)
    TARGET="x86_64-apple-darwin"
    DEFAULT_CHANNEL="stable-macos-intel"
    ;;
  *)
    echo "[错误] 未知架构: $ARCH (支持 intel/arm64)" >&2
    exit 1
    ;;
 esac
CHANNEL=${CHANNEL_OVERRIDE:-${VITE_APP_CHANNEL:-$DEFAULT_CHANNEL}}
VERSION=${VITE_APP_VERSION:-${APP_VERSION:-"1.0.0"}}
BUILD=${VITE_APP_BUILD:-${APP_BUILD:-"100"}}
EXPORT_DIR="dist/releases/macos/$CHANNEL"
mkdir -p "$EXPORT_DIR"
echo "==> 构建参数: ARCH=$ARCH TARGET=$TARGET CHANNEL=$CHANNEL VERSION=$VERSION BUILD=$BUILD"
export VITE_APP_CHANNEL="$CHANNEL"
export VITE_APP_VERSION="$VERSION"
export VITE_APP_BUILD="$BUILD"
BINARY_NAME=$(node -p "require('./src-tauri/tauri.conf.json').productName" 2>/dev/null || echo "Chatly")

# 检查并准备updater二进制
echo "==> 准备updater二进制"
cd src-tauri
if [ ! -f "target/$TARGET/release/updater" ]; then
    echo "==> 编译updater二进制"
    cargo build --release --bin updater --target "$TARGET"
else
    echo "==> 使用已存在的updater二进制"
fi

# 准备resources目录
mkdir -p resources
cp "target/$TARGET/release/updater" resources/
cd ..

bunx tauri build --target "$TARGET"
BUNDLE_ROOT="src-tauri/target/$TARGET/release/bundle"
DMG_FILE=$(find "$BUNDLE_ROOT" -maxdepth 3 -type f -name '*.dmg' | head -n 1)
if [ -z "$DMG_FILE" ]; then
  echo "[警告] 未找到 DMG 文件，构建可能失败" >&2
  exit 1
fi
OUTPUT_NAME="${BINARY_NAME}-${CHANNEL}-${VERSION}.dmg"
cp "$DMG_FILE" "$EXPORT_DIR/$OUTPUT_NAME"
echo "✅ 构建完成: $EXPORT_DIR/$OUTPUT_NAME"
