#!/bin/bash
# 测试IP地理位置解析开关功能

set -e

API_BASE="http://localhost:3000"

echo "=================================="
echo "IP地理位置解析开关功能测试"
echo "=================================="
echo ""

# 1. 查询当前状态
echo "1. 查询当前开关状态..."
curl -s -X GET "$API_BASE/api/admin/ip-geolocation/enabled" | jq '.' || echo "请求失败"
echo ""

# 2. 开启开关
echo "2. 开启IP地理位置解析开关..."
curl -s -X PATCH "$API_BASE/api/admin/ip-geolocation/enabled" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}' | jq '.' || echo "请求失败"
echo ""

# 3. 再次查询确认
echo "3. 确认开关已开启..."
curl -s -X GET "$API_BASE/api/admin/ip-geolocation/enabled" | jq '.' || echo "请求失败"
echo ""

# 4. 关闭开关
echo "4. 关闭IP地理位置解析开关..."
curl -s -X PATCH "$API_BASE/api-admin/ip-geolocation/enabled" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}' | jq '.' || echo "请求失败"
echo ""

# 5. 最终确认
echo "5. 确认开关已关闭..."
curl -s -X GET "$API_BASE/api-admin/ip-geolocation/enabled" | jq '.' || echo "请求失败"
echo ""

echo "=================================="
echo "测试完成！"
echo "=================================="
echo ""
echo "注意事项："
echo "1. 如果请求失败，请检查："
echo "   - 后端服务是否运行"
echo "   - API路径是否正确"
echo "   - 管理员权限是否设置"
echo ""
echo "2. 查看后端日志："
echo "   tail -f /Users/chen/code/redcode-im/backend/log/app.log | grep 'IP地理位置解析'"
echo ""
echo "3. 手动测试WebSocket连接："
echo "   - 开启开关后，尝试建立WebSocket连接"
echo "   - 查看日志是否执行IP解析"
echo "   - 关闭开关后，连接应跳过IP解析"
