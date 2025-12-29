# RedCode IM - 待完成任务清单

## 🔴 高优先级 (影响核心功能)

### 1. 后端 - 管理员密码加密 (backend)
**位置**: `backend/src/auth/mod.rs`, `backend/src/database/user_store.rs`, `backend/src/handlers/admin.rs`
```rust
// 当前实现: 统一使用 bcrypt 进行密码哈希与校验
```
**影响**: 管理员与普通用户密码已可正常创建与验证
**状态**: ✅ 已完成
**优先级**: 🔴 高（已处理）
**实际方案**:
- 已统一使用 `bcrypt 0.16` 作为密码哈希方案
- `argon2` 依赖与 `middleware::password_security` 仅作为备用实现存在，未在生产路径中使用
- 后续如无 Argon2 需求，可视情况移除相关依赖与辅助模块

---

### 2. 后端 - 文件上传 multipart 处理
**位置**: 设计变更
```rust
// 原计划: 在后端实现接收 multipart/form-data 的头像/文件上传
// 当前方案: 统一采用对象存储(COS/S3 等)直传,后端仅负责签名与提交确认
```
**影响**: 头像与聊天文件上传路径已统一为直传方案
**状态**: ✅ 已通过架构调整完成 (不再实现后端 multipart)
**优先级**: 🔴 高（已处理）
**实际方案**:
- 用户头像: 使用 `generate_avatar_direct_upload`+`commit_avatar_upload` 完成直传与落库
- 存储层: 已实现腾讯云 COS 等对象存储适配,支持签名上传与下载 URL 生成
- 后端不再接收通用 multipart/form-data 文件流,仅保留少量管理端场景所需的专用接口

---

### 3. 前端 - WebSocket 事件业务逻辑 (desktop)
**位置**: `desktop/src/utils/websocket.ts`, `desktop/src/App.vue`

#### 3.1 群聊创建逻辑
- ✅ 后端通过 `ServerEvent::roomCreated` / `ServerPush::RoomCreated` 推送房间创建事件
- ✅ Desktop 端在 `websocket.ts` 中处理 `roomcreated` / `room_created`，刷新聊天列表
- ✅ `Chat.vue` 中已正确响应房间创建事件更新 UI

#### 3.2 群聊删除逻辑
- ✅ 后端通过 `ServerEvent::groupDissolved` 推送解散事件
- ✅ Desktop 端在 `websocket.ts` / `App.vue` 中处理 `websocket-delete-group`，关闭当前会话并提示

#### 3.3 删除好友逻辑
- ✅ 后端: `DELETE /friends/{friend_user_id}` 已实现删除好友及 WebSocket 推送 (`FriendshipDeleted`)
- ✅ Desktop: `websocket.ts` 中处理 `friendship_deleted`，派发 `websocket-delete-friend` / `websocket-friend-change` 事件，刷新联系人和聊天列表；`Contact.vue` 已接入删除好友按钮并调用 `FriendApi.deleteFriend`
- ✅ Flutter: `WebSocketService` 中 `_handleFriendshipDeleted` 已接入，`FriendStore` 会移除对应好友

#### 3.4 好友状态变更逻辑（头像 / 昵称等）
- ✅ 后端: `ServerPush::FriendProfileUpdated` 已在头像更新等场景推送
- ✅ Desktop: `websocket.ts` 中处理 `friend_profile_updated` / `friend.updated`，触发 `websocket-friend-change` 并刷新联系人列表
- ✅ Flutter: `_handleFriendProfileUpdated` 更新 `FriendStore` 中好友资料

**影响**: 好友相关的 WebSocket 事件（删除好友、好友资料变更）已串联 Desktop + Flutter，多端状态一致
**状态**: ✅ 已完成（好友相关部分）；群聊创建/删除事件已接入基础逻辑（仍可按产品需求做体验增强）
**优先级**: 🔴 高（已处理好友链路，群聊部分按后续规划继续迭代）

---

## 🟠 中优先级 (功能完善)

### 4. 前端 - 群聊管理对话框 (desktop)
**位置**: `desktop/src/views/Chat.vue`

#### 4.1 添加成员对话框
- UI: `GroupSettingsDrawer.vue` 触发 `@add-member` 事件，`Chat.vue::handleAddMember` 加载可选联系人并弹出 `AddGroupMemberDialog`
- 逻辑: `handleConfirmAddExistingGroupMembers` 调用 `MessageApi.addGroupMembers({ roomId, userIds })`，成功后刷新群成员并提示

