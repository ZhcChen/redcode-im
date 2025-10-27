# WebSocket 实时分发测试指南

## 概述
本项目已实现完整的WebSocket实时消息分发功能，支持：
- JWT Token认证
- 房间订阅/取消订阅
- Redis Pub/Sub跨节点消息分发
- 消息实时广播到房间内所有连接

## 架构说明

### 消息流程
1. 客户端通过HTTP API发送消息到服务器
2. 服务器将消息存储到PostgreSQL数据库
3. 服务器发布消息到Redis Pub/Sub频道（`room:{room_id}`）
4. 所有订阅该房间的WebSocket连接收到消息
5. WebSocket将消息推送给客户端

### 关键组件
- **ConnectionManager**: 管理WebSocket连接、用户映射、房间订阅
- **Redis Pub/Sub**: 实现跨节点消息分发
- **WebSocket Handler**: 处理连接认证、房间订阅、消息转发

## 测试工具

### 1. HTML可视化测试页面
```bash
# 打开浏览器访问
open backend/test_websocket.html
```
- 提供两个用户面板，可视化测试消息实时分发
- 支持登录、连接、认证、订阅、发送消息等操作

### 2. Node.js自动化测试脚本
```bash
cd backend

# 安装依赖
npm install

# 运行测试
npm run test:ws
# 或
node test_websocket.js
```
- 自动完成用户注册、登录、WebSocket连接、消息发送和验证
- 输出彩色测试结果

### 3. Bash测试脚本（需要websocat）
```bash
# 安装websocat (可选)
cargo install websocat

# 运行测试
cd backend
./test_websocket.sh
```

## 快速开始

### 1. 启动依赖服务
```bash
# 启动PostgreSQL和Redis
docker-compose up -d
```

### 2. 启动后端服务
```bash
cd backend
cargo run
```
服务将在 http://localhost:8010 启动

### 3. 运行测试
选择以下任一方式：

#### 方式A：使用HTML页面手动测试
1. 打开 `test_websocket.html`
2. 点击"登录获取Token"
3. 点击"连接WebSocket"
4. 点击"认证"
5. 点击"加入房间"
6. 输入消息并发送
7. 观察两个用户面板的消息接收情况

#### 方式B：运行自动化测试
```bash
cd backend
npm install
node test_websocket.js
```

## WebSocket协议

### 客户端消息格式

#### 认证
```json
{
  "type": "auth",
  "token": "JWT_TOKEN_HERE"
}
```

#### 加入房间
```json
{
  "type": "join",
  "room_id": "UUID"
}
```

#### 离开房间
```json
{
  "type": "leave",
  "room_id": "UUID"
}
```

#### 心跳
```json
{
  "type": "ping"
}
```

### 服务端消息格式

#### 认证成功
```json
{
  "type": "authed",
  "user_id": "USER_ID",
  "conn_id": "CONNECTION_ID"
}
```

#### 加入房间成功
```json
{
  "type": "joined",
  "room_id": "ROOM_ID"
}
```

#### 收到消息
```json
{
  "type": "message",
  "room_id": "ROOM_ID",
  "sender_id": "SENDER_ID",
  "content": "MESSAGE_CONTENT",
  "message_type": "text",
  "timestamp": "ISO_8601_TIMESTAMP"
}
```

#### 错误
```json
{
  "type": "error",
  "message": "ERROR_MESSAGE"
}
```

## 测试用例

### 1. 基本连接测试
- [x] WebSocket连接建立
- [x] JWT Token认证
- [x] 认证失败处理

### 2. 房间订阅测试
- [x] 加入房间
- [x] 离开房间
- [x] 重复加入处理

### 3. 消息分发测试
- [x] 同房间用户收到消息
- [x] 不同房间用户隔离
- [x] 多连接用户消息同步

### 4. 性能测试
- [x] 并发连接处理
- [x] 消息广播延迟
- [x] Redis Pub/Sub吞吐量

## 故障排除

### WebSocket连接失败
1. 检查后端服务是否运行：`curl http://localhost:8010/healthz`
2. 检查Token是否有效
3. 查看服务器日志：`RUST_LOG=debug cargo run`

### 消息未收到
1. 确认用户已加入房间
2. 检查Redis连接：`docker-compose ps`
3. 查看Redis订阅：`redis-cli -p 6381 pubsub channels`

### 认证失败
1. 确认用户已注册
2. 检查Token格式
3. 验证Token未过期

## 性能优化建议

1. **连接池优化**
   - 使用连接池管理Redis连接
   - 限制每个用户的最大连接数

2. **消息批处理**
   - 批量发送消息到Redis
   - 使用消息队列缓冲高峰流量

3. **横向扩展**
   - 支持多节点部署
   - 使用负载均衡分发WebSocket连接

## 下一步计划

- [ ] 添加消息确认机制（ACK）
- [ ] 实现离线消息存储和推送
- [ ] 添加消息加密
- [ ] 支持二进制消息（文件、图片）
- [ ] 实现typing状态同步
- [ ] 添加在线状态广播
