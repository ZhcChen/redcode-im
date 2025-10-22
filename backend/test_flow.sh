#!/bin/bash

# WebSocket实时消息测试流程
# 使用方法：chmod +x test_flow.sh && ./test_flow.sh

BASE_URL="http://localhost:8010"

echo "================================"
echo "WebSocket 实时消息测试流程"
echo "================================"
echo ""

# 1. 注册两个测试用户
echo "步骤 1: 注册测试用户..."
USER1=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_test",
    "email": "alice@test.com",
    "password": "test123456",
    "nickname": "Alice"
  }')

USER2=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_test",
    "email": "bob@test.com",
    "password": "test123456",
    "nickname": "Bob"
  }')

echo "用户1: $USER1"
echo "用户2: $USER2"
echo ""

# 2. 登录获取token
echo "步骤 2: 登录获取 JWT Token..."
LOGIN1=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "alice_test",
    "password": "test123456"
  }')

LOGIN2=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "bob_test",
    "password": "test123456"
  }')

TOKEN1=$(echo $LOGIN1 | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
TOKEN2=$(echo $LOGIN2 | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

echo "Alice Token: ${TOKEN1:0:50}..."
echo "Bob Token: ${TOKEN2:0:50}..."
echo ""

# 3. 创建房间
echo "步骤 3: 创建测试房间..."
ROOM=$(curl -s -X POST "$BASE_URL/rooms" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN1" \
  -d '{
    "name": "测试聊天室",
    "description": "WebSocket测试",
    "room_type": "group"
  }')

ROOM_ID=$(echo $ROOM | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
echo "房间ID: $ROOM_ID"
echo ""

# 4. Bob加入房间
echo "步骤 4: Bob 加入房间..."
JOIN=$(curl -s -X POST "$BASE_URL/rooms/$ROOM_ID/join" \
  -H "Authorization: Bearer $TOKEN2")
echo "加入结果: $JOIN"
echo ""

# 5. 输出WebSocket测试信息
echo "================================"
echo "🎉 准备工作完成！"
echo "================================"
echo ""
echo "现在请执行以下操作测试实时消息："
echo ""
echo "1. 在浏览器打开: file://$(pwd)/test_websocket.html"
echo ""
echo "2. 打开两个浏览器标签页（模拟Alice和Bob）"
echo ""
echo "3. Alice标签页："
echo "   - Token: $TOKEN1"
echo "   - 房间ID: $ROOM_ID"
echo "   - 点击 [连接] -> [加入房间]"
echo ""
echo "4. Bob标签页："
echo "   - Token: $TOKEN2"
echo "   - 房间ID: $ROOM_ID"
echo "   - 点击 [连接] -> [加入房间]"
echo ""
echo "5. 在任一标签页输入消息点击 [发送到房间]"
echo "   ✅ 应该看到两个标签页都实时收到消息"
echo ""
echo "================================"
echo "快速测试命令（发送消息）："
echo "================================"
echo ""
echo "curl -X POST \"$BASE_URL/rooms/$ROOM_ID/messages\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"Authorization: Bearer $TOKEN1\" \\"
echo "  -d '{\"content\": \"Hello from Alice!\", \"message_type\": \"text\"}'"
echo ""
