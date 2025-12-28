# 消息反应（Reactions）和正在输入（Typing）功能实现状态分析

**更新时间**: 2025-12-28  
**分析范围**: Backend、Desktop、Flutter 全端代码库

> 说明：本文用于反映当前实现状态。此前（2025-12-27）“未实现”的检查结论已过时；截至 2025-12-28，Reactions 与 Typing 已完成全链路实现并合并。

## ✅ 总结

- ✅ 消息反应（Reactions）：已实现（DB + API + WebSocket + Desktop + Flutter）
- ✅ 正在输入（Typing）：已实现（WebSocket 协议 + 节流/过期 + Desktop + Flutter）

---

## 1. 消息反应（Reactions）

### 1.1 后端实现

- **数据库**：`message_reactions`（迁移文件：`backend/sql/migrations/20251227024227_create_message_reactions.sql`）
- **API**：
  - `POST /rooms/{room_id}/messages/{message_id}/reactions`（添加/恢复）
  - `DELETE /rooms/{room_id}/messages/{message_id}/reactions`（删除；兼容 body/query 传参）
  - `GET /rooms/{room_id}/messages/{message_id}/reactions`（查询聚合结果 + self 状态）
- **WebSocket**：`reaction_update`（跨节点通过 Redis Pub/Sub 广播）
- **关键实现位置**：
  - `backend/src/handlers/message.rs`
  - `backend/src/database/message_reaction_store.rs`
  - `backend/proto/ws.proto`

### 1.2 Desktop 实现

- **UI**：上下文菜单 + `ReactionPicker`；消息下方展示聚合标签（可点击 toggle）
- **WebSocket**：监听 `reaction_update` 并更新本地消息 reactions
- **关键实现位置**：
  - `desktop/src/views/Chat.vue`
  - `desktop/src/components/ReactionPicker.vue`
  - `desktop/src/utils/websocket.ts`

### 1.3 Flutter 实现

- **UI**：`ReactionPicker` + 气泡内 reaction tags（可点击 toggle）
- **WebSocket**：监听 `reaction_update` 并更新本地消息 reactions
- **关键实现位置**：
  - `frontend/lib/core/services/message_service.dart`
  - `frontend/lib/features/chat/widgets/reaction_picker.dart`
  - `frontend/lib/core/services/websocket_service.dart`

---

## 2. 正在输入（Typing）

### 2.1 WebSocket 协议

- `ClientTyping`：`room_id` + `is_typing`
- `ServerTypingUpdate`：`room_id` + `user_id` + `is_typing` + `expires_in_ms`

对应定义已同步至：
- `backend/proto/ws.proto`
- `desktop/src/proto/ws.proto`
- `frontend/lib/proto/`（由 proto 生成产物）

### 2.2 后端实现

- **节流**：连接级（默认 1200ms），避免频繁广播
- **广播**：房间维度；跨节点通过 Redis Pub/Sub 分发
- **清理**：发送消息 / 离开房间 / 断线时清理 typing 状态
- **关键实现位置**：
  - `backend/src/websocket/mod.rs`
  - `backend/src/redis/models.rs`
  - `backend/src/redis/pubsub.rs`

### 2.3 Desktop 实现

- **发送**：输入变化节流上报；空闲自动发送 `typing=false`
- **展示**：typing 指示器按过期时间清理
- **关键实现位置**：
  - `desktop/src/views/Chat.vue`
  - `desktop/src/utils/websocket.ts`

### 2.4 Flutter 实现

- **发送**：本地节流上报 + idle timer
- **展示**：`ChatDetailPageV2` 显示 typing 文案
- **关键实现位置**：
  - `frontend/lib/features/chat/chat_detail_page_v2.dart`
  - `frontend/lib/core/services/websocket_service.dart`

---

## 📌 可继续优化（非阻塞）

- Typing：群聊多人输入态的 UI 折叠策略、跨端一致的“停止输入”时机细化
- Reactions：查看详情列表（谁点了哪些 reaction）、离线补齐/分页拉取 reactions 的策略（如需要）

