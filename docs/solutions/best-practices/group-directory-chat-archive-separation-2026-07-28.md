---
title: 群目录、会话归档与消息历史必须按所有权分层
date: 2026-07-28
category: best-practices
module: chat-and-group-domain
problem_type: data_ownership
component: room-preferences
severity: high
applies_when:
  - IM 需要支持从聊天收件箱移除会话，但用户仍应保留群成员关系
  - 联系人页需要提供不依赖最近消息的稳定群目录
  - 产品同时支持服务端消息持久化和 relay-only 实时模式
  - 现有删除会话逻辑可能修改 rooms、room_members 或全局消息历史
tags:
  - im
  - group-directory
  - chat-archive
  - room-membership
  - relay-only
  - postgres
---

# 群目录、会话归档与消息历史必须按所有权分层

## 背景

IM 中“从聊天列表删除”很容易被误实现为删除房间或批量软删除成员关系。这样会让某位成员清理自己的收件箱时影响整群，并使群无法再从联系人入口恢复。

正确做法是将四类状态分开：

- `rooms` + `room_members`：群成员关系
- `user_room_preferences.group_directory_favorited_at`：当前用户的群目录收藏
- `user_room_preferences.chat_archived_at`：当前用户的会话归档
- `messages` + `message_parts`：房间级消息历史

## 处理方式

1. 用用户-房间偏好表承载收藏和归档，联合主键为 `user_id + room_id`。
2. `GET /groups/directory` 只依据有效群成员关系查询，并附带当前用户收藏状态；它不依赖最后消息、未读数或设备缓存。
3. `DELETE /chats/{room_id}` 只写当前用户的 `chat_archived_at`，绝不修改 `rooms` 或 `room_members`。
4. `persist` 模式下，以最新持久化消息时间与归档时间比较，新消息自动让会话回到收件箱。
5. `relay_only` 不保存消息活动状态，客户端收到实时消息后显式调用 `POST /chats/{room_id}/restore`。
6. 用户离群或被移出群时删除对应偏好，避免重加群后带回过时的收藏/归档状态。

## 验证

至少覆盖以下契约：

- 收藏仅对当前用户可见。
- 会话归档不影响其他成员的聊天列表。
- 归档后群仍在 `GET /groups/directory` 中，房间详情仍可访问。
- `persist` 模式下一条新消息会使归档会话重现。
- 恢复会话、取消收藏和非成员拒绝均可验证。
- 数据库迁移 smoke、全量 API Compose 测试、迁移守卫必须通过。

## 不应复用的模型

- `RoomType::Favorite` 是个人收藏夹房间，不是群目录收藏。
- `user_room_pins` 是收件箱置顶，不是群目录排序。
- `DELETE /rooms/{room_id}/messages` 是房间级历史清空，不是个人历史清除。
- 客户端 SQLite / IndexedDB 清理只是本机缓存操作，不改变服务端成员关系。

## 相关资料

- [会话与历史数据生命周期](../../reference/architecture/conversation-state-lifecycle.md)
- [群目录接口](../../reference/api/group-directory.md)
- [群目录收藏与用户级会话归档计划](../../plans/2026-07-28-001-feat-group-directory-and-chat-archive-plan.md)