#### 4.2 删除成员对话框
- UI: `GroupSettingsDrawer.vue` 触发 `@remove-member` 事件，`Chat.vue::handleRemoveMember` 打开 `RemoveGroupMemberDialog`
- 逻辑: `handleConfirmRemoveMembers` 使用 `Promise.allSettled` 批量调用 `MessageApi.removeGroupMember({ roomId, userId })`，统计成功/失败并刷新群成员

#### 4.3 举报功能
- UI: `GroupSettingsDrawer.vue` 触发 `@report-group` 事件（群聊/单聊共用），`Chat.vue::handleReportGroup` 打开 `ReportDialog`
- 逻辑: `handleConfirmReport` 要求“内容 + 至少 1 张截图”必填；截图走 `POST /reports/attachments/signature` 直传 + `POST /reports/attachments/commit`，最后调用 `POST /reports` 提交举报（`target_type=room/user`）

#### 4.4 其他群管理能力
- 退出群聊: `handleLeaveGroup` 调用 `MessageApi.leaveGroup` 并从聊天列表移除当前群
- 全体禁言: `handleToggleGlobalMute` 调用 `GroupApi.updateGlobalMute` 并更新本地 `groupSettings`
- 转让群主: `confirmTransferOwner` 调用 `GroupApi.transferGroupOwner`，成功后刷新群详情与设置
- 解散群聊: `confirmDissolveGroup` 调用 `GroupApi.dissolveGroup`，清空当前会话并刷新聊天列表

**影响**: 桌面端群聊管理（添加/删除成员、举报、禁言、转让/解散、退出等）已完整串联后端接口
**状态**: ✅ 已完成（后续仅做体验与文案级优化）
**优先级**: 🟠 中（已处理）

---

### 5. 前端 (Flutter) - 聊天功能 (frontend)
**位置**: `frontend/lib/features/chat/`

#### 5.1 删除消息 (chat_provider.dart:327)
```dart
// UI: ChatDetailPageV2._confirmDeleteMessage
await _chatProvider.deleteMessage(message);
```

#### 5.2 更新未读数 (chat_provider.dart:347)
```dart
// ChatProvider._syncReadState
await _messageService.markMessagesAsRead(roomId, latestIncoming.id);
```

#### 5.3 更新置顶状态 (chat_provider.dart:358)
```dart
// ChatProvider.pinMessage / unpinMessage
await _messageService.pinMessage(message.roomId, message.id);
await _messageService.unpinMessage(message.roomId, message.id);
```

#### 5.4 清空聊天记录 (chat_provider.dart:369)
```dart
// ChatProvider.clearChatMessages(roomId)
// -> 清空单个房间本地缓存，群聊设置页在调用前先请求
//    DELETE /rooms/{room_id}/messages 再同步本地状态
```

#### 5.5 语音功能 (chat_detail_page_v2.dart:826)
```dart
// ChatDetailPageV2._handleVoiceRecordingComplete
await _chatProvider.sendVoiceMessage(...);
```

**影响**: Flutter 移动端聊天已具备删除消息、已读同步、消息/会话置顶、语音消息和单群清空聊天能力
**状态**: ✅ 已完成（后续可按需要补充更细粒度的测试）
**优先级**: 🟠 中（已处理）

---

### 6. 消息编辑 / Reactions / Typing（backend + desktop + frontend）
**目标**: 桌面端与移动端能力对齐，实现"消息编辑 / 消息反应（reactions）/ 正在输入（typing）"并通过 WebSocket 保障多端实时一致。

#### 6.1 消息编辑（edit）✅
- **完成情况**:
  - ✅ 后端：新增 `PATCH /rooms/{room_id}/messages/{message_id}` 接口，支持编辑消息内容
  - ✅ 数据库：新增 `messages.edited_at` 字段（迁移文件：`20251227021700_add_message_edited_at.sql`）
  - ✅ WebSocket：扩展 `MessageUpdatePayload` 支持 `update_type=edited`，包含 `edited_at` 和 `content` 字段
  - ✅ Desktop：右键菜单新增"编辑"选项，实现编辑对话框和 API 调用
  - ✅ Flutter：更新 `Message` 模型添加 `isEdited` 和 `editedAt` 字段，添加 `editMessage` API 方法
  - ✅ 限制：仅允许编辑自己发送的文本消息，编辑后实时同步到所有客户端
