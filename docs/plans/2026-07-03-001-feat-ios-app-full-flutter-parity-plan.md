---
title: "feat: Migrate full Flutter app functionality to native iOS"
type: feat
status: completed
date: 2026-07-03
origin: docs/plans/2026-07-02-002-feat-ios-app-native-migration-plan.md
deepened: 2026-07-03
completed: 2026-07-04
---

# feat: Migrate full Flutter app functionality to native iOS

## Overview

`ios-app` 的目标调整为：完整迁移 Flutter `app/` 当前功能逻辑到原生 iOS，而不是只做 MVP。迁移时以 Flutter 的功能行为、接口协议、缓存语义和测试覆盖为 parity 基准；实现方式以 iOS 原生开发为准，不逐行翻译 Dart，不照搬 Flutter Widget/Provider 结构。

> 收口说明（2026-07-04）：除必须依赖 iPhone 真机与 Apple APNs 凭据的真实 APNs 投递、系统通知点击唤醒和真机签名安装外，完整 parity 范围已通过本机 Simulator、SwiftPM、XCUITest、H5/API/iOS live smoke 和 mock 外部服务完成验收。用户已明确要求跳过需要真机的部分；跳过项记录在 `docs/plans/2026-07-04-001-ios-app-remaining-parity-execution-list.md`、`ios-app/docs/full-migration-task-tree.md` 和 `docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`。

## Problem Frame

Flutter `app/` 已经包含认证、聊天、联系人、群管理、媒体、语音、表情、设置、配置、通知、版本和热更新等多组能力。原计划只强调先建 `ios-app` 和核心 MVP，会低估迁移范围。现在需要一份完整目标阶段方案，让后续执行能从一开始按“完整 Flutter parity”组织工程、模块、测试和验收。

## Requirements Trace

- R1. `ios-app` 最终完整覆盖 Flutter `app/` 当前用户可见功能和核心数据流。
- R2. iOS 实现必须采用原生 Swift/SwiftUI、Keychain、SwiftData/FileManager/UserNotifications/AVFoundation 等 iOS 习惯，不机械翻译 Flutter 写法。
- R3. 认证主线只做普通账号密码注册/登录、重置密码、登出和启动态恢复，不做 Google/Apple 登录；邮箱注册/登录作为后台配置能力保留。
- R4. 聊天功能完整覆盖会话列表、聊天详情、WebSocket、文本、pending、失败重试、已读、删除、置顶、引用、reaction、未读数和搜索。
- R5. 联系人、好友、私聊、群聊和群管理完整覆盖 Flutter 当前页面能力。
- R6. 媒体、附件、头像、语音、视频预览、表情包、贴纸和缓存语义完整迁移。
- R7. 设置、账号安全、文档、反馈、App 配置、版本检查和更新提示完整迁移；Flutter 热更新执行能力不按原样迁移。
- R8. Push 与本地通知作为后期阶段迁移，iOS 优先 APNs；Firebase Messaging 不作为默认 iOS 依赖。
- R9. H5 继续作为 API 联调和功能流程基准；Flutter 作为完整功能 parity 清单来源。
- R10. 完整 parity 通过前，不删除 Flutter `app/`。
- R11. `ios-app` 默认使用本机 iOS Simulator 验收，不套用 Flutter `app` 的 Pixel 8 Pro 优先规则。

## Scope Boundaries

- 不迁移 Android 原生。
- 不删除 Flutter `app/`，直到 iOS 全量 parity 验收完成。
- 不恢复 Google/Apple 登录。
- 不改变后端 HTTP/WS 协议作为迁移前提；如发现接口缺口，单独列后端任务。
- 不把 Flutter 热更新按原样搬到 iOS；iOS 侧只做远程配置、版本检查和更新提示。
- 不为了“代码结构相似”牺牲 iOS 原生生命周期、权限、导航、本地存储和安全模型。
- 不默认安排 iPhone 真机测试；真机只用于 APNs、相机、麦克风、后台通知、签名发布等 Simulator 无法完整覆盖的能力。

## Context & Research

