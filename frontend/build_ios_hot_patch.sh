#!/bin/bash

# iOS 热更新补丁打包脚本
# 用法: ./build_ios_hot_patch.sh <基线版本> <补丁版本> [channel]

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "用法: $0 <base_version> <patch_version> [channel]"
  exit 1
fi

BASE_VERSION="$1"
PATCH_VERSION="$2"
CHANNEL="${3:-stable}"

ASSETS_DIR="assets"
if [ ! -d "$ASSETS_DIR" ]; then
  echo "未找到 assets 目录，无法生成补丁"
  exit 1
fi

OUTPUT_ROOT="build/hot-patches/ios"
PATCH_DIR="$OUTPUT_ROOT/$PATCH_VERSION"
ZIP_FILE="$OUTPUT_ROOT/${PATCH_VERSION}.zip"

rm -rf "$PATCH_DIR"
mkdir -p "$PATCH_DIR"

echo "📦 复制资源到补丁目录..."
rsync -a "$ASSETS_DIR/" "$PATCH_DIR/assets/"

MANIFEST_PATH="$PATCH_DIR/manifest.json"
cat > "$MANIFEST_PATH" <<EOF
{
  "schema": 1,
  "base_version": "$BASE_VERSION",
  "patch_version": "$PATCH_VERSION",
  "channel": "$CHANNEL",
  "description": "iOS 热更新补丁",
  "payloads": {
    "assets": {
      "root": "assets"
    }
  }
}
EOF

echo "🗜️ 生成补丁 ZIP..."
rm -f "$ZIP_FILE"
(cd "$PATCH_DIR" && zip -qr "../${PATCH_VERSION}.zip" .)

echo "✅ 补丁构建完成"
echo "📍 目录: $PATCH_DIR"
echo "🗃️ 文件: $ZIP_FILE"
echo "请将 ZIP 上传到 Admin 热更新管理"
