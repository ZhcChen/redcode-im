# Desktop EL 更深群事件接通 Plan

**Goal:** 把 `desktop-el` 当前仍缺的群管理事件继续接回统一刷新链路，优先补齐“管理员角色变更提示”和“入群审批导致的活跃群面板刷新”。

**Cut:**
- renderer `group_member_changed(role_changed)` 对当前用户给出角色变更 notice
- renderer 在 `room_updated` 命中当前群时，继续刷新管理员 / 入群审核 / 禁言面板
- backend 在创建/审批入群申请后，向房间广播 `room_updated` 提示，复用现有 stdio RPC + renderer 刷新链路

**Verification:**
- `cd desktop-el && bun test renderer/src/utils/chat-group-realtime.test.ts`
- `cd desktop-el && bun test`
- `cd desktop-el && bun run build`
- `cd backend && cargo test`
