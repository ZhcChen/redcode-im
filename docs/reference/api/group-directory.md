# 群目录接口

群目录是当前用户仍有效的群成员关系视图，与聊天收件箱、消息历史和本机缓存分离。即使当前用户归档了群会话，群仍会保留在该目录中。

## GET /groups/directory

返回当前用户加入且未离开的 `group` 类型房间。收藏群排在前面，随后按房间更新时间排序。

- 需要认证：是
- 消息运行模式：`persist` 与 `relay_only` 都可用
- 不依赖最后一条消息或未读数

### 响应

```json
[
  {
    "room_id": "8b2d5f33-1a6a-4c8a-9c2e-1c7b7fc6e5a1",
    "name": "产品评审群",
    "description": "移动端评审",
    "avatar_url": null,
    "avatar_object_key": null,
    "member_count": 18,
    "is_favorited": true,
    "favorited_at": "2026-07-28T09:55:00Z"
  }
]
```

## POST /rooms/:room_id/directory-favorite

收藏当前用户已经加入的群聊，使其优先显示在群目录中。

- 需要认证：是
- 权限：当前用户必须是该群有效成员
- 非群聊房间返回验证错误
- 幂等：重复调用会刷新收藏时间

### 响应

```json
{
  "room_id": "8b2d5f33-1a6a-4c8a-9c2e-1c7b7fc6e5a1",
  "is_favorited": true,
  "favorited_at": "2026-07-28T09:55:00Z"
}
```

## DELETE /rooms/:room_id/directory-favorite

取消收藏当前用户已经加入的群聊。取消收藏不会退出群，也不会让该群从群目录消失。

- 需要认证：是
- 权限：当前用户必须是该群有效成员
- 幂等：未收藏时仍返回 `is_favorited: false`

### 响应

```json
{
  "room_id": "8b2d5f33-1a6a-4c8a-9c2e-1c7b7fc6e5a1",
  "is_favorited": false
}
```

## 数据边界

- 群成员关系来自 `rooms` 和 `room_members`。
- 收藏状态来自当前用户的 `user_room_preferences.group_directory_favorited_at`。
- `RoomType::Favorite` 是私人收藏夹房间，与群目录收藏没有关系。
- `user_room_pins` 是聊天收件箱置顶，与群目录收藏没有关系。
