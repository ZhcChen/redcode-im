#!/bin/bash

# 认证API测试脚本

BASE_URL="http://localhost:8080"

echo "🧪 测试用户认证系统"
echo "================================"

# 测试1: 健康检查
echo "1. 测试健康检查..."
curl -s $BASE_URL/healthz

echo -e "\n\n2. 测试用户注册..."
# 测试用户注册
REGISTER_RESPONSE=$(curl -s -X POST $BASE_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "password123",
    "nickname": "测试用户"
  }')
echo "注册响应: $REGISTER_RESPONSE"

echo -e "\n\n3. 测试用户登录..."
# 测试用户登录
LOGIN_RESPONSE=$(curl -s -X POST $BASE_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "password123"
  }')
echo "登录响应: $LOGIN_RESPONSE"

# 提取token
TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token')
echo "提取的Token: $TOKEN"

if [ "$TOKEN" != "null" ] && [ "$TOKEN" != "" ]; then
    echo -e "\n\n4. 测试获取当前用户信息..."
    # 测试获取当前用户信息
    curl -s -X GET $BASE_URL/auth/me \
      -H "Authorization: Bearer $TOKEN"
else
    echo -e "\n\n❌ 登录失败，无法获取token"
fi

echo -e "\n\n5. 测试重复注册（应该失败）..."
curl -s -X POST $BASE_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test2@example.com",
    "password": "password123"
  }'

echo -e "\n\n6. 测试错误登录..."
curl -s -X POST $BASE_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "wrongpassword"
  }'

echo -e "\n\n✅ 测试完成！"