#!/bin/bash

set -e

echo "运行 Flutter 应用..."

# 确保在正确的目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source "$SCRIPT_DIR/common.sh"

DEVICE_ID="${1:-}"
if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="$(resolve_app_acceptance_device)"
fi
DEVICE_LABEL="$(describe_flutter_device "$DEVICE_ID")"

# 获取依赖
echo "1. 获取依赖..."
flutter pub get

# 检查设备连接
echo ""
echo "2. 检查设备..."
show_and_verify_flutter_devices "$DEVICE_ID"

# 运行应用
echo ""
echo "3. 在 ${DEVICE_LABEL} 上运行应用..."
flutter run -d "$DEVICE_ID"
