#!/bin/bash

echo "运行 Flutter 应用..."

# 确保在正确的目录
cd /Users/chen/code/redcode-im/frontend

# 获取依赖
echo "1. 获取依赖..."
flutter pub get

# 检查设备连接
echo ""
echo "2. 检查设备..."
flutter devices | grep "A00E0853-BAD5-4D96-8506-32587C3C388B"

# 运行应用
echo ""
echo "3. 在 iPhone 16 Pro 模拟器上运行应用..."
flutter run -d A00E0853-BAD5-4D96-8506-32587C3C388B