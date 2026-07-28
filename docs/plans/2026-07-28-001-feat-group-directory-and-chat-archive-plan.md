---
title: "feat: 群目录收藏与用户级会话归档"
type: feat
status: completed
date: 2026-07-28
---

# feat: 群目录收藏与用户级会话归档

## 背景

群成员关系、聊天收件箱和设备消息缓存属于不同层级。当前群目录需要能从联系人入口稳定恢复，不能依赖最近会话缓存；同时，`DELETE /chats/{room_id}` 不能再破坏整间房间及其他成员关系。

## 目标

- 联系人中的群聊目录返回当前用户仍有效的群成员关系。
- 用户可以收藏群聊，使其在群目录中优先展示；收藏不决定群是否存在于目录中。
- 删除会话改为用户级归档，不影响 `rooms`、`room_members`、其他成员或群目录。
- `persist` 下，新消息可使已归档会话重新进入收件箱；`relay_only` 下客户端收到实时消息后通过恢复接口显式恢复。
- HTML 设计源以 `48px` 会话头像和群聊收藏开关表现上述层级，不改动 Flutter 或 H5 运行端。

## 方案

### 数据模型

新增 `user_room_preferences`：

- 联合主键：`user_id`、`room_id`
- `group_directory_favorited_at`：当前用户收藏群聊的时间
- `chat_archived_at`：当前用户从聊天收件箱归档会话的时间

该表只承载用户级房间偏好，不复用 `RoomType::Favorite`、`user_room_pins` 或群全局设置。

### API

- `GET /groups/directory`：返回所有当前用户仍在其中的 `group` 房间，含成员数、收藏状态和收藏时间。
- `POST /rooms/{room_id}/directory-favorite`：收藏当前用户所在的群聊。
- `DELETE /rooms/{room_id}/directory-favorite`：取消收藏当前用户所在的群聊。
- `DELETE /chats/{room_id}`：归档当前用户的会话，不再删除房间或成员关系。
- `POST /chats/{room_id}/restore`：恢复当前用户已归档的会话。

### UI 设计源

- `Conversation Cell` 的头像提升为 `48px`，会话行最小高度为 `76px`。
- `联系人 > 群聊` 仅在存在收藏群时显示“收藏群聊”分组；未收藏的有效群紧随其后，不重新引入冗余“已加入”标题。
- 群设置增加“我的群聊”中的收藏开关，状态写入设计源 `localStorage`。

## 验证

- 新迁移可在空库中完整执行，且通过 migration guard。
- API 集成测试覆盖收藏隔离、目录稳定性、归档不影响群成员、恢复会话与非成员拒绝。
- HTML 检查覆盖语法、深链、收藏切换、头像尺寸、设备裁切、暗色模式和浏览器控制台。

## 执行结果

- 新增 `20260728175513_user_room_preferences.sql`，本地 dev API 已完成迁移并保持健康。
- 新增群目录与收藏 API，`DELETE /chats/{room_id}` 已收敛为用户级归档，新增恢复接口。
- `room_directory_integration` 覆盖用户隔离、成员关系保留、`persist` 新消息重现、恢复和非成员拒绝。
- HTML 设计源已验证 `48px` 会话头像、收藏群分组、收藏状态持久化、联系人入口返回、暗色主题和两种设备外壳裁切。
- 已通过 `make api.test`、`make api.migration.guard`、`cargo fmt --check`、`cargo check`、`node --check` 与 `git diff --check`。

## 非目标

- 不把房间级 `DELETE /rooms/{room_id}/messages` 改成个人历史清除接口。
- 不修改 Flutter、H5 或桌面运行端；这些端在 HTML 评审确认后再接新契约。
