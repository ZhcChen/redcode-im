# 数据模型接口

## INFO  — 字段说明 / 模型定义

本项目主要数据模型与枚举说明，便于前后端对齐。

- 需要认证：否
- 标识：models-overview

### 请求体
无

### 响应
#### HTTP 200
模型与枚举
示例：
```json
{
  "enums": {
    "RoomType": [
      "private",
      "group",
      "public"
    ],
    "MessageType": [
      "text",
      "image",
      "file",
      "system"
    ],
    "FriendRequestStatus": [
      "pending",
      "accepted",
      "declined"
    ]
  },
  "models": {
    "UserInfo": {
      "id": "string(uuid)",
      "username": "string",
      "email": "string(email)",
      "nickname": "string|null",
      "avatar_url": "string|null",
      "status": "active|inactive|banned"
    },
    "ChatMessagePreview": {
      "id": "string(uuid)",
      "content": "string",
      "message_type": "MessageType",
      "created_at": "string(ISO8601)",
      "sender_id": "string(uuid)",
      "sender_username": "string",
      "sender_nickname": "string|null"
    },
    "ChatSummary": {
      "room_id": "string(uuid)",
      "name": "string",
      "room_type": "RoomType",
      "avatar_url": "string|null",
      "description": "string|null",
      "unread_count": "number",
      "last_read_message_id": "string(uuid)|null",
      "last_read_at": "string(ISO8601)|null",
      "last_message": "ChatMessagePreview|null"
    },
    "MessageInfo": {
      "id": "string(uuid)",
      "room_id": "string(uuid)",
      "sender_id": "string(uuid)",
      "sender_username": "string",
      "sender_nickname": "string|null",
      "sender_avatar_url": "string|null",
      "content": "string",
      "message_type": "MessageType",
      "created_at": "string(ISO8601)"
    },
    "FriendRequestInfo": {
      "id": "string(uuid)",
      "requester": "UserInfo",
      "addressee": "UserInfo",
      "status": "FriendRequestStatus",
      "message": "string|null",
      "created_at": "string(ISO8601)",
      "responded_at": "string(ISO8601)|null",
      "is_incoming": "boolean"
    },
    "EnsureChatResponse": {
      "room_id": "string(uuid)",
      "room_name": "string",
      "room_type": "RoomType",
      "friend_id": "string(uuid)",
      "friend_name": "string",
      "friend_avatar": "string|null"
    }
  }
}
```
