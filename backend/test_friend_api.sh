#!/bin/bash

# 测试好友 API 的脚本
# 需要先登录获取 token

API_BASE="http://localhost:8010"

echo "=== 好友 API 测试脚本 ==="
echo ""

# 1. 先登录获取 token
echo "1. 登录中..."
LOGIN_RESPONSE=$(curl -s -X POST "${API_BASE}/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "登录失败，请检查用户名和密码"
  echo "响应: $LOGIN_RESPONSE"
  exit 1
fi

echo "登录成功，获取到 token"
echo ""

# 2. 搜索用户 alice
echo "2. 搜索用户 'alice'..."
SEARCH_RESPONSE=$(curl -s -X GET "${API_BASE}/users/search?keyword=alice&limit=10" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

echo "搜索结果:"
echo $SEARCH_RESPONSE | jq '.'
echo ""

# 3. 获取好友请求列表
echo "3. 获取好友请求列表..."
FRIEND_REQUESTS_RESPONSE=$(curl -s -X GET "${API_BASE}/friends/requests" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

echo "好友请求列表:"
echo $FRIEND_REQUESTS_RESPONSE | jq '.'
echo ""

# 4. 获取好友列表
echo "4. 获取好友列表..."
FRIENDS_RESPONSE=$(curl -s -X GET "${API_BASE}/friends" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

echo "好友列表:"
echo $FRIENDS_RESPONSE | jq '.'
echo ""

echo "=== 测试完成 ==="