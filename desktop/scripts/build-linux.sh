#!/bin/bash
# 用法: ./scripts/build-linux.sh [channel]
set -euo pipefail
CHANNEL=${1:-${VITE_APP_CHANNEL:-stable-linux}}
VERSION=${VITE_APP_VERSION:-${APP_VERSION:-"1.0.1"}}
BUILD=${VITE_APP_BUILD:-${APP_BUILD:-"100"}}
EXPORT_DIR="dist/releases/linux/$CHANNEL"
mkdir -p "$EXPORT_DIR"
echo "==> 构建 Linux: CHANNEL=$CHANNEL VERSION=$VERSION BUILD=$BUILD"
export VITE_APP_CHANNEL="$CHANNEL"
export VITE_APP_VERSION="$VERSION"
export VITE_APP_BUILD="$BUILD"
bunx tauri build --target x86_64-unknown-linux-gnu
BUNDLE_ROOT="src-tauri/target/x86_64-unknown-linux-gnu/release/bundle"
APPIMAGE=$(find "$BUNDLE_ROOT" -maxdepth 3 -type f -name '*.AppImage' | head -n 1)
if [ -z "$APPIMAGE" ]; then
  echo "[警告] 未找到 AppImage 文件" >&2
  exit 1
fi
BINARY_NAME=$(basename "$APPIMAGE")
OUTPUT_NAME="${BINARY_NAME%.*}-${CHANNEL}-${VERSION}.AppImage"
cp "$APPIMAGE" "$EXPORT_DIR/$OUTPUT_NAME"
echo "✅ AppImage 输出: $EXPORT_DIR/$OUTPUT_NAME"
