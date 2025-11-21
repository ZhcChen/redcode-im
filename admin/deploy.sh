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
POST_DEPLOY_COMMAND=""  # 部署完成后执行的自定义命令

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

# 压缩 dist 目录中的所有文件
cd ${DIST_DIR}
7z a -t7z -mx=9 ../${ARCHIVE_NAME} *
cd ..

if [ $? -ne 0 ]; then
    echo -e "${RED}压缩失败!${NC}"
    exit 1
fi

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

# 在服务器上解压并部署
echo -e "\n${YELLOW}在服务器上解压并部署...${NC}"
ssh ${SERVER_HOST} bash -s << EOF
    set -e

    SERVER_PATH="${SERVER_PATH}"
    ARCHIVE_NAME="${ARCHIVE_NAME}"

    # 备份旧文件
    if [ -d "\${SERVER_PATH}" ] && [ "\$(ls -A \${SERVER_PATH} 2>/dev/null)" ]; then
        BACKUP_DIR="\${SERVER_PATH}_backup_\$(date +%Y%m%d-%H%M%S)"
        echo "备份旧文件到: \${BACKUP_DIR}"
        cp -r \${SERVER_PATH} \${BACKUP_DIR}
    fi

    # 完全删除旧目录并重新创建
    rm -rf \${SERVER_PATH}
    mkdir -p \${SERVER_PATH}

    # 解压文件到目标目录
    7z x /tmp/\${ARCHIVE_NAME} -o\${SERVER_PATH}

    # 删除临时文件
    rm -f /tmp/\${ARCHIVE_NAME}

    # 设置权限 (根据实际用户调整,ubuntu 用户通常不需要改为 www-data)
    # 如果使用 nginx,取消下面的注释
    # sudo chown -R www-data:www-data \${SERVER_PATH}
    chmod -R 755 \${SERVER_PATH}

    echo "部署完成!"
EOF

if [ $? -ne 0 ]; then
    echo -e "${RED}服务器部署失败!${NC}"
    exit 1
fi

# 执行部署后自定义命令
if [ -n "${POST_DEPLOY_COMMAND}" ]; then
    echo -e "\n${YELLOW}执行部署后命令...${NC}"
    echo -e "命令: ${POST_DEPLOY_COMMAND}"

    ssh ${SERVER_HOST} bash -s << EOF
        set -e
        ${POST_DEPLOY_COMMAND}
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 命令执行成功${NC}"
    else
        echo -e "${RED}✗ 命令执行失败${NC}"
        exit 1
    fi
fi

# 清理本地压缩文件
echo -e "\n${YELLOW}清理本地文件...${NC}"
rm -f ${ARCHIVE_NAME}

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}部署成功! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "访问地址: http://admin.chatlyme.com"
