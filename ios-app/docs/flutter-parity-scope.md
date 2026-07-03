# ios-app Flutter 完整功能迁移范围

本文件定义 `ios-app` 的目标范围：完整迁移 Flutter `app/` 当前功能逻辑，并用原生 iOS 方式实现。

## 迁移边界

必须迁移：

- 用户可见功能流程。
- HTTP API 与 WebSocket 协议语义。
- 本地缓存、离线展示、失败重试、去重、未读数等状态语义。
- Flutter 现有测试覆盖到的核心行为。
- 视觉语言和交互节奏，允许用 iOS 原生控件重建。

不按原样迁移：

- Flutter Widget 树、Provider 写法、Dart service 结构。
- Flutter 热更新执行能力。
- Google/Apple 登录。
- Android 平台能力。
- 为 Flutter 兼容而存在、但 iOS 原生不需要的适配代码。

## 功能清单

### 启动、环境与认证

- Splash、启动态恢复、登录态判断。
- 环境配置：API base URL、WebSocket URL、测试/开发/发布配置。
- 邮箱注册、邮箱登录、重置密码。
- 用户协议/隐私协议提示。
- Token 安全存储、登出清理。

参考：

- `app/lib/features/startup/splash_page.dart`
- `app/lib/core/config/environment.dart`
- `app/lib/core/auth/`
- `app/lib/features/auth/`
- `app/lib/core/storage/token_storage.dart`

### App Shell、主题与公共组件

- 首页三栏/Tab：聊天、联系人、设置。
- 全局主题、颜色、间距、按钮、输入框、弹窗、Picker、Badge、Skeleton。
- 原生 iOS 允许用 TabView、NavigationStack、sheet、alert、toolbar 重建。

参考：

- `app/lib/features/home/home_shell_page.dart`
- `app/lib/core/theme/`
- `app/lib/core/constants/`
- `app/lib/core/widgets/`

### 聊天核心

- 会话列表、本地会话缓存、未读数、置顶/免打扰展示。
- 聊天详情、历史消息、本地消息缓存、pending 消息、失败重试。
- 文本消息、引用消息、已读、删除、置顶消息、反应/reaction。
- WebSocket 连接、认证、订阅、重连、事件去重。
- 消息搜索。

参考：

- `app/lib/features/chat/chat_list_page.dart`
- `app/lib/features/chat/chat_detail_page_v2.dart`
- `app/lib/features/chat/providers/chat_provider.dart`
- `app/lib/core/services/message_service.dart`
- `app/lib/core/services/websocket_service.dart`
- `app/lib/core/services/room_subscription_manager.dart`
- `app/lib/core/storage/message_storage.dart`
- `app/lib/core/storage/message_search_storage.dart`

### 联系人与好友

- 联系人列表、本地好友缓存。
- 搜索用户、发送好友申请、处理好友请求。
- 联系人详情、打开私聊。

参考：

- `app/lib/features/contacts/`
- `app/lib/core/services/friend_service.dart`
- `app/lib/core/services/friend_store.dart`
- `app/lib/core/storage/friend_storage.dart`

### 群聊与群管理

- 选择好友建群。
- 群设置、群成员、改名、免打扰、置顶。
- 群管理员、禁言、入群申请、群规则、操作日志。
- 退出/解散群聊。

参考：

- `app/lib/features/chat/create_group_page.dart`
- `app/lib/features/chat/group_settings_page.dart`
- `app/lib/features/chat/group_admin_management_page.dart`
- `app/lib/features/chat/group_mute_management_page.dart`
- `app/lib/features/chat/group_join_requests_page.dart`
- `app/lib/features/chat/group_rules_page.dart`
- `app/lib/features/chat/group_operation_logs_page.dart`
- `app/lib/core/services/room_service.dart`

### 媒体、附件、头像与语音

- 图片/视频/文件选择与预览。
- 附件上传策略、直传、hash、MIME、缓存。
- 用户头像、群头像加载与缓存。
- 语音录制、发送、播放、权限处理。
- 视频预览。

参考：

- `app/lib/core/network/direct_upload.dart`
- `app/lib/core/services/upload_policy_service.dart`
- `app/lib/core/services/user_avatar_service.dart`
- `app/lib/core/services/room_avatar_service.dart`
- `app/lib/core/services/voice_service.dart`
- `app/lib/core/storage/attachment_cache.dart`
- `app/lib/core/storage/attachment_url_cache.dart`
- `app/lib/core/storage/avatar_cache.dart`
- `app/lib/features/chat/video_preview_page.dart`
- `app/lib/features/chat/widgets/voice_message_widget.dart`

### 表情、贴纸与聊天扩展

- 内置 emoji。
- 表情包、表情项、贴纸管理。
- 表情资源缓存。

参考：

- `app/lib/features/chat/constants/emoji_list.dart`
- `app/lib/features/emoji/models/emoji_pack_models.dart`
- `app/lib/core/services/emoji_pack_service.dart`
- `app/lib/core/services/emoji_item_service.dart`
- `app/lib/core/storage/emoji_cache.dart`
- `app/lib/features/settings/sticker_management_page.dart`

