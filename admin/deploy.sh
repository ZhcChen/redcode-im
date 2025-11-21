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
    echo "解压文件到: \${SERVER_PATH}"
    7z x /tmp/\${ARCHIVE_NAME} -o\${SERVER_PATH} -y

    # 验证解压结果
    echo "解压后的文件结构:"
    ls -lh \${SERVER_PATH} | head -15

    if [ -d "\${SERVER_PATH}/assets" ]; then
        echo "assets 目录内容 (前 10 个文件):"
        ls -lh \${SERVER_PATH}/assets | head -10
        ASSETS_COUNT=\$(find \${SERVER_PATH}/assets -type f | wc -l)
        echo "assets 目录文件总数: \${ASSETS_COUNT}"
    fi

    # 删除临时文件
    rm -f /tmp/\${ARCHIVE_NAME}

    # 设置权限
    echo "设置文件权限..."

    # 目录权限: 755 (所有者rwx,组和其他用户rx - Nginx需要x权限进入目录)
    find \${SERVER_PATH} -type d -exec chmod 755 {} \;
    # 文件权限: 644 (所有者rw,组和其他用户r - Nginx只需要读权限)
    find \${SERVER_PATH} -type f -exec chmod 644 {} \;

    # 关键: 设置父目录权限,让 Nginx 能进入 (最常见的 403 原因!)
    echo "设置父目录权限..."

    # 尝试设置 /home/ubuntu 权限 (当前用户应该有权限)
    if chmod 755 /home/ubuntu 2>/dev/null; then
        echo "✓ 已设置 /home/ubuntu 权限为 755"
    else
        echo "⚠ 警告: 无法修改 /home/ubuntu 权限"
    fi

    # 尝试设置 /home 权限 (通常需要 sudo)
    if chmod 755 /home 2>/dev/null; then
        echo "✓ 已设置 /home 权限为 755"
    elif command -v sudo &> /dev/null && sudo -n true 2>/dev/null; then
        echo "尝试使用 sudo 设置 /home 权限..."
        if sudo chmod 755 /home 2>/dev/null; then
            echo "✓ 已使用 sudo 设置 /home 权限为 755"
        else
            echo "⚠ 警告: 即使使用 sudo 也无法修改 /home 权限"
        fi
    else
        echo "⚠ 警告: 无法修改 /home 权限,且无 sudo 权限"
        echo "   如果遇到 403 错误,请手动执行: sudo chmod 755 /home"
    fi

    # 验证关键路径权限
    echo "验证权限设置:"
    ls -ld /home/ubuntu \${SERVER_PATH} | awk '{print \$1, \$NF}'

    # 可选: 如果需要将所有者改为 nginx 用户,取消下面的注释
    # sudo chown -R www-data:www-data \${SERVER_PATH}

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

# 提示: 检查 nginx 配置
echo -e "\n${YELLOW}温馨提示:${NC}"
echo -e "1. 确保服务器上的 nginx 配置是最新的"
echo -e "   当前本地配置: ${SCRIPT_DIR}/nginx/nginx.conf"
echo -e "   服务器配置路径: /etc/nginx/sites-enabled/admin.conf"
echo -e ""
echo -e "2. 如果遇到 JS 文件 404 问题:"
echo -e "   - 清除浏览器缓存 (Ctrl+Shift+R / Cmd+Shift+R)"
echo -e "   - 在服务器上运行诊断脚本: ./diagnose-js-404.sh"
echo -e "   - 重新加载 nginx: sudo systemctl reload nginx"
