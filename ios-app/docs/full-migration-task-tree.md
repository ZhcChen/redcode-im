# ios-app 全量 Flutter parity 任务索引树

本任务树是 `ios-app` 的执行索引。目标是完整迁移 Flutter `app/` 当前功能逻辑，但用 Apple 官方优先的原生 iOS 工程规范实现。

## 全局约束

- 技术栈：Swift 6 mode + SwiftUI-first。
- 工程规范：Apple 官方文档优先，包括 Swift、SwiftUI、Swift Package Manager、SwiftData、XCTest/XCUITest、Human Interface Guidelines。
- 语言边界：新业务代码只写 Swift；不使用 Objective-C。只有系统/第三方桥接无法避免时，才允许单独说明并引入 bridge。
- UI 规则：视觉语言参考 Flutter/H5，但控件、导航、权限、可访问性和系统交互遵循 iOS 原生习惯。
- 测试设备：默认本机 iOS Simulator；Simulator 使用 `127.0.0.1` 访问本机 Compose API/WS。
- 后端依赖：API、PG、Redis、对象存储 mock 等联调依赖由 Docker Compose 创建。
- 迁移策略：先建立可测试模块，再逐阶段补齐功能；全量 parity 通过前不删除 Flutter `app/`。

## 索引树

```text
IOS
├── IOS-00 方案、范围和骨架
├── IOS-01 原生基础设施
├── IOS-02 启动、认证与会话安全
├── IOS-03 网络、WebSocket、本地数据和缓存底座
├── IOS-04 聊天核心全量
├── IOS-05 联系人、好友与私聊
├── IOS-06 群聊和群管理全量
├── IOS-07 媒体、附件、头像、语音和视频
├── IOS-08 表情、贴纸、消息搜索和聊天扩展
├── IOS-09 设置、账号、文档、反馈、配置和版本
├── IOS-10 Push、本地通知和通知导航
└── IOS-11 全量 parity 验收与切换准备
```

## IOS-00 方案、范围和骨架

- [x] IOS-00.01 创建 `ios-app/` 模块目录。
- [x] IOS-00.02 创建 `ios-app/README.md`。
- [x] IOS-00.03 创建 `ios-app/docs/architecture.md`。
- [x] IOS-00.04 创建 `ios-app/docs/flutter-parity-scope.md`。
- [x] IOS-00.05 创建全量迁移计划 `docs/plans/2026-07-03-001-feat-ios-app-full-flutter-parity-plan.md`。
- [x] IOS-00.06 明确本机 iOS Simulator 为默认验收设备。

验收：

- 文档能说明完整 Flutter parity 目标、非目标、原生 iOS 映射和测试设备策略。

## IOS-01 原生基础设施

- [x] IOS-01.01 确认本机工具链：Xcode 26.6、Apple Swift 6.3.3。
- [x] IOS-01.02 建立 SwiftPM package：`ios-app/Package.swift`。
- [x] IOS-01.03 启用 Swift 6 language mode。
- [x] IOS-01.04 建立 local package targets：
  - `RedCodeCore`
  - `RedCodeNetworking`
  - `RedCodeStorage`
  - `RedCodeFeatures`
- [x] IOS-01.05 建立 test targets：
  - `RedCodeCoreTests`
  - `RedCodeNetworkingTests`
  - `RedCodeStorageTests`
  - `RedCodeFeaturesTests`
- [x] IOS-01.06 建立核心环境配置模型，默认 Simulator API/WS 指向 `127.0.0.1:8010`。
- [x] IOS-01.07 建立错误模型和平台策略常量。
- [x] IOS-01.08 建立 HTTP endpoint 与 WebSocket 配置基础类型。
- [x] IOS-01.09 建立本地 key-value store 协议和消息缓存策略基础类型。
- [x] IOS-01.10 建立 App tab、route、session state 基础类型。
- [x] IOS-01.11 建立 SwiftUI App shell 源码草案。
- [x] IOS-01.12 增加 `make ios-app.check` / `make ios-app.test` 入口。
- [x] IOS-01.13 创建可由 Xcode 打开的 iOS App 工程。
- [x] IOS-01.14 将 `ios-app/App/` 接入 Xcode App target。
- [x] IOS-01.15 在本机 iOS Simulator 启动空壳 App。