- **实现位置**:
  - 后端：`backend/src/handlers/message.rs::edit_message`, `backend/src/database/message_store.rs::update_message_content`
  - Desktop：`desktop/src/components/MessageContextMenu.vue`, `desktop/src/views/Chat.vue::handleMessageMenuEdit`
  - Flutter：`frontend/lib/core/services/message_service.dart::editMessage`
- **状态**: ✅ 已完成
- **完成时间**: 2025-12-27

#### 6.2 消息反应（reactions）✅
- **完成情况**:
  - ✅ 数据库：新增 `message_reactions` 表（迁移文件：`20251227024227_create_message_reactions.sql`），支持软删除与唯一约束 `(message_id, user_id, reaction_key)`
  - ✅ API：新增 reactions 接口（`POST/DELETE/GET /rooms/{room_id}/messages/{message_id}/reactions`），删除接口兼容 body/query 两种传参
  - ✅ WebSocket：新增 `reaction_update` 推送，并通过 Redis Pub/Sub 做跨节点广播
  - ✅ Desktop：上下文菜单 + `ReactionPicker`，消息下方展示聚合标签并支持点击 toggle
  - ✅ Flutter：`ReactionPicker` + 气泡内 reaction tags；API 调用与 WS 更新保持一致
  - ✅ 约束：反应类型固定集合（👍 ❤️ 😂 🎉 😮 😢），同一用户对同一消息同一 reaction 为 0/1 toggle
- **实现位置**:
  - 后端：`backend/src/handlers/message.rs::{add_message_reaction,remove_message_reaction,get_message_reactions}`，`backend/src/database/message_reaction_store.rs`，`backend/proto/ws.proto`
  - Desktop：`desktop/src/views/Chat.vue`，`desktop/src/components/ReactionPicker.vue`，`desktop/src/api/message.ts`
  - Flutter：`frontend/lib/core/services/message_service.dart`，`frontend/lib/features/chat/widgets/reaction_picker.dart`，`frontend/lib/core/services/websocket_service.dart`
- **状态**: ✅ 已完成

#### 6.3 正在输入（typing）✅
- **完成情况**:
  - ✅ WebSocket 协议：新增 `ClientTyping` / `ServerTypingUpdate`，并同步到 Desktop/Flutter 的 proto
  - ✅ 后端：连接级节流（1200ms）+ `expires_in_ms`，通过 Redis Pub/Sub 广播到房间；发送消息/离开房间/断线时清理 typing 状态
  - ✅ Desktop：输入变化节流上报 typing；空闲自动发送 `typing=false`；UI 显示 typing 指示器并按过期时间清理
  - ✅ Flutter：`ChatDetailPageV2` 本地节流上报 + idle timer；订阅 `onTypingUpdate` 更新 UI
- **实现位置**:
  - 后端：`backend/proto/ws.proto`，`backend/src/websocket/mod.rs`，`backend/src/redis/models.rs`，`backend/src/redis/pubsub.rs`
  - Desktop：`desktop/src/views/Chat.vue`，`desktop/src/utils/websocket.ts`，`desktop/src/api/websocket.ts`
  - Flutter：`frontend/lib/core/services/websocket_service.dart`，`frontend/lib/features/chat/chat_detail_page_v2.dart`
- **状态**: ✅ 已完成

**影响**: 多端核心聊天体验对齐（编辑/反应/输入态）；涉及 WS 协议与 DB 变更，需要统一灰度与兼容策略
**状态**: ✅ 已完成（消息编辑 / Reactions / Typing 全端已对齐）
**优先级**: 🟠 中（已处理）

---

### 7. COS 大文件分片前端直传（backend + desktop + frontend + admin）
**目标**: 扩展现有"单文件直传"能力，支持大文件（例如视频/安装包）走 COS Multipart Upload（分片直传），文件数据始终由前端上传到 COS，后端仅负责分片会话与最终合并（Complete）。

#### 7.1 实现概览
- **后端 COS 层**: `backend/src/storage/cos.rs` 已实现 `initiate_multipart_upload`、`generate_multipart_upload_part_signature`、`complete_multipart_upload`、`abort_multipart_upload`
- **后端 API**: `backend/src/handlers/multipart_upload.rs` 提供 5 个完整的分片上传 API
- **后端路由**: `routes.rs` 已注册管理员端 + 普通用户端 + 消息附件三套路由
- **数据库**: `20251219120000_create_file_upload_multipart_sessions.sql` 已创建分片会话表
- **后端服务**: `backend/src/services/multipart_upload.rs` 实现分片计划计算（阈值 5MB，默认分片 8MB）

