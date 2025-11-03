# WebSocket 全局处理功能使用说明

## 概述

本项目已成功集成了基于 bear-chat-uniapp 项目的 WebSocket 全局处理逻辑，提供了完整的实时通信功能。

## 功能特性

### 1. 自动连接管理
- 用户登录后自动建立 WebSocket 连接
- 用户登出时自动关闭 WebSocket 连接
- 支持断线重连机制（最多重连5次）
- 页面可见性变化时智能重连

### 2. 心跳检测
- 每3秒发送一次心跳包
- 自动检测连接状态
- 连接异常时自动重连

### 3. 消息类型支持
- 聊天消息 (Chatting)
- AI 消息 (AI)
- 好友关系变化 (FriendBindChange)
- 删除好友通知 (FriendDeleteNotify)
- 朋友圈动态 (FriendCircle)
- 群聊相关 (LaunchGroup, DeleteGroup)
- 通话消息 (Calling)

## 文件结构

```
src/
├── types/
│   └── websocket.ts          # WebSocket 类型定义和常量
├── utils/
│   ├── websocket.ts          # WebSocket 管理器主要逻辑
│   └── index.ts              # 工具函数统一导出
├── store/
│   └── index.ts              # Vuex 状态管理（已添加 WebSocket 状态）
├── App.vue                   # 全局 WebSocket 事件监听和处理
├── App-simple.vue           # 简化版本（使用 Options API）
└── examples/
    └── websocket-test.ts     # WebSocket 功能测试示例
```

## 使用方法

### 1. 基本使用

WebSocket 连接会在用户登录后自动建立，无需手动调用。

### 2. 发送消息

```typescript
import { webSocketManager } from '@/utils/websocket'
import { BUSINESS_CODE } from '@/types/websocket'

// 发送聊天消息
const message = {
  content: '你好，这是一条消息',
  messageType: 1,
  contentType: 1
}

webSocketManager.sendMessage(
  message,
  BUSINESS_CODE.chatting,
  (success) => {
    if (success) {
      console.log('消息发送成功')
    } else {
      console.log('消息发送失败')
    }
  }
)
```

### 3. 监听 WebSocket 事件

WebSocket 事件通过自定义 DOM 事件进行传递：

```typescript
// 监听聊天消息
window.addEventListener('websocket-chat-message', (event) => {
  const detail = (event as CustomEvent).detail
  console.log('收到聊天消息:', detail)
})

// 监听 AI 消息
window.addEventListener('websocket-ai-message', (event) => {
  const detail = (event as CustomEvent).detail
  console.log('收到 AI 消息:', detail)
})

// 监听好友变化
window.addEventListener('websocket-friend-change', (event) => {
  const detail = (event as CustomEvent).detail
  console.log('好友关系变化:', detail)
})
```

### 4. 获取连接状态

```typescript
import { webSocketManager } from '@/utils/websocket'

// 获取当前连接状态
const isConnected = webSocketManager.getConnectionState()
console.log('连接状态:', isConnected ? '已连接' : '未连接')
```

### 5. 手动控制连接

```typescript
import { webSocketManager } from '@/utils/websocket'

// 手动初始化连接
const params = {
  userId: 'user123',
  token: 'token456',
  chatGroupId: '00000000'
}
webSocketManager.initWebSocket(params)

// 手动关闭连接
webSocketManager.closeWebSocket()
```

## Vuex 状态管理

项目已集成 WebSocket 相关的 Vuex 状态：

```typescript
// 获取 WebSocket 状态
const websocket = store.state.websocket          // WebSocket 对象
const networkState = store.state.networkState    // 网络连接状态
const currentChatGroupId = store.state.currentChatGroupId  // 当前聊天群组 ID

// 通过 getters 获取
const isConnected = store.getters.networkState
const currentWS = store.getters.websocket
```

## 配置说明

### 服务器配置

WebSocket 服务器地址在 `src/api/config.ts` 中配置：

```typescript
export const apiConfig = {
  WS_URL: "ws://localhost:8010/ws",  // WebSocket 服务器地址
  // ... 其他配置
}
```

### 连接参数

WebSocket 连接需要以下参数：

- `userId`: 用户 ID
- `token`: 认证 token
- `chatGroupId`: 群组 ID（可选，默认为 "00000000"）

## 错误处理

### 1. 连接失败
- 自动重连机制会尝试重新连接
- 最多重连5次，间隔5秒
- 重连失败后会清除用户状态并跳转到登录页

### 2. 认证失败
- 显示错误提示
- 自动清除用户状态
- 跳转到登录页面

### 3. 消息发送失败
- 回调函数返回 false
- 更新网络状态为离线

## 测试功能

使用 `src/examples/websocket-test.ts` 中的测试函数：

```typescript
import { 
  testWebSocketConnection, 
  testSendMessage, 
  testCloseConnection,
  getConnectionStatus 
} from '@/examples/websocket-test'

// 测试连接
testWebSocketConnection()

// 获取状态
getConnectionStatus()

// 测试发送消息
testSendMessage()

// 测试关闭连接
testCloseConnection()
```

## 注意事项

1. **自动管理**: WebSocket 连接会根据用户登录状态自动管理，通常不需要手动控制
2. **事件监听**: 确保在组件中正确添加和移除事件监听器，避免内存泄漏
3. **错误处理**: 网络异常时会自动重连，但多次重连失败后会要求重新登录
4. **消息格式**: 发送的消息需要遵循项目定义的消息格式
5. **性能考虑**: 心跳包和重连机制已优化，但在低网络环境下可能需要调整参数

## 与原项目对比

本实现基于 bear-chat-uniapp 项目的 WebSocket 逻辑，主要差异：

1. **技术栈**: 从 uni-app 迁移到 Vue 3 + Tauri
2. **状态管理**: 从 uView 的 Vuex 迁移到标准 Vuex 4
3. **事件系统**: 使用 DOM 自定义事件替代 uni.$emit
4. **类型安全**: 添加了完整的 TypeScript 类型定义
5. **模块化**: 更好的代码组织和模块分离

## 后续扩展

1. **消息持久化**: 可以添加本地消息存储功能
2. **离线消息**: 可以添加离线消息处理逻辑
3. **消息加密**: 可以添加端到端加密功能
4. **文件传输**: 可以扩展文件传输相关的 WebSocket 处理
5. **音视频通话**: 可以进一步完善通话相关的 WebSocket 处理