当前说明：

- XcodeGen/Tuist 当前未安装；本阶段采用 SwiftPM + Xcode App project 的方式建立模块和可运行空壳。
- Xcode project 由本地 `xcodeproj` 工具生成，后续可通过 Xcode 维护；如后续引入 XcodeGen/Tuist，再迁移为生成式工程。

验收：

- `make ios-app.check` 通过。
- SwiftPM 模块可独立测试。
- 本机 iOS Simulator 可启动空壳 App。

## IOS-02 启动、认证与会话安全

- [x] IOS-02.01 梳理 Flutter/H5/API 认证接口和 payload。
- [x] IOS-02.02 实现 Splash 和启动恢复状态机。
- [x] IOS-02.03 实现普通账号密码注册。
- [x] IOS-02.04 实现普通账号密码登录。
- [x] IOS-02.05 实现重置密码。
- [x] IOS-02.06 实现用户协议/隐私协议提示。
- [x] IOS-02.07 实现 Token Keychain 存取。
- [x] IOS-02.08 实现登录态校验和 session 恢复。
- [x] IOS-02.09 实现登出清理：Token、WS、内存态、本地敏感缓存。
- [x] IOS-02.10 增加认证 ViewModel 单测。
- [x] IOS-02.11 增加认证 UI test。
- [x] IOS-02.12 与 API Compose 做账号密码注册/登录 smoke。

当前说明：

- 当前默认关闭邮箱注册/登录主线；不做 Google/Apple 登录，不做邮箱验证码二次验证。
- 邮箱注册/登录作为后台配置能力保留；当前开发测试跳过真实邮箱资源依赖。
- 已建立账号规范化、认证用户、认证会话、认证 HTTP endpoint/payload、本地 session store 基础。
- 已建立 `APIClient`、`AuthAPIClient`、`AuthController`、`KeychainKeyValueStore`，并补充 SwiftPM 单测。
- `KeyValueAuthSessionStore` 可通过 `KeychainKeyValueStore` 落 Keychain；SwiftUI App target 已接入 SwiftPM 本地模块、Keychain-backed session store 和认证 UI。
- IOS-02.09 已在 IOS-09 设置域收口，并由 IOS-10 补齐通知态清理：退出登录会清理认证 session、WebSocket、聊天列表、消息、联系人、群、配置缓存、附件、头像、表情缓存、聊天背景偏好和当前用户通知注册态。
- 当前 iOS UI 已提供普通账号密码登录、注册并登录、启动恢复 loading、登录后 tab shell 和设置页登出入口；登录/注册前需勾选用户协议/隐私协议。
- 已接入登录后验证码重置密码入口，调用 `POST /auth/password/reset`；本地测试阶段可使用后台通用验证码，不依赖真实邮箱。
- 认证 UI test 已接入 `RedCodeIMUITests`，覆盖未勾选协议时禁止登录、已同意协议后账号密码登录进入聊天页。
- 已通过 `RED_CODE_IOS_LIVE_API_SMOKE=1 swift test --filter AuthAPIClientLiveTests` 对本机 Compose API 完成注册、登录、`/auth/me` live smoke。

参考：

- `app/lib/features/startup/`
- `app/lib/features/auth/`
- `app/lib/core/auth/`
- `app/lib/core/storage/token_storage.dart`

验收：

- 注册后自动登录。
- 重启 App 可恢复 session。
- 登出后不残留当前用户认证态。

## IOS-03 网络、WebSocket、本地数据和缓存底座

- [x] IOS-03.01 实现 HTTP API client。
- [x] IOS-03.02 实现统一 request/response DTO mapping。
- [x] IOS-03.03 实现认证 header 注入。
- [x] IOS-03.04 实现网络错误分类和 UI 可恢复错误。
- [x] IOS-03.05 实现 WebSocket client。
- [x] IOS-03.06 实现 WS 认证、订阅、取消订阅。
- [x] IOS-03.07 实现 WS 重连、订阅恢复和事件去重。
- [x] IOS-03.08 建立 SwiftData schema：会话、消息、联系人、群、配置。
- [x] IOS-03.09 实现 FileManager Caches：附件、头像、表情。
- [x] IOS-03.10 设计消息搜索索引：SwiftData 优先，必要时 SQLite FTS5/GRDB。
- [x] IOS-03.11 增加 Networking 单测与 mock transport。
- [x] IOS-03.12 增加 Storage 单测。
- [x] IOS-03.13 增加 API Compose smoke。