### Flutter 功能面

- 认证与启动：`app/lib/features/startup/`、`app/lib/features/auth/`、`app/lib/core/auth/`、`app/lib/core/storage/token_storage.dart`
- App Shell 与 UI 基础：`app/lib/features/home/home_shell_page.dart`、`app/lib/core/theme/`、`app/lib/core/widgets/`
- 聊天核心：`app/lib/features/chat/`、`app/lib/core/services/message_service.dart`、`app/lib/core/services/websocket_service.dart`、`app/lib/core/storage/message_storage.dart`
- 联系人与好友：`app/lib/features/contacts/`、`app/lib/core/services/friend_service.dart`、`app/lib/core/storage/friend_storage.dart`
- 群管理：`app/lib/features/chat/group_*`、`app/lib/features/chat/create_group_page.dart`、`app/lib/core/services/room_service.dart`
- 媒体与上传：`app/lib/core/network/direct_upload.dart`、`app/lib/core/services/upload_policy_service.dart`、`app/lib/core/storage/attachment_cache.dart`
- 头像、语音、视频：`app/lib/core/services/user_avatar_service.dart`、`app/lib/core/services/room_avatar_service.dart`、`app/lib/core/services/voice_service.dart`、`app/lib/features/chat/video_preview_page.dart`
- 表情与贴纸：`app/lib/core/services/emoji_pack_service.dart`、`app/lib/core/services/emoji_item_service.dart`、`app/lib/core/storage/emoji_cache.dart`、`app/lib/features/settings/sticker_management_page.dart`
- 设置与反馈：`app/lib/features/settings/`、`app/lib/core/services/settings_service.dart`、`app/lib/core/services/feedback_service.dart`
- 配置、版本、更新：`app/lib/core/services/app_config_service.dart`、`app/lib/core/services/version_service.dart`、`app/lib/core/update/`
- 通知：`app/lib/core/services/local_notification_service.dart`、`app/lib/core/services/push_service.dart`、`app/lib/core/services/push_navigation.dart`

### 现有测试参考

- Flutter 单元/组件测试：`app/test/`
- Flutter integration：`app/integration_test/`
- Flutter Patrol：`app/patrol_test/`
- H5 live/API smoke：`h5-app/README.md`、`h5-app/src/`

### iOS 官方方向

- SwiftUI App 生命周期、`WindowGroup`、`NavigationStack` 适合作为原生 App Shell 与导航基础。
- SwiftData 提供 `ModelContainer`/`ModelContext` 模型持久化能力，适合会话、消息、联系人等结构化缓存。
- Swift Package Manager 用 products、targets、testTarget 拆分本地模块和测试。

## Key Technical Decisions

- **完整 parity，而不是 MVP parity。** 实施顺序可以分阶段，但目标清单必须覆盖 Flutter 当前功能逻辑。
- **Apple 官方工程规范优先。** Swift、SwiftUI、Swift Package Manager、SwiftData、XCTest/XCUITest 和 Human Interface Guidelines 作为工程与交互基线。
- **Swift only。** 新业务代码使用 Swift 6 language mode，不使用 Objective-C；只有无法避免的系统/第三方桥接才允许单独说明。
- **SwiftUI-first。** App Shell、页面、列表、表单、弹窗、sheet、导航优先用 SwiftUI；UIKit 只在 SwiftUI 不足时桥接。
- **MVVM + Repository + Service/Actor。** Flutter Provider 和 service 只作为行为参考；iOS 用 ViewModel 承接 UI 状态，用 Repository/Service/Actor 承接异步、缓存和协议。
- **SPM local packages。** 建议拆为 `RedCodeCore`、`RedCodeNetworking`、`RedCodeStorage`、`RedCodeFeatures`，避免 App target 膨胀。
- **Keychain 存敏感凭据。** Token、会话凭据进入 Keychain；UserDefaults 只存非敏感偏好。
- **SwiftData 做主缓存。** 会话、消息、联系人、群、配置等结构化数据用 SwiftData；附件/头像/表情资源用 FileManager Caches。
- **消息搜索保留 SQLite FTS 选项。** SwiftData 不足以支撑消息全文搜索时，引入 SQLite FTS5/GRDB 作为搜索索引侧车，不替代 SwiftData 主缓存。
- **WebSocket JSON 协议先行。** 优先复用 H5/后端当前 JSON WS 主链路；不把 protobuf 作为 iOS 首期必要条件。
- **上传与媒体用 iOS 原生框架。** 图片/视频选择用 PhotosUI/DocumentPicker，语音用 AVFoundation，通知用 UserNotifications。
- **Push 优先 APNs。** Flutter 当前依赖 Firebase Messaging，但 iOS 原生不默认引入 Firebase；如果后端只支持 FCM，再单独评估桥接。
- **热更新原生化替代。** Flutter 热更新模块在 iOS 侧改为远程配置、版本检查、更新提示和资源配置，不迁移动态代码执行。
- **测试设备默认本机 iOS Simulator。** `ios-app` 的开发、smoke、UI test 与 H5/API 联调默认在本机 iOS Simulator 执行，Simulator 使用 `127.0.0.1` 访问本机 Compose API/WS。

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification. The implementing agent should treat it as context, not code to reproduce.*

