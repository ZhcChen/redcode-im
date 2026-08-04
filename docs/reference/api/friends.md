# 好友接口

## GET /friends/requests?direction=incoming&status=pending — 获取好友请求列表

按方向与状态筛选好友请求。direction: incoming|outgoing；status: pending|accepted|declined。

- 需要认证：是
- 标识：listFriendRequests

### 请求体
无

### 响应
#### HTTP 200
成功，返回 FriendRequestInfo 数组
示例：
```json
[
  {
    "id": "3c6f0a9b-1d2e-4f6a-9a7b-2c4d5e6f7a8b",
    "requester": {
      "id": "e1b2c3d4-5f67-8901-2345-67890abcde01",
      "username": "alice",
      "email": "alice@example.com",
      "nickname": "Alice",
      "avatar_url": null,
      "status": "active"
    },
    "addressee": {
      "id": "f2c3d4e5-6f78-9012-3456-7890abcdef12",
      "username": "bob",
      "email": "bob@example.com",
      "nickname": "Bob",
      "avatar_url": null,
      "status": "active"
    },
    "status": "pending",
    "message": "你好，加个好友～",
    "created_at": "2025-10-20T10:00:00Z",
    "responded_at": null,
    "is_incoming": true
  }
]
```

#### HTTP 401
未授权（鉴权中间件层返回空响应体）

## POST /friends/requests — 创建好友请求

向目标用户发送好友请求，可附带一段打招呼内容。

- 需要认证：是
- 标识：createFriendRequest

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": [
    "target_user_id"
  ],
  "properties": {
    "target_user_id": {
      "type": "string",
      "description": "目标用户ID (UUID)",
      "example": "f2c3d4e5-6f78-9012-3456-7890abcdef12"
    },
    "message": {
      "type": "string",
      "description": "打招呼内容（可选）",
      "example": "你好，我们同事，方便加个好友吗？"
    }
  }
}
```
- 示例：
```json
{
  "target_user_id": "f2c3d4e5-6f78-9012-3456-7890abcdef12",
  "message": "你好，我们同事，方便加个好友吗？"
}
```

### 响应
#### HTTP 200
成功，返回创建的请求
示例：
```json
{
  "id": "3c6f0a9b-1d2e-4f6a-9a7b-2c4d5e6f7a8b",
  "requester": {
    "id": "e1b2c3d4-5f67-8901-2345-67890abcde01",
    "username": "alice",
    "email": "alice@example.com",
    "nickname": "Alice",
    "avatar_url": null,
    "status": "active"
  },
  "addressee": {
    "id": "f2c3d4e5-6f78-9012-3456-7890abcdef12",
    "username": "bob",
    "email": "bob@example.com",
    "nickname": "Bob",
    "avatar_url": null,
    "status": "active"
  },
  "status": "pending",
  "message": "你好，我们同事，方便加个好友吗？",
  "created_at": "2025-10-20T10:00:00Z",
  "responded_at": null,
  "is_incoming": false
}
```

#### HTTP 401
未授权（鉴权中间件层返回空响应体）

#### HTTP 404
目标用户不存在
示例：
```json
{
  "code": 40401,
  "message": "目标用户不存在"
}
```

## POST /friends/requests/:request_id/respond — 响应好友请求

同意或拒绝好友请求。action: accept|decline。

- 需要认证：是
- 标识：respondFriendRequest

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": [
    "action"
  ],
  "properties": {
    "action": {
      "type": "string",
      "description": "响应动作：accept 或 decline",
      "example": "accept"
    }
  }
}
```
- 示例：
```json
{
  "action": "accept"
}
```

### 响应
#### HTTP 200
成功，返回更新后的请求信息
示例：
```json
{
  "id": "3c6f0a9b-1d2e-4f6a-9a7b-2c4d5e6f7a8b",
  "requester": {
    "id": "e1b2c3d4-5f67-8901-2345-67890abcde01",
    "username": "alice",
    "email": "alice@example.com",
    "nickname": "Alice",
    "avatar_url": null,
    "status": "active"
  },
  "addressee": {
    "id": "f2c3d4e5-6f78-9012-3456-7890abcdef12",
    "username": "bob",
    "email": "bob@example.com",
    "nickname": "Bob",
    "avatar_url": null,
    "status": "active"
  },
  "status": "accepted",
  "message": "你好，我们同事，方便加个好友吗？",
  "created_at": "2025-10-20T10:00:00Z",
  "responded_at": "2025-10-20T10:05:00Z",
  "is_incoming": true
}
```

#### HTTP 401
未授权（鉴权中间件层返回空响应体）

#### HTTP 404
请求不存在
示例：
```json
{
  "code": 40401,
  "message": "请求不存在"
}
```

## POST /friends/:friend_user_id/chat — 确保与好友的单聊房间存在

若不存在则创建，返回房间与对方信息。

- 需要认证：是
- 标识：ensurePrivateChat

### 请求体
无

### 响应
#### HTTP 200
成功返回房间信息
示例：
```json
{
  "room_id": "8b2d5f33-1a6a-4c8a-9c2e-1c7b7fc6e5a1",
  "room_name": "Alice · Bob",
  "room_type": "private",
  "friend_id": "e2b3c4d5-6f78-9012-3456-7890abcdef12",
  "friend_name": "Bob 昵称",
  "friend_avatar": "https://example.com/avatar/bob.png"
}
```

#### HTTP 401
未授权（鉴权中间件层返回空响应体）

#### HTTP 404
好友不存在或已停用
示例：
```json
{
  "code": 40401,
  "message": "好友不存在或已停用"
}
```

## GET /friends — 获取好友列表

获取当前用户的全部好友。

- 需要认证：是
- 标识：listFriends

### 请求体
无

### 响应
#### HTTP 200
成功，返回 FriendInfo 数组（无好友时为空数组）：
```json
[
  {
    "id": "5c6d7e8f-9012-3456-7890-abcdef123456",
    "user": {
      "id": "f2c3d4e5-6f78-9012-3456-7890abcdef12",
      "username": "bob",
      "email": "bob@example.com",
      "nickname": "Bob",
      "avatar_url": null,
      "avatar_object_key": null,
      "signature": null,
      "status": "active"
    },
    "created_at": "2025-10-20T10:00:00Z",
    "friend_remark": "小明同学"
  }
]
```

#### HTTP 401
未授权（鉴权中间件层返回空响应体）

## PATCH /friends/:friend_user_id/remark — 更新好友备注

设置或更新好友的备注名；`remark` 传空串可清除备注。

- 需要认证：是
- 标识：updateFriendRemark

### 请求体
```json
{
  "remark": "小明同学"
}
```

### 响应
#### HTTP 200
```json
{
  "remark": "小明同学"
}
```

#### HTTP 400
不能给自己设置备注（code 42201）

#### HTTP 401
未授权（鉴权中间件层返回空响应体）

## DELETE /friends/:friend_user_id — 删除好友

删除与指定用户的好友关系（双向删除），并向双方在线连接推送
`friendship_deleted` 事件（见 `websocket.md` 事件 19）。

- 需要认证：是
- 标识：deleteFriend

### 响应
#### HTTP 200
```json
{
  "success": true,
  "message": "删除好友成功"
}
```

#### HTTP 404
好友关系不存在
```json
{
  "code": 40401,
  "message": "好友关系不存在"
}
```
