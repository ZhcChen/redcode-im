# 快速测试指南（5-10 分钟冒烟）

## 一键启动（终端1：依赖 + 后端）

```bash
# 启动测试栈（PG/Redis 不暴露宿主端口；Backend 默认暴露到宿主 8010）
docker-compose -f tests/docker-compose.yml up -d --build

# 如宿主 8010 被占用：
# BACKEND_HOST_PORT=18010 docker-compose -f tests/docker-compose.yml up -d --build
```

## 准备测试数据（终端2）

```bash
cd backend
./test_flow.sh
```

脚本会创建/复用测试账号、好友关系、私聊/群聊房间，并输出可用的 `room_id`。

默认测试账号：
- `13800138000` / `Test123456`
- `13800138001` / `Test123456`
- `13800138002` / `Test123456`

## 启动 Flutter（终端3）

```bash
cd frontend
flutter run --dart-define=API_BASE_URL=http://localhost:8010 --dart-define=WS_URL=ws://localhost:8010/ws
```

> Android 模拟器访问宿主机后端：把 `localhost` 替换为 `10.0.2.2`；真机请使用宿主机 IP。

## 测试流程

### 步骤1：登录

- 使用 `13800138000` / `Test123456` 登录（按需勾选用户协议）。

### 步骤2：验证 WebSocket 连接

- 登录成功后应自动建立 WebSocket 连接（控制台/日志可看到连接与认证信息）。

### 步骤3：测试私聊消息

1. 在另一台设备/模拟器使用 `13800138001` 登录
2. 两端进入会话列表中的私聊会话（通常显示为“测试用户2”）
3. 双向发送消息，验证实时同步与消息状态更新

### 步骤4：测试群聊消息

1. 进入会话列表中的群聊“自动化测试群聊”
2. 双端发送消息，验证实时同步

## 验证清单

| 步骤 | 预期结果 | 状态 |
|-----|---------|------|
| 1. 登录 | 成功进入主页 | ⬜ |
| 2. WebSocket | 连接并认证成功 | ⬜ |
| 3. 私聊收发 | 双端实时同步 | ⬜ |
| 4. 群聊收发 | 双端实时同步 | ⬜ |

## 清理数据重新测试

```bash
docker-compose -f tests/docker-compose.yml down -v
docker-compose -f tests/docker-compose.yml up -d --build
cd backend && ./test_flow.sh
```

## 问题排查

### 登录失败
- 确认后端在 `8010` 端口运行（`GET /healthz` 返回 200）
- 确认 `API_BASE_URL` 指向正确地址（Android 模拟器用 `10.0.2.2`）

### WebSocket 连接失败
- 确认 `WS_URL` 指向正确地址（Android 模拟器用 `10.0.2.2`）
- 检查测试栈是否正常运行（`docker-compose -f tests/docker-compose.yml ps`）

### 消息发送/同步异常
- 确认已运行 `./test_flow.sh` 准备好友关系与房间
- 查看后端日志定位 4xx/5xx 与 WS 推送情况
