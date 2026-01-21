# WebSocket 实时分发测试指南

## 概述

后端提供 WebSocket 推送能力，用于实时分发消息、已读、置顶、群事件、好友事件等。

- WebSocket 入口：`GET /ws`
- 推送格式：JSON（默认）/ Protobuf（可选）
- 客户端事件：`auth` / `join` / `leave` / `ping`

> 说明：当前实现中，即使握手 URL 里带了 `token`，也仍需要在连接建立后发送一次 `auth` 事件完成连接绑定（收到 `authed` 推送才算认证完成）。

## 前置条件

1. 启动测试栈（PG/Redis 不暴露宿主端口；Backend 默认随机分配宿主端口）：
   ```bash
   docker-compose -f tests/docker-compose.yml up -d --build
   ```
2. 准备测试账号与房间（推荐一键脚本）：
   ```bash
   cd backend
   ./test_flow.sh
   ```
   脚本会输出可用账号与房间 `room_id`（私聊/群聊）。

## 推荐测试方式：websocat

### 1) 安装工具

任选其一：
- `cargo install websocat`
- 或使用系统包管理器安装 `websocat`

### 2) 获取 token（示例）

> 以下示例使用 `test_flow.sh` 的默认账号：`13800138000 / Test123456`。

```bash
curl -sS -X POST "http://localhost:<BACKEND_HOST_PORT>/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"13800138000","password":"Test123456"}'
```

响应中获取 `token` 字段。

### 3) 连接 WebSocket

```bash
websocat "ws://localhost:<BACKEND_HOST_PORT>/ws?format=json"
```

连接成功后，手动发送 `auth`：
```json
{"type":"auth","token":"<JWT_TOKEN>"}
```

认证成功会收到：
```json
{"type":"authed","user_id":"...","conn_id":"..."}
```

### 4) 订阅房间

```json
{"type":"join","room_id":"<ROOM_UUID>"}
```

成功会收到：
```json
{"type":"joined","room_id":"<ROOM_UUID>"}
```

### 5) 触发推送（消息分发）

在另一个终端（同一房间内的任一成员 token），调用发送消息接口触发 WS 推送：

```bash
curl -sS -X POST "http://localhost:<BACKEND_HOST_PORT>/rooms/<ROOM_UUID>/messages" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "content":"hello",
    "parts":[{"type":"text","text":"hello"}]
  }'
```

订阅了该房间的连接会收到 `type=message` 的推送（字段以实际返回为准，核心键包含 `room_id`、`sender_id`、`content`、`message_type`、`parts` 等）。

### 6) 心跳

```json
{"type":"ping"}
```

会收到：
```json
{"type":"pong"}
```

## 可选：一键脚本（Node）

> 适合做“连通性 + auth + join + ping/pong”快速验证。

```bash
cd backend
USERNAME="13800138000" PASSWORD="Test123456" ROOM_ID="<ROOM_UUID>" npm run test:ws
```

如需自定义地址：
```bash
cd backend
API_BASE_URL="http://localhost:<BACKEND_HOST_PORT>" \
WS_URL="ws://localhost:<BACKEND_HOST_PORT>/ws?format=json" \
USERNAME="13800138000" PASSWORD="Test123456" ROOM_ID="<ROOM_UUID>" \
npm run test:ws
```

## 可选：Go 黑盒回归（推荐纳入 `./tests/run.sh`）

仓库已提供 Go 端的 WebSocket 冒烟用例（auth → join → message push）：

```bash
cd tests/go
API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> go test -v ./backend/ws -run TestWebSocket_
```

> 通常无需手工起后端：直接运行 `./tests/run.sh` 会自动起测试栈并执行全部 Go 回归。

## 常见问题

### 1) 收不到 joined / message

- 确认已发送 `auth` 并收到 `authed`
- `join` 会校验“用户是否为房间成员”，非成员会返回 `type=error`
- 若 Redis 不可用，房间订阅对应的 Pub/Sub 会失败，日志会提示

### 2) 401 / 连接被拒绝

- HTTP 接口 401：检查请求头是否带 `Authorization: Bearer ...`
- WS：当前实现可能在握手阶段对 `token` 做校验（无效则 401）；推荐做法是握手不带 token，连接后走 `auth` 事件