```text
ios-app/App
  -> App lifecycle / TabView / NavigationStack / dependency assembly

ios-app/Sources/RedCodeFeatures
  -> Startup / Auth / Chat / Contacts / Groups / Media / Settings / Push

ios-app/Sources/RedCodeCore
  -> domain models / environment / errors / constants / validators

ios-app/Sources/RedCodeNetworking
  -> HTTP API / WebSocket / upload / DTO mapping / retry policy

ios-app/Sources/RedCodeStorage
  -> Keychain / SwiftData / FileManager cache / search index

External runtime
  -> api Compose stack / object storage mock / H5 parity runner / Flutter reference
```

## Target Phases

### Phase 0：方案、范围和骨架

**Goal:** 固化完整 Flutter parity 迁移目标，避免后续只按 MVP 设计。

**Files:**
- Create/Modify: `ios-app/README.md`
- Create/Modify: `ios-app/docs/architecture.md`
- Create: `ios-app/docs/flutter-parity-scope.md`
- Create: `docs/plans/2026-07-03-001-feat-ios-app-full-flutter-parity-plan.md`

**Verification:**
- 文档明确说明迁移范围、非目标、iOS 原生映射和阶段目标。

### Phase 1：原生基础设施

**Goal:** 建立可构建、可测试、可联调的原生 iOS 基座。

**Scope:**
- Xcode 工程或 XcodeGen/Tuist 选型。
- SPM local packages。
- SwiftUI App 入口、TabView、NavigationStack。
- 环境配置、日志、错误模型、依赖组装。
- XCTest/XCUITest 基础入口。
- 阶段任务索引树。

**Reference:** `app/lib/main.dart`、`app/lib/app.dart`、`app/lib/core/config/environment.dart`

**Acceptance:**
- iOS Simulator 可启动空壳 App。
- 可切换开发/测试 API 和 WS 地址。
- package 单元测试可运行。
- `ios-app/docs/full-migration-task-tree.md` 能作为后续执行索引。

### Phase 2：启动、认证与会话安全

**Goal:** 完成账号密码认证闭环和启动态恢复。

**Scope:**
- Splash。
- 普通账号密码注册、普通账号密码登录、重置密码。
- 用户协议/隐私协议提示。
- Token Keychain。
- 启动恢复和登出清理。

**Reference:** `app/lib/features/startup/`、`app/lib/features/auth/`、`app/lib/core/auth/`

**Acceptance:**
- 注册后自动登录。
- 重启 App 可恢复 session。
- 登出后清理 Token、断开 WS、清理内存态。

### Phase 3：网络、WebSocket、本地数据和缓存底座

**Goal:** 为后续全功能迁移建立稳定的数据层。

**Scope:**
- HTTP API client。
- WebSocket client：认证、订阅、重连、去重。
- SwiftData schema：会话、消息、联系人、群、配置。
- Keychain/UserDefaults/FileManager Caches。
- 附件、头像、表情资源缓存。
- 消息搜索索引策略。

