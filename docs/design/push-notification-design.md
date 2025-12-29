# Push 通知集成方案（FCM / APNs）

## 目标

- App 不在前台（或离线）时，仍能收到新消息提醒。
- 点击通知可直接打开对应会话（可选定位到 `message_id`）。
- 支持多设备、多账号切换、token 刷新。

## 需求（配置后台化，2025-12-28）

Push 平台（FCM/APNs/厂商推送等）的 **凭据与开关**需要由 **Admin 管理后台可视化配置**；若未配置任何平台凭据，则系统默认只提供“应用存活时的实时推送能力”（WebSocket），不发送系统通知。

详见需求文档：`docs/design/push-provider-config-requirements.md`。

## 当前实现（2025-12-29）

### Backend

- 数据表：`push_devices`（`backend/sql/migrations/20251228090000_create_push_devices.sql`）
- 数据表：`push_logs`（`backend/sql/migrations/20251228130000_create_push_logs.sql`）
- 接口：
  - `POST /push/devices`：注册/更新设备 token（需要登录）
  - `DELETE /push/devices/{device_id}`：注销当前账号在该设备上的 push（软禁用）
  - `GET /api/admin/push/logs`：查询 push 发送日志（管理员）
  - `POST /api/admin/push/logs/cleanup`：按保留天数清理 push 日志（管理员）
- 发送链路：
  - 在消息发送成功后异步触发 push（不阻塞发消息接口）
  - 后台队列/Worker：通过内置队列统一消费 push job，避免业务接口直接 `tokio::spawn` 大量 push 任务
  - 首版仅实现 **FCM HTTP v1**（通过 Admin 后台配置启用）
  - 默认 `PUSH_SKIP_IF_ONLINE=true`：基于跨节点在线态（Redis）判断“在线则跳过”以减少重复提醒
  - 基础失败重试：指数退避，最多 3 次；每次发送结果写入 `push_logs`
  - 无效 token 自动停用：当 FCM 返回 `UNREGISTERED`（或明显的 token 非法）时，会将对应 `push_devices` 记录置为 `is_active=false`（等待客户端重新注册）
  - 覆盖触发点：新消息、好友请求、群解散/踢人/转让群主等群管理事件

### Flutter

- 使用 `firebase_core` + `firebase_messaging` 获取 FCM token
- 登录成功后自动注册设备；登出时注销设备
- 处理通知点击（`getInitialMessage` / `onMessageOpenedApp`）→ 打开 `ChatDetailPageV2`
- 本地通知兜底：WebSocket 新消息且 App 非前台时弹本地通知（不依赖 Firebase 配置）

## 数据结构

### push_devices

核心字段：
- `user_id`：所属用户
- `device_id`：客户端生成的稳定设备 ID（用于 token 刷新/账号切换）
- `device_token`：FCM/APNs token
- `platform`：`android/ios/...`（TEXT）
- `channel`：`fcm/apns/...`（TEXT）
- `is_active`：是否启用（注销后为 `false`）
- `last_seen_at`：最近上报时间

### push_logs

核心字段：
- `push_id`：同一“通知事件”的追踪 ID（同一事件可能对多个设备发送）
- `user_id`/`device_id`：目标用户与设备
- `event_type`：`message/friend_request/group_event/...`
- `attempt`/`success`/`error`：发送次数、是否成功与错误信息

#### 运维查询建议

- 一次通知事件的全链路排查：用 `push_id` 过滤，即可看到同一事件对多个设备的发送结果与错误信息。
- 常用过滤维度：`event_type`、`success`、`provider/channel/platform`、时间范围、关键字（标题/正文/错误/用户名等）。

## 推送载荷约定

### FCM data 字段（用于点击跳转）

Backend 会附带以下 `data`：
- `push_id`: UUID（用于追踪）
- `type`: `"message" | "friend_request" | "group_event"`

`type=message`：
- `room_id`
- `message_id`
- `room_type`: `"private" | "group" | "favorite" | "public"`
- `sender_id`
- `sender_name`
- `chat_name`：用于客户端展示/导航（群聊为群名，私聊为对方昵称/用户名）

`type=friend_request`：
- `request_id`
- `requester_id`
- `requester_name`

`type=group_event`：
- `event`（例如：`kicked/dissolved/owner_transferred`）
- `room_id`
- `room_name`

> 说明：当前客户端导航主要依赖 `room_id`/`room_type`/`chat_name`/`message_id`。

## 配置与材料清单

## 概念补充：Firebase / Push capability

- Firebase（这里指 Firebase Cloud Messaging, FCM）：Android/iOS 的“系统通知/离线推送”入口。iOS 侧通常是 **FCM 转发到 APNs**，服务端只需对接 FCM HTTP v1。
- Push capability（iOS 工程能力开关）：Xcode 的 “Signing & Capabilities -> Push Notifications” 对应的能力声明，本质是给 App 打上 entitlements（例如 `aps-environment`），否则无法拿到 APNs token，也无法接收系统推送。

### Backend（FCM HTTP v1）

