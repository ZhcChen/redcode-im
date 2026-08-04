# 群公告接口

每个群至多一条当前公告（覆盖式更新）。群主/管理员可发布与删除，群成员可读。
发布或删除后，服务端向群内在线成员推送 WebSocket 事件
`group_announcement_updated`（事件编号 23，见 `websocket.md`）。

- 版本：API 2.0.0
- 认证：以下接口均需要 `Authorization: Bearer <token>`

## 权限规则

| 角色 | 读取 | 发布/更新 | 删除 |
|---|---|---|---|
| 群主 | ✅ | ✅ | ✅ |
| 群管理员 | ✅ | ✅ | ✅ |
| 群成员 | ✅ | ❌（403） | ❌（403） |
| 非成员 | ❌（403） | ❌（403） | ❌（403） |

- 非群聊房间调用返回 `422`。

## 1. 获取群公告

- **方法**：`GET`
- **路径**：`/rooms/{room_id}/announcement`
- **认证**：是

响应：

```json
{
  "roomId": "550e8400-e29b-41d4-a716-446655440000",
  "content": "本周六晚 8 点群例会",
  "createdBy": "550e8400-e29b-41d4-a716-446655440000",
  "updatedBy": "550e8400-e29b-41d4-a716-446655440000",
  "createdAt": "2026-08-04T10:00:00Z",
  "updatedAt": "2026-08-04T10:30:00Z"
}
```

- 无公告时返回 `404`。

## 2. 发布 / 更新群公告

- **方法**：`PUT`
- **路径**：`/rooms/{room_id}/announcement`
- **认证**：是（仅群主/管理员）

请求体：

```json
{
  "content": "本周六晚 8 点群例会"
}
```

响应与 `GET` 相同；`content` 为空返回 `422`。

发布成功后，群内在线成员收到：

```json
{
  "type": "group_announcement_updated",
  "room_id": "550e8400-e29b-41d4-a716-446655440000",
  "content": "本周六晚 8 点群例会",
  "updated_by": "550e8400-e29b-41d4-a716-446655440000",
  "updated_at": "2026-08-04T10:30:00Z"
}
```

## 3. 删除群公告

- **方法**：`DELETE`
- **路径**：`/rooms/{room_id}/announcement`
- **认证**：是（仅群主/管理员）

响应：

```json
{ "success": true }
```

删除后推送 `group_announcement_updated`，其中 `content` 为 `null`：

```json
{
  "type": "group_announcement_updated",
  "room_id": "550e8400-e29b-41d4-a716-446655440000",
  "content": null,
  "updated_by": "550e8400-e29b-41d4-a716-446655440000",
  "updated_at": "2026-08-04T10:35:00Z"
}
```

- 无公告时删除返回 `404`。
