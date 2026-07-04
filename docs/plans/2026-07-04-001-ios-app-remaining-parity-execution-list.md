# ios-app 剩余 Flutter parity 结构化执行清单

本文档把 `ios-app/docs/full-migration-task-tree.md` 中未完成项目整理为执行顺序清单。原则是先补齐可测试的数据/API/缓存底座，再补 UI，再做 H5/API/iOS 联调，最后做媒体、通知和切换验收。

## 执行策略

- 主线顺序：IOS-05 -> IOS-06 -> IOS-07 -> IOS-08 -> IOS-09 -> IOS-10 -> IOS-11。
- 收尾项穿插：IOS-02/IOS-04 的 UI test 与登出清理在相关底座可用后回补。
- 每个阶段至少包含：
  - Networking DTO/API client
  - Storage cache / local state
  - Features controller / SwiftUI view
  - SwiftPM 单测
  - H5/API/iOS live smoke 或明确的阻塞说明
- 本机验收默认使用 iOS Simulator；API/WS 使用 `127.0.0.1`。
- 后端依赖统一由 Docker Compose 提供；对象存储只走 mock。

## P0 阶段：联系人、好友与私聊

### IOS-05-A 数据/API/缓存底座

- [x] IOS-05-A1 建立 `FriendAPIEndpoint`：
  - `/users/search`
  - `/friends`
  - `/friends/requests`
  - `/friends/requests/{requestId}/respond`
  - `/friends/{friendUserId}/chat`
  - `/friends/{friendUserId}`
- [x] IOS-05-A2 建立好友域模型：
  - `FriendInfo`
  - `FriendRequestInfo`
  - `FriendRequestStatus`
  - `FriendRequestAction`
  - `EnsurePrivateChatResult`
- [x] IOS-05-A3 建立 `FriendAPIClient`：
  - 搜索用户
  - 拉取好友列表
  - 发送好友申请
  - 拉取好友申请
  - 接受/拒绝好友申请
  - 打开/确保私聊
  - 删除好友
- [x] IOS-05-A4 建立 `ContactCacheStore`：
  - SwiftData 读取联系人
  - SwiftData 保存联系人
  - upsert / remove / clear
  - displayName 排序
- [x] IOS-05-A5 增加 Networking/Storage 单测。

验收：

- [x] iOS 能 decode 后端好友/请求/私聊响应。
- [x] 联系人缓存支持缓存优先展示。
- [x] 单测覆盖 endpoint、payload、decode、缓存排序和删除。

当前结果：

- 已补 `FriendAPIEndpoint`、`FriendModels`、`FriendAPIClient`、`SwiftDataContactCacheStore`。
- 已补 `FriendAPIClientTests` 与 `StorageTests` 联系人缓存覆盖。
- 已通过 `swift test`、`make ios-app.check`、`git diff --check`。

### IOS-05-B 控制器与 UI

- [x] IOS-05-B1 建立 `ContactsController`：
  - 缓存优先加载
  - 远端刷新
  - 好友请求 badge
  - 接受请求后更新本地好友列表
- [x] IOS-05-B2 建立 `AddFriendController`：
  - 用户搜索
  - 发送好友申请
  - 请求列表与处理
- [x] IOS-05-B3 建立联系人 SwiftUI：
  - 联系人列表
  - 新朋友入口和 badge
  - 用户搜索
  - 好友请求处理
  - 联系人详情
  - 打开私聊
- [x] IOS-05-B4 接入 App shell contacts tab。
- [x] IOS-05-B5 增加 Features 单测。

验收：

- iOS 可以搜索 H5 创建的账号并发送好友申请。
- H5/iOS 好友状态双向可见。
- 联系人详情可打开私聊，并且会话列表状态一致。

当前结果：

