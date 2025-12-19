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

### 6. Push 通知集成（backend + frontend）
**目标**: App 不在前台时也能收到通知（新消息/好友请求等），并与“会话免打扰/仅@通知/完全静音”等设置保持一致。

#### 6.1 产品与策略对齐
- 通知类型：新消息、@提醒、好友请求、群管理事件（被踢/解散/转让等）等（按产品最终取舍）
- 通知过滤：
  - 不给发送者自己推送
  - 按 `room_members.notification_settings`（0=全部通知，1=仅@通知，2=完全静音）过滤
  - 支持全局免打扰/时段免打扰（如需）
- 通知载荷（用于点击跳转）：至少包含 `room_id`、可选 `message_id`（用于定位消息）与展示用的 `sender_name/message_preview`

#### 6.2 后端（接口 + 存储）
- 设备标识与 token 存储：新增 `push_devices`（或同等表）记录 `user_id/platform/device_token/channel/device_id/last_seen/is_active` 等
- Token 注册接口：
  - `POST /push/devices`：上报/更新 token（支持 token 刷新）
  - `DELETE /push/devices/{device_id}`（或按 token 注销）
- 推送触发点：
  - 消息落库成功后，对房间成员进行过滤并异步发送 push
  - 好友请求、群解散/踢人等事件同理
- 异步化：推送发送必须走后台任务（避免阻塞发消息接口）；支持失败重试与退避
- Provider 集成：
  - Android：FCM HTTP v1（Service Account JSON）
  - iOS：APNs（Auth Key `.p8` + Key ID + Team ID）
- 可观测性：记录发送结果、错误码、可追踪的 `push_id`（便于排障）

#### 6.3 Flutter（移动端）
- 集成推送 SDK：
  - Android：Firebase Messaging（获取 FCM token）
  - iOS：APNs 权限 + FCM（或直接 APNs，根据最终选型）
- Token 生命周期：首次登录上报、token 刷新回调更新、登出时解绑
- 通知点击跳转：解析 payload → 打开对应会话 →（有 `message_id` 则）定位到目标消息

#### 6.4 配置与材料清单（落地前准备）
- iOS：Bundle ID、开启 Push capability、APNs `.p8` / Key ID / Team ID
- Android：Firebase 项目、`google-services.json`、Service Account JSON

**影响**: 移动端离线可达性与提醒体验显著提升；涉及安全凭据与服务稳定性，需要完整的环境配置与灰度策略
**状态**: ❌ 未完成
**优先级**: 🟠 中（文档先行，后续按里程碑实现）

---

## 🟡 低优先级 (体验优化)

### 7. 前端 - 音频波形可视化 (desktop)
**位置**: `desktop/src/utils/voiceRecorder.ts:332`
```typescript
// VoiceUtils.createWaveformData / createWaveformFromBlob
```
**影响**: 桌面端语音录制时支持根据录音音频生成简单的波形采样数据（VoiceUtils 基于 Web Audio API 将 AudioBuffer 采样为 0-1 振幅数组），在 `VoiceMessage.vue` 的预览区域按采样数据渲染波形条；未支持复杂频谱分析，后续可按需要扩展
**状态**: ✅ 已完成（基础波形可视化）
**优先级**: 🟡 低（如需更精细的频谱/样式可另起任务）

---

### 8. 后端 - 测试用例待完善
**位置**: `backend/tests/file_upload_test.rs`
```rust
// 覆盖头像/附件的类型白名单与大小限制逻辑
```
**影响**: 文件上传相关的核心校验（允许的 MIME 类型、危险类型黑名单、各类文件的最大体积）已有针对性的单元测试，后续如需端到端直传测试可单独新增集成用例
**状态**: ✅ 已完成（当前粒度为纯逻辑单测）
**优先级**: 🟡 低（如需扩展为集成测试可另起任务）

---

### 9. 前端 (Flutter) - Android 构建配置
**位置**: `frontend/android/app/build.gradle.kts`

#### 8.1 应用 ID 配置 (第23行)
```kotlin
// TODO: Specify your own unique Application ID
```

#### 8.2 签名配置 (第35行)
```kotlin
// TODO: Add your own signing config for the release build.
```

**影响**: Android 发布配置未完成
**状态**: ❌ 未完成
**优先级**: 🟡 低

---

### 10. 管理后台 - ECharts 主题 (admin)
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
| 🔴 高优先级 | 3 | 后端(2，含 2 个已完成) + 前端桌面端(1，已完成) |
| 🟠 中优先级 | 3 | 前端桌面端(1，已完成) + 前端移动端(1，已完成) + Push 通知(1，未完成) |
| 🟡 低优先级 | 4 | 后端测试(1，已完成基础单测) + 桌面端(1，已完成) + 移动端(1，未完成) + 管理后台(1，已完成基础主题结构) |
| **总计** | **10** | - |

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
8. ❌ Android 发布配置（集中配置 Application ID 与签名）
9. ✅ 图表主题优化（admin 基础主题结构与示例接入）
10. ❌ Push 通知集成（先按文档准备环境与凭据，再按里程碑实现）

---

**最后更新**: 2025-12-19
**总完成度**: 8/10 (80%)
