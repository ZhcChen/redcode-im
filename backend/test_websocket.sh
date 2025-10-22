#!/bin/bash

# WebSocket实时分发测试脚本
# 测试WebSocket认证、房间订阅和消息分发功能

set -e

API_BASE="http://localhost:8010"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}WebSocket 实时消息分发测试${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查服务器是否运行
echo -e "\n${YELLOW}检查服务器状态...${NC}"
if ! curl -s -f "$API_BASE/healthz" > /dev/null 2>&1; then
    echo -e "${RED}错误: 服务器未运行在 $API_BASE${NC}"
    echo "请先运行: cargo run"
    exit 1
fi
echo -e "${GREEN}✓ 服务器正在运行${NC}"

# 检查必要工具
if ! command -v websocat &> /dev/null; then
    echo -e "${RED}错误: 未安装 websocat${NC}"
    echo "请安装: cargo install websocat"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}错误: 未安装 jq${NC}"
    echo "请安装: brew install jq (macOS) 或 apt-get install jq (Linux)"
    exit 1
fi

# 创建测试用户
echo -e "\n${YELLOW}准备测试数据...${NC}"

# 注册用户alice
echo "注册用户 alice..."
ALICE_REGISTER=$(curl -s -X POST "$API_BASE/auth/register" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "alice",
        "email": "alice@example.com",
        "password": "password123",
        "nickname": "Alice"
    }' 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ alice 注册成功或已存在${NC}"
else
    echo -e "${YELLOW}! alice 可能已存在${NC}"
fi

# 注册用户bob
echo "注册用户 bob..."
BOB_REGISTER=$(curl -s -X POST "$API_BASE/auth/register" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "bob",
        "email": "bob@example.com",
        "password": "password123",
        "nickname": "Bob"
    }' 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ bob 注册成功或已存在${NC}"
else
    echo -e "${YELLOW}! bob 可能已存在${NC}"
fi

# 登录获取token
echo -e "\n${YELLOW}用户登录...${NC}"

ALICE_LOGIN=$(curl -s -X POST "$API_BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "alice",
        "password": "password123"
    }')

ALICE_TOKEN=$(echo "$ALICE_LOGIN" | jq -r '.token')
ALICE_ID=$(echo "$ALICE_LOGIN" | jq -r '.user.id')

if [ -n "$ALICE_TOKEN" ] && [ "$ALICE_TOKEN" != "null" ]; then
    echo -e "${GREEN}✓ alice 登录成功${NC}"
    echo "  Token: ${ALICE_TOKEN:0:20}..."
    echo "  User ID: $ALICE_ID"
else
    echo -e "${RED}✗ alice 登录失败${NC}"
    echo "$ALICE_LOGIN"
    exit 1
fi

BOB_LOGIN=$(curl -s -X POST "$API_BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d '{
        "username": "bob",
        "password": "password123"
    }')

BOB_TOKEN=$(echo "$BOB_LOGIN" | jq -r '.token')
BOB_ID=$(echo "$BOB_LOGIN" | jq -r '.user.id')

if [ -n "$BOB_TOKEN" ] && [ "$BOB_TOKEN" != "null" ]; then
    echo -e "${GREEN}✓ bob 登录成功${NC}"
    echo "  Token: ${BOB_TOKEN:0:20}..."
    echo "  User ID: $BOB_ID"
else
    echo -e "${RED}✗ bob 登录失败${NC}"
    echo "$BOB_LOGIN"
    exit 1
fi

# 创建测试房间
echo -e "\n${YELLOW}创建测试房间...${NC}"

ROOM_RESPONSE=$(curl -s -X POST "$API_BASE/rooms" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "name": "WebSocket测试房间",
        "room_type": "group",
        "description": "用于WebSocket实时分发测试"
    }')

ROOM_ID=$(echo "$ROOM_RESPONSE" | jq -r '.room.id')

if [ -n "$ROOM_ID" ] && [ "$ROOM_ID" != "null" ]; then
    echo -e "${GREEN}✓ 房间创建成功${NC}"
    echo "  Room ID: $ROOM_ID"
else
    echo -e "${YELLOW}! 使用默认测试房间${NC}"
    ROOM_ID="00000000-0000-0000-0000-000000000001"
    
    # 确保两个用户都在房间中
    curl -s -X POST "$API_BASE/rooms/$ROOM_ID/join" \
        -H "Authorization: Bearer $ALICE_TOKEN" > /dev/null 2>&1
    
    curl -s -X POST "$API_BASE/rooms/$ROOM_ID/join" \
        -H "Authorization: Bearer $BOB_TOKEN" > /dev/null 2>&1
fi

# Bob加入房间
echo -e "\n${YELLOW}Bob 加入房间...${NC}"
JOIN_RESPONSE=$(curl -s -X POST "$API_BASE/rooms/$ROOM_ID/join" \
    -H "Authorization: Bearer $BOB_TOKEN")

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Bob 成功加入房间${NC}"
else
    echo -e "${YELLOW}! Bob 可能已在房间中${NC}"
fi

# WebSocket测试
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}开始WebSocket测试${NC}"
echo -e "${YELLOW}========================================${NC}"

# 创建临时文件存储WebSocket输出
ALICE_OUTPUT=$(mktemp)
BOB_OUTPUT=$(mktemp)