#### 7.2 前端实现
- **Admin 后台**: `admin/src/api/multipart-upload.ts` + `admin/src/utils/multipart-upload.ts` 完整实现
- **Desktop 桌面端**: `desktop/src/api/message.ts` API 封装 + `Chat.vue` 实际调用 `initiateAttachmentMultipartUpload` → `generateMultipartPartSignature` → `completeMultipartUpload`
- **Flutter 移动端**: `frontend/lib/core/services/message_service.dart` 自动判断（> 5MB 走分片），完整实现分片上传流程

#### 7.3 API 路由清单
```
# 管理员端
POST /api/admin/uploads/multipart/sessions/{session_id}/parts/signature
POST /api/admin/uploads/multipart/sessions/{session_id}/parts/commit
POST /api/admin/uploads/multipart/sessions/{session_id}/complete
POST /api/admin/uploads/multipart/sessions/{session_id}/abort
GET  /api/admin/uploads/multipart/sessions/{session_id}

# 普通用户端
POST /uploads/multipart/sessions/{session_id}/parts/signature
POST /uploads/multipart/sessions/{session_id}/parts/commit
POST /uploads/multipart/sessions/{session_id}/complete
POST /uploads/multipart/sessions/{session_id}/abort
GET  /uploads/multipart/sessions/{session_id}

# 消息附件
POST /rooms/{room_id}/messages/attachments/multipart/initiate
```

**影响**: 大文件上传稳定性与体验显著提升；已完整实现分片上传全链路
**状态**: ✅ 已完成
**优先级**: 🟠 中（已处理）
**完成时间**: 2025-12-19（迁移文件日期）

---

### 8. Push 通知集成（backend + frontend）
**目标**: App 不在前台时也能收到通知（新消息/好友请求等），并与“会话免打扰/仅@通知/完全静音”等设置保持一致。

#### 8.1 产品与策略对齐
- 通知类型：新消息、@提醒、好友请求、群管理事件（被踢/解散/转让等）等（按产品最终取舍）
- 通知过滤：
  - 不给发送者自己推送
  - 按 `room_members.notification_settings`（0=全部通知，1=仅@通知，2=完全静音）过滤
  - 支持全局免打扰/时段免打扰（如需）
- 通知载荷（用于点击跳转）：至少包含 `room_id`、可选 `message_id`（用于定位消息）与展示用的 `sender_name/message_preview`

#### 8.2 后端（接口 + 存储）
- ✅ 设备标识与 token 存储：已新增 `push_devices` 表记录 `user_id/platform/device_token/channel/device_id/last_seen/is_active` 等（迁移文件：`20251228090000_create_push_devices.sql`）
- Token 注册接口：
  - ✅ `POST /push/devices`：上报/更新 token（支持 token 刷新）
  - ✅ `DELETE /push/devices/{device_id}`：注销（软禁用）
- 推送触发点：
  - ✅ 消息落库成功后，对房间成员进行过滤并异步发送 push（已覆盖 `send_message` / `forward_message`）
  - ✅ 已补齐更多触发点：好友请求、群解散/踢人/转让群主等事件触发 push
- ✅ 异步化：推送发送走后台任务（`tokio::spawn`），避免阻塞发消息接口
- ✅ 失败重试与退避：已实现基础重试（指数退避，最多 3 次）
- ✅ 稳定性优化：增加 push job 队列/worker 与全局并发限流（避免高峰期 spawn 风暴），无效 token 自动停用
- Provider 集成：
  - ✅ Android：FCM HTTP v1（Service Account JSON）
  - 🟡 iOS：首版先走 Firebase Messaging（经 FCM 转发到 APNs）；APNs 直连可后续补齐
- ✅ 可观测性：发送结果落库（`push_logs`）+ `push_id` 追踪（错误码聚合可后续补齐）
- ✅ 运维可视化：Admin 支持查询/清理 push 日志（`GET /api/admin/push/logs`、`POST /api/admin/push/logs/cleanup`）