参考：

- `app/lib/core/services/`
- `app/lib/core/storage/`
- `h5-app/src/services/`
- `h5-app/src/storage/`

验收：

- HTTP 和 WS 可对真实后端工作。
- 本地缓存优先展示，后台刷新。
- HTTP/WS 双路径不会重复插入同一消息。

当前说明：

- HTTP 基础 client、认证 API client、bearer token 注入、后端错误 message 解析和 mock transport 单测已完成。
- WebSocket JSON client 已完成基础接入：`format=json` 握手、连接后 `auth`、房间 `join`/`leave`、typing、断线自动重连、desired room 订阅恢复、消息/read/update/pin/reaction 事件去重和 AsyncStream 事件分发。
- WebSocket 已补 mock transport 单测，并新增 `RED_CODE_IOS_LIVE_WS_SMOKE=1 swift test --filter WebSocketClientLiveTests` 对本机 Compose API 做真实连接和认证 smoke。
- SwiftData schema 已覆盖会话、消息、联系人、群、配置，并补 `SwiftDataMessageCacheStore` 对齐 Flutter/H5 每 room 最近 200 条消息缓存语义。
- Storage 单测已覆盖 SwiftData in-memory container、核心缓存模型存取、消息缓存保留策略、房间清理和 Keychain key-value store。
- FileManager cache 已补通用 `FileResourceCache`，并提供附件、用户/群头像、表情资源缓存封装；覆盖 objectKey 校验、TTL 过期、扩展名解析、remove 和 clearAll 测试。
- HTTP DTO 基础已补 `BackendErrorResponse`、`APIResponseEnvelope`；后续聊天、联系人、群和设置接口落地时在此基础上补各域 DTO。
- 网络错误已补 `NetworkFailure` 分类、HTTP status 映射、URLSession transport 映射、用户可恢复标记和 recovery suggestion。
- 消息搜索索引策略已补 `MessageSearchIndexStrategy`：默认 SwiftData，超过阈值后切 SQLite FTS5/GRDB 侧车。
- 当前 WebSocket live smoke 覆盖真实后端连接与认证；真实房间订阅/消息收发会在 IOS-04 iOS/H5 同后端互发 smoke 中继续扩展。

## IOS-04 聊天核心全量

- [x] IOS-04.01 实现会话列表数据源。
- [x] IOS-04.02 实现会话列表 UI。
- [x] IOS-04.03 实现未读数、置顶、免打扰展示。
- [x] IOS-04.04 实现聊天详情数据源。
- [x] IOS-04.05 实现聊天详情 UI。
- [x] IOS-04.06 实现历史消息加载和本地缓存合并。
- [x] IOS-04.07 实现每 room 最近 200 条消息保留策略。
- [x] IOS-04.08 实现文本消息发送。
- [x] IOS-04.09 实现 pending、失败重试、服务端回包替换。
- [x] IOS-04.10 实现引用消息。
- [x] IOS-04.11 实现已读。
- [x] IOS-04.12 实现消息删除。
- [x] IOS-04.13 实现置顶消息。
- [x] IOS-04.14 实现 reaction。
- [x] IOS-04.15 实现房间订阅管理。
- [x] IOS-04.16 增加聊天 ViewModel 单测。
- [x] IOS-04.17 增加聊天 UI test。
- [x] IOS-04.18 与 H5 做同后端互发 smoke。

参考：

- `app/lib/features/chat/`
- `app/lib/core/services/message_service.dart`
- `app/lib/core/services/websocket_service.dart`
- `app/lib/core/services/room_subscription_manager.dart`

验收：

