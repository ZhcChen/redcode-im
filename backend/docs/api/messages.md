# 消息接口

## POST /rooms/:room_id/messages — 发送消息

向指定房间发送消息。需要认证。可选 message_type: text/image/file/system（默认 text）。

- 需要认证：是
- 标识：sendMessage

### 请求体
- Content-Type：application/json
- Schema：
```json
{
  "type": "object",
  "required": [
    "content"
  ],
  "properties": {
    "content": {
      "type": "string",
      "description": "消息内容",
      "example": "大家好"
    },
    "message_type": {
      "type": "string",
      "description": "消息类型，可选 text/image/file/system",
      "example": "text"
    }
  }
}
```
- 示例：
```json
{
  "content": "大家好",
  "message_type": "text"
}
```

### 响应
#### HTTP 200
发送成功，返回消息对象
示例：
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "room_id": "11111111-2222-3333-4444-555555555555",
  "sender_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "content": "大家好",
  "message_type": "text",
  "created_at": "2024-10-10T10:00:00Z",
  "updated_at": "2024-10-10T10:00:00Z"
}
```

#### HTTP 401
未授权
示例：
```json
{
  "error": "Unauthorized"
}
```

#### HTTP 403
非房间成员禁止发送
示例：
```json
{
  "error": "Not a room member"
}
```

## GET /rooms/:room_id/messages?limit=50 — 获取消息列表

按时间倒序获取房间最近消息。支持查询参数 limit(1-200)，默认50。需要认证。

- 需要认证：是
- 标识：listMessages

### 请求体
无

### 响应
#### HTTP 200
获取成功，返回消息数组（倒序）
示例：
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "room_id": "11111111-2222-3333-4444-555555555555",
    "sender_id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    "content": "大家好",
    "message_type": "text",
    "created_at": "2024-10-10T10:00:00Z",
    "updated_at": "2024-10-10T10:00:00Z"
  }
]
```

#### HTTP 401
未授权
示例：
```json
{
  "error": "Unauthorized"
}
```

#### HTTP 403
非房间成员禁止访问
示例：
```json
{
  "error": "Not a room member"
}
```
