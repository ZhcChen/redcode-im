#!/bin/bash

# 动态更新应用名称脚本
# 从后端API获取应用名并更新配置文件

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
source "$SCRIPT_DIR/common.sh"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# API配置
DEFAULT_API_BASE_URL="http://127.0.0.1:8010"
if LAN_IP="$(get_current_lan_ip)"; then
    DEFAULT_API_BASE_URL="http://${LAN_IP}:8010"
fi

API_BASE_URL="${API_BASE_URL:-$DEFAULT_API_BASE_URL}"
APP_NAME_ENDPOINT="${API_BASE_URL}/settings/app-name"

echo -e "${BLUE}🔄 获取应用名称...${NC}"

# 获取应用名
echo -e "${YELLOW}📡 调用 API: ${APP_NAME_ENDPOINT}${NC}"

# 使用 curl 获取应用名，设置超时时间
response=$(curl -s --max-time 10 "${APP_NAME_ENDPOINT}" 2>/dev/null || echo "")

if [ -z "$response" ]; then
    echo -e "${RED}❌ 无法连接到服务器，使用默认名称 'RedCode IM'${NC}"
    APP_NAME="RedCode IM"
else
    # 解析JSON响应
    APP_NAME=$(echo "$response" | grep -o '"app_name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "")

    if [ -z "$APP_NAME" ]; then
        echo -e "${RED}❌ API响应中未找到应用名，使用默认名称 'RedCode IM'${NC}"
        APP_NAME="RedCode IM"
    else
        echo -e "${GREEN}✅ 获取应用名成功: ${APP_NAME}${NC}"
    fi
fi

# 更新 Android 配置
echo -e "${YELLOW}📱 更新 Android 配置...${NC}"
ANDROID_MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$ANDROID_MANIFEST" ]; then
    # 备份原文件
    cp "$ANDROID_MANIFEST" "${ANDROID_MANIFEST}.backup"

    # 更新 android:label
    sed -i.bak "s/android:label=\"[^\"]*\"/android:label=\"${APP_NAME}\"/" "$ANDROID_MANIFEST" && rm "${ANDROID_MANIFEST}.bak"
    echo -e "${GREEN}✅ Android 配置已更新${NC}"
else
    echo -e "${RED}❌ 未找到 Android 配置文件的${NC}"
fi

# 更新 iOS 配置
echo -e "${YELLOW}🍎 更新 iOS 配置...${NC}"
IOS_PLIST="ios/Runner/Info.plist"
if [ -f "$IOS_PLIST" ]; then
    # 备份原文件
    cp "$IOS_PLIST" "${IOS_PLIST}.backup"

    # 更新 CFBundleDisplayName
    sed -i.bak "s|<string>Frontend</string>|<string>${APP_NAME}</string>|" "$IOS_PLIST" && rm "${IOS_PLIST}.bak"
    echo -e "${GREEN}✅ iOS 配置已更新${NC}"
else
    echo -e "${RED}❌ 未找到 iOS 配置文件${NC}"
fi

echo -e "${GREEN}🎉 应用名称更新完成！${NC}"
echo -e "${GREEN}📱 应用将在桌面上显示为: ${APP_NAME}${NC}"
