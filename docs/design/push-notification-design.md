# Push 通知集成方案（FCM / APNs）

## 目标

- App 不在前台（或离线）时，仍能收到新消息提醒。
- 点击通知可直接打开对应会话（可选定位到 `message_id`）。
- 支持多设备、多账号切换、token 刷新。

## 需求（配置后台化，2025-12-28）

Push 平台（FCM/APNs/厂商推送等）的 **凭据与开关**需要由 **Admin 管理后台可视化配置**；若未配置任何平台凭据，则系统默认只提供“应用存活时的实时推送能力”（WebSocket），不发送系统通知。

详见需求文档：`docs/design/push-provider-config-requirements.md`。

## 当前实现（2025-12-28）

### Backend

- 数据表：`push_devices`（`backend/sql/migrations/20251228090000_create_push_devices.sql`）
- 接口：
  - `POST /push/devices`：注册/更新设备 token（需要登录）
  - `DELETE /push/devices/{device_id}`：注销当前账号在该设备上的 push（软禁用）
- 发送链路：
  - 在消息发送成功后异步触发 push（不阻塞发消息接口）
  - 首版仅实现 **FCM HTTP v1**（通过 Admin 后台配置启用）
  - 默认 `PUSH_SKIP_IF_ONLINE=true`：若用户当前已建立 WebSocket 连接则跳过 push（减少重复提醒）

### Flutter

- 使用 `firebase_core` + `firebase_messaging` 获取 FCM token
- 登录成功后自动注册设备；登出时注销设备
- 处理通知点击（`getInitialMessage` / `onMessageOpenedApp`）→ 打开 `ChatDetailPageV2`

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

## 推送载荷约定

### FCM data 字段（用于点击跳转）

Backend 会附带以下 `data`：
- `type`: `"message"`
- `room_id`
- `message_id`
- `room_type`: `"private" | "group" | "favorite" | "public"`
- `sender_id`
- `sender_name`
- `chat_name`：用于客户端展示/导航（群聊为群名，私聊为对方昵称/用户名）

> 说明：当前客户端导航主要依赖 `room_id`/`room_type`/`chat_name`/`message_id`。

## 配置与材料清单

### Backend（FCM HTTP v1）

通过 Admin 后台配置（`系统设置 -> Push 通知`）：
- FCM：粘贴 Firebase Service Account JSON（服务端会加密落库）
- 全局开关：`push_enabled`、`push_skip_if_online`

服务端环境变量（见 `backend/.env.example`）：
- `DATA_ENCRYPTION_KEY=...`：用于加密存储 Push 平台敏感配置（必填，生产环境建议强随机）
- `PUSH_ENABLED=true` / `PUSH_SKIP_IF_ONLINE=true`：仅作为开发兜底（优先以后台配置为准）

### Flutter（Android / iOS）

- Android：需要 Firebase 项目与 `google-services.json`
  - 由于仓库默认不携带该文件，`frontend/android/app/build.gradle.kts` 已做“存在才启用 google-services 插件”的降级处理
- iOS：需要 `GoogleService-Info.plist`、开启 Push capability，并按 Firebase Messaging 文档配置 APNs

## 后续待完善

- APNs 直连（不经 FCM）或多通道抽象（当前仅 fcm）
- 更精细的通知过滤（`mentions_only` 的精准 @ 解析；当前为简化实现：content 含 `@` 即视为 mention）
- 推送发送结果落库（`push_logs` / `push_id`）与失败重试/退避
- 前台消息本地通知（`flutter_local_notifications`）
- 更多触发点：好友请求、群管理事件（被踢/解散/转让等）
