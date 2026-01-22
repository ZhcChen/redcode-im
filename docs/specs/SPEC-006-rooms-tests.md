# SPEC-006: Rooms 模块测试完善技术规范

> 版本: 1.0
> 日期: 2026-01-22
> 对应 PRD: PRD-006 Phase 6

## 1. 概述

完善 `/rooms/{}/...` 下 50 个未覆盖路由的测试。

## 2. 已覆盖路由（现有测试）

| 文件 | 路由 | 用例数 |
|------|------|--------|
| rooms_tests.rs | POST/GET /rooms, PATCH /rooms/{}, members, join, leave | 10 |
| messages_tests.rs | messages CRUD, read, reactions, pin | 9 |
| **合计** | - | **19** |

## 3. 未覆盖路由分析（50 个）

### 3.1 房间基础操作 (5)

| 方法 | 路由 | 说明 |
|------|------|------|
| DELETE | `/rooms/{}` | 删除房间 |
| GET | `/rooms/{}` | 获取房间（返回 ChatSummary） |
| GET | `/rooms/{}/detail` | 获取群组详情 |
| GET | `/rooms/{}/settings` | 获取房间设置 |
| PATCH | `/rooms/{}/settings` | 更新房间设置 |

### 3.2 成员/管理员管理 (8)

| 方法 | 路由 | 说明 |
|------|------|------|
| GET | `/rooms/{}/admins` | 管理员列表 |
| POST | `/rooms/{}/admins` | 添加管理员 |
| DELETE | `/rooms/{}/admins/{}` | 移除管理员 |
| POST | `/rooms/{}/members` | 添加成员（群主） |
| POST | `/rooms/{}/members/add` | 批量添加成员 |
| DELETE | `/rooms/{}/members/{}` | 移除成员 |
| POST | `/rooms/{}/transfer` | 转让群主 |

### 3.3 邀请/加入申请 (6)

| 方法 | 路由 | 说明 |
|------|------|------|
| POST | `/rooms/{}/invitations` | 发送邀请 |
| PATCH | `/rooms/{}/invitations/{}/respond` | 响应邀请 |
| GET | `/rooms/{}/join-requests` | 加入申请列表 |
| POST | `/rooms/{}/join-requests` | 提交加入申请 |
| POST | `/rooms/{}/join-requests/{}/review` | 审核申请 |
| PATCH | `/rooms/{}/join-requests/{}/review` | 审核申请（兼容） |

### 3.4 规则/禁言 (8)

| 方法 | 路由 | 说明 |
|------|------|------|
| GET | `/rooms/{}/rules` | 规则列表 |
| POST | `/rooms/{}/rules` | 创建规则 |
| PATCH | `/rooms/{}/rules/{}` | 更新规则 |
| DELETE | `/rooms/{}/rules/{}` | 删除规则 |
| GET | `/rooms/{}/mutes` | 禁言列表 |
| POST | `/rooms/{}/mutes` | 禁言用户 |
| POST | `/rooms/{}/mutes/global` | 全局禁言 |
| DELETE | `/rooms/{}/mutes/{}` | 解除禁言 |

### 3.5 消息扩展 (8)

| 方法 | 路由 | 说明 |
|------|------|------|
| DELETE | `/rooms/{}/messages` | 批量删除消息 |
| DELETE | `/rooms/{}/messages/{}/pin` | 取消置顶 |
| DELETE | `/rooms/{}/messages/{}/reactions` | 移除反应 |
| GET | `/rooms/{}/messages/{}/reactions` | 反应列表 |
| GET | `/rooms/{}/messages/{}/reads` | 已读列表 |
| POST | `/rooms/{}/messages/forward` | 转发消息 |
| POST | `/rooms/{}/messages/read_until` | 批量已读 |
| POST | `/rooms/{}/messages/encrypted` | 加密消息 |

### 3.6 其他 (5)