**Reference:** `app/lib/core/services/`、`app/lib/core/storage/`

**Acceptance:**
- HTTP 和 WS 可用 mock/真实后端测试。
- 本地缓存优先展示、后台刷新。
- 同一消息不会因 HTTP/WS 双路径重复插入。

### Phase 4：聊天核心全量

**Goal:** 完整迁移聊天主链路。

**Scope:**
- 会话列表、聊天详情。
- 历史消息、本地消息缓存、每 room 最近 200 条语义。
- 文本消息发送、pending、失败重试、服务端回包替换。
- 已读、删除、置顶消息、引用消息、reaction。
- 未读数、置顶/免打扰展示。
- 房间订阅管理。

**Reference:** `app/lib/features/chat/`、`app/lib/core/services/message_service.dart`、`app/lib/core/services/room_subscription_manager.dart`

**Acceptance:**
- iOS 与 H5 同后端互发文本消息。
- 断网/重连/失败重试行为符合 Flutter/H5 语义。
- 本地缓存和未读数在重启后保持一致。

### Phase 5：联系人、好友与私聊

**Goal:** 完整迁移联系人和好友关系流程。

**Scope:**
- 联系人列表和本地好友缓存。
- 搜索用户、发送好友申请。
- 接收/处理好友请求。
- 联系人详情、打开私聊。

**Reference:** `app/lib/features/contacts/`、`app/lib/core/services/friend_service.dart`

**Acceptance:**
- H5 创建/处理好友状态后 iOS 可见。
- iOS 创建/处理好友状态后 H5 可见。
- 私聊入口与会话列表状态一致。

### Phase 6：群聊和群管理全量

**Goal:** 完整迁移群聊管理能力。

**Scope:**
- 创建群聊、群设置、成员列表。
- 改名、置顶、免打扰、退出/解散。
- 管理员管理、禁言管理、入群申请。
- 群规则、群操作日志。
- 群内置顶消息。

**Reference:** `app/lib/features/chat/group_*`、`app/lib/core/services/room_service.dart`

**Acceptance:**
- 普通成员、管理员、群主权限表现正确。
- 群设置变更能同步到 H5 和会话列表。
- 无权限操作显示明确错误，不污染本地状态。

### Phase 7：媒体、附件、头像、语音和视频

**Goal:** 完整迁移非文本消息与媒体能力。

**Scope:**
- 图片、视频、文件选择。
- 上传策略、直传、hash、MIME。
- 图片/视频/附件预览和缓存。
- 用户头像、群头像展示与缓存。
- 语音录制、发送、播放、权限处理。

**Reference:** `app/lib/core/network/direct_upload.dart`、`app/lib/core/services/upload_policy_service.dart`、`app/lib/core/services/voice_service.dart`、`app/lib/features/chat/widgets/voice_message_widget.dart`

**Acceptance:**
- 对象存储 mock 环境下可完成上传/下载/缓存验证。
- 权限拒绝、上传失败、播放失败都有可恢复 UI。
- 媒体消息在 iOS/H5 间互通。

### Phase 8：表情、贴纸、消息搜索和聊天扩展

**Goal:** 补齐聊天扩展体验。

**Scope:**
- 内置 emoji。
- 表情包、表情项、贴纸管理。
- 表情资源缓存。
- 消息搜索页面和本地搜索索引。
- 聊天背景、聊天设置。

**Reference:** `app/lib/features/chat/message_search_page.dart`、`app/lib/features/settings/sticker_management_page.dart`、`app/lib/core/storage/message_search_storage.dart`

**Acceptance:**
- 搜索结果与本地缓存一致。
- 表情资源离线缓存可用。
- 聊天背景/设置在重启后保持。

### Phase 9：设置、账号、文档、反馈、配置和版本

**Goal:** 完整迁移设置域和配置能力。

**Scope:**
- 设置首页。
- 个人资料、账号安全、修改密码。
- 用户协议、隐私政策、关于。
- 反馈提交。
- App 配置拉取与缓存。
- 版本检查和更新提示。
- Flutter 热更新替代策略。

