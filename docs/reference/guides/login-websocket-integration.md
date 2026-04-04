# 登录与WebSocket完整集成说明

## 当前实现状态

### ✅ 已完成功能

1. **用户登录** - 已对接后端API
   - 登录接口：`POST /auth/login`
   - 支持JWT Token认证
   - Token自动保存到本地存储

2. **WebSocket连接** - 登录后自动连接
   - 自动使用登录Token进行WebSocket认证
   - 支持自动重连和心跳保活

3. **消息系统** - 完整的收发功能
   - HTTP API发送消息
   - WebSocket接收实时消息
   - 消息状态管理

## 完整流程

### 1. 用户登录流程

```
用户输入账号密码
    ↓
调用后端 /auth/login API
    ↓
获取JWT Token和用户信息
    ↓
保存到 SharedPreferences
    ↓
跳转到主页面
    ↓
自动连接WebSocket
```

### 2. WebSocket连接流程

```
读取保存的Token
    ↓
建立WebSocket连接 (wss://api.chatlyme.com/ws)
    ↓
发送认证消息 {"type": "auth", "token": "..."}
    ↓
接收认证成功响应
    ↓
状态变为 authenticated
    ↓
可以订阅房间接收消息
```

### 3. 消息收发流程

```
发送消息:
用户输入 → HTTP API → 服务器存储 → Redis Pub/Sub → WebSocket广播

接收消息:
其他用户发送 → Redis Pub/Sub → WebSocket推送 → 更新UI
```

## 测试步骤

### 准备工作

1. **启动后端服务**
```bash
cd backend
cp .env.example .env
docker compose -f docker/dev/docker-compose.yml up -d backend
```

2. **创建测试用户**（如果还没创建）
```bash
cd backend
./test_flow.sh  # 创建alice和bob两个测试用户
```

### 测试流程

1. **启动Flutter应用**
```bash
cd frontend
flutter run
```

2. **登录测试**
   - 默认填充账号：alice
   - 默认填充密码：password123
   - 也可以使用bob/password123登录
   - 点击"登录账号"

3. **验证WebSocket连接**
   - 登录成功后自动跳转到主页
   - WebSocket会自动连接并认证
   - 可以在控制台看到连接日志

4. **测试消息功能**
   - 进入任意聊天室
   - 发送消息
   - 在另一个设备/模拟器用另一个账号登录
   - 验证消息实时同步

## 配置说明

### 前端配置文件
`frontend/lib/core/constants/app_config.dart`
```dart
class AppConfig {
  static const apiBaseUrl = 'https://api.chatlyme.com';  // 后端API地址
  static const wsUrl = 'wss://api.chatlyme.com/ws';      // WebSocket地址
  static const useMockData = false;                    // 关闭Mock模式
}
```

### 测试账号
| 用户名 | 密码 | 说明 |
|-------|------|------|
| alice | password123 | 测试用户1 |
| bob | password123 | 测试用户2 |

### 测试房间
| 房间ID | 说明 |
|--------|------|
| 00000000-0000-0000-0000-000000000001 | 默认测试房间 |

## 调试技巧

### 查看登录日志
在VS Code调试控制台或终端中可以看到：
```
Login successful: alice
WebSocket connecting...
WebSocket authenticated
```

### 查看WebSocket状态
在任何页面可以通过监听WebSocketService查看状态：
```dart
WebSocketService.instance.addListener(() {
  print('WebSocket status: ${WebSocketService.instance.status}');
});
```

### 手动测试WebSocket
如果需要独立测试WebSocket，可以：
1. 先通过登录获取Token
2. 使用浏览器控制台或websocat工具连接
3. 发送认证消息测试

## 常见问题

### 1. 登录失败
**问题**：提示"用户名或密码错误"
**解决**：
- 确认后端服务已启动（端口8010）
- 运行 `test_flow.sh` 创建测试用户
- 使用正确的用户名密码（alice/password123）

### 2. WebSocket连接失败
**问题**：WebSocket无法连接或认证失败
**解决**：
- 检查Token是否正确保存
- 确认后端WebSocket服务正常
- 查看后端日志排查问题

### 3. 消息无法发送
**问题**：发送消息一直显示发送中
**解决**：
- 检查是否已加入房间
- 确认WebSocket已认证
- 查看网络请求是否正常

### 4. 消息不同步
**问题**：其他用户发的消息收不到
**解决**：
- 确认已订阅房间
- 检查Redis是否正常运行
- 查看WebSocket连接状态

## 完整性检查

| 功能 | 状态 | 备注 |
|-----|------|------|
| 用户登录 | ✅ | 对接 /auth/login |
| 验证码登录 | ✅ | 对接 /auth/login/sms（需后端开启验证码登录开关） |
| 用户注册 | ✅ | 对接 /auth/register |
| 找回密码 | ✅ | 对接 /auth/password/reset |
| 第三方登录 | ✅ | 对接 /auth/login/oauth（Google/Apple，需配置环境变量） |
| Token存储 | ✅ | SharedPreferences |
| WebSocket连接 | ✅ | 自动连接 |
| WebSocket认证 | ✅ | JWT Token |
| 房间订阅 | ✅ | join/leave |
| 发送消息 | ✅ | HTTP API |
| 接收消息 | ✅ | WebSocket |
| 消息状态 | ✅ | 发送/送达/已读 |
| 断线重连 | ✅ | 自动重连 |
| 心跳保活 | ✅ | 30秒间隔 |

## 后续优化建议

1. **登录体验**
   - 添加记住密码功能
   - 实现自动登录
   - ✅ 支持手机号验证码登录

2. **连接优化**
   - 后台保活策略
   - 消息队列缓存
   - ✅ 离线消息同步

3. **功能扩展**
   - ✅ 用户注册功能
   - ✅ 找回密码功能
   - ✅ 第三方登录（Google/Apple）

## 第三方登录（Google / Apple）

客户端获取第三方 `id_token` 后，调用：

- `POST /auth/login/oauth`

请求体：
```json
{
  "provider": "google",
  "id_token": "..."
}
```

后端需要配置环境变量：

- `GOOGLE_OAUTH_CLIENT_ID`（Google）
- `APPLE_OAUTH_CLIENT_ID`（Apple）

当前登录和WebSocket功能已完全对接，可以进行完整的即时通讯测试。