| 方法 | 路由 | 说明 |
|------|------|------|
| GET | `/rooms/{}/unread_count` | 未读数 |
| POST | `/rooms/{}/notification-settings` | 通知设置 |
| GET | `/rooms/{}/operation-logs` | 操作日志 |
| POST | `/rooms/{}/pin` | 置顶房间 |
| DELETE | `/rooms/{}/pin` | 取消置顶房间 |

## 4. 测试用例设计（45 用例）

### 4.1 房间基础 (6 用例)

```
delete_room_success                    - 群主删除房间
delete_room_not_owner_fails            - 非群主删除返回 403
get_room_success                       - 获取房间信息
get_room_detail_success                - 获取群组详情
get_room_settings_success              - 获取房间设置
update_room_settings_success           - 更新房间设置
```

### 4.2 成员管理 (10 用例)

```
list_admins_success                    - 获取管理员列表
add_admin_success                      - 添加管理员
add_admin_not_owner_fails              - 非群主添加管理员返回 403
remove_admin_success                   - 移除管理员
add_member_success                     - 群主添加成员
add_members_batch_success              - 批量添加成员
remove_member_success                  - 移除成员
remove_member_not_admin_fails          - 非管理员移除返回 403
transfer_ownership_success             - 转让群主
transfer_ownership_not_owner_fails     - 非群主转让返回 403
```

### 4.3 邀请/申请 (8 用例)

```
send_invitation_success                - 发送邀请
respond_invitation_accept              - 接受邀请
respond_invitation_reject              - 拒绝邀请
list_join_requests_success             - 加入申请列表
submit_join_request_success            - 提交加入申请
review_join_request_approve            - 审核通过申请
review_join_request_reject             - 审核拒绝申请
join_request_requires_review           - 私密群需要审核
```

### 4.4 规则/禁言 (8 用例)

```
list_rules_success                     - 规则列表
create_rule_success                    - 创建规则
update_rule_success                    - 更新规则
delete_rule_success                    - 删除规则
list_mutes_success                     - 禁言列表
mute_user_success                      - 禁言用户
global_mute_success                    - 全局禁言
unmute_user_success                    - 解除禁言
```

### 4.5 消息扩展 (8 用例)

```
batch_delete_messages_success          - 批量删除消息
unpin_message_success                  - 取消置顶
remove_reaction_success                - 移除反应
list_reactions_success                 - 反应列表
list_message_reads_success             - 已读列表
forward_message_success                - 转发消息
mark_read_until_success                - 批量已读
send_encrypted_message_success         - 加密消息
```

### 4.6 其他 (5 用例)

```
get_unread_count_success               - 获取未读数
update_notification_settings_success   - 更新通知设置
list_operation_logs_success            - 操作日志列表
pin_room_success                       - 置顶房间
unpin_room_success                     - 取消置顶房间
```

## 5. 实现要点

### 5.1 测试前置条件

大部分测试需要：
1. 创建群组房间（非公共房间）
2. 至少 2-3 个用户
3. 群主 + 成员 + 非成员角色

### 5.2 辅助函数（需新增）

```rust
// common.rs 新增
pub async fn create_private_group(app: Router, token: &str, name: &str, member_ids: &[&str]) -> String
pub async fn send_message(app: Router, token: &str, room_id: &str, content: &str) -> String
```

### 5.3 文件结构

```
backend/tests/api/
├── rooms_tests.rs      [EXPAND] 房间基础 + 成员 + 邀请
├── messages_tests.rs   [EXPAND] 消息扩展测试
└── common.rs           [UPDATE] 新增辅助函数
```

## 6. 验收标准

| 指标 | 当前 | 目标 |
|------|------|------|
| rooms 相关用例 | 19 | **64** (+45) |
| 覆盖路由 | 57 | **100+** |

## 7. 预计新增测试

| 文件 | 新增用例 |
|------|----------|
| rooms_tests.rs | +27 |
| messages_tests.rs | +18 |
| **合计** | **+45** |
