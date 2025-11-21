#!/bin/bash

# 部分 JS 文件 404 问题诊断脚本

echo "=========================================="
echo "JS 文件 404 问题诊断"
echo "=========================================="

DEPLOY_PATH="/home/ubuntu/admin"

echo -e "\n1. 检查部署目录中的所有 JS 文件"
echo "文件列表:"
find "$DEPLOY_PATH" -name "*.js" -type f | head -20

echo -e "\n总共 JS 文件数量:"
find "$DEPLOY_PATH" -name "*.js" -type f | wc -l

echo -e "\n2. 检查 JS 文件权限"
echo "权限列表 (显示前 10 个):"
find "$DEPLOY_PATH" -name "*.js" -type f -exec ls -lh {} \; | head -10

echo -e "\n权限统计:"
find "$DEPLOY_PATH" -name "*.js" -type f -exec stat -c "%a %n" {} \; | awk '{print $1}' | sort | uniq -c

echo -e "\n3. 检查 index.html 中引用的资源路径"
if [ -f "$DEPLOY_PATH/index.html" ]; then
    echo "JS 文件引用:"
    grep -oP 'src="[^"]*\.js"' "$DEPLOY_PATH/index.html" || \
    grep -oE 'src="[^"]*\.js"' "$DEPLOY_PATH/index.html"

    echo -e "\nCSS 文件引用:"
    grep -oP 'href="[^"]*\.css"' "$DEPLOY_PATH/index.html" || \
    grep -oE 'href="[^"]*\.css"' "$DEPLOY_PATH/index.html"
else
    echo "✗ index.html 不存在"
fi

echo -e "\n4. 检查 nginx 访问日志中的 404 错误"
echo "最近的 JS 文件 404 错误:"
sudo tail -100 /var/log/nginx/access.log 2>/dev/null | grep "\.js" | grep " 404 " | tail -10 || echo "无法读取 nginx 日志"

echo -e "\n5. 检查 nginx 配置"
echo "nginx 静态资源配置:"
sudo grep -A 3 "location.*\\.js" /etc/nginx/sites-enabled/*.conf 2>/dev/null || echo "未找到相关配置"

echo -e "\n6. 测试文件访问"
echo "尝试读取一个 JS 文件:"
JS_FILE=$(find "$DEPLOY_PATH" -name "*.js" -type f | head -1)
if [ -n "$JS_FILE" ]; then
    echo "测试文件: $JS_FILE"
    if [ -r "$JS_FILE" ]; then
        echo "✓ 文件可读"
        ls -lh "$JS_FILE"
    else
        echo "✗ 文件不可读"
    fi
else
    echo "✗ 未找到 JS 文件"
fi

echo -e "\n7. 检查父目录权限"
namei -l "$DEPLOY_PATH/assets" 2>/dev/null || {
    echo "namei 命令不可用,手动检查:"
    ls -ld /home
    ls -ld /home/ubuntu
    ls -ld /home/ubuntu/admin
    [ -d "$DEPLOY_PATH/assets" ] && ls -ld "$DEPLOY_PATH/assets"
}

echo -e "\n=========================================="
echo "诊断完成"
echo "=========================================="

echo -e "\n常见修复方法:"
echo ""
echo "1. 如果权限不一致,统一设置权限:"
echo "   find $DEPLOY_PATH -type d -exec chmod 755 {} \;"
echo "   find $DEPLOY_PATH -type f -exec chmod 644 {} \;"
echo ""
echo "2. 如果是浏览器缓存,清除缓存:"
echo "   - Chrome: Ctrl+Shift+R (Mac: Cmd+Shift+R)"
echo "   - 或使用隐私模式/无痕模式测试"
echo ""
echo "3. 如果是路径问题,检查 Vite 配置:"
echo "   确保 vite.config.ts 中 base: '/' "
echo ""
echo "4. 重新部署:"
echo "   ./deploy.sh"
echo ""
echo "5. 重启 nginx:"
echo "   sudo systemctl reload nginx"