- 已补 `ContactsController`、`AddFriendController`、`ContactsHomeView`、联系人详情、新朋友页面。
- 已接入 iOS App contacts tab，支持缓存优先加载、远端刷新、好友请求 badge、搜索、发送申请、接受/拒绝、删除好友、打开私聊。
- 已补 `ContactsControllerTests`，并通过 `swift test`、`make ios-app.check`、`git diff --check`。
- H5/iOS 好友互通 live smoke 仍在 IOS-05-C 执行；当前已知 H5 旧拒绝动作仍为 `reject`，IOS-05-C 前需改为后端合同 `decline`。

### IOS-05-C 联调

- [x] IOS-05-C1 增加 iOS 好友 live smoke。
- [x] IOS-05-C2 增加 H5/iOS 好友流程互通 smoke。
- [x] IOS-05-C3 更新 `ios-app/docs/full-migration-task-tree.md` IOS-05 状态。

当前结果：

- 已把 H5 好友拒绝动作从旧 `reject` 对齐为后端合同 `decline`。
- 已补 `FriendAPIClientLiveTests` 并接入 `make ios-app.test.live`。
- 已通过 `make h5-app.test.live` 和 `make ios-app.test.live`，覆盖 H5/iOS 好友搜索、申请、接受、好友列表、打开私聊和私聊消息可见。

## P1 阶段：群聊和群管理

### IOS-06-A 群基础与设置

- [x] IOS-06-A1 选择联系人建群。
- [x] IOS-06-A2 群设置首页。
- [x] IOS-06-A3 群成员列表。
- [x] IOS-06-A4 群改名。
- [x] IOS-06-A5 群置顶和免打扰。
- [x] IOS-06-A6 退出/解散群聊。

### IOS-06-B 群权限与管理

- [x] IOS-06-B1 管理员管理。
- [x] IOS-06-B2 禁言管理。
- [x] IOS-06-B3 入群申请。
- [x] IOS-06-B4 群规则。
- [x] IOS-06-B5 群操作日志。
- [x] IOS-06-B6 群内置顶消息。

### IOS-06-C 测试与联调

- [x] IOS-06-C1 群权限单测。
- [x] IOS-06-C2 H5/iOS 群管理 smoke。

当前结果：

- 已扩展 `RoomAPIEndpoint` / `RoomAPIClient` / `RoomModels`，覆盖群创建、列表、详情、成员、设置、置顶、免打扰、退出/解散、管理员、禁言、入群申请、群规则、操作日志和群详情接口。
- 已新增 `SwiftDataGroupCacheStore`，支持群缓存 load/save/upsert/remove/clear。
- 已新增 `GroupManagementController`、`CreateGroupView`、`GroupSettingsView` 和群管理子页面；联系人页可发起群聊，聊天详情可进入群设置。
- 已补 `RoomAPIClientTests`、`GroupManagementControllerTests`、`StorageTests` 群缓存覆盖，并新增 `RoomAPIClientLiveTests` 接入 `make ios-app.test.live`。
- 已通过 `swift test`、`make ios-app.check`、`make h5-app.test.live` 与 `make ios-app.test.live`。

## P2 阶段：媒体、附件、头像、语音和视频

### IOS-07-A 选择、上传和缓存

- [x] IOS-07-A1 PhotosUI 图片/视频选择。
- [x] IOS-07-A2 DocumentPicker 文件选择。
- [x] IOS-07-A3 上传策略获取。
- [x] IOS-07-A4 对象存储 mock 直传。
- [x] IOS-07-A5 文件 hash 与 MIME 识别。
- [x] IOS-07-A6 附件缓存。

### IOS-07-B 预览、头像和语音

- [x] IOS-07-B1 图片/视频/文件预览。
- [x] IOS-07-B2 用户头像展示与缓存。
- [x] IOS-07-B3 群头像展示与缓存。
- [x] IOS-07-B4 头像上传。
- [x] IOS-07-B5 AVFoundation 语音录制。
- [x] IOS-07-B6 语音消息发送。
- [x] IOS-07-B7 语音播放。
- [x] IOS-07-B8 权限拒绝和恢复路径。

### IOS-07-C 测试与联调

