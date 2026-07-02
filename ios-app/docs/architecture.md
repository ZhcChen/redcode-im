# ios-app 原生 iOS 架构方案

## 总体方向

`ios-app` 采用 SwiftUI-first 的原生 iOS 架构。UIKit 不作为主 UI 框架，仅在 SwiftUI 无法直接满足的系统能力处桥接使用。

## 模块分层

```text
SwiftUI App Shell
  -> Feature View + ViewModel
  -> Domain Models / Use Cases
  -> Networking / Storage / Device Services
  -> API / WebSocket / SwiftData / Keychain
```

### App

- 放置 SwiftUI `App` 入口、环境注入、根导航和登录态切换。
- 使用 `NavigationStack` 管理页面导航。
- 负责连接 Auth、Chat、Contacts、Settings 等 feature。

### RedCodeCore

- 放置跨模块领域模型、错误类型、环境配置、常量和协议定义。
- 避免依赖 UI，便于单元测试。

### RedCodeNetworking

- 放置 HTTP API client、认证请求、WebSocket client 和重试/超时策略。
- HTTP 与 WebSocket 的数据结构优先对齐 `app/lib/core/services/`、`h5-app/src/services/` 和后端接口。

### RedCodeStorage

- Token 使用 Keychain，不放入普通 UserDefaults。
- 消息、会话、联系人缓存优先使用 SwiftData。
- 本地缓存语义对齐 Flutter `MessageStorage`：按 room 缓存，默认每房间保留最近 200 条。

### RedCodeFeatures

- 按业务能力拆分：Auth、Chat、Contacts、Groups、Settings。
- 每个 feature 保持 View、ViewModel、Service/Repository 边界清晰。
- View 只负责展示和交互，业务状态与异步流程进入 ViewModel。

## 状态与并发

- iOS 17+ 优先使用 Swift Observation；若后续要求兼容 iOS 16，再降级为 `ObservableObject`。
- 异步网络、WebSocket 和存储操作统一使用 Swift Concurrency。
- UI 更新必须回到主线程语义，由 ViewModel 层收敛。

## 本地数据策略

首选 SwiftData 的原因：

- Apple 官方现代持久化方案，和 SwiftUI 生命周期集成更自然。
- 适合会话、消息、联系人、配置等结构化本地缓存。
- 支持 schema 管理和后续迁移计划。

保留 SQLite/GRDB 作为二期备选：

- 当消息量、全文搜索、复杂查询或迁移控制成为瓶颈时再引入。
- 第一阶段不提前增加复杂依赖，降低原生迁移启动成本。

## 与现有模块关系

- `app/`：Flutter 现有实现，是 iOS 原生 parity 的主要行为参考。
- `h5-app/`：当前端到端联调基准，iOS 开发期间继续用它验证后端协议和流程。
- `api/`：后端接口和 WebSocket 协议不因 iOS 原生迁移而立即改变。

## 第一阶段不做

- 不迁移 Android 原生。
- 不删除 Flutter `app/`。
- 不恢复 Google/Apple 登录。
- 不在首版接入 APNs/FCM；Push 后置到核心聊天链路稳定后。
- 不在没有明确选型前手写或生成复杂 Xcode 工程配置。
