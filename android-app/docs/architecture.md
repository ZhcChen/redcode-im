# android-app 原生 Android 架构方案

## 总体方向

`android-app` 采用 Android 官方推荐的现代应用架构：Compose UI、ViewModel 状态持有、单向数据流、Repository/DataSource 分层、Coroutines/Flow、可测试的依赖注入。

迁移目标是功能和行为对齐 Flutter `app/`，但实现方式以 Android 原生开发规范为准，不复制 Flutter Widget/Provider 结构。

## 分层

```text
MainActivity / Compose App Shell
  -> Feature Composables
  -> ViewModel / UI State
  -> Repository
  -> DataSource
  -> HTTP / WebSocket / Room / DataStore / Keystore / File Cache
```

## UI 层

- Single Activity。
- Jetpack Compose + Material 3。
- 页面使用 Composable。
- ViewModel 暴露 `StateFlow<UiState>`。
- Composable 使用 lifecycle-aware collection 订阅状态。
- 事件从 UI 派发到 ViewModel，ViewModel 再调用 Repository。

## 数据层

- Repository 是 UI/Domain 访问数据的唯一入口。
- HTTP 和 WebSocket DataSource 对齐后端现有协议。
- Room 保存消息、会话、联系人、群和配置缓存。
- DataStore 保存非敏感偏好。
- Token 和敏感会话数据走 Android Keystore / Jetpack Security。
- 附件、头像、表情资源进入 app cache 目录。

当前 Room 底座已覆盖：

- `RedCodeDatabase`
- `ChatSummaryEntity` / `ChatMessageEntity` / `ContactEntity` / `RoomInfoEntity` / `RoomMemberEntity` / `GroupSettingsEntity`
- `ChatDao` / `ContactDao` / `RoomDao`
- `RoomChatRepository`：会话摘要、消息缓存、发送文本、本地已读、每 room 最近消息裁剪。
- `RoomContactsRepository`：联系人缓存、搜索、upsert、remove、clear。
- `RoomGroupRepository`：群聊、群成员、群设置缓存和清理。

群和配置 schema 在后续阶段扩展，避免第一版 schema 过早锁定未接入的业务字段。

## 当前第一切片

当前已建立 in-memory Repository：

- `InMemoryAuthRepository`
- `InMemoryChatRepository`
- `InMemoryContactsRepository`
- `InMemorySettingsRepository`

它们用于在真实 HTTP/WS/Room 接入前，让 Compose UI、ViewModel、测试覆盖率、Emulator 启动验收先闭环。后续每个真实 DataSource 接入后保留 fake/in-memory 实现用于测试。

认证域已补真实 API 数据源基线：

- `APIClient`：统一 JSON 编解码、Bearer token、HTTP 错误消息提取。
- `HttpAuthRemoteDataSource`：对齐 `/auth/register`、`/auth/login`、`/auth/me`、`/auth/refresh`。
- `RemoteAuthRepository`：普通账号密码注册后自动登录、登录会话保存、登出清理。
- `AuthSessionStore`：提供 in-memory 测试实现和 `SerializedAuthSessionStore`。
- `AndroidKeystoreKeyValueStore`：Android Keystore 生成不可导出 AES/GCM 密钥，SharedPreferences 只保存密文，App 启动时恢复 `AuthSession`，登出时清理会话密文。
- `UserPreferenceStore`：协议勾选等非敏感偏好走 Preferences DataStore；测试使用 in-memory 实现。
- `SettingsRepository`：提供公开协议文档拉取，真实联调时访问 `/settings/privacy-policy` 和 `/settings/user-agreement`，本地模拟时返回内置 mock 文档。
- `RemoteChatRepository`：在真实认证构建下接入 `/chats`、`/rooms/{room_id}/messages`、文本发送和已读标记；本地默认仍使用 in-memory 数据便于无后端 UI smoke。
- `RemoteContactsRepository`：在真实认证构建下接入用户搜索、好友列表、好友申请/响应和打开私聊；Compose 联系人页已覆盖搜索添加、好友申请处理、联系人详情和私聊入口；本地默认仍使用 in-memory 联系人数据。
- `RemoteRoomRepository`：在真实认证构建下接入 `/rooms`、成员、群设置、置顶/免打扰、管理员、禁言、群规、入群申请、操作日志、退出/解散。
- `CachedRemoteChatRepository` / `CachedRemoteContactsRepository` / `CachedRemoteRoomRepository`：真实 API 构建下优先以 HTTP 刷新远端数据，并将会话、消息、联系人、群聊、成员、群设置写入 Room；UI 订阅 Room Flow，后续 WebSocket 增量事件会复用同一缓存入口。
- `ChatRepository.resendMessage`：文本发送先落本地 `Pending`；远端失败更新为 `Failed`，详情页提供重试，成功后删除本地临时消息并写入服务端消息。
- `RedCodeWebSocketClient`：真实 API 构建下连接后端 `/ws?format=json`，登录后发送 `auth`，会话列表变化后维护 `join` / `leave` 房间订阅，已支持 `ping`、`typing`、断线重连、重复订阅保护和旧连接回调隔离。
- `RealtimeEventProcessor`：消费 WebSocket JSON 服务端事件，已把 `message`、`message_read`、`message_update`、`room_created`、`room_updated`、`room_history_cleared`、`group_dissolved`、`friend_request_update` 接到 Room/Repository；protobuf 二进制帧在后续切片补齐。
- `AppContainer.clearLocalSessionState`：登出时断开 WebSocket，并通过 Repository `clearLocalState` 清理 Room Chat/Contacts 缓存和内存态；文件 cache 和通知态清理留到对应能力接入后补齐。

## 测试策略

- JVM unit test 覆盖校验、领域模型、Repository、ViewModel。
- Compose instrumented test 覆盖 Emulator 上的关键 UI flow。
- Room in-memory instrumented test 覆盖 DAO SQL、Flow 查询和 Repository 持久化行为。
- Android Keystore instrumented test 覆盖密文落盘、读取恢复、覆盖写、删除和损坏 payload 丢弃。
- DataStore instrumented test 覆盖协议勾选偏好读写；Compose UI test 覆盖未勾选协议时阻止认证和协议文档弹窗。
- Chat HTTP JVM test 覆盖 token、endpoint、DTO 映射、会话列表刷新、消息首屏加载、文本发送和已读标记。
- Contacts HTTP JVM test 覆盖 token、endpoint、DTO 映射、好友列表刷新、用户搜索、好友申请、请求响应和打开私聊。
- Rooms HTTP JVM test 覆盖 token、endpoint、DTO 映射、建群、群资料、成员、设置、置顶/免打扰、管理员、禁言、群规、入群申请、日志和空响应合同。
- WebSocket JVM test 覆盖 URL 规范化、auth/ping、join/leave、typing guard、服务端错误、断开清理、失败重连、旧连接回调隔离和增量事件分发。
- Jacoco 输出覆盖率报告。
- 后续 live smoke 统一接入本机 Docker Compose API；Android Emulator 使用 `10.0.2.2` 访问宿主机。

## 真机跳过策略

以下能力需要真机或云凭据时不在 Emulator 阶段伪造通过：

- FCM 真实 token 与云端投递。
- 相机/麦克风硬件差异补验。
- 后台限制、厂商 ROM、通知点击冷启动差异。
- Play 签名、release 包安装和商店分发链路。

跳过项记录在 `android-app/docs/full-migration-task-tree.md`。