- [x] IOS-07-C1 对象存储 mock 上传/下载 smoke。
- [x] IOS-07-C2 H5/iOS 媒体消息互通 smoke。

当前结果：

- 已新增 iOS 媒体网络层 `MediaAPIEndpoint` / `MediaModels` / `MediaAPIClient`，覆盖用户头像、群头像、消息附件上传签名、commit、download URL 与 direct upload/download。
- 已新增 `MediaUploadPreparer`，支持 SHA256、MIME/UTType 推断、文件名规范化和图片/视频/音频/文件类型推断。
- 已接入聊天详情 PhotosUI、文件选择、待发送附件 strip、富媒体 pending/failed/resend、上传成功后发送 rich message，并把附件落到 `AttachmentFileCache`。
- 已接入用户/群头像 object key 下载缓存展示，语音录制、语音发送、语音播放与麦克风权限拒绝提示。
- 已把 dev Compose 接入 `external-mock`，本地媒体 smoke 不访问线上 B2；API 生成的 presigned URL 会通过 `REDCODE_IM_B2_PRESIGN_PUBLIC_ENDPOINT` 改写为 Simulator/H5 可访问的 `127.0.0.1`。
- 已补 `MediaAPIClientTests`、`MediaAPIClientLiveTests`、`ChatDetailControllerTests`、`ChatAPIClientTests` 和 `StorageTests` 媒体覆盖。
- 已通过 `RED_CODE_IOS_LIVE_MEDIA_SMOKE=1 swift test --filter MediaAPIClientLiveTests`，覆盖 Compose mock 对象存储上传、commit、富媒体发送和下载校验。
- H5 已补 `messageService.sendRichMessage`，并在 `ios-h5-chat-interop-smoke` 中覆盖 H5 直传 mock 对象存储、commit、发送富媒体消息，以及 iOS-compatible HTTP 读取附件。

## P3 阶段：表情、贴纸、搜索和聊天扩展

- [x] IOS-08-A1 内置 emoji。
- [x] IOS-08-A2 表情包列表。
- [x] IOS-08-A3 表情项加载。
- [x] IOS-08-A4 表情资源缓存。
- [x] IOS-08-A5 贴纸管理。
- [x] IOS-08-B1 消息搜索索引写入。
- [x] IOS-08-B2 消息搜索页面。
- [x] IOS-08-B3 聊天背景。
- [x] IOS-08-B4 聊天设置。
- [x] IOS-08-C1 搜索与表情缓存测试。

当前结果：

- 已新增 iOS 表情网络层 `EmojiAPIEndpoint` / `EmojiModels` / `EmojiAPIClient`，覆盖我的表情、可用表情、搜索、添加/移除、套装添加、套装表情和表情下载 URL。
- 聊天输入区已接入内置 emoji 面板；已登录用户打开面板时会加载“我的表情”，点选贴纸后先下载并缓存表情图，再复用现有消息图片上传链路发送为图片消息。
- 已新增 `SwiftDataMessageSearchStore`，从本地消息缓存重建搜索索引，支持关键词、房间、消息类型过滤、分页和删除消息过滤。
- 已新增 `MessageSearchView`，会话列表和聊天详情均可进入搜索页，优先查本地缓存并合并服务端 `/messages/search` 结果。
- 已新增 `UserDefaultsChatPreferencesStore`、聊天背景设置、聊天设置页、表情管理页，以及媒体/头像/表情缓存清理和本地聊天记录清理入口。
- 已修复 SwiftData 消息缓存中删除状态字段与模型运行态语义冲突的问题，将持久化字段改为 `messageIsDeleted`。
- 已补 `EmojiAPIClientTests`、`ChatAPIClientTests` 搜索覆盖、`StorageTests` 搜索/偏好覆盖和 `ChatExtensionControllerTests`。
- 已通过 `swift test`、`make ios-app.check`、`make h5-app.test.live` 和 `make ios-app.test.live`。

