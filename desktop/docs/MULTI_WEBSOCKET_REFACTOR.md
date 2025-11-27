# 多账号 WebSocket 连接重构计划

## 背景

当前架构只维护单个 WebSocket 连接，账号切换时会断开旧连接、建立新连接。这导致：
- 非当前账号无法实时收到消息推送
- 多账号 Tab 标签页无法及时显示未读闪烁
- 只能依赖 5 秒轮询来更新其他账号状态

## 目标架构

```
改造前（单连接）：
┌─────────────────┐
│  账号 A/B/C     │
└────────┬────────┘
         │ 切换时重连
         ▼
┌──────────────────────┐
│ WebSocketManager     │
│ client: Option<...>  │  ◄─── 只有一个连接
└──────────────────────┘

改造后（多连接）：
┌─────────────────┐
│  账号 A/B/C     │
└────────┬────────┘
         │
         ▼
┌──────────────────────────────────┐
│ WebSocketManager                 │
│ clients: HashMap<user_id, ...>   │  ◄─── 每个账号一个连接
│   ├── A 的连接                    │
│   ├── B 的连接                    │
│   └── C 的连接                    │
└──────────────────────────────────┘
```

---

## 改动文件清单

| 文件 | 层级 | 改动类型 | 重要性 |
|-----|------|---------|--------|
| `src-tauri/src/websocket/commands.rs` | Rust | 重构 | ⭐⭐⭐ |
| `src-tauri/src/websocket/client.rs` | Rust | 小改 | ⭐⭐ |
| `src-tauri/src/websocket/types.rs` | Rust | 增强 | ⭐⭐ |
| `src/api/websocket.ts` | TypeScript | 改动 | ⭐⭐⭐ |
| `src/utils/websocket.ts` | TypeScript | 重构 | ⭐⭐⭐ |
| `src/App.vue` | TypeScript | 改动 | ⭐⭐⭐ |
| `src/store/modules/accounts.ts` | TypeScript | 小改 | ⭐⭐ |

---

## 任务列表

### 第一阶段：Rust 后端改造

#### 1.1 重构 WebSocketManager（commands.rs）✅ 已完成
- [x] 将 `client: Option<WebSocketClient>` 改为 `clients: HashMap<String, WebSocketClient>`
- [x] 新增 `current_user_id: Option<String>` 字段
- [x] 修改 `ws_connect` 命令：按 user_id 管理连接，不覆盖已有连接
- [x] 修改 `ws_disconnect` 命令：新增 `user_id` 参数，支持断开特定账号
- [x] 修改 `ws_get_status` 命令：新增 `user_id` 参数
- [x] 修改 `ws_join_room` / `ws_leave_room`：使用当前账号或指定账号
- [x] 新增 `ws_disconnect_all` 命令：断开所有连接
- [x] 新增 `ws_get_all_status` 命令：获取所有连接状态
- [x] 新增 `ws_set_current_user` 命令：设置当前活跃账号
- [x] 新增 `ws_get_connected_count` 命令：获取连接数量
- [x] 新增 `ws_get_current_user` 命令：获取当前活跃账号

#### 1.2 增强事件负载（types.rs）✅ 已完成
- [x] 新增 `UserEventWrapper` 包装结构，包含 `user_id` 和 `event` 字段
- [x] 所有事件通过 `UserEventWrapper` 发送，自动携带 user_id

#### 1.3 WebSocketClient 小改（client.rs）✅ 已完成
- [x] 添加 `user_id: String` 字段
- [x] 修改 `new()` 方法接收 user_id 参数
- [x] 修改 `handle_binary_message` 使用 `UserEventWrapper` 发送事件
- [x] 更新日志输出包含 user_id

#### 1.4 编译验证 ✅ 已完成
- [x] 运行 `cargo build` 确保无编译错误
- [x] 无警告

---

### 第二阶段：TypeScript API 层改造 ✅ 已完成

#### 2.1 更新 WebSocketApi（api/websocket.ts）✅ 已完成
- [x] `connect()` 方法保持不变（user_id 已在 params 中）
- [x] `disconnect(userId?: string)` 新增可选参数
- [x] `getStatus(userId?: string)` 新增可选参数
- [x] 新增 `disconnectAll()` 方法
- [x] 新增 `getAllStatus()` 方法
- [x] 新增 `setCurrentUser(userId)` 方法
- [x] 新增 `getCurrentUser()` 方法
- [x] 新增 `getConnectedCount()` 方法
- [x] `joinRoom(roomId, userId?)` 新增可选参数
- [x] `leaveRoom(roomId, userId?)` 新增可选参数
- [x] `joinRooms(roomIds, userId?)` 新增可选参数
- [x] `getSubscribedRooms(userId?)` 新增可选参数

#### 2.2 更新类型定义（types/websocket.ts）✅ 已完成
- [x] 新增 `TauriEventPayload` 联合类型定义
- [x] 新增 `UserEventWrapper` 接口定义

---

### 第三阶段：核心管理器重构 ✅ 已完成

#### 3.1 重构 WebSocketManager（utils/websocket.ts）✅ 已完成
- [x] 将单连接状态改为 Map 管理多连接
  ```typescript
  // 改造后
  private connections: Map<string, ConnectionInfo> = new Map();
  private currentUserId: string | null = null;
  ```
- [x] 修改 `initWebSocketSafely()` 支持多账号同时连接
- [x] 修改 `closeWebSocket(userId?: string)` 支持选择性关闭
- [x] 新增 `closeAllWebSockets()` 关闭所有连接
- [x] 修改 `setupEventListeners()` 处理带 user_id 的事件

