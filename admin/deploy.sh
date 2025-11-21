#!/bin/bash

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认配置
SERVER_HOST="xin-im-prod-0"  # 使用 SSH config 中配置的别名
SERVER_PATH="/home/ubuntu/admin"
DIST_DIR="dist"
ARCHIVE_NAME="admin-dist-$(date +%Y%m%d-%H%M%S).7z"

# 加载配置文件
CONFIG_FILE="${SCRIPT_DIR}/deploy.config"
if [ -f "${CONFIG_FILE}" ]; then
    echo -e "${GREEN}加载配置文件: ${CONFIG_FILE}${NC}"
    source "${CONFIG_FILE}"
else
    echo -e "${YELLOW}警告: 未找到配置文件 deploy.config${NC}"
    echo -e "${YELLOW}将使用脚本中的默认配置${NC}"
    echo -e "${YELLOW}建议: 复制 deploy.config.example 为 deploy.config 并修改配置${NC}\n"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始部署 Admin 前端${NC}"
echo -e "${GREEN}========================================${NC}"

# 步骤 1: 构建项目
echo -e "\n${YELLOW}[1/3] 构建项目...${NC}"
bun run build

if [ $? -ne 0 ]; then
    echo -e "${RED}构建失败!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 构建完成${NC}"

# 步骤 2: 压缩 dist 目录
echo -e "\n${YELLOW}[2/3] 压缩文件...${NC}"

# 检查 7z 命令是否存在
if ! command -v 7z &> /dev/null; then
    echo -e "${RED}错误: 未找到 7z 命令${NC}"
    echo -e "${YELLOW}请安装 p7zip:${NC}"
    echo -e "  macOS: brew install p7zip"
    echo -e "  Ubuntu: sudo apt-get install p7zip-full"
    echo -e "  CentOS: sudo yum install p7zip"
    exit 1
fi

# 删除旧的压缩文件
rm -f admin-dist-*.7z

# 压缩 dist 目录中的所有文件 (使用 . 而不是 * 来包含所有文件和目录)
cd ${DIST_DIR}
7z a -t7z -mx=9 ../${ARCHIVE_NAME} . -r
cd ..

if [ $? -ne 0 ]; then
    echo -e "${RED}压缩失败!${NC}"
    exit 1
fi

# 验证压缩文件内容
echo -e "${YELLOW}验证压缩文件内容...${NC}"
echo "压缩包中的文件列表 (前 20 行):"
7z l ${ARCHIVE_NAME} | head -25

echo -e "${GREEN}✓ 压缩完成: ${ARCHIVE_NAME}${NC}"

# 步骤 3: 上传到服务器
echo -e "\n${YELLOW}[3/3] 上传到服务器...${NC}"
echo -e "服务器: ${SERVER_HOST}"
echo -e "目标路径: ${SERVER_PATH}"

# 上传压缩文件
scp ${ARCHIVE_NAME} ${SERVER_HOST}:/tmp/

if [ $? -ne 0 ]; then
    echo -e "${RED}上传失败!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 上传完成${NC}"
echo -e "压缩包已上传到: ${SERVER_HOST}:/tmp/${ARCHIVE_NAME}"

# 清理本地压缩文件
echo -e "\n${YELLOW}清理本地文件...${NC}"
rm -f ${ARCHIVE_NAME}

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}上传成功! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}下一步: 登录服务器手动部署${NC}"
echo -e "${YELLOW}========================================${NC}"

cat << 'DEPLOY_STEPS'

1. 登录服务器
   ssh ${SERVER_HOST}

2. 备份旧文件 (可选)
   cp -r ${SERVER_PATH} ${SERVER_PATH}_backup_$(date +%Y%m%d-%H%M%S)

3. 删除旧目录
   rm -rf ${SERVER_PATH}
   mkdir -p ${SERVER_PATH}

4. 解压文件
   7z x /tmp/${ARCHIVE_NAME} -o${SERVER_PATH} -y

5. 设置权限
   sudo chmod 755 /home /home/ubuntu
   find ${SERVER_PATH} -type d -exec chmod 755 {} \;
   find ${SERVER_PATH} -type f -exec chmod 644 {} \;

6. 清理临时文件
   rm -f /tmp/${ARCHIVE_NAME}

7. 重新加载 nginx (如果修改了配置)
   sudo systemctl reload nginx

DEPLOY_STEPS

# 替换变量
cat << EOF

${GREEN}实际命令 (复制粘贴执行):${NC}

ssh ${SERVER_HOST} << 'REMOTE_CMD'
# 备份
[ -d "${SERVER_PATH}" ] && cp -r ${SERVER_PATH} ${SERVER_PATH}_backup_\$(date +%Y%m%d-%H%M%S)

# 重新部署
rm -rf ${SERVER_PATH}
mkdir -p ${SERVER_PATH}
7z x /tmp/${ARCHIVE_NAME} -o${SERVER_PATH} -y

# 设置权限
sudo chmod 755 /home /home/ubuntu
find ${SERVER_PATH} -type d -exec chmod 755 {} \\;
find ${SERVER_PATH} -type f -exec chmod 644 {} \\;

# 清理
rm -f /tmp/${ARCHIVE_NAME}

echo "部署完成!"
REMOTE_CMD

${GREEN}访问地址:${NC} http://admin.chatlyme.com
EOF