## P4 阶段：设置、账号、文档、反馈、配置和版本

- [x] IOS-09-A1 设置首页。
- [x] IOS-09-A2 个人资料。
- [x] IOS-09-A3 昵称更新。
- [x] IOS-09-A4 账号安全。
- [x] IOS-09-A5 修改密码。
- [x] IOS-09-A6 用户协议和隐私政策。
- [x] IOS-09-A7 关于页面。
- [x] IOS-09-B1 反馈提交。
- [x] IOS-09-B2 App 配置拉取与缓存。
- [x] IOS-09-B3 版本检查。
- [x] IOS-09-B4 iOS 原生更新提示。
- [x] IOS-09-C1 设置域测试。

当前结果：

- 已补 `SettingsAPIEndpoint`、`SettingsModels`、`SettingsAPIClient`，覆盖 `/settings/general`、`/settings/app-name`、用户协议、隐私协议、`/feedbacks`、`/versions/latest` 和版本下载 URL。
- 已扩展 `AuthAPIClient` / `AuthController` 支持 `/users/me` 昵称更新，并写回本地 session。
- 已新增 `SwiftDataAppConfigStore`，使用现有 `RedCodeAppConfigRecord` 缓存通用设置与协议文档。
- 设置 Tab 已切换为原生 SwiftUI 设置首页，包含个人资料、账号安全、聊天设置、用户协议、隐私协议、关于、反馈、版本检查和 iOS 原生更新提示。
- 登出入口已清理 WebSocket、聊天/消息/联系人/群/配置缓存、媒体/头像/表情缓存和聊天背景偏好。
- 已补 `SettingsAPIClientTests`、`SettingsControllerTests`、`StorageTests` 配置缓存覆盖，并扩展 Auth 相关测试。
- 已通过 `swift test`。

## P5 阶段：Push、本地通知和通知导航

- [x] IOS-10-A1 本地通知权限请求。
- [x] IOS-10-A2 本地通知展示。
- [x] IOS-10-A3 APNs token 注册。
- [x] IOS-10-A4 token 上报后端。
- [x] IOS-10-A5 前台通知处理。
- [x] IOS-10-A6 后台通知点击进入会话。
- [x] IOS-10-A7 冷启动通知导航。
- [x] IOS-10-A8 登出后通知态清理。
- [x] IOS-10-B1 如后端只支持 FCM，设计兼容桥接。
- [ ] IOS-10-C1 iPhone 真机验收。

当前结果：

- 已新增 Push 网络层：`PushAPIEndpoint`、`PushModels`、`PushAPIClient`，覆盖 `POST /push/devices` 与 `DELETE /push/devices/{device_id}`。
- 已新增 `UserDefaultsPushDeviceIdentityStore`，稳定保存 iOS device id、已注册 token、channel 与更新时间。
- 已新增 `PushController`、`LocalNotificationScheduler`、`NotificationNavigationController` 与通知 payload/destination 映射。
- WebSocket 新消息在 App 非前台且非自己消息时触发本地通知兜底；前台保持静默。
- SwiftUI App 已接入通知权限、APNs token 注册回调、remote notification payload 处理、Tab 导航切换、聊天通知深链与登出通知态清理。
- 后端已补 APNs provider 配置、APNs token 投递、Push 日志和 `external-mock` APNs 测试链路；iOS 原生 APNs token 会按 `/push/devices` 的 `apns` channel 注册，服务端离线通知会按设备 channel 分发到 FCM/APNs。
- iOS App 已支持通过 Info.plist 或启动环境读取真机可访问的 `REDCODE_API_BASE_URL` / `REDCODE_WS_URL`，并新增 `make ios-app.apns.preflight` 做 iPhone/APNs 真机验收前置检查；`make ios-app.smoke.device` 会串联预检、真机构建、安装和启动。
- 真机 APNs token 获取、Apple 平台真实投递和点击系统通知唤醒仍放入 IOS-10-C1 / IOS-11-A6；当前 `xcrun devicectl list devices` 未检测到 iPhone 真机。
- 已补 `PushAPIClientTests`、`PushControllerTests`、`StorageTests` Push identity 覆盖。
- 已通过 `swift test`。

