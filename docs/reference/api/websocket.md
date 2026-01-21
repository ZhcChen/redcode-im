# WebSocket 接口

## WebSocket /ws — WebSocket 连接

建立WebSocket连接用于实时消息传递。支持认证、加入房间、消息推送与好友请求红点更新等事件。

- 需要认证：否（连接时不需要，但需要发送 auth 事件完成认证）
- 标识：ws-connection
> 说明：当前实现中，连接建立后仍需发送一次 `auth` 事件完成绑定（收到 `authed` 推送才算认证完成）；可参考 `docs/reference/testing/websocket-test.md` 的可执行步骤。

### 连接参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| token | string | 是 | JWT Token（通过查询参数传递） |
| format | string | 否 | 消息格式：`json`(默认) 或 `proto/protobuf/pb/binary` |

**连接示例**：
```
ws://localhost:8010/ws?token=<your-jwt-token>&format=json
```

### 响应
#### HTTP 101
WebSocket连接建立成功

---

## 客户端发送事件

客户端可以通过 WebSocket 发送以下事件：

### 1. auth - 认证
```json
{
  "type": "auth",
  "token": "jwt-token"
}
```

### 2. join - 加入房间
```json
{
  "type": "join",
  "room_id": "room-uuid"
}
```

### 3. leave - 离开房间
```json
{
  "type": "leave",
  "room_id": "room-uuid"
}
```

### 4. ping - 心跳
```json
{
  "type": "ping"
}
```

### 5. typing - 正在输入
```json
{
  "type": "typing",
  "room_id": "room-uuid",
  "is_typing": true
}
```
- 服务端会对 typing 事件进行节流（约 1200ms），避免频繁广播
- 发送消息、离开房间或断开连接时会自动清除 typing 状态

---

## 服务端推送事件

WebSocket 服务端会向客户端推送以下类型的事件：

### 1. authed - 认证成功
客户端连接并认证成功后推送
```json
{
  "type": "authed",
  "user_id": "user-uuid",
  "conn_id": "connection-uuid"
}
```

### 2. joined - 加入房间
用户成功加入房间后推送
```json
{
  "type": "joined",
  "room_id": "room-uuid"
}
```

### 3. left - 离开房间
用户离开房间后推送
```json
{
  "type": "left",
  "room_id": "room-uuid"
}
```

### 4. message - 新消息
房间中有新消息时推送给所有订阅该房间的用户
```json
{
  "type": "message",
  "id": "message-uuid",
  "message_id": "message-uuid",
  "room_id": "room-uuid",
  "sender_id": "user-uuid",
  "sender_username": "用户名",
  "sender_nickname": "用户昵称",
  "sender_avatar_url": "https://...",
  "content": "消息内容",
  "message_type": "text",
  "parts": [
    {
      "position": 0,
      "part_type": "text",
      "text": "消息内容",
      "attachment": null
    }
  ],
  "quoted_message": null,
  "forward_message": null,
  "timestamp": "2024-01-01T00:00:00Z"
}
```

**parts 字段说明**：
- `position`: 分片位置索引
- `part_type`: 分片类型（text/image/file/video/audio/sticker）
- `text`: 文本内容（文本类型时）
- `attachment`: 附件信息（媒体类型时）
  ```json
  {
    "key": "存储key",
    "name": "文件名",
    "mime": "mime类型",
    "size": 12345,
    "width": 800,
    "height": 600,
    "duration_ms": 30000,
    "thumbnail_key": "缩略图key"
  }
  ```

**quoted_message 字段说明**（引用消息）：
```json
{
  "id": "message-uuid",
  "room_id": "room-uuid",
  "sender_id": "user-uuid",
  "sender_username": "用户名",
  "sender_nickname": "昵称",
  "sender_avatar_url": "头像URL",
  "content": "原消息内容",
  "message_type": "text",
  "created_at": "2024-01-01T00:00:00Z",
  "is_deleted": false,
  "parts": []
}
```

**forward_message 字段说明**（转发消息）：
```json
{
  "message_id": "原消息ID",
  "room_id": "原房间ID",
  "sender_id": "原发送者ID",
  "sender_username": "原发送者用户名",
  "sender_nickname": "原发送者昵称"
}
```

### 5. message_read - 消息已读回执
有用户读取消息时推送
```json
{
  "type": "message_read",
  "room_id": "room-uuid",
  "message_id": "message-uuid",
  "reader_id": "user-uuid",
  "read_at": "2024-01-01T00:00:00Z"
}
```

### 6. message_update - 消息更新
消息被更新（编辑、删除等）时推送
```json
{
  "type": "message_update",
  "room_id": "room-uuid",
  "message_id": "message-uuid",
  "is_deleted": true,
  "deleted_at": "2024-01-01T00:00:00Z",
  "update_type": "deleted",
  "edited_at": null,
  "content": null
}
```
- `update_type`: `"deleted"` 删除 | `"edited"` 编辑

### 7. pin_update - 置顶更新
消息被置顶或取消置顶时推送
```json
{
  "type": "pin_update",
  "room_id": "room-uuid",
  "message_id": "message-uuid",
  "is_pinned": true,
  "pinned_at": "2024-01-01T00:00:00Z",
  "pinned_by": "user-uuid"
}
```

### 8. error - 错误
服务端发生错误时推送
```json
{
  "type": "error",
  "message": "错误描述"
}
```

### 9. pong - 心跳响应
响应客户端的 ping 请求
```json
{
  "type": "pong"
}
```