- iOS 与 H5 可互发文本消息。
- 断网、重连、失败重试符合 Flutter/H5 语义。
- 重启后消息缓存和未读数一致。

当前说明：

- 聊天网络层已补 `ChatAPIClient`、`ChatAPIEndpoint` 和 HTTP DTO，覆盖 `/chats`、`/rooms/{roomId}/messages`、文本发送、已读、删除会话、删除消息、置顶/取消置顶基础调用。
- 会话列表数据源已补 `SwiftDataChatSummaryCacheStore` 和 `ChatListController`，实现缓存优先刷新、远端刷新后落 SwiftData、乐观删除失败回滚、WebSocket 入站消息更新 last message/unread、当前用户已读清零。
- 聊天详情数据源已补 `ChatDetailController`，实现缓存优先进入房间、远端历史消息合并、每 room 最近 200 条持久化策略复用、文本 pending/failed/retry、服务端回包替换和进入房间后的已读同步。
- SwiftUI App shell 已接入 `ChatHomeView` 和 `ChatDetailView`，支持会话列表刷新、删除会话、未读数、置顶/免打扰标识、聊天详情、文本发送、引用、失败重试、消息删除和置顶基础交互。
- 已补 `ChatListControllerTests` 和 `ChatDetailControllerTests`，覆盖会话刷新、入站消息、删除回滚、历史消息合并、发送 pending/failed/retry 和服务端回包替换。
- 已补 `ChatRealtimeController`，集中管理 WebSocket 连接、会话房间订阅、入站消息落本地缓存、会话列表更新、active detail 更新、已读回执、消息删除更新和置顶更新。
- 已补 `ChatRealtimeControllerTests` 和 WebSocket message event 解码测试，覆盖入站消息同步、active detail 自动已读、read/pin 事件同步到详情和缓存。
- 已补 reaction 基础链路：`MessageReactionSummary` 模型、reaction add/remove/get API、详情页 reaction 标签展示和点击切换、`reaction_update` 后 active detail 刷新 summaries。
- 已新增 `RED_CODE_IOS_LIVE_CHAT_SMOKE=1 swift test --filter ChatAPIClientLiveTests`，对本机 Compose API 的 `/chats` 解码做 live smoke。
- 已新增 `RedCodeIMUITests` XCUITest target、Debug-only 认证/聊天 UI fixture 和 `make ios-app.ui-test` 入口；当前已通过认证与聊天 smoke。
- 已补 `RoomAPIClient` 和 `make ios-app.test.live`，覆盖 iOS 认证、WebSocket、建群、文本互发和已读 live smoke。
- 已补 H5 `ios-h5-chat-interop-smoke`，通过 H5 service 与 iOS-compatible HTTP contract 在同一 Compose API 上验证双向文本可见。
- IOS-04.17 已通过 `make ios-app.ui-test`；IOS-04.18 已通过 `make h5-app.test.live` 和 `make ios-app.test.live`。

## IOS-05 联系人、好友与私聊

- [x] IOS-05.01 实现联系人模型和缓存。
- [x] IOS-05.02 实现联系人列表 UI。
- [x] IOS-05.03 实现用户搜索。
- [x] IOS-05.04 实现发送好友申请。
- [x] IOS-05.05 实现好友请求 badge。
- [x] IOS-05.06 实现处理好友请求。
- [x] IOS-05.07 实现联系人详情。
- [x] IOS-05.08 实现打开私聊。
- [x] IOS-05.09 增加联系人/好友单测。
- [x] IOS-05.10 与 H5 做好友流程 smoke。

当前说明：

