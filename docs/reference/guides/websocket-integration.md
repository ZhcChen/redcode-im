# WebSocket 消息系统集成文档

## 概述
已完成Flutter前端与后端WebSocket的实时消息系统集成，支持消息的发送、接收和状态管理。

## 实现的功能

### 1. WebSocket服务（WebSocketService）
- ✅ WebSocket连接管理
- ✅ 自动重连机制
- ✅ JWT Token认证
- ✅ 房间订阅/取消订阅
- ✅ 心跳保活
- ✅ 网络状态监听

### 2. 消息服务（MessageService）
- ✅ 消息发送（HTTP API）
- ✅ 消息接收（WebSocket）
- ✅ 消息状态管理（发送中、已发送、已送达、已读、失败）
- ✅ 消息重发机制
- ✅ 本地消息缓存
- ✅ 历史消息加载

### 3. 聊天界面（ChatDetailPageV2）
- ✅ 实时消息展示
- ✅ 消息发送状态显示
- ✅ 失败消息重发
- ✅ 消息时间戳分组
- ✅ 表情和更多功能面板

## 架构设计

```
┌─────────────────┐
│   Flutter App   │
├─────────────────┤
│  ChatProvider   │ ← 管理聊天状态
├─────────────────┤
│ MessageService  │ ← 消息发送/接收
├─────────────────┤
│WebSocketService │ ← WebSocket连接
└────────┬────────┘
         │
    WebSocket/HTTP
         │
┌────────▼────────┐
│  API API    │
│   (Rust/Axum)   │
├─────────────────┤
│ Redis Pub/Sub   │ ← 消息分发
├─────────────────┤
│   PostgreSQL    │ ← 消息持久化
└─────────────────┘
```

## 使用方法

### 1. 初始化WebSocket连接
```dart
// 在用户登录成功后
await WebSocketService.instance.connect();
```

### 2. 进入聊天室
```dart
final chatProvider = ChatProvider();
await chatProvider.enterChatRoom(roomId, chat);
```

### 3. 发送消息
```dart
// 文本消息
await chatProvider.sendTextMessage("Hello!");

// 图片/文件等富消息：通过 attachments 发送
final attachment = MessageAttachmentDraft(
  type: MessagePartType.image,
  file: File(imagePath),
  displayName: "photo.jpg",
  mime: "image/jpeg",
);
await chatProvider.sendRichMessage(attachments: [attachment]);
```

### 4. 接收消息
消息会自动通过WebSocket推送，并更新UI：
```dart
Consumer<ChatProvider>(
  builder: (context, provider, child) {
    return ListView.builder(
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final message = provider.messages[index];
        return MessageBubble(message: message);
      },
    );
  },
)
```

## 消息流程

### 发送消息流程
1. 用户输入消息并点击发送
2. 创建临时消息（状态：sending）
3. 调用HTTP API发送到服务器
4. 服务器存储消息并返回消息ID
5. 通过Redis Pub/Sub广播到所有订阅者
6. 更新消息状态为sent
7. WebSocket接收到自己的消息，更新状态为delivered

### 接收消息流程
1. 其他用户发送消息
2. 服务器通过Redis Pub/Sub广播
3. WebSocket接收到消息
4. MessageService处理消息
5. 更新本地消息列表
6. UI自动刷新显示新消息

## 测试步骤

### 1. 启动后端服务
```bash
cd api
cp .env.example .env
docker compose -f docker/dev/docker-compose.yml up -d api
```

### 2. 创建测试用户和房间
```bash
cd api
./test_flow.sh
```

### 3. 运行Flutter应用
```bash
cd app
flutter run
```

### 4. 测试消息功能
1. 使用alice账号登录（用户名：alice，密码：password123）
2. 进入聊天室（默认测试房间ID：00000000-0000-0000-0000-000000000001）
3. 发送消息
4. 在另一个设备或模拟器使用bob账号登录
5. 验证消息实时同步

## 已实现功能（同步日期：2026-01-15）

- ✅ 图片/文件消息发送
- ✅ 语音消息录制与发送
- ✅ 删除消息（对所有人/撤回）
- ✅ 消息转发（当前仅支持文本）
- ✅ 消息已读回执（标记已读 + 已读列表）
- ✅ 消息搜索（本地索引 + 服务端搜索）
- ✅ 离线消息同步（断线重连后自动补拉缺失消息）
- ✅ 群聊 @ 功能（输入 @ 选择成员并插入 @username）
- ✅ typing 状态同步（正在输入提示）

## 待实现功能

- [ ] 消息加密

## 性能优化建议

1. **消息分页加载**
   - 实现上拉加载更多历史消息
   - 使用游标分页避免重复数据

2. **图片优化**
   - 实现图片压缩上传
   - 使用缩略图预览
   - 懒加载大图

3. **连接优化**
   - 实现断线重连队列
   - 缓存未发送消息
   - 后台保活策略

4. **内存优化**
   - 限制消息缓存数量
   - 及时释放不需要的资源
   - 使用虚拟列表优化长消息列表

## 注意事项

1. **网络切换**
   - 已实现网络状态监听，自动重连
   - 切换网络时会重新认证和订阅房间

2. **消息去重**
   - 通过消息ID避免重复显示
   - WebSocket和HTTP API可能收到同一消息

3. **错误处理**
   - 发送失败的消息显示错误图标
   - 点击可重新发送
   - 超过3次重试后放弃

4. **安全性**
   - JWT Token存储在安全存储中
   - WebSocket使用Token认证
   - 敏感操作需要重新验证

## 调试技巧

### 查看WebSocket日志
```dart
// 在WebSocketService中启用调试日志
debugPrint('WebSocket message: $message');
```

### 查看消息状态
```dart
// 在MessageService中查看消息状态变化
debugPrint('Message status: ${message.id} -> ${message.status}');
```

### 模拟网络断开
```dart
// 手动断开WebSocket测试重连
WebSocketService.instance.disconnect();
```

### 清空消息缓存
```dart
// 清除本地消息缓存
MessageService.instance.clearAll();
```
