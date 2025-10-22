#!/bin/bash

# 测试前端是否能访问后端 API

API_BASE="http://localhost:8010"
echo "测试前端 API 访问..."
echo ""

# 1. 测试健康检查
echo "1. 测试健康检查..."
curl -s $API_BASE/healthz
echo ""
echo ""

# 2. 测试登录（获取 token）
echo "2. 测试登录..."
TOKEN=$(curl -s -X POST "$API_BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }' | jq -r '.token // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "登录失败！"
  exit 1
fi

echo "登录成功，获取到 token"
echo ""

# 3. 测试搜索用户
echo "3. 测试搜索用户 'alice'..."
RESPONSE=$(curl -s -X GET "$API_BASE/users/search?keyword=alice&limit=10" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

echo "响应状态码: $RESPONSE"
echo $RESPONSE | jq '.'
echo ""

# 4. 测试获取当前用户信息
echo "4. 测试获取当前用户信息..."
curl -s -X GET "$API_BASE/auth/me" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '.'
echo ""

echo "测试完成！"