#### 8.3 Flutter（移动端）
- ✅ 集成推送 SDK：`firebase_core` + `firebase_messaging` 获取 FCM token
- ✅ Token 生命周期：首次登录上报、token 刷新回调更新、登出时解绑
- ✅ 通知点击跳转：解析 payload → 打开对应会话（`ChatDetailPageV2`）
- ✅ 本地通知兜底：WebSocket 新消息且 App 非前台时弹本地通知（不依赖 Firebase 配置）

#### 8.4 配置与材料清单（落地前准备）
- iOS：Bundle ID、开启 Push capability、APNs `.p8` / Key ID / Team ID
- Android：Firebase 项目、`google-services.json`、Service Account JSON

**影响**: 移动端离线可达性与提醒体验显著提升；涉及安全凭据与服务稳定性，需要完整的环境配置与灰度策略
**状态**: 🟡 部分完成（核心链路与可观测性已补齐；iOS 工程材料与 capability 仍需配置，详见 `docs/design/push-notification-design.md`）
**优先级**: 🟠 中（按里程碑继续完善）

---

## 🟡 低优先级 (体验优化)

### 9. 前端 - 音频波形可视化 (desktop)
**位置**: `desktop/src/utils/voiceRecorder.ts:332`
```typescript
// VoiceUtils.createWaveformData / createWaveformFromBlob
```
**影响**: 桌面端语音录制时支持根据录音音频生成简单的波形采样数据（VoiceUtils 基于 Web Audio API 将 AudioBuffer 采样为 0-1 振幅数组），在 `VoiceMessage.vue` 的预览区域按采样数据渲染波形条；未支持复杂频谱分析，后续可按需要扩展
**状态**: ✅ 已完成（基础波形可视化）
**优先级**: 🟡 低（如需更精细的频谱/样式可另起任务）

---

### 10. 后端 - 测试用例待完善
**位置**: `backend/tests/file_upload_test.rs`
```rust
// 覆盖头像/附件的类型白名单与大小限制逻辑
```
**影响**: 文件上传相关的核心校验（允许的 MIME 类型、危险类型黑名单、各类文件的最大体积）已有针对性的单元测试，后续如需端到端直传测试可单独新增集成用例
**状态**: ✅ 已完成（当前粒度为纯逻辑单测）
**优先级**: 🟡 低（如需扩展为集成测试可另起任务）

---

### 11. 前端 (Flutter) - Android 构建配置
**位置**: `frontend/android/app/build.gradle.kts`, `frontend/config/android/app_config.properties`

#### 11.1 应用 ID 配置
- `build.gradle.kts` 已从统一配置文件 `config/android/app_config.properties` 读取 `APPLICATION_ID`
- 默认值：`com.chatlyme.app`

#### 11.2 签名配置
- `build.gradle.kts` 已实现从配置文件读取 keystore 相关配置：
  - `KEYSTORE_FILE`: keystore 文件路径
  - `KEYSTORE_PASSWORD`: keystore 密码
  - `KEY_ALIAS`: 密钥别名
  - `KEY_PASSWORD`: 密钥密码
- 如配置完整则使用 release 签名，否则自动回退到 debug 签名（保证开发环境可用）

#### 11.3 配置文件示例
```properties
# frontend/config/android/app_config.properties
APPLICATION_ID=com.chatlyme.app
KEYSTORE_FILE=keystore/release.keystore
KEYSTORE_PASSWORD=change_me_keystore_password
KEY_ALIAS=release
KEY_PASSWORD=change_me_key_password
```

**影响**: Android 发布配置已完成，只需在配置文件中填写实际值即可发布
**状态**: ✅ 已完成
**优先级**: 🟡 低（已处理）
**说明**: 生产环境的 keystore 文件和真实密码请不要提交到代码仓库，建议使用 CI Secret 注入

---

### 12. 管理后台 - ECharts 主题 (admin)
**位置**: `admin/src/hooks/chart-option.ts:20`
```typescript
// useChartOption(sourceOption: (isDark, theme) => option)
```
**影响**: 将主题相关配置（背景色、文字颜色、坐标轴线/分割线颜色、主色渐变和面积渐变色等）集中在 `ChartTheme` 中，由 `useChartOption` 统一根据深色/浅色返回；示例实现已应用到内容统计折线图（workplace/content-chart.vue）
**状态**: ✅ 已完成（已接入基础主题结构，后续可为更多图表复用）
**优先级**: 🟡 低

---

## 📊 统计概览