### 10. friend_request_update - 好友请求更新
收到新的好友请求时推送
```json
{
  "type": "friend_request_update",
  "pending_count": 5
}
```

### 11. room_created - 房间创建
用户被邀请加入新房间时推送
```json
{
  "type": "room_created",
  "room_id": "room-uuid",
  "room_name": "群聊名称",
  "room_type": "group",
  "initiator_id": "user-uuid",
  "owner_id": "user-uuid",
  "description": "群简介",
  "avatar_url": "https://...",
  "created_at": "2024-01-01T00:00:00Z"
}
```

### 12. room_updated - 房间信息更新
房间名称、头像、描述等信息变更时推送
```json
{
  "type": "room_updated",
  "room_id": "room-uuid",
  "room_name": "新群名称",
  "room_type": "group",
  "avatar_url": "https://...",
  "avatar_object_key": "rooms/xxx/avatar.png",
  "description": "新的群描述"
}
```

### 13. user_banned - 用户被封禁
当前用户被封禁时推送
```json
{
  "type": "user_banned",
  "user_id": "user-uuid",
  "reason": "违规操作"
}
```

### 14. group_dissolved - 群组解散
群组被解散时推送给所有成员
```json
{
  "type": "group_dissolved",
  "room_id": "room-uuid"
}
```

### 15. group_owner_transferred - 群主转让
群主身份转让时推送
```json
{
  "type": "group_owner_transferred",
  "room_id": "room-uuid",
  "old_owner_id": "user-uuid",
  "new_owner_id": "user-uuid"
}
```

### 16. group_settings_updated - 群设置更新
群组设置（如全员禁言）变更时推送
```json
{
  "type": "group_settings_updated",
  "room_id": "room-uuid",
  "global_mute_enabled": true,
  "global_mute_reason": "会议进行中",
  "global_mute_until": "2024-01-01T12:00:00Z",
  "global_mute_set_by": "user-uuid"
}
```

### 17. group_member_changed - 群成员变更
成员加入、退出、被禁言、角色变更等时推送
```json
{
  "type": "group_member_changed",
  "room_id": "room-uuid",
  "member_id": "user-uuid",
  "change_type": "muted",
  "new_role": null,
  "operator_id": "admin-uuid",
  "reason": "发送广告",
  "until": "2024-01-01T12:00:00Z"
}
```
- `change_type`: `"joined"` | `"left"` | `"kicked"` | `"muted"` | `"unmuted"` | `"role_changed"`

### 18. room_history_cleared - 房间历史清除
房间聊天记录被清空时推送
```json
{
  "type": "room_history_cleared",
  "room_id": "room-uuid",
  "cleared_by": "admin-uuid",
  "cleared_at": "2024-01-01T00:00:00Z"
}
```

### 19. friendship_deleted - 好友关系删除
好友关系被删除时推送
```json
{
  "type": "friendship_deleted",
  "user_id": "friend-uuid"
}
```
- `user_id`: 被删除的好友用户ID（对事件接收方而言，对方的 user_id）

### 20. friend_profile_updated - 好友资料更新
好友的用户资料变更时推送
```json
{
  "type": "friend_profile_updated",
  "user_id": "friend-uuid",
  "username": "newusername",
  "nickname": "新昵称",
  "avatar_url": "https://...",
  "avatar_object_key": "avatars/xxx.png"
}
```

### 21. reaction_update - 消息反应更新
有用户添加或删除消息反应时推送
```json
{
  "type": "reaction_update",
  "room_id": "room-uuid",
  "message_id": "message-uuid",
  "reaction_key": "👍",
  "user_id": "user-uuid",
  "action": "add"
}
```
- `action`: `"add"` 添加反应 | `"remove"` 删除反应

### 22. typing_update - 正在输入
有用户在房间中输入时推送
```json
{
  "type": "typing_update",
  "room_id": "room-uuid",
  "user_id": "user-uuid",
  "is_typing": true,
  "expires_in_ms": 3000
}
```
- `expires_in_ms`: 输入状态过期时间（毫秒），客户端应在过期后自动清除显示

---

## 消息格式

### JSON 格式
默认使用 JSON 格式，所有消息都是 UTF-8 编码的 JSON 字符串。

### Protocol Buffers 格式
使用二进制 Protocol Buffers 格式，性能更高，带宽占用更少。

协议定义位置: `backend/src/proto/ws.proto`

连接时通过 `format` 参数指定：
```
ws://localhost:8010/ws?token=xxx&format=proto
```

---

## 连接管理

### 特性
- **多连接支持**: 同一用户可以有多个并发连接（多设备）
- **房间订阅**: 自动管理用户对房间的订阅
- **心跳机制**: Ping/Pong 保持连接活跃
- **连接追踪**: 记录连接时间、最后活跃时间等

### 连接生命周期
1. 客户端发起 WebSocket 连接
2. 连接建立后发送 `auth` 事件进行认证
3. 收到 `authed` 事件确认认证成功
4. 发送 `join` 事件加入房间
5. 收到 `joined` 事件确认加入成功
6. 开始收发消息
7. 定期发送 `ping` 保持连接
8. 断开连接或发送 `leave` 退出房间

### 心跳保活
建议客户端每 30 秒发送一次 `ping` 事件，服务端会响应 `pong` 事件。
如果超过 60 秒没有收到客户端消息，服务端可能会断开连接。

---

## 事件统计

| 类型 | 数量 |
|------|------|
| 客户端发送事件 | 5 种 |
| 服务端推送事件 | 22 种 |

---

**文档最后更新**: 2026-01-13