通过 Admin 后台配置（`系统设置 -> Push 通知`）：
- FCM：粘贴 Firebase Service Account JSON（服务端会加密落库）
- 全局开关：`push_enabled`、`push_skip_if_online`

服务端环境变量（见 `backend/.env.example`）：
- `DATA_ENCRYPTION_KEY=...`：用于加密存储 Push 平台敏感配置（必填，生产环境建议强随机）
- `PUSH_ENABLED=true` / `PUSH_SKIP_IF_ONLINE=true`：仅作为开发兜底（优先以后台配置为准）

性能/稳定性相关（可选）：
- `PUSH_HTTP_TIMEOUT_SECONDS=10`：FCM/OAuth 请求超时（秒）
- `PUSH_SEND_CONCURRENCY=50`：全局并发上限（限制同时进行的 FCM 请求数）
- `PUSH_DEVICE_SEND_CONCURRENCY=20`：单个事件内对多个设备发送的并发度
- `PUSH_JOB_QUEUE_CAPACITY=10000`：push job 队列容量
- `PUSH_JOB_CONCURRENCY=20`：push job worker 并发度

### Flutter（Android / iOS）

- Android：需要 Firebase 项目与 `google-services.json`
  - 由于仓库默认不携带该文件，`frontend/android/app/build.gradle.kts` 已做“存在才启用 google-services 插件”的降级处理
- iOS：
  - 需要 `GoogleService-Info.plist`
  - Push capability（仓库已提供 entitlements）：
    - Debug：`frontend/ios/Runner/RunnerDebug.entitlements`
    - Release/Profile：`frontend/ios/Runner/RunnerRelease.entitlements`
  - 并按 Firebase Messaging 文档配置 APNs（`.p8` / Key ID / Team ID）

### Desktop（Windows / macOS）

- 使用 Tauri 的系统通知插件：`@tauri-apps/plugin-notification`（由 Desktop 端在窗口不前台时触发系统通知）

## 工程配置步骤（不提交敏感文件）

### 1) 后端（Admin 后台配置）

1. 设置环境变量 `DATA_ENCRYPTION_KEY`（生产环境必须，建议强随机）。
2. 使用 Admin 后台：`系统设置 -> Push 通知`
   - 开启“离线推送总开关”
   - 配置并启用 FCM：粘贴 Firebase Service Account JSON
3. 可使用“测试发送”验证（建议优先填 `device_token`，其次 `user_id`）。

### 2) Android（Flutter）

1. Firebase 控制台新增 Android App（应用 ID 与 Flutter `applicationId` 一致）。
2. 下载 `google-services.json` 放入：`frontend/android/app/google-services.json`（仓库已忽略该文件，请勿提交）。
3. 运行 App 登录一次，客户端会自动注册设备（`POST /push/devices`）。

### 3) iOS（Flutter）

1. Firebase 控制台新增 iOS App（Bundle ID 与 Xcode 工程一致）。
2. 下载 `GoogleService-Info.plist` 放入：`frontend/ios/Runner/GoogleService-Info.plist`（仓库已忽略该文件，请勿提交），并确保加入 Runner target。
3. Xcode：开启 Push Notifications capability
   - 仓库已提供 entitlements：`frontend/ios/Runner/RunnerDebug.entitlements`、`frontend/ios/Runner/RunnerRelease.entitlements`
4. Apple Developer：创建 APNs Auth Key（`.p8`），在 Firebase Cloud Messaging 中配置（Key ID / Team ID / Bundle ID 对应）。
5. 运行 App 登录一次，客户端会自动注册设备（`POST /push/devices`）。

## 验证与排障

- 推荐验证顺序：
  1) 后台“测试发送” → 目标设备应出现系统通知  
  2) 发送真实消息 → 检查接收端是否收到通知（在线是否按策略跳过）
- 排障入口：
  - Admin：`运维管理 -> Push 日志`
  - 重点看 `success/error/push_id`；同一事件可用 `push_id` 追踪多设备投递结果。

## 降级策略说明（与产品需求对齐）

- 当未配置任何离线推送平台（或平台不可用）时：服务端不会发送系统通知；客户端仍可通过 **WebSocket 实时推送**收到消息。
- 对于“应用存活但不在前台”的场景：移动端会使用 **Local Notification** 在收到 WebSocket 新消息时弹出本地系统通知（不依赖 Firebase 配置）。

## 后续待完善

- APNs 直连（不经 FCM）或多通道抽象（当前仅 fcm）
- 更精细的通知过滤（例如：更丰富的 @ 语法、别名/备注匹配、避免歧义等）
- 通知样式与策略（如需：前台展示、聚合、badge、sound 等）
- iOS 工程材料与 capability（`GoogleService-Info.plist` / Push capability / APNs 配置等）

## 点击跳转策略（当前实现）

- `type=message`：打开对应会话（`room_id` 必填，`message_id` 可选用于定位）
- `type=friend_request`：打开“好友请求”页（移动端 `AddFriendPage(showRequestsFirst=true)`）
- `type=group_event`：默认按 `room_id` 打开会话（若被踢/解散导致无法进入，客户端会按业务逻辑提示）