- 已补好友 API 底座：`FriendAPIEndpoint`、`FriendInfo`、`FriendRequestInfo`、`FriendRequestStatus`、`FriendRequestAction`、`EnsurePrivateChatResult`、`FriendAPIClient`。
- 已覆盖 `/users/search`、`/friends`、`/friends/requests`、`/friends/requests/{requestId}/respond`、`/friends/{friendUserId}/chat`、`/friends/{friendUserId}`。
- 已补联系人 SwiftData 缓存：`ContactCacheStore`、`SwiftDataContactCacheStore`，支持 load/save/upsert/remove/clear 和 displayName 排序。
- 已补 `ContactsController`、`AddFriendController`、`ContactsHomeView`、联系人详情和新的朋友页面；App contacts tab 已从占位页切换为真实联系人流程。
- 已补 Networking/Storage/Features 单测，覆盖好友 API、联系人缓存、缓存优先刷新、好友请求 badge、打开私聊、删除回滚、搜索、发送申请和接受申请。
- 已把 H5 旧拒绝动作 `reject` 对齐为后端合同 `decline`，并补充 H5 service contract 测试。
- 已新增 `FriendAPIClientLiveTests` 并接入 `make ios-app.test.live`；已通过 `make h5-app.test.live` 和 `make ios-app.test.live` 完成 H5/iOS 好友流程 live smoke。

参考：

- `app/lib/features/contacts/`
- `app/lib/core/services/friend_service.dart`
- `app/lib/core/services/friend_store.dart`
- `app/lib/core/storage/friend_storage.dart`

验收：

- H5/iOS 好友状态双向可见。
- 私聊入口和会话列表状态一致。

## IOS-06 群聊和群管理全量

- [x] IOS-06.01 实现选择联系人建群。
- [x] IOS-06.02 实现群设置首页。
- [x] IOS-06.03 实现群成员列表。
- [x] IOS-06.04 实现群改名。
- [x] IOS-06.05 实现群置顶和免打扰。
- [x] IOS-06.06 实现退出/解散群聊。
- [x] IOS-06.07 实现管理员管理。
- [x] IOS-06.08 实现禁言管理。
- [x] IOS-06.09 实现入群申请。
- [x] IOS-06.10 实现群规则。
- [x] IOS-06.11 实现群操作日志。
- [x] IOS-06.12 实现群内置顶消息。
- [x] IOS-06.13 增加群权限测试。
- [x] IOS-06.14 与 H5 做群管理 smoke。

当前说明：

- 群网络层已扩展 `RoomAPIEndpoint`、`RoomModels`、`RoomAPIClient`，覆盖 `/rooms`、成员管理、群设置、置顶/免打扰、退出/解散、管理员、禁言、入群申请、群规则、操作日志和群详情。
- 群缓存已补 `SwiftDataGroupCacheStore`，复用 SwiftData 本地 schema 支持群资料缓存优先展示和本地状态收口。
- Feature 层已补 `GroupManagementController`，覆盖建群、加载群详情、成员排序、权限判断、改名、添加/移除成员、置顶/免打扰、退出/解散、管理员、禁言、全员禁言、群规则、入群申请审批和操作日志。
- SwiftUI 已接入联系人页“发起群聊”、聊天详情群设置入口、群设置首页、成员列表、添加成员、管理员管理、禁言管理、入群申请、群规则和操作日志页面。
- 群内消息置顶沿用 IOS-04 聊天详情上下文菜单与消息置顶 API；群管理阶段补齐了群级设置入口与 live smoke 合同。
- 已补 `RoomAPIClientTests`、`GroupManagementControllerTests`、`StorageTests` 群缓存覆盖，并新增 `RoomAPIClientLiveTests` 接入 `make ios-app.test.live`。
- 已通过 `swift test`、`make ios-app.check`、`make h5-app.test.live` 与 `make ios-app.test.live`。

参考：

- `app/lib/features/chat/create_group_page.dart`
- `app/lib/features/chat/group_settings_page.dart`
- `app/lib/features/chat/group_admin_management_page.dart`
- `app/lib/features/chat/group_mute_management_page.dart`
- `app/lib/features/chat/group_join_requests_page.dart`
- `app/lib/features/chat/group_rules_page.dart`
- `app/lib/features/chat/group_operation_logs_page.dart`
- `app/lib/core/services/room_service.dart`

验收：

- 群主、管理员、普通成员权限表现正确。
- 群设置变更同步 H5 和会话列表。
- 无权限操作不污染本地状态。

## IOS-07 媒体、附件、头像、语音和视频

