# SPEC-008: Phase 8 测试完善技术规范

> 版本: 1.0
> 日期: 2026-01-22
> 对应 PRD: PRD-006 Phase 8

## 1. 概述

补充 Phase 1-7 未覆盖的可测试路由，排除存储/上传/推送/SMS/外部服务依赖的路由。

## 2. 当前覆盖情况

| 模块 | 已覆盖路由 | 未覆盖可测试路由 |
|------|-----------|-----------------|
| rooms | 30+ | ~10 |
| auth | 5 | ~4 |
| users | 2 | ~2 |
| activity | 3 | ~2 |

## 3. 未覆盖可测试路由分析（18 个）

### 3.1 Rooms 扩展 (10)

| 方法 | 路由 | 说明 |
|------|------|------|
| POST | `/rooms/{}/invitations` | 发送邀请 |
| PATCH | `/rooms/{}/invitations/{}/respond` | 响应邀请 |
| POST | `/rooms/{}/join-requests` | 申请加入 |
| GET | `/rooms/{}/join-requests` | 获取加入请求列表 |
| PATCH | `/rooms/{}/join-requests/{}/review` | 审核加入请求 |
| POST | `/rooms/{}/members/add` | 添加成员 |
| POST | `/rooms/{}/rules` | 创建规则 |
| PATCH | `/rooms/{}/rules/{}` | 更新规则 |
| DELETE | `/rooms/{}/rules/{}` | 删除规则 |
| POST | `/rooms/{}/mutes/global` | 全局禁言 |

### 3.2 Auth 扩展 (4)

| 方法 | 路由 | 说明 |
|------|------|------|
| POST | `/auth/refresh` | Token 刷新 |
| POST | `/auth/admin/refresh` | 管理员 Token 刷新 |
| POST | `/auth/admin/me/password` | 修改管理员密码 |
| PATCH | `/auth/admin/me` | 更新管理员信息 |

### 3.3 Users 扩展 (2)

| 方法 | 路由 | 说明 |
|------|------|------|
| GET | `/users/{}` | 获取用户信息 |
| GET | `/unread_counts` | 全局未读数 |

### 3.4 Activity 扩展 (2)

| 方法 | 路由 | 说明 |
|------|------|------|
| POST | `/activity/login` | 记录登录活动 |
| POST | `/activity/login/{}/logout` | 记录登出活动 |

## 4. 排除路由

- SMS 相关 (`/auth/sms/*`, `/auth/login/sms`) - 用户要求跳过
- OAuth (`/auth/login/oauth`) - 需要外部服务
- 密码重置 (`/auth/password/reset`) - 需要邮件服务

## 5. 测试用例设计（18 用例）

### 5.1 Rooms 扩展 (10 用例)

```
send_invitation_success                 - 发送邀请
respond_invitation_accept              - 接受邀请
create_join_request_success            - 申请加入需审批房间
list_join_requests_success             - 获取加入请求列表
review_join_request_approve            - 审批通过加入请求
add_members_batch_success              - 批量添加成员
create_room_rule_success               - 创建房间规则
update_room_rule_success               - 更新房间规则
delete_room_rule_success               - 删除房间规则
global_mute_success                    - 全局禁言
```

### 5.2 Auth 扩展 (4 用例)

```
refresh_token_success                  - 用户 Token 刷新
admin_refresh_token_success            - 管理员 Token 刷新
admin_change_password_success          - 管理员修改密码
admin_update_profile_success           - 管理员更新信息
```

### 5.3 Users 扩展 (2 用例)

```
get_user_by_id_success                 - 获取用户信息
get_global_unread_counts_success       - 获取全局未读数
```

### 5.4 Activity 扩展 (2 用例)

```
record_login_activity_success          - 记录登录活动
record_logout_activity_success         - 记录登出活动
```

## 6. 验收标准

| 指标 | 当前 | 目标 |
|------|------|------|
| API 测试总数 | 201 | **219** (+18) |
| Rust 路由覆盖 | 72 | **90** (+18) |

## 7. 文件结构

```
backend/tests/api/
├── rooms_tests.rs   [EXPAND] +10 用例
├── auth_tests.rs    [EXPAND] +4 用例
├── users_tests.rs   [EXPAND] +2 用例
└── activity_tests.rs [EXPAND] +2 用例
```