### 设置、账号、文档与反馈

- 设置首页。
- 个人资料、账号安全、修改密码。
- 聊天背景、聊天设置。
- 用户协议、隐私政策、关于。
- 反馈提交。

参考：

- `app/lib/features/settings/`
- `app/lib/core/services/settings_service.dart`
- `app/lib/core/services/feedback_service.dart`
- `app/lib/core/services/user_service.dart`

### App 配置、版本与更新

- App 配置拉取与本地缓存。
- 版本检查。
- Flutter 热更新逻辑在 iOS 原生侧不按原样迁移。
- iOS 替代方案：远程配置、资源配置、版本提示、App Store/企业分发更新提示。

参考：

- `app/lib/core/services/app_config_service.dart`
- `app/lib/core/storage/app_config_storage.dart`
- `app/lib/core/services/version_service.dart`
- `app/lib/core/update/`

### Push 与本地通知

- 本地通知展示。
- Push token 注册、通知点击进入目标会话。
- iOS 优先采用 APNs；是否兼容 Firebase Messaging 由后端能力决定，不作为默认依赖。

参考：

- `app/lib/core/services/local_notification_service.dart`
- `app/lib/core/services/push_service.dart`
- `app/lib/core/services/push_navigation.dart`

## 原生 iOS 映射

- Flutter `Provider` / store -> Swift ViewModel + Observable state。
- Flutter service -> Swift Repository / API client / domain service。
- Flutter `sqflite` 消息缓存 -> SwiftData 主缓存；消息搜索可加 SQLite FTS5/GRDB 索引。
- Flutter `shared_preferences` -> UserDefaults，仅用于非敏感偏好。
- Flutter secure token 语义 -> Keychain。
- Flutter 文件缓存 -> FileManager + Caches directory。
- Flutter image/file picker -> PhotosUI / DocumentPicker / Transferable。
- Flutter audio record/playback -> AVFoundation。
- Flutter local notifications -> UserNotifications。
- Flutter push -> APNs 优先。
- Flutter URL launcher -> `UIApplication.open` / SwiftUI openURL。

## 阶段目标

### Phase 0：模块与方案

- 已创建 `ios-app/` 模块目录。
- 已建立原生 iOS 架构说明。
- 输出完整 Flutter parity 范围。

### Phase 1：原生基础设施

- Xcode 工程或生成工具选型。
- SPM local packages。
- 环境配置、依赖注入、日志、错误模型。
- SwiftUI App Shell、Tab、NavigationStack。
- XCTest/XCUITest 基础测试入口。

### Phase 2：认证与启动闭环

- Splash、邮箱注册、邮箱登录、重置密码。
- Token Keychain、启动恢复、登出清理。
- 协议提示与公开文档展示。

### Phase 3：网络、WebSocket 与本地数据底座

- HTTP API client。
- WebSocket client、认证、订阅、重连。
- SwiftData 会话/消息/联系人缓存。
- 文件、头像、附件、表情缓存。
- 消息搜索索引策略。

### Phase 4：聊天核心全量

- 会话列表。
- 聊天详情。
- 文本消息发送、pending、失败重试。
- 已读、删除、置顶、引用、reaction。
- 未读数、置顶/免打扰状态。

### Phase 5：联系人、好友与私聊

- 联系人列表与缓存。
- 用户搜索、好友申请、处理请求。
- 联系人详情和打开私聊。

### Phase 6：群聊全量管理

- 建群、群设置、成员管理。
- 管理员、禁言、入群申请。
- 群规则、操作日志、退出/解散。

### Phase 7：媒体、附件、语音与头像

- 图片、视频、文件选择与预览。
- 上传策略与直传。
- 头像上传/展示/缓存。
- 语音录制、发送、播放。
- 权限和失败路径。

### Phase 8：表情、贴纸、搜索与聊天扩展

- emoji、表情包、贴纸管理。
- 表情资源缓存。
- 消息搜索页面与本地索引。
- 聊天背景和聊天设置。

### Phase 9：设置、配置、版本与更新

- 设置完整页面。
- 个人资料、账号安全、反馈。
- App 配置、版本检查。
- 原生 iOS 更新提示替代 Flutter 热更新执行能力。

### Phase 10：Push、本地通知与深链

- 本地通知。
- APNs token 注册。
- 通知点击进入会话/消息。
- 前后台状态切换和未读同步。

### Phase 11：全量 parity 验收与切换准备

- 与 Flutter/H5/API 做功能对照验收。
- 本机 iOS Simulator smoke、UI test 与 H5/API 联调验收。
- 后端 Compose 环境联调。
- 形成缺口清单。
- 满足全量 parity 后，再讨论是否下线 Flutter iOS。

## 测试设备策略

- 默认测试设备：本机 iOS Simulator。
- 默认联调网络：Simulator 使用 `127.0.0.1` 访问本机 Compose API/WS。
- 不默认使用 iPhone 真机；真机只用于 APNs、相机、麦克风、后台通知、签名发布等 Simulator 无法完整验证的能力。
- 不套用 Flutter `app` 的 Pixel 8 Pro 优先规则。
