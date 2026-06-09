#!/bin/bash

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始部署 Backend 后端${NC}"
echo -e "${GREEN}========================================${NC}"

# 步骤 1: 构建后端
echo -e "\n${YELLOW}[1/2] 构建后端 (Linux x86_64-musl)...${NC}"
TARGET=x86_64-unknown-linux-musl \
PROFILE=release \
scripts/build-linux-zig.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}构建失败!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 构建完成${NC}"

# 步骤 2: 上传到服务器
echo -e "\n${YELLOW}[2/2] 上传到服务器...${NC}"
echo -e "服务器: xin-im-prod-0"
echo -e "目标路径: /home/ubuntu"

scp target/x86_64-unknown-linux-musl/release/redcode-im-api xin-im-prod-0:/home/ubuntu

if [ $? -ne 0 ]; then
    echo -e "${RED}上传失败!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 上传完成${NC}"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}部署成功! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}下一步: 登录服务器重启服务${NC}"
echo -e "  ssh xin-im-prod-0"
echo -e "  sudo systemctl restart redcode-im-api"
echo -e "  ${YELLOW}# 二进制已更名为 redcode-im-api；systemd 单元名以生产主机实际部署为准，"
echo -e "  ${YELLOW}# 若线上单元仍为 redcode-im-backend.service，请沿用旧名或在主机侧同步改名${NC}"
