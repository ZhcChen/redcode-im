# 会话与历史数据生命周期

RedCode IM 将群成员关系、会话收件箱、消息历史和设备缓存拆开管理，避免“清空会话”误伤群成员关系或整个房间历史。

## 数据所有权

| 数据 | 事实来源 | 作用 |
| --- | --- | --- |
| 群成员关系 | `rooms` + `room_members` | 决定用户是否仍在群中，以及是否出现在群目录 |
| 群目录收藏 | `user_room_preferences.group_directory_favorited_at` | 当前用户在联系人群目录中的优先显示偏好 |
| 会话归档 | `user_room_preferences.chat_archived_at` | 当前用户暂时从聊天收件箱隐藏某个会话 |
| 服务端消息历史 | `messages` + `message_parts` | 仅 `persist` 模式下的可恢复消息记录 |
| 本机消息缓存 | 客户端 SQLite / IndexedDB / OPFS | 加速展示、离线回退和 `relay_only` 本机历史 |

## 用户动作

| 用户意图 | 正确动作 | 影响范围 |
| --- | --- | --- |
| 清除本机消息缓存 | 客户端删除本地消息库 | 仅当前设备；不调用服务端消息删除接口 |
| 从聊天列表暂时移除会话 | `DELETE /chats/{room_id}` | 仅当前用户的收件箱；保留房间、成员关系和消息 |
| 恢复归档会话 | `POST /chats/{room_id}/restore` | 仅当前用户的收件箱 |
| 收藏群聊 | `POST /rooms/{room_id}/directory-favorite` | 仅当前用户的联系人群目录排序 |
| 取消收藏群聊 | `DELETE /rooms/{room_id}/directory-favorite` | 仅取消排序优先级，不退出群 |
| 退出群聊 | `POST /rooms/{room_id}/leave` | 当前用户的群成员关系结束，群目录不再展示 |
| 解散群聊 | `DELETE /rooms/{room_id}` | 仅群主；结束整群及成员关系 |
| 清空整个房间历史 | `DELETE /rooms/{room_id}/messages` | 房间级操作；私聊由任一成员执行，群聊仅群主执行，并广播给全体成员 |

## 消息运行模式

### `persist`

消息写入 PostgreSQL。归档会话后，如果该房间产生了新的持久化消息，`GET /chats` 会重新返回该会话；群目录始终可通过 `GET /groups/directory` 恢复。

### `relay_only`

消息正文不写入服务端历史，客户端可保留自己的本机缓存。群成员关系、群目录收藏和会话归档仍是轻量用户/房间元数据，继续由服务端保存；由于服务端没有新的消息记录可用于判断归档后的活动，客户端收到新的实时消息后应调用恢复会话接口，或在本机收件箱中恢复该会话。

## 禁止的替代实现

- 不把群成员关系写入好友关系表。
- 不用 `RoomType::Favorite` 表达“收藏群聊”。
- 不用 `user_room_pins` 表达联系人群目录收藏。
- 不把 `DELETE /rooms/{room_id}/messages` 暴露为常规“清除我的聊天记录”操作。
- 不把本机缓存清除等同于退出群或解散群。