| 优先级 | 数量 | 模块分布 |
|--------|------|----------|
| 🔴 高优先级 | 3 | 后端(2，✅已完成) + 前端桌面端(1，✅已完成) |
| 🟠 中优先级 | 5 | 前端桌面端(1，✅已完成) + 前端移动端(1，✅已完成) + 消息编辑/反应/输入态(1，✅已完成) + COS 分片直传(1，✅已完成) + Push 通知(1，🟡部分完成-iOS 工程材料) |
| 🟡 低优先级 | 4 | 后端测试(1，✅已完成基础单测) + 桌面端(1，✅已完成) + 移动端(1，✅已完成) + 管理后台(1，✅已完成基础主题结构) |
| **总计** | **12** | **已完成: 11/12（Push 部分完成）** |

---

## 🎯 推荐处理顺序

### 第一阶段 (本周)
1. ✅ 修复 argon2 密码加密问题 (已通过统一采用 bcrypt 完成)
2. ✅ 实现 WebSocket 事件真实业务逻辑 (好友与群聊核心事件已接入 Desktop + Flutter)
3. ✅ 完成文件上传方案调整 (采用 COS 直传,不再实现后端 multipart)

### 第二阶段 (下周)
4. ✅ 实现群聊管理对话框 (添加/删除成员、举报、禁言、转让/解散、退出)
5. ✅ 完善 Flutter 端聊天 API 调用（删除消息、已读同步、置顶、清空、语音）

### 第三阶段 (有空时)
6. ✅ 音频波形可视化（desktop 录音预览的基础波形渲染）
7. ✅ 测试用例补充（文件上传相关逻辑的基础单元测试）
8. ✅ Android 发布配置（已从统一配置文件读取 Application ID 与签名配置）
9. ✅ 图表主题优化（admin 基础主题结构与示例接入）
10. 🟡 Push 通知集成（剩余 iOS 工程材料，继续按文档完善）
11. ✅ 消息编辑 / Reactions / Typing（已完成：编辑 + Reactions + Typing）
12. ✅ COS 大文件分片前端直传（已完成：后端 API + Admin/Desktop/Flutter 全端实现）

---

## 🎯 待完成任务清单（按优先级）

### 🔴 高优先级
无（所有高优先级任务已完成）

### 🟠 中优先级

#### 1. Push 通知集成（里程碑）
- **状态**: 🟡 部分完成
- **已完成**:
  - ✅ 后端：`push_devices` 表 + `POST/DELETE /push/devices`；消息发送后异步触发推送（FCM HTTP v1）
  - ✅ Admin：Push 日志查询/清理（`/api/admin/push/logs`）
  - ✅ Flutter：Firebase Messaging 获取 token；登录后注册、登出注销；点击通知跳转到会话
  - ✅ Flutter：本地通知兜底（WebSocket 新消息且 App 非前台时提示，不依赖 Firebase 配置）
  - ✅ Desktop：系统通知（`tauri-plugin-notification`，窗口非前台时提示）+ 提示音/任务栏提醒
- **待补齐**:
  - ✅ 更多触发点：好友请求、群管理事件（踢人/解散/转让等）
  - ✅ `mentions_only` 精准 @ 解析（按 `@用户名/@昵称/@all` 解析，仅对被提及成员推送）
  - ✅ 跨节点在线状态去重（`PUSH_SKIP_IF_ONLINE` 支持跨节点在线态判断）
  - ✅ 失败重试/退避 + 发送结果落库（`push_logs`）与 `push_id` 追踪
  - 🟡 iOS 工程侧材料（`GoogleService-Info.plist` / APNs `.p8` 等）仍需配置（仓库已提供 Push capability entitlements）
  - ✅ 通知样式/渠道策略（基础策略已落地：iOS 前台展示选项 + 本地通知兜底 + 点击跳转）

### 🟡 低优先级
#### 1. Flutter 视频预览
- **状态**: ✅ 已完成
- **位置**: `frontend/lib/features/chat/chat_detail_page_v2.dart:6966`
- **说明**: 已支持点击视频附件打开播放器预览（单视频与混合消息均可打开）。

#### 2. Desktop 文档同步（视频缩略图参数）
- **状态**: ✅ 已完成
- **位置**: `docs/desktop/desktop-remaining-tasks.md:146`
- **说明**: 已在文档中补充并确认视频缩略图生成参数（尺寸/质量）。

---

**最后更新**: 2025-12-29
**总完成度**: 11/12（Push 部分完成）
**待完成任务**: Push 通知里程碑（iOS 工程材料）