## P6 阶段：全量验收与切换准备

- [x] IOS-11-A1 Flutter vs iOS 功能对照清单。
- [x] IOS-11-A2 H5/API/iOS 联调脚本。
- [x] IOS-11-A3 本机 iOS Simulator smoke。
- [x] IOS-11-A4 UI test 回归。
- [x] IOS-11-A5 媒体 mock 回归。
- [ ] IOS-11-A6 通知真机补验。
- [x] IOS-11-B1 P0/P1 缺口清单。
- [x] IOS-11-B2 Flutter iOS 下线条件。
- [x] IOS-11-B3 回滚策略。
- [x] IOS-11-B4 更新 `docs/reference/testing/README.md`。

当前结果：

- 已新增 `make ios-app.test.interop`，串联 `h5-app.test.live` 与 `ios-app.test.live`。
- 已通过 `make ios-app.test.interop`，覆盖 H5 live smoke、H5/iOS 富媒体互通与 iOS 认证、WebSocket、聊天、好友、群、媒体 mock live smoke。
- 已通过 `make ios-app.smoke.simulator`，本机 `iPhone 17 Pro` Simulator 可构建、安装、启动。
- 已通过 `make ios-app.check` 与 `cd ios-app && swift test`。
- 已通过 `make ios-app.ui-test`，覆盖认证协议门禁/登录和聊天详情发送 smoke。
- 已新增 `docs/reports/2026-07-04-ios-app-parity-cutover-readiness.md`，记录 Flutter vs iOS 对照、P0/P1 缺口、下线条件和回滚策略。
- 当前本机已具备可运行 XCUITest 的 Simulator runtime；若后续 Xcode SDK 升级导致 runtime 不匹配，按测试文档安装对应 runtime 后重跑。
- IOS-11-A6 仍需要 iPhone 真机与 Apple APNs 平台凭据；API mock 已覆盖 APNs/FCM 投递，Simulator/单测已覆盖本地通知调度、payload 导航和登出通知态清理。
- 真机补验前先运行 `IOS_APP_API_BASE_URL=http://<LAN_IP>:8010 IOS_APP_WS_URL=ws://<LAN_IP>:8010/ws IOS_APNS_PROVIDER_CONFIGURED=1 make ios-app.apns.preflight`，确保未误用 `127.0.0.1` 且 API 对 iPhone 可达；设备签名可用后再运行 `IOS_APP_DEVELOPMENT_TEAM=<Apple Team ID> ... make ios-app.smoke.device` 完成真机安装启动。

## 横向收尾任务

- [x] X-01 IOS-02.05 重置密码。
- [x] X-02 IOS-02.06 用户协议/隐私协议提示。
- [x] X-03 IOS-02.09 登出清理 Token、WS、内存态、本地敏感缓存。
- [x] X-04 IOS-02.11 认证 UI test。
- [x] X-05 IOS-04.17 聊天 UI test。

说明：

- X-04 / X-05 已通过 `make ios-app.ui-test`；认证用例使用 mock fixture 验证未同意协议时禁止登录、已同意协议后账号密码登录进入聊天页，聊天用例使用本机 fixture 验证会话详情和文本发送。
- X-01 已接入认证重置密码 API：`POST /auth/password/reset`，当前 iOS 设置页提供“验证码重置密码”入口，测试阶段可使用后台通用验证码，不依赖真实邮箱。
- X-02 已在登录/注册页增加用户协议/隐私协议勾选，未勾选时禁止登录或注册；协议内容来自后端公开配置。
- X-03 已在 IOS-09 设置域收口并由 IOS-10 补齐通知态：退出登录会清理 Token、WS、聊天/消息/联系人/群/配置缓存、媒体/头像/表情缓存、聊天背景偏好和当前用户通知注册态。