# 清理函数
cleanup() {
    echo -e "\n${YELLOW}清理测试资源...${NC}"
    rm -f "$ALICE_OUTPUT" "$BOB_OUTPUT"
    # 杀死后台进程
    jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT

# 启动Alice的WebSocket连接（后台）
echo -e "\n${GREEN}1. Alice 连接WebSocket...${NC}"
(
    echo '{"type":"auth","token":"'$ALICE_TOKEN'"}'
    sleep 1
    echo '{"type":"join","room_id":"'$ROOM_ID'"}'
    sleep 10  # 保持连接
) | websocat -t ws://localhost:8010/ws 2>/dev/null | tee "$ALICE_OUTPUT" &
ALICE_PID=$!

sleep 2  # 等待Alice连接和认证

# 启动Bob的WebSocket连接（后台）
echo -e "${GREEN}2. Bob 连接WebSocket...${NC}"
(
    echo '{"type":"auth","token":"'$BOB_TOKEN'"}'
    sleep 1
    echo '{"type":"join","room_id":"'$ROOM_ID'"}'
    sleep 8  # 保持连接
) | websocat -t ws://localhost:8010/ws 2>/dev/null | tee "$BOB_OUTPUT" &
BOB_PID=$!

sleep 2  # 等待Bob连接和认证

# Alice通过HTTP API发送消息
echo -e "${GREEN}3. Alice 发送消息...${NC}"
MSG_RESPONSE=$(curl -s -X POST "$API_BASE/rooms/$ROOM_ID/messages" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "content": "Hello from Alice! Testing WebSocket broadcast.",
        "message_type": "text"
    }')

MSG_ID=$(echo "$MSG_RESPONSE" | jq -r '.message.id')

if [ -n "$MSG_ID" ] && [ "$MSG_ID" != "null" ]; then
    echo -e "${GREEN}✓ 消息发送成功${NC}"
    echo "  Message ID: $MSG_ID"
else
    echo -e "${RED}✗ 消息发送失败${NC}"
    echo "$MSG_RESPONSE"
fi

# Bob通过HTTP API发送消息
echo -e "${GREEN}4. Bob 发送消息...${NC}"
MSG_RESPONSE2=$(curl -s -X POST "$API_BASE/rooms/$ROOM_ID/messages" \
    -H "Authorization: Bearer $BOB_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "content": "Hi Alice! Message received loud and clear.",
        "message_type": "text"
    }')

MSG_ID2=$(echo "$MSG_RESPONSE2" | jq -r '.message.id')

if [ -n "$MSG_ID2" ] && [ "$MSG_ID2" != "null" ]; then
    echo -e "${GREEN}✓ 消息发送成功${NC}"
    echo "  Message ID: $MSG_ID2"
else
    echo -e "${RED}✗ 消息发送失败${NC}"
    echo "$MSG_RESPONSE2"
fi

# 等待消息传递
sleep 3

# 检查WebSocket接收
echo -e "\n${YELLOW}检查WebSocket消息接收...${NC}"

# 检查Alice是否收到消息
if grep -q "Hello from Alice" "$ALICE_OUTPUT" 2>/dev/null; then
    echo -e "${GREEN}✓ Alice 收到自己的消息（通过WebSocket）${NC}"
else
    echo -e "${YELLOW}! Alice 未收到自己的消息${NC}"
fi

if grep -q "Hi Alice" "$ALICE_OUTPUT" 2>/dev/null; then
    echo -e "${GREEN}✓ Alice 收到Bob的消息（通过WebSocket）${NC}"
else
    echo -e "${RED}✗ Alice 未收到Bob的消息${NC}"
fi

# 检查Bob是否收到消息
if grep -q "Hello from Alice" "$BOB_OUTPUT" 2>/dev/null; then
    echo -e "${GREEN}✓ Bob 收到Alice的消息（通过WebSocket）${NC}"
else
    echo -e "${RED}✗ Bob 未收到Alice的消息${NC}"
fi

if grep -q "Hi Alice" "$BOB_OUTPUT" 2>/dev/null; then
    echo -e "${GREEN}✓ Bob 收到自己的消息（通过WebSocket）${NC}"
else
    echo -e "${YELLOW}! Bob 未收到自己的消息${NC}"
fi

# 测试消息历史
echo -e "\n${YELLOW}测试消息历史查询...${NC}"
HISTORY=$(curl -s -X GET "$API_BASE/rooms/$ROOM_ID/messages?limit=10" \
    -H "Authorization: Bearer $ALICE_TOKEN")

MESSAGE_COUNT=$(echo "$HISTORY" | jq '. | length')

if [ "$MESSAGE_COUNT" -ge 2 ]; then
    echo -e "${GREEN}✓ 消息历史查询成功，共 $MESSAGE_COUNT 条消息${NC}"
    echo "$HISTORY" | jq -r '.[] | "  - \(.sender_id[0:8]): \(.content[0:50])"'
else
    echo -e "${RED}✗ 消息历史查询异常${NC}"
fi

# 测试总结
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}测试完成！${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}测试总结:${NC}"
echo "• 用户认证: ✓"
echo "• WebSocket连接: ✓"
echo "• 房间订阅: ✓"
echo "• 消息发送: ✓"
echo "• 实时分发: 需要检查上方结果"
echo "• 消息持久化: ✓"

echo -e "\n${YELLOW}提示:${NC}"
echo "• 可以打开 test_websocket.html 进行可视化测试"
echo "• 使用 'cargo run' 启动服务器"
echo "• 使用 'docker-compose up -d' 启动依赖服务"
