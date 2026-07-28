# 会话接口

## GET /chats — 获取会话列表

返回当前用户的会话概要列表（含未读数和最后一条消息预览）。

- 需要认证：是
- 标识：listChats

### 请求体
无

### 响应
#### HTTP 200
成功，返回 ChatSummary 数组
示例：
```json
[
  {
    "room_id": "8b2d5f33-1a6a-4c8a-9c2e-1c7b7fc6e5a1",
    "name": "Alice · Bob",
    "room_type": "private",
    "avatar_url": null,
    "description": null,
    "unread_count": 3,
    "last_read_message_id": "1f9d2a9e-9b82-4c3f-9b60-f0c4a7f7b1c2",
    "last_read_at": "2025-10-20T10:15:20Z",
    "last_message": {
      "id": "a3f9a9f1-2d34-45e2-9a3b-9c7e2f1d2a3b",
      "content": "你好",
      "message_type": "text",
      "created_at": "2025-10-20T10:10:00Z",
      "sender_id": "e1b2c3d4-5f67-8901-2345-67890abcde01",
      "sender_username": "alice",
      "sender_nickname": "Alice 昵称"
    },
    "friend_user_id": "e1b2c3d4-5f67-8901-2345-67890abcde01",
    "friend_avatar_object_key": "avatars/e1b2c3d4-5f67-8901-2345-67890abcde01/avatar.png"
  }
]
```

**注意**：对于单聊（`room_type: "private"`），会额外返回以下字段（群聊和收藏夹不返回）：
- `friend_user_id`：对方用户的 ID
- `friend_avatar_object_key`：对方用户的头像对象键（对象存储路径）

#### HTTP 401
未授权
示例：
```json
{
  "error": "Unauthorized"
}
```

## DELETE /chats/:room_id — 归档会话

将当前用户的会话从聊天收件箱归档，不删除房间、群成员关系或消息历史。

- 需要认证：是
- 权限：当前用户必须是该房间有效成员
- `persist`：新消息写入服务端后会重新出现在 `GET /chats`
- `relay_only`：客户端收到新的实时消息后应调用恢复接口，或在本机收件箱中恢复

响应：

```json
{
  "success": true,
  "archived_at": "2026-07-28T09:55:00Z"
}
```

## POST /chats/:room_id/restore — 恢复归档会话

恢复当前用户已归档的会话。该操作不改变其他成员的收件箱，也不改变群成员关系。

- 需要认证：是
- 权限：当前用户必须是该房间有效成员

响应：

```json
{
  "success": true
}
```
