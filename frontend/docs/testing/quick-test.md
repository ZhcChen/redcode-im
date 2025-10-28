# 快速测试指南

## 一键启动测试

### 1. 启动后端（终端1）
```bash
cd backend
docker-compose up -d
cargo run
```

### 2. 准备测试数据（终端2）
```bash
cd backend
./test_flow.sh
```
这会创建两个测试用户：
- alice / password123
- bob / password123

### 3. 启动Flutter应用（终端3）
```bash
cd frontend
flutter run
```

## 测试流程

### 步骤1：登录
- 应用启动后显示登录页
- 默认已填充账号：alice，密码：password123
- 点击"登录账号"按钮

### 步骤2：验证WebSocket连接
- 登录成功后自动跳转到主页
- 查看控制台输出，应该看到：
  ```
  WebSocket connected after login
  WebSocket authenticated: conn_xxxxx
  ```

### 步骤3：测试消息
1. 点击底部"聊天"标签
2. 进入任意聊天室
3. 发送消息
4. 在另一个设备/模拟器用bob账号登录
5. 进入相同聊天室
6. 验证消息实时同步

## 验证清单

| 步骤 | 预期结果 | 状态 |
|-----|---------|------|
| 1. 登录 | 成功跳转到主页 | ⬜ |
| 2. WebSocket连接 | 控制台显示连接成功 | ⬜ |
| 3. 进入聊天室 | 加载历史消息 | ⬜ |
| 4. 发送消息 | 消息显示在列表中 | ⬜ |
| 5. 接收消息 | 实时收到其他用户消息 | ⬜ |

## 常用命令

### 查看后端日志
```bash
RUST_LOG=debug cargo run
```

### 查看Flutter日志
```bash
flutter run -v
```

### 清理数据重新测试
```bash
# 清理数据库
docker-compose down -v
docker-compose up -d

# 重新创建测试用户
./test_flow.sh
```

## 测试账号信息

| 账号 | 密码 | 用途 |
|------|------|------|
| alice | password123 | 测试用户1 |
| bob | password123 | 测试用户2 |

## 测试房间

默认测试房间ID：`00000000-0000-0000-0000-000000000001`

## 问题排查

### 登录失败
- 检查后端是否在8010端口运行
- 确认已运行test_flow.sh创建用户

### WebSocket连接失败  
- 查看后端控制台是否有WebSocket连接日志
- 检查Token是否正确保存

### 消息发送失败
- 确认已加入房间
- 检查网络请求是否正常

---

**完整流程已实现**：登录 → WebSocket连接 → 消息收发
