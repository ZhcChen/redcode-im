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
- [ ] IOS-02.05 实现重置密码。
- [ ] IOS-02.06 实现用户协议/隐私协议提示。
- [x] IOS-02.07 实现 Token Keychain 存取。
- [x] IOS-02.08 实现登录态校验和 session 恢复。
- [ ] IOS-02.09 实现登出清理：Token、WS、内存态、本地敏感缓存。
- [x] IOS-02.10 增加认证 ViewModel 单测。
- [ ] IOS-02.11 增加认证 UI test。
- [x] IOS-02.12 与 API Compose 做账号密码注册/登录 smoke。

当前说明：

- 当前默认关闭邮箱注册/登录主线；不做 Google/Apple 登录，不做邮箱验证码二次验证。
- 邮箱注册/登录作为后台配置能力保留；当前开发测试跳过真实邮箱资源依赖。
- 已建立账号规范化、认证用户、认证会话、认证 HTTP endpoint/payload、本地 session store 基础。
- 已建立 `APIClient`、`AuthAPIClient`、`AuthController`、`KeychainKeyValueStore`，并补充 SwiftPM 单测。
- `KeyValueAuthSessionStore` 可通过 `KeychainKeyValueStore` 落 Keychain；SwiftUI App target 已接入 SwiftPM 本地模块、Keychain-backed session store 和认证 UI。
- IOS-02.09 当前只完成认证 session 清理基础；WS 断开和本地敏感缓存清理需等待 IOS-03/IOS-04 底座完成后收口。
- 当前 iOS UI 已提供普通账号密码登录、注册并登录、启动恢复 loading、登录后 tab shell 和设置页登出入口；UI test 尚未完成。
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
- [ ] IOS-03.02 实现统一 request/response DTO mapping。
- [x] IOS-03.03 实现认证 header 注入。
- [ ] IOS-03.04 实现网络错误分类和 UI 可恢复错误。
- [x] IOS-03.05 实现 WebSocket client。
- [x] IOS-03.06 实现 WS 认证、订阅、取消订阅。
- [x] IOS-03.07 实现 WS 重连、订阅恢复和事件去重。
- [ ] IOS-03.08 建立 SwiftData schema：会话、消息、联系人、群、配置。
- [ ] IOS-03.09 实现 FileManager Caches：附件、头像、表情。
- [ ] IOS-03.10 设计消息搜索索引：SwiftData 优先，必要时 SQLite FTS5/GRDB。
- [x] IOS-03.11 增加 Networking 单测与 mock transport。
- [ ] IOS-03.12 增加 Storage 单测。
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
- IOS-03.02/03.04 仍需在聊天、联系人、群和设置接口扩展时统一 DTO mapping 与 UI 可恢复错误模型。
- SwiftData schema、FileManager cache 和 Storage 单测尚未开始。
- 当前 WebSocket live smoke 覆盖真实后端连接与认证；真实房间订阅/消息收发会在 IOS-04 iOS/H5 同后端互发 smoke 中继续扩展。

## IOS-04 聊天核心全量

- [ ] IOS-04.01 实现会话列表数据源。
- [ ] IOS-04.02 实现会话列表 UI。
- [ ] IOS-04.03 实现未读数、置顶、免打扰展示。
- [ ] IOS-04.04 实现聊天详情数据源。
- [ ] IOS-04.05 实现聊天详情 UI。
- [ ] IOS-04.06 实现历史消息加载和本地缓存合并。
- [ ] IOS-04.07 实现每 room 最近 200 条消息保留策略。
- [ ] IOS-04.08 实现文本消息发送。
- [ ] IOS-04.09 实现 pending、失败重试、服务端回包替换。
- [ ] IOS-04.10 实现引用消息。
- [ ] IOS-04.11 实现已读。
- [ ] IOS-04.12 实现消息删除。
- [ ] IOS-04.13 实现置顶消息。
- [ ] IOS-04.14 实现 reaction。
- [ ] IOS-04.15 实现房间订阅管理。
- [ ] IOS-04.16 增加聊天 ViewModel 单测。
- [ ] IOS-04.17 增加聊天 UI test。
- [ ] IOS-04.18 与 H5 做同后端互发 smoke。

参考：

- `app/lib/features/chat/`
- `app/lib/core/services/message_service.dart`
- `app/lib/core/services/websocket_service.dart`
- `app/lib/core/services/room_subscription_manager.dart`

验收：

- iOS 与 H5 可互发文本消息。
- 断网、重连、失败重试符合 Flutter/H5 语义。
- 重启后消息缓存和未读数一致。

## IOS-05 联系人、好友与私聊

- [ ] IOS-05.01 实现联系人模型和缓存。
- [ ] IOS-05.02 实现联系人列表 UI。
- [ ] IOS-05.03 实现用户搜索。
- [ ] IOS-05.04 实现发送好友申请。
- [ ] IOS-05.05 实现好友请求 badge。
- [ ] IOS-05.06 实现处理好友请求。
- [ ] IOS-05.07 实现联系人详情。
- [ ] IOS-05.08 实现打开私聊。
- [ ] IOS-05.09 增加联系人/好友单测。
- [ ] IOS-05.10 与 H5 做好友流程 smoke。

参考：