- [x] IOS-07.01 接入 PhotosUI 图片/视频选择。
- [x] IOS-07.02 接入 DocumentPicker 文件选择。
- [x] IOS-07.03 实现上传策略获取。
- [x] IOS-07.04 实现直传。
- [x] IOS-07.05 实现文件 hash 和 MIME 识别。
- [x] IOS-07.06 实现附件缓存。
- [x] IOS-07.07 实现图片/视频/文件预览。
- [x] IOS-07.08 实现用户头像展示与缓存。
- [x] IOS-07.09 实现群头像展示与缓存。
- [x] IOS-07.10 实现头像上传。
- [x] IOS-07.11 接入 AVFoundation 语音录制。
- [x] IOS-07.12 实现语音消息发送。
- [x] IOS-07.13 实现语音播放。
- [x] IOS-07.14 实现权限拒绝和恢复路径。
- [x] IOS-07.15 使用对象存储 mock 做上传/下载 smoke。

当前说明：

- 媒体网络层已补 `MediaAPIEndpoint`、`MediaModels`、`MediaAPIClient`，覆盖用户头像、群头像、消息附件上传签名、commit、download URL 与 direct upload/download。
- `MediaUploadPreparer` 已支持 SHA256、MIME/UTType 推断、文件名规范化和图片/视频/音频/文件类型推断，hash_alg 对齐后端 `2`。
- 聊天详情已接入 PhotosUI 图片/视频选择、文件选择、附件待发送 strip、富媒体 pending/failed/resend、上传后 rich message 发送和附件缓存。
- 会话/聊天头像已优先使用 object key 获取下载 URL 并落本地 avatar cache；消息附件展示使用 `AttachmentFileCache`。
- 语音基础能力已补 `VoiceRecorderController` / `VoicePlaybackController`，覆盖 AVFoundation 录音、语音消息发送、播放和麦克风权限拒绝提示。
- dev Compose 已接入 `external-mock`，B2/IPInfo/FCM/APNs 均指向本地 mock；API presigned URL 通过 `REDCODE_IM_B2_PRESIGN_PUBLIC_ENDPOINT` 改写为 Simulator 可访问地址。
- 已补 `MediaAPIClientTests`、`MediaAPIClientLiveTests`、`ChatAPIClientTests`、`ChatDetailControllerTests`、`StorageTests` 媒体覆盖。
- 已通过 `RED_CODE_IOS_LIVE_MEDIA_SMOKE=1 swift test --filter MediaAPIClientLiveTests`，覆盖 mock 对象存储上传、commit、富媒体消息发送和下载校验。
- H5 已补 `messageService.sendRichMessage`，并在 live smoke 中覆盖 H5 直传 mock 对象存储、commit、发送富媒体消息，以及 iOS-compatible HTTP 读取附件。

参考：

- `app/lib/core/network/direct_upload.dart`
- `app/lib/core/services/upload_policy_service.dart`
- `app/lib/core/services/user_avatar_service.dart`
- `app/lib/core/services/room_avatar_service.dart`
- `app/lib/core/services/voice_service.dart`
- `app/lib/core/storage/attachment_cache.dart`
- `app/lib/core/storage/avatar_cache.dart`
- `app/lib/features/chat/video_preview_page.dart`
- `app/lib/features/chat/widgets/voice_message_widget.dart`

验收：

- 媒体消息在 iOS/H5 间互通。
- 权限拒绝、上传失败、播放失败都有可恢复 UI。
- 测试不访问线上对象存储。

## IOS-08 表情、贴纸、消息搜索和聊天扩展

- [x] IOS-08.01 实现内置 emoji。
- [x] IOS-08.02 实现表情包列表。
- [x] IOS-08.03 实现表情项加载。
- [x] IOS-08.04 实现表情资源缓存。
- [x] IOS-08.05 实现贴纸管理。
- [x] IOS-08.06 实现消息搜索索引写入。
- [x] IOS-08.07 实现消息搜索页面。
- [x] IOS-08.08 实现聊天背景。
- [x] IOS-08.09 实现聊天设置。
- [x] IOS-08.10 增加搜索与表情缓存测试。

当前说明：

