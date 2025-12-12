# WebSocket 实时分发测试指南

## 概述

后端提供 WebSocket 推送能力，用于实时分发消息、已读、置顶、群事件、好友事件等。

- WebSocket 入口：`GET /ws`
- 推送格式：JSON（默认）/ Protobuf（可选）
- 客户端事件：`auth` / `join` / `leave` / `ping`

> 说明：当前实现中，即使握手 URL 里带了 `token`，也仍需要在连接建立后发送一次 `auth` 事件完成连接绑定（收到 `authed` 推送才算认证完成）。

## 前置条件

1. 启动依赖服务（PostgreSQL/Redis）：
   ```bash
   cd backend
   docker compose up -d postgres redis-session redis-cache
   ```
2. 启动后端：
   ```bash
   cd backend
   RUST_LOG=debug cargo run
   ```
3. 准备两个可用的测试账号（或自行注册）与一个可用的房间（room_id）。

## 推荐测试方式：websocat

### 1) 安装工具

任选其一：
- `cargo install websocat`
- 或使用系统包管理器安装 `websocat`

### 2) 获取 token（示例）

> 以下仅为示例命令，账号规则/密码策略以实际环境为准。

```bash
curl -sS -X POST "http://localhost:8010/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"15300000000","password":"Passw0rd!"}'
```

响应中获取 `token` 字段。

### 3) 连接 WebSocket

```bash
websocat "ws://localhost:8010/ws?format=json"
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
curl -sS -X POST "http://localhost:8010/rooms/<ROOM_UUID>/messages" \
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

## 常见问题

### 1) 收不到 joined / message

- 确认已发送 `auth` 并收到 `authed`
- `join` 会校验“用户是否为房间成员”，非成员会返回 `type=error`
- 若 Redis 不可用，房间订阅对应的 Pub/Sub 会失败，日志会提示

### 2) 401 / 连接被拒绝

- HTTP 接口 401：检查请求头是否带 `Authorization: Bearer ...`
- WS：当前实现可能在握手阶段对 `token` 做校验（无效则 401）；推荐做法是握手不带 token，连接后走 `auth` 事件
