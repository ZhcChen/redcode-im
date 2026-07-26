#!/bin/bash
# 用法:
#   ./scripts/build-macos.sh [intel|arm64] [channel]
#
# 默认签名策略：
# - macOS 本地打包默认使用 ad-hoc 签名（codesign --sign -）
# - 如需切换为正式证书，可显式传入 MACOS_SIGN_IDENTITY
# - 如需跳过签名，可传入 MACOS_SIGN_IDENTITY=skip

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
VERSION=${VITE_APP_VERSION:-${APP_VERSION:-"2.0.0"}}
BUILD=${VITE_APP_BUILD:-${APP_BUILD:-"100"}}
DEFAULT_MACOS_SIGN_IDENTITY="-"
MACOS_SIGN_IDENTITY="${MACOS_SIGN_IDENTITY:-$DEFAULT_MACOS_SIGN_IDENTITY}"
EXPORT_DIR="dist/releases/macos/$CHANNEL"

mkdir -p "$EXPORT_DIR"

echo "==> 构建参数: ARCH=$ARCH TARGET=$TARGET CHANNEL=$CHANNEL VERSION=$VERSION BUILD=$BUILD"
echo "==> macOS 签名身份: $MACOS_SIGN_IDENTITY"

export VITE_APP_CHANNEL="$CHANNEL"
export VITE_APP_VERSION="$VERSION"
export VITE_APP_BUILD="$BUILD"

BINARY_NAME=$(node -p "require('./src-tauri/tauri.conf.json').productName" 2>/dev/null || echo "Chatly")

# 检查并准备 updater 二进制
echo "==> 准备 updater 二进制"
cd src-tauri
if [ ! -f "target/$TARGET/release/updater" ]; then
  echo "==> 编译 updater 二进制"
  cargo build --release --bin updater --target "$TARGET"
else
  echo "==> 使用已存在的 updater 二进制"
fi

mkdir -p resources
if [ -f "target/$TARGET/release/updater" ]; then
  cp "target/$TARGET/release/updater" resources/
  echo "==> updater 二进制已复制到 resources 目录"
else
  echo "[错误] updater 二进制编译失败" >&2
  exit 1
fi
cd ..

echo "==> 执行 tauri build"
bunx tauri build --target "$TARGET"

BUNDLE_ROOT="src-tauri/target/$TARGET/release/bundle"
APP_BUNDLE=$(find "$BUNDLE_ROOT/macos" -maxdepth 1 -type d -name "*.app" | head -n 1)

if [ -z "$APP_BUNDLE" ]; then
  APP_BUNDLE=$(find "$BUNDLE_ROOT" -maxdepth 3 -type d -name "*.app" | head -n 1)
fi

if [ -z "$APP_BUNDLE" ]; then
  echo "[错误] 未找到 .app 包，构建可能失败" >&2
  exit 1
fi

APP_CONTENTS="$APP_BUNDLE/Contents"
UPDATER_BIN="src-tauri/target/$TARGET/release/updater"
UPDATER_DEST="$APP_CONTENTS/MacOS/updater"

if [ -f "$UPDATER_BIN" ]; then
  cp "$UPDATER_BIN" "$UPDATER_DEST"
  chmod +x "$UPDATER_DEST"
  echo "==> updater 已复制到应用包: $UPDATER_DEST"
fi

if [ "$MACOS_SIGN_IDENTITY" != "skip" ]; then
  echo "==> 对应用执行 macOS 签名"
  codesign --force --deep --sign "$MACOS_SIGN_IDENTITY" "$APP_BUNDLE"
  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  echo "✅ macOS 签名完成"
else
  echo "==> 已跳过 macOS 签名"
fi

OUTPUT_NAME="${BINARY_NAME}-${CHANNEL}-${VERSION}.dmg"
OUTPUT_PATH="$EXPORT_DIR/$OUTPUT_NAME"

if command -v hdiutil >/dev/null 2>&1; then
  echo "==> 重新打包已签名 DMG"
  rm -f "$OUTPUT_PATH"
  hdiutil create -volname "$BINARY_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$OUTPUT_PATH" >/dev/null
else
  echo "[警告] 未找到 hdiutil，回退复制 Tauri 原始 DMG" >&2
  DMG_FILE=$(find "$BUNDLE_ROOT" -maxdepth 3 -type f -name '*.dmg' | head -n 1)
  if [ -z "$DMG_FILE" ]; then
    echo "[错误] 未找到 DMG 文件，构建可能失败" >&2
    exit 1
  fi
  cp "$DMG_FILE" "$OUTPUT_PATH"
fi

echo "✅ 构建完成: $OUTPUT_PATH"
