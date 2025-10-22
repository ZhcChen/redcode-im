#!/bin/bash

# 全栈测试脚本
# 用于快速启动和测试整个系统

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}RedCode IM 全栈测试${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查Docker是否运行
echo -e "\n${YELLOW}检查Docker...${NC}"
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker未运行，请先启动Docker${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker正在运行${NC}"

# 启动数据库和Redis
echo -e "\n${YELLOW}启动数据库和Redis...${NC}"
cd backend
docker-compose down
docker-compose up -d
sleep 3
echo -e "${GREEN}✓ 数据库和Redis已启动${NC}"

# 启动后端服务
echo -e "\n${YELLOW}启动后端服务...${NC}"
cargo build --release
cargo run &
BACKEND_PID=$!
sleep 5

# 检查后端服务
if curl -s http://localhost:8010/healthz > /dev/null; then
    echo -e "${GREEN}✓ 后端服务已启动（PID: $BACKEND_PID）${NC}"
else
    echo -e "${RED}✗ 后端服务启动失败${NC}"
    kill $BACKEND_PID 2>/dev/null
    exit 1
fi

# 创建测试用户
echo -e "\n${YELLOW}创建测试用户...${NC}"
./test_flow.sh
echo -e "${GREEN}✓ 测试用户已创建${NC}"

# 运行WebSocket测试
echo -e "\n${YELLOW}运行WebSocket测试...${NC}"
if command -v node &> /dev/null; then
    npm install
    node test_websocket.js &
    WS_TEST_PID=$!
    wait $WS_TEST_PID
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ WebSocket测试通过${NC}"
    else
        echo -e "${YELLOW}! WebSocket测试有部分失败${NC}"
    fi
else
    echo -e "${YELLOW}! 未安装Node.js，跳过WebSocket自动测试${NC}"
fi

# 提示Flutter测试
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}后端服务已就绪！${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}现在可以测试Flutter应用：${NC}"
echo "1. 打开新终端"
echo "2. cd frontend"
echo "3. flutter run"
echo ""
echo -e "${YELLOW}测试账号：${NC}"
echo "• alice / password123"
echo "• bob / password123"
echo ""
echo -e "${YELLOW}测试步骤：${NC}"
echo "1. 使用alice账号登录"
echo "2. 进入聊天室发送消息"
echo "3. 用另一个设备/模拟器登录bob账号"
echo "4. 验证消息实时同步"
echo ""
echo -e "${YELLOW}WebSocket测试页面：${NC}"
echo "打开浏览器访问: file://$(pwd)/test_websocket.html"
echo ""
echo -e "${YELLOW}按 Ctrl+C 停止所有服务${NC}"

# 等待用户中断
trap cleanup INT

cleanup() {
    echo -e "\n${YELLOW}正在停止服务...${NC}"
    kill $BACKEND_PID 2>/dev/null
    docker-compose down
    echo -e "${GREEN}✓ 所有服务已停止${NC}"
    exit 0
}

# 保持脚本运行
while true; do
    sleep 1
done