#### 3.2 修改事件处理逻辑 ✅ 已完成
- [x] `handleTauriEvent()` 根据 user_id 分发事件
- [x] 消息事件：根据 user_id 更新对应账号的未读数
- [x] 好友请求事件：根据 user_id 更新对应账号的好友请求数
- [x] 确保事件处理不再假设只有当前账号

#### 3.3 修改房间订阅管理 ✅ 已完成
- [x] `joinRoom(roomId, userId?)` 支持指定账号
- [x] `leaveRoom(roomId, userId?)` 支持指定账号
- [x] `ensureRoomsSubscribed(roomIds, pruneMissing, userId?)` 支持指定账号
- [x] 房间订阅按账号隔离存储

#### 3.4 新增多账号管理方法 ✅ 已完成
- [x] `setCurrentUser(userId)` 设置当前活跃账号
- [x] `getCurrentUserId()` 获取当前活跃账号ID
- [x] `isUserConnected(userId)` 检查指定账号是否已连接
- [x] `getConnectedUserIds()` 获取所有已连接的用户ID列表
- [x] `getAllConnectionStates()` 获取所有连接状态
- [x] `getConnectedCount()` 获取已连接账号数量

---

### 第四阶段：应用层集成 ✅ 已完成

#### 4.1 修改账号切换逻辑（App.vue）✅ 已完成
- [x] `handleAccountSwitch()` 不再断开旧连接
- [x] 新账号登录时建立新连接（如尚未连接）
- [x] 已有连接则只切换当前活跃账号
- [x] 保留切换 token 和用户信息的逻辑

#### 4.2 修改登录/登出逻辑（App.vue）✅ 已完成
- [x] 登录成功：为当前账号建立 WebSocket 连接
- [x] 添加新账号：为新账号建立 WebSocket 连接
- [x] 移除账号：只断开该账号的 WebSocket 连接（不影响其他账号）
- [x] 完全登出（无剩余账号）：断开所有 WebSocket 连接

#### 4.3 修改消息处理 ✅ 已完成
- [x] `handleChatMessage()` 支持根据 user_id 识别消息所属账号
- [x] 事件携带 userId 字段供上层处理

#### 4.4 移除轮询依赖（可选优化）
- [ ] 评估是否可以降低或移除 `refreshAllAccountsUnreadCount` 轮询
- [ ] 保留轮询作为 fallback 但降低频率

---

### 第五阶段：状态管理改造

#### 5.1 修改 accounts store（store/modules/accounts.ts）
- [ ] 确保 `UPDATE_UNREAD_COUNT` 可以按 accountId 更新
- [ ] 确保 `UPDATE_FRIEND_REQUEST_COUNT` 可以按 accountId 更新
- [ ] 可能需要新增 action 处理 WebSocket 事件

#### 5.2 修改全局 store（store/index.ts）
- [ ] 检查全局状态是否需要改动
- [ ] 确保 `pendingFriendRequests` 与多账号兼容

---

### 第六阶段：测试与验证

#### 6.1 基础功能测试
- [ ] 单账号登录 WebSocket 连接正常
- [ ] 多账号登录各自 WebSocket 连接正常
- [ ] 账号切换不断开其他账号连接

#### 6.2 消息推送测试
- [ ] A 账号收到消息，A 的 Tab 闪烁
- [ ] B 账号（非当前）收到消息，B 的 Tab 闪烁
- [ ] 切换到 B 账号，消息正确显示

#### 6.3 好友请求测试
- [ ] A 账号收到好友请求，A 的 Tab 闪烁
- [ ] B 账号收到好友请求，B 的 Tab 闪烁

#### 6.4 边界情况测试
- [ ] 网络断开后重连
- [ ] 单个账号连接失败不影响其他账号
- [ ] 移除账号时正确清理连接
- [ ] 应用退出时正确清理所有连接

#### 6.5 性能测试
- [ ] 多连接内存占用合理
- [ ] 心跳不会过度消耗资源
- [ ] 事件分发延迟可接受

---

## 风险点

### 1. 事件竞态条件
多个账号事件同时到达可能导致处理顺序混乱。
- **防范**：事件处理加入 user_id 校验

### 2. 内存泄漏
多连接可能导致资源未正确清理。
- **防范**：App.vue 卸载时确保关闭所有连接

### 3. 状态不一致
全局状态与连接状态可能不同步。
- **防范**：使用 Map 管理连接状态，避免全局变量

### 4. Rust 命令签名变更
前端调用需要同步更新。
- **防范**：先完成 Rust 改造，再更新前端

---

## 估算工时

| 阶段 | 预计工时 |
|-----|---------|
| 第一阶段：Rust 后端 | 4-6 小时 |
| 第二阶段：API 层 | 1-2 小时 |
| 第三阶段：核心管理器 | 4-6 小时 |
| 第四阶段：应用层 | 2-3 小时 |
| 第五阶段：状态管理 | 1-2 小时 |
| 第六阶段：测试 | 3-4 小时 |
| **总计** | **15-23 小时** |

---

## 实施顺序

1. 先完成 Rust 端改造（第一阶段）并验证编译通过
2. 更新 TypeScript API 层（第二阶段）
3. 重构核心 WebSocketManager（第三阶段）
4. 修改应用层逻辑（第四阶段）
5. 调整状态管理（第五阶段）
6. 全面测试（第六阶段）

建议按阶段提交代码，每阶段完成后进行基础验证。
