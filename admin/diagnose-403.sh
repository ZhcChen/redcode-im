#!/bin/bash

# 403/404 问题诊断脚本

echo "=========================================="
echo "Nginx 403/404 问题诊断"
echo "=========================================="

DEPLOY_PATH="/home/ubuntu/admin"

echo -e "\n1. 检查部署目录是否存在"
if [ -d "$DEPLOY_PATH" ]; then
    echo "✓ 目录存在: $DEPLOY_PATH"
    ls -lh "$DEPLOY_PATH" | head -10
else
    echo "✗ 目录不存在: $DEPLOY_PATH"
fi

echo -e "\n2. 检查整个路径的权限"
echo "从根到目标的每级目录权限:"
namei -l "$DEPLOY_PATH" 2>/dev/null || {
    echo "namei 命令不可用,手动检查:"
    ls -ld /home
    ls -ld /home/ubuntu
    ls -ld /home/ubuntu/admin
}

echo -e "\n3. 检查关键文件权限"
if [ -f "$DEPLOY_PATH/index.html" ]; then
    ls -lh "$DEPLOY_PATH/index.html"
else
    echo "✗ index.html 不存在"
fi

echo -e "\n4. 检查 Nginx 运行用户"
NGINX_USER=$(ps aux | grep nginx | grep -v grep | head -1 | awk '{print $1}')
echo "Nginx 运行用户: $NGINX_USER"

echo -e "\n5. 检查 Nginx 配置文件"
echo "当前 nginx 配置中的 root 路径:"
sudo grep -r "root " /etc/nginx/ 2>/dev/null | grep -v "#" | grep admin || echo "未找到配置"

echo -e "\n6. 检查 Nginx 错误日志"
echo "最近的 Nginx 错误:"
sudo tail -20 /var/log/nginx/error.log 2>/dev/null || echo "无法读取错误日志"

echo -e "\n7. 检查 SELinux 状态 (CentOS/RHEL)"
if command -v getenforce &> /dev/null; then
    echo "SELinux 状态: $(getenforce)"
else
    echo "系统未使用 SELinux"
fi

echo -e "\n8. 测试 Nginx 用户能否读取文件"
if [ -f "$DEPLOY_PATH/index.html" ]; then
    sudo -u "$NGINX_USER" cat "$DEPLOY_PATH/index.html" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Nginx 用户可以读取 index.html"
    else
        echo "✗ Nginx 用户无法读取 index.html"
        echo "尝试切换到 Nginx 用户查看详细错误:"
        sudo -u "$NGINX_USER" cat "$DEPLOY_PATH/index.html" 2>&1 | head -5
    fi
fi

echo -e "\n=========================================="
echo "诊断完成"
echo "=========================================="

echo -e "\n建议修复步骤:"
echo "1. 确保整个路径有执行权限:"
echo "   sudo chmod 755 /home /home/ubuntu /home/ubuntu/admin"
echo ""
echo "2. 设置目录和文件权限:"
echo "   find $DEPLOY_PATH -type d -exec chmod 755 {} \;"
echo "   find $DEPLOY_PATH -type f -exec chmod 644 {} \;"
echo ""
echo "3. 检查 Nginx 配置 root 路径:"
echo "   sudo nginx -t"
echo "   确保 root 指向 $DEPLOY_PATH"
echo ""
echo "4. 重启 Nginx:"
echo "   sudo systemctl restart nginx"