- 表情网络层已补 `EmojiAPIEndpoint`、`EmojiModels`、`EmojiAPIClient`，覆盖 `/emoji-packs/my`、`/emoji-packs/available`、搜索、添加/移除、套装添加、套装下贴纸和下载 URL。
- 聊天详情输入区已接入内置 emoji；打开表情面板时会加载用户已添加表情包，点击贴纸会下载并缓存表情图，再通过消息附件上传链路发送为图片消息，避免直接把 `emoji-items/*` 写入消息附件。
- 表情资源缓存复用 `EmojiFileCache`，聊天面板和设置页共用同一缓存；聊天设置支持清除媒体、头像和表情缓存。
- 消息搜索已补本地 `SwiftDataMessageSearchStore`，支持从消息缓存重建索引、房间/类型过滤、分页和删除消息过滤；搜索页会优先展示本地结果并合并服务端 `/messages/search`。
- 聊天设置已补背景偏好 `UserDefaultsChatPreferencesStore`、聊天背景选择、表情管理、本地聊天记录清理入口。
- 已修复 SwiftData 消息记录删除状态字段命名，避免与 SwiftData 模型运行态删除语义冲突。
- 已补 `EmojiAPIClientTests`、`ChatAPIClientTests` 搜索覆盖、`StorageTests` 搜索/偏好覆盖和 `ChatExtensionControllerTests`。
- 已通过 `swift test`、`make ios-app.check`、`make h5-app.test.live` 与 `make ios-app.test.live`。

参考：

- `app/lib/features/chat/constants/emoji_list.dart`
- `app/lib/features/chat/message_search_page.dart`
- `app/lib/features/emoji/models/emoji_pack_models.dart`
- `app/lib/core/services/emoji_pack_service.dart`
- `app/lib/core/services/emoji_item_service.dart`
- `app/lib/core/storage/emoji_cache.dart`
- `app/lib/features/settings/sticker_management_page.dart`

验收：

- 搜索结果与本地缓存一致。
- 表情资源可离线复用。

## IOS-09 设置、账号、文档、反馈、配置和版本

- [x] IOS-09.01 实现设置首页。
- [x] IOS-09.02 实现个人资料。
- [x] IOS-09.03 实现昵称更新。
- [x] IOS-09.04 实现账号安全。
- [x] IOS-09.05 实现修改密码。
- [x] IOS-09.06 实现用户协议和隐私政策。
- [x] IOS-09.07 实现关于页面。
- [x] IOS-09.08 实现反馈提交。
- [x] IOS-09.09 实现 App 配置拉取与缓存。
- [x] IOS-09.10 实现版本检查。
- [x] IOS-09.11 实现 iOS 原生更新提示。
- [x] IOS-09.12 增加设置域测试。

当前说明：

- 设置网络层已补 `SettingsAPIEndpoint` / `SettingsModels` / `SettingsAPIClient`，覆盖通用设置、App 名称、隐私协议、用户协议、反馈提交、最新版本检查和版本下载 URL。
- 用户资料链路已扩展 `AuthAPIClient.updateProfile` 与 `AuthController.updateProfile`，昵称更新会写回 Keychain-backed session。
- App 配置缓存已补 `SwiftDataAppConfigStore`，复用 `RedCodeAppConfigRecord` 保存通用设置和协议文档，设置页按“缓存优先、远端刷新”展示。
- 原生 SwiftUI 设置页已覆盖个人资料、账号与安全、修改密码、验证码重置密码、聊天设置入口、协议文档、关于页、反馈页、消息运行模式展示、版本检查和更新链接提示。
- iOS 原生更新不做包内下载安装，按系统规范提示并打开 Admin 配置的 App Store URL / 下载 URL。
- 登出流程已清理 WebSocket、聊天列表、消息、联系人、群、配置缓存、附件、头像、表情缓存和聊天背景偏好。
- 已补 `SettingsAPIClientTests`、`SettingsControllerTests`、`StorageTests` AppConfig 缓存覆盖，并扩展 Auth profile 更新测试。
- 已通过 `swift test`。

参考：

- `app/lib/features/settings/`
- `app/lib/core/services/settings_service.dart`
- `app/lib/core/services/feedback_service.dart`
- `app/lib/core/services/user_service.dart`
- `app/lib/core/services/app_config_service.dart`
- `app/lib/core/services/version_service.dart`
- `app/lib/core/update/`

