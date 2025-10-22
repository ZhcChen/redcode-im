#!/bin/bash

# 统一错误处理测试脚本
# 测试所有 API 端点的错误响应格式

BASE_URL="http://localhost:8010"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================"
echo "统一错误处理测试"
echo "================================"
echo ""

test_count=0
pass_count=0
fail_count=0

# 测试函数
test_api() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"
    local token="$5"
    local expected_code="$6"

    test_count=$((test_count + 1))
    echo -n "[$test_count] $name ... "

    if [ "$method" = "POST" ]; then
        if [ -n "$token" ]; then
            response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL$endpoint" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $token" \
                -d "$data")
        else
            response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL$endpoint" \
                -H "Content-Type: application/json" \
                -d "$data")
        fi
    else
        if [ -n "$token" ]; then
            response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL$endpoint" \
                -H "Authorization: Bearer $token")
        else
            response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL$endpoint")
        fi
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    # 检查是否有错误码字段
    error_code=$(echo "$body" | grep -o '"code":[0-9]*' | cut -d':' -f2)

    if [ "$http_code" = "$expected_code" ] && [ -n "$error_code" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $http_code, Error Code: $error_code)"
        pass_count=$((pass_count + 1))
        # echo "  Response: $body"
    else
        echo -e "${RED}✗ FAIL${NC} (HTTP $http_code, Expected $expected_code)"
        fail_count=$((fail_count + 1))
        echo "  Response: $body"
    fi
}

echo "1. 认证相关错误测试"
echo "----------------------------"

# 测试 1: 用户名太短
test_api "注册 - 用户名太短" "POST" "/auth/register" \
    '{"username":"ab","email":"test@example.com","password":"123456"}' \
    "" "400"

# 测试 2: 密码太短
test_api "注册 - 密码太短" "POST" "/auth/register" \
    '{"username":"testuser","email":"test@example.com","password":"12345"}' \
    "" "400"

# 测试 3: 邮箱格式错误
test_api "注册 - 邮箱格式错误" "POST" "/auth/register" \
    '{"username":"testuser","email":"invalid-email","password":"123456"}' \
    "" "400"

# 测试 4: 错误的登录凭证
test_api "登录 - 错误凭证" "POST" "/auth/login" \
    '{"username":"nonexistent","password":"wrongpass"}' \
    "" "401"

echo ""
echo "2. Token 相关错误测试"
echo "----------------------------"

# 测试 5: 无效的 Token
test_api "获取当前用户 - 无效Token" "GET" "/auth/me" \
    "" "invalid-token-here" "401"

# 测试 6: 缺少 Token
test_api "创建房间 - 缺少Token" "POST" "/rooms" \
    '{"name":"Test Room"}' \
    "" "401"

echo ""
echo "3. 成功注册并获取 Token"
echo "----------------------------"

# 创建测试用户
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
    -H "Content-Type: application/json" \
    -d "{
        \"username\": \"error_test_user_$(date +%s)\",
        \"email\": \"errortest_$(date +%s)@example.com\",
        \"password\": \"test123456\"
    }")

echo "注册响应: $REGISTER_RESPONSE"

# 登录获取 Token
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{
        \"username\": \"error_test_user_$(date +%s)\",
        \"email\": \"errortest@example.com\",
        \"password\": \"test123456\"
    }")

TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
    echo -e "${GREEN}✓ 成功获取 Token${NC}"
    echo "Token: ${TOKEN:0:50}..."
else
    echo -e "${YELLOW}⚠ 未能获取 Token，部分测试将跳过${NC}"
fi

echo ""
echo "4. 资源相关错误测试"
echo "----------------------------"

if [ -n "$TOKEN" ]; then
    # 测试 7: 房间名称为空
    test_api "创建房间 - 空名称" "POST" "/rooms" \
        '{"name":""}' \
        "$TOKEN" "400"

    # 测试 8: 访问不存在的房间成员
    test_api "查看房间成员 - 不存在的房间" "GET" "/rooms/00000000-0000-0000-0000-000000000000/members" \
        "" "$TOKEN" "200"
fi

echo ""
echo "5. 限流错误测试（需要快速发送消息）"
echo "----------------------------"

if [ -n "$TOKEN" ]; then
    # 先创建一个房间
    CREATE_ROOM=$(curl -s -X POST "$BASE_URL/rooms" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{"name":"Rate Limit Test Room"}')

    ROOM_ID=$(echo $CREATE_ROOM | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$ROOM_ID" ]; then
        echo "创建测试房间: $ROOM_ID"
        echo "发送 35 条消息测试限流..."

        rate_limit_hit=false
        for i in {1..35}; do
            response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/rooms/$ROOM_ID/messages" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $TOKEN" \
                -d "{\"content\":\"Test message $i\"}")

            http_code=$(echo "$response" | tail -n1)

            if [ "$http_code" = "429" ]; then
                body=$(echo "$response" | head -n-1)
                error_code=$(echo "$body" | grep -o '"code":[0-9]*' | cut -d':' -f2)
                echo -e "${GREEN}✓ 触发限流 (第 $i 条消息)${NC} Error Code: $error_code"
                rate_limit_hit=true
                pass_count=$((pass_count + 1))
                test_count=$((test_count + 1))
                break
            fi
        done

        if [ "$rate_limit_hit" = false ]; then
            echo -e "${RED}✗ 未触发限流${NC}"
            fail_count=$((fail_count + 1))
            test_count=$((test_count + 1))
        fi
    fi
fi

echo ""
echo "================================"
echo "测试总结"
echo "================================"
echo "总测试数: $test_count"
echo -e "通过: ${GREEN}$pass_count${NC}"
echo -e "失败: ${RED}$fail_count${NC}"
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}✓ 所有测试通过！${NC}"
    exit 0
else
    echo -e "${RED}✗ 部分测试失败${NC}"
    exit 1
fi
