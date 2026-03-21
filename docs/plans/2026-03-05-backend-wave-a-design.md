# Backend Wave A（readyz / 改密 / 未读计数）测试设计

**日期**: 2026-03-05  
**范围**: `tests/go/backend/system`、`tests/go/backend/users`、`tests/go/backend/messages`

## 1. 目标

补齐 Backend 剩余 TODO 中的第一批高价值项：

1. `BE-SYS-002`：`/readyz` 就绪检查契约。
2. `BE-USER-003`：`/users/me/password` 修改密码流程。
3. `BE-MSG-004`：`/unread_counts` 未读统计链路。

## 2. 策略

- 测试类型：Go 黑盒契约测试（真实 HTTP 调用，最小 mocking）。
- 重点覆盖：
  - 正常路径 + 关键错误路径（例如旧密码错误）。
  - 状态转换（例如未读从 2 -> 0）。
  - 响应字段契约（status、code、message、关键业务字段）。

## 3. 用例设计

### 3.1 readyz

- `GET /readyz` 返回 200。
- `status=ok`。
- `checks.database/redisSession/redisCache.status=ok`，且包含 `latencyMs`。

### 3.2 change password

- 使用错误旧密码调用 `/users/me/password`：返回 400 + `42201`。
- 使用正确旧密码调用 `/users/me/password`：返回 200 + `success=true`。
- 改密后旧密码登录失败，新密码登录成功。

### 3.3 unread counts

- A 在群聊发送 2 条消息，B 拉取 `/unread_counts`：目标房间 `unread_count=2`。
- B 调用 `read_until` 到最后一条消息。
- 再次拉取 `/unread_counts`（以及 `/rooms/{id}/unread_count`）：`unread_count=0`。

## 4. 验收标准

1. 三条用例全部稳定通过。
2. `backend.csv` 中对应条目从 `todo` 更新为 `done`。
3. 回归报告与测试指南同步更新。