**Reference:** `app/lib/features/settings/`、`app/lib/core/services/app_config_service.dart`、`app/lib/core/update/`

**Acceptance:**
- 设置页功能与 Flutter/H5 等价。
- 配置/文档接口失败时有缓存或明确错误展示。
- 版本更新提示符合 iOS 分发方式。

### Phase 10：Push、本地通知和通知导航

**Goal:** 完成通知闭环。

**Scope:**
- 本地通知。
- APNs token 注册。
- 通知点击进入对应会话/消息。
- 前后台状态切换、未读同步。
- 如后端只支持 FCM，单独设计兼容桥接。

**Reference:** `app/lib/core/services/local_notification_service.dart`、`app/lib/core/services/push_service.dart`、`app/lib/core/services/push_navigation.dart`

**Acceptance:**
- 前台/后台/冷启动点击通知均可进入正确页面。
- 登出后不再接收当前用户通知态。

### Phase 11：全量 parity 验收与切换准备

**Goal:** 确认 iOS 原生具备替换 Flutter iOS 的条件。

**Scope:**
- Flutter vs iOS 功能清单逐项验收。
- H5/API/iOS 联调。
- 本机 iOS Simulator smoke、UI test 与 H5/API 联调。
- 真机签名和发布前检查。
- 缺口清单和切换策略。

**Acceptance:**
- 核心功能无 P0/P1 缺口。
- 全量 smoke 通过。
- 明确 Flutter iOS 下线条件和回滚策略。

## Verification Strategy

- 单元测试：Core、Networking、Storage、Feature ViewModel。
- UI 测试：认证、聊天、联系人、群、设置主流程。
- 集成测试：本机 iOS Simulator + API Compose + H5 对照。
- 媒体测试：对象存储 mock，避免真实对象存储浪费。
- 回归基准：先 H5，后 iOS；Flutter 作为完整功能清单和视觉/行为参考。
- 设备策略：默认只用本机 iOS Simulator；APNs、相机、麦克风、后台通知、签名发布等能力再单独用 iPhone 真机补验。

## Risks & Dependencies

- 全量范围大：按阶段交付，但始终维护完整 parity 清单。
- SwiftData 搜索能力不足：消息搜索预留 SQLite FTS5/GRDB 侧车。
- WebSocket 状态复杂：重连、重复事件、pending 替换和订阅恢复必须专项测试。
- 媒体权限复杂：Photos、麦克风、通知、文件访问都要覆盖拒绝和恢复路径。
- Push 后端能力不确定：APNs 优先；FCM 兼容作为独立设计。
- 热更新不可原样迁移：接受 iOS 原生发布限制，用配置和版本更新提示替代。
- 工程管理风险：不手写复杂 `.xcodeproj`；明确 Xcode/XcodeGen/Tuist 后再落地。

## Documentation / Operational Notes

- `ios-app/docs/flutter-parity-scope.md` 是完整迁移范围源。
- `ios-app/docs/full-migration-task-tree.md` 是执行任务索引树。
- `ios-app/docs/architecture.md` 记录 iOS 原生架构原则。
- `ios-app/RedCodeIM.xcodeproj` 是当前 iOS App Xcode 工程。
- 后续实现阶段需要更新 `docs/reference/testing/README.md`，加入 `ios-app` 构建、单测、Simulator smoke、H5/API 联调入口。
- 每完成一个阶段，应沉淀实现经验到 `docs/solutions/`。

## Sources & References

- Origin plan: `docs/plans/2026-07-02-002-feat-ios-app-native-migration-plan.md`
- Flutter app: `app/lib/`
- Flutter tests: `app/test/`、`app/integration_test/`、`app/patrol_test/`
- H5 parity: `h5-app/README.md`、`h5-app/src/`
- Testing docs: `docs/reference/testing/README.md`
- iOS module docs: `ios-app/README.md`、`ios-app/docs/architecture.md`、`ios-app/docs/flutter-parity-scope.md`