验收：

- 设置页功能与 Flutter/H5 等价。
- 配置/文档接口失败时有缓存或明确错误展示。

## IOS-10 Push、本地通知和通知导航

- [x] IOS-10.01 实现本地通知权限请求。
- [x] IOS-10.02 实现本地通知展示。
- [x] IOS-10.03 实现 APNs token 注册。
- [x] IOS-10.04 实现 token 上报后端。
- [x] IOS-10.05 实现前台通知处理。
- [x] IOS-10.06 实现后台通知点击进入会话。
- [x] IOS-10.07 实现冷启动通知导航。
- [x] IOS-10.08 实现登出后通知态清理。
- [x] IOS-10.09 如后端只支持 FCM，单独设计兼容桥接。
- [ ] IOS-10.10 补 iPhone 真机验收。

当前说明：

- 已接入 `UserNotifications` 本地通知权限和展示；App 前台不弹系统通知，后台/非前台收到 WebSocket 新消息时用本地通知兜底。
- 已接入 APNs 注册回调和 `PushController.registerAPNsDeviceToken`；服务端现有 `/push/devices` 合约也支持保存 channel。
- 后端已补 APNs provider 配置、APNs token 投递、Push 日志和本地 mock 验证链路；离线通知会按 `push_devices.channel` 分发到 FCM 或 APNs。
- 通知点击 payload 会映射为聊天或好友请求目的地；冷启动 payload 由 App delegate 写入 `NotificationNavigationController`，App root 再切换到对应 Tab/会话。
- 登出会先尝试注销当前 push device，并清理本地通知 token、待导航 payload 和已投递/待发送通知。
- SwiftPM 已覆盖 Push API、Push controller、通知导航、本地通知调度条件和 device identity 存储。

参考：

- `app/lib/core/services/local_notification_service.dart`
- `app/lib/core/services/push_service.dart`
- `app/lib/core/services/push_navigation.dart`

验收：

- Simulator/SwiftPM 已覆盖 payload 导航、后台本地通知兜底和登出通知态清理。
- iPhone 真机需补验 APNs token 获取、Apple 平台真实投递和点击进入正确页面。

## IOS-11 全量 parity 验收与切换准备

- [x] IOS-11.01 建立 Flutter vs iOS 功能对照清单。
- [x] IOS-11.02 建立 H5/API/iOS 联调脚本。
- [x] IOS-11.03 完成本机 iOS Simulator smoke。
- [x] IOS-11.04 完成 UI test 回归。
- [x] IOS-11.05 完成媒体 mock 回归。
- [ ] IOS-11.06 完成通知真机补验。
- [x] IOS-11.07 建立 P0/P1 缺口清单。
- [x] IOS-11.08 建立 Flutter iOS 下线条件。
- [x] IOS-11.09 建立回滚策略。
- [x] IOS-11.10 更新 `docs/reference/testing/README.md`。

当前说明：

- Flutter vs iOS 功能对照、P0/P1 缺口、下线条件和回滚策略已沉淀到 `docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`。
- 已新增 `make ios-app.test.interop`，串联 H5 live smoke 与 iOS live smoke。
- 已通过 `make ios-app.test.interop`，覆盖 H5/API/iOS 认证、WebSocket、聊天、好友、群管理和媒体 mock 关键链路。
- 已通过 `make ios-app.smoke.simulator`，本机 `iPhone 17 Pro` Simulator 可构建、安装、启动。
- IOS-11.04 已通过 `make ios-app.ui-test`，覆盖认证协议门禁/登录和聊天详情发送 smoke；若后续 Xcode SDK 升级导致 runtime 不匹配，按测试文档安装对应 runtime 后重跑。
- IOS-11.06 需要 iPhone 真机与 Apple APNs 平台凭据；当前 API mock 已覆盖 APNs/FCM 投递，Simulator/SwiftPM 已覆盖本地通知调度、payload 导航和登出通知态清理。

验收：

- 核心功能无 P0/P1 缺口。
- 全量 smoke 通过。
- 切换和回滚策略清晰。