- `app/lib/features/contacts/`
- `app/lib/core/services/friend_service.dart`
- `app/lib/core/services/friend_store.dart`
- `app/lib/core/storage/friend_storage.dart`

验收：

- H5/iOS 好友状态双向可见。
- 私聊入口和会话列表状态一致。

## IOS-06 群聊和群管理全量

- [ ] IOS-06.01 实现选择联系人建群。
- [ ] IOS-06.02 实现群设置首页。
- [ ] IOS-06.03 实现群成员列表。
- [ ] IOS-06.04 实现群改名。
- [ ] IOS-06.05 实现群置顶和免打扰。
- [ ] IOS-06.06 实现退出/解散群聊。
- [ ] IOS-06.07 实现管理员管理。
- [ ] IOS-06.08 实现禁言管理。
- [ ] IOS-06.09 实现入群申请。
- [ ] IOS-06.10 实现群规则。
- [ ] IOS-06.11 实现群操作日志。
- [ ] IOS-06.12 实现群内置顶消息。
- [ ] IOS-06.13 增加群权限测试。
- [ ] IOS-06.14 与 H5 做群管理 smoke。

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

- [ ] IOS-07.01 接入 PhotosUI 图片/视频选择。
- [ ] IOS-07.02 接入 DocumentPicker 文件选择。
- [ ] IOS-07.03 实现上传策略获取。
- [ ] IOS-07.04 实现直传。
- [ ] IOS-07.05 实现文件 hash 和 MIME 识别。
- [ ] IOS-07.06 实现附件缓存。
- [ ] IOS-07.07 实现图片/视频/文件预览。
- [ ] IOS-07.08 实现用户头像展示与缓存。
- [ ] IOS-07.09 实现群头像展示与缓存。
- [ ] IOS-07.10 实现头像上传。
- [ ] IOS-07.11 接入 AVFoundation 语音录制。
- [ ] IOS-07.12 实现语音消息发送。
- [ ] IOS-07.13 实现语音播放。
- [ ] IOS-07.14 实现权限拒绝和恢复路径。
- [ ] IOS-07.15 使用对象存储 mock 做上传/下载 smoke。

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

- [ ] IOS-08.01 实现内置 emoji。
- [ ] IOS-08.02 实现表情包列表。
- [ ] IOS-08.03 实现表情项加载。
- [ ] IOS-08.04 实现表情资源缓存。
- [ ] IOS-08.05 实现贴纸管理。
- [ ] IOS-08.06 实现消息搜索索引写入。
- [ ] IOS-08.07 实现消息搜索页面。
- [ ] IOS-08.08 实现聊天背景。
- [ ] IOS-08.09 实现聊天设置。
- [ ] IOS-08.10 增加搜索与表情缓存测试。

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

- [ ] IOS-09.01 实现设置首页。
- [ ] IOS-09.02 实现个人资料。
- [ ] IOS-09.03 实现昵称更新。
- [ ] IOS-09.04 实现账号安全。
- [ ] IOS-09.05 实现修改密码。
- [ ] IOS-09.06 实现用户协议和隐私政策。
- [ ] IOS-09.07 实现关于页面。
- [ ] IOS-09.08 实现反馈提交。
- [ ] IOS-09.09 实现 App 配置拉取与缓存。
- [ ] IOS-09.10 实现版本检查。
- [ ] IOS-09.11 实现 iOS 原生更新提示。
- [ ] IOS-09.12 增加设置域测试。

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

- [ ] IOS-10.01 实现本地通知权限请求。
- [ ] IOS-10.02 实现本地通知展示。
- [ ] IOS-10.03 实现 APNs token 注册。
- [ ] IOS-10.04 实现 token 上报后端。
- [ ] IOS-10.05 实现前台通知处理。
- [ ] IOS-10.06 实现后台通知点击进入会话。
- [ ] IOS-10.07 实现冷启动通知导航。
- [ ] IOS-10.08 实现登出后通知态清理。
- [ ] IOS-10.09 如后端只支持 FCM，单独设计兼容桥接。
- [ ] IOS-10.10 补 iPhone 真机验收。

参考：

- `app/lib/core/services/local_notification_service.dart`
- `app/lib/core/services/push_service.dart`
- `app/lib/core/services/push_navigation.dart`

验收：

- 前台、后台、冷启动通知都能进入正确页面。
- 登出后不再保留当前用户通知态。

## IOS-11 全量 parity 验收与切换准备

- [ ] IOS-11.01 建立 Flutter vs iOS 功能对照清单。
- [ ] IOS-11.02 建立 H5/API/iOS 联调脚本。
- [ ] IOS-11.03 完成本机 iOS Simulator smoke。
- [ ] IOS-11.04 完成 UI test 回归。
- [ ] IOS-11.05 完成媒体 mock 回归。
- [ ] IOS-11.06 完成通知真机补验。
- [ ] IOS-11.07 建立 P0/P1 缺口清单。
- [ ] IOS-11.08 建立 Flutter iOS 下线条件。
- [ ] IOS-11.09 建立回滚策略。
- [ ] IOS-11.10 更新 `docs/reference/testing/README.md`。

验收：

- 核心功能无 P0/P1 缺口。
- 全量 smoke 通过。
- 切换和回滚策略清晰。
