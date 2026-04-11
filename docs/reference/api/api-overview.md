# RedCode IM API 概览

> 本文档用于“快速查找接口入口”。接口实现以 `backend/src/routes.rs` 为准。
>
> 详细参数与响应请参考：
> - `docs/reference/api/api-reference.md`（全量路由清单）
> - `docs/reference/api/README.md`（专题文档索引）

## 基础信息

- HTTP（开发默认）：`http://localhost:8010`
- WebSocket（开发默认）：`ws://localhost:8010/ws`
- 认证：除公开接口外，Header 需要携带 `Authorization: Bearer <token>`

## 响应与错误

- **成功响应**：当前后端并未强制统一 envelope（有的接口返回 `{success,message,...}`，有的接口直接返回业务对象）。建议以 **HTTP 状态码** 为第一判断依据，并按各接口文档解析字段。
- **错误响应**：当接口返回非 2xx 时，响应体遵循统一结构（见 `backend/src/error.rs`）：

```json
{
  "code": 40001,
  "message": "错误信息",
  "details": "可选的详细信息"
}
```

## 接口导航

### 公共/基础

- `GET /`：服务信息
- `GET /healthz`：健康检查
- `GET /ws`：WebSocket 升级（支持查询参数 `token`、`format`）

### 认证（用户）

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/login/oauth`
- `POST /auth/login/sms`
- `POST /auth/refresh`
- `POST /auth/sms/send`
- `GET /auth/me`
- `POST /auth/password/reset`

### 认证（管理员）

- `POST /auth/admin/login`
- `POST /auth/admin/refresh`
- `GET /auth/admin/me` / `PATCH /auth/admin/me`
- `POST /auth/admin/me/password`

### 用户资料

- `GET /users/search`
- `GET /users/{user_id}`
- `PATCH /users/me` / `DELETE /users/me`
- `POST /users/me/password`
- 头像直传：
  - `POST /users/me/avatar/direct-upload`
  - `POST /users/me/avatar/commit`
  - `GET /users/me/avatar/url`
  - `GET /users/{user_id}/avatar/url`

### 好友

- `GET /friends`
- `GET /friends/requests` / `POST /friends/requests`
- `POST /friends/requests/{request_id}/respond`
- `POST /friends/{friend_user_id}/chat`
- `PATCH /friends/{friend_user_id}/remark`
- `DELETE /friends/{friend_user_id}`

### 会话/房间

- `GET /chats`
- `DELETE /chats/{room_id}`
- `GET /rooms` / `POST /rooms`
- `POST /rooms/{room_id}/join`
- `POST /rooms/{room_id}/leave`
- `GET /rooms/{room_id}/members` / `POST /rooms/{room_id}/members`
- `DELETE /rooms/{room_id}/members/{user_id}`
- `GET /rooms/{room_id}` / `PATCH /rooms/{room_id}` / `DELETE /rooms/{room_id}`
- `POST /rooms/{room_id}/transfer`
- `POST /rooms/{room_id}/pin` / `DELETE /rooms/{room_id}/pin`
- `POST /rooms/{room_id}/notification-settings`
- 群头像直传：
  - `POST /rooms/{room_id}/avatar/direct-upload`
  - `POST /rooms/{room_id}/avatar/commit`
  - `GET /rooms/{room_id}/avatar/url`

### 消息与附件

- `POST /rooms/{room_id}/messages` / `GET /rooms/{room_id}/messages` / `DELETE /rooms/{room_id}/messages`
- `DELETE /rooms/{room_id}/messages/{message_id}`
- `POST /rooms/{room_id}/messages/forward`
- `POST /rooms/{room_id}/messages/{message_id}/pin` / `DELETE /rooms/{room_id}/messages/{message_id}/pin`
- 附件直传：
  - `POST /rooms/{room_id}/messages/attachments/signature`
  - `POST /rooms/{room_id}/messages/attachments/commit`
  - `GET /rooms/{room_id}/messages/attachments/download`

### 已读/未读

- `POST /rooms/{room_id}/messages/read`
- `POST /rooms/{room_id}/messages/read_until`
- `GET /rooms/{room_id}/messages/{message_id}/reads`
- `GET /rooms/{room_id}/unread_count`
- `GET /unread_counts`

### 消息搜索

- `GET /messages/search`
- `GET /messages/search/suggestions`
- `GET /messages/search/trending`

### 版本与更新

- `GET /versions/latest`
- `GET /versions/latest/download-url`
- `GET /versions/download`
- `GET /versions/hot-update`
- `GET /versions/hot-update/download`
- `POST /versions/hot-update/report`

### 系统设置（公开）

- `GET /settings/privacy-policy`
- `GET /settings/user-agreement`
- `GET /settings/general`
- `GET /settings/app-name`
- `GET /settings/captcha`

### 管理后台（需管理员 Token）

管理后台 API 主要位于 `/api/admin/*`，另包含 `/api/dashboard/*` 等路由；完整列表请查看 `docs/reference/api/api-reference.md` 的“管理后台 API”章节。
