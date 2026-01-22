# SPEC-007: Admin 模块测试完善技术规范

> 版本: 1.0
> 日期: 2026-01-22
> 对应 PRD: PRD-006 Phase 7

## 1. 概述

完善 `/api/admin/...` 下未覆盖路由的测试，排除存储/上传/推送/外部服务依赖的路由。

## 2. 已覆盖路由（现有测试）

| 文件 | 路由 | 用例数 |
|------|------|--------|
| admin_tests.rs | login, me, dashboard, users, roles, files, logs | 27 |

## 3. 未覆盖可测试路由分析（30 个）

### 3.1 用户管理 (6)

| 方法 | 路由 | 说明 |
|------|------|------|
| PATCH | `/api/admin/users/{}` | 更新用户信息 |
| DELETE | `/api/admin/users/{}` | 删除用户 |
| POST | `/api/admin/users/{}/password/reset` | 重置用户密码 |
| GET | `/api/admin/users/{}/rooms` | 用户房间列表 |
| GET | `/api/admin/users/geolocation/distribution` | 用户地理分布 |

### 3.2 管理员账号 (4)

| 方法 | 路由 | 说明 |
|------|------|------|
| POST | `/api/admin/admin-users` | 创建管理员 |
| PATCH | `/api/admin/admin-users/{}/status` | 更新管理员状态 |
| POST | `/api/admin/reset-admin-password` | 重置管理员密码 |
| GET | `/api/admin/check-admin-users` | 检查管理员存在 |

### 3.3 角色权限 (4)

| 方法 | 路由 | 说明 |
|------|------|------|
| POST | `/api/admin/roles` | 创建角色 |
| PATCH | `/api/admin/roles/{}` | 更新角色 |
| DELETE | `/api/admin/roles/{}` | 删除角色 |
| POST | `/api/admin/permissions/check` | 权限检查 |

### 3.4 系统设置 (10)

| 方法 | 路由 | 说明 |
|------|------|------|
| GET | `/api/admin/settings/privacy-policy` | 隐私政策 |
| POST | `/api/admin/settings/privacy-policy` | 更新隐私政策 |
| GET | `/api/admin/settings/user-agreement` | 用户协议 |
| POST | `/api/admin/settings/user-agreement` | 更新用户协议 |
| GET | `/api/admin/settings/user-account-limit` | 账号限制 |
| PUT | `/api/admin/settings/user-account-limit` | 更新账号限制 |
| PUT | `/api/admin/settings/app-name` | 更新应用名称 |
| POST | `/api/admin/settings/captcha` | 更新验证码设置 |

### 3.5 系统监控 (4)

| 方法 | 路由 | 说明 |
|------|------|------|
| GET | `/api/admin/chat-history` | 聊天记录 |
| GET | `/api/admin/rooms/{}/chat-history` | 房间聊天记录 |
| GET | `/api/admin/metrics/performance` | 性能指标 |
| GET | `/api/admin/nodes/monitor` | 节点监控 |

### 3.6 其他 (2)

| 方法 | 路由 | 说明 |
|------|------|------|
| POST | `/api/admin/logs/cleanup` | 日志清理 |
| PATCH | `/auth/admin/me` | 更新管理员信息 |

## 4. 排除路由（依赖外部服务）

以下路由因依赖存储/上传/推送/外部服务而跳过：

- `/api/admin/storage-providers/*` - 存储服务
- `/api/admin/uploads/*` - 上传服务
- `/api/admin/files/batch-delete` - 存储服务
- `/api/admin/push/*` - 推送服务
- `/api/admin/emoji-*` - 需要文件上传
- `/api/admin/hot-updates/*` - 需要文件上传
- `/api/admin/app-versions/*` - 需要文件上传
- `/api/admin/ipinfo-tokens/*` - 外部 IP 服务
- `/api/admin/test-geolocation-api` - 外部服务

## 5. 测试用例设计（25 用例）

### 5.1 用户管理 (5 用例)

```
admin_update_user_success              - 更新用户信息
admin_delete_user_success              - 删除用户
admin_reset_user_password_success      - 重置用户密码
admin_get_user_rooms_success           - 获取用户房间列表
admin_get_user_geolocation_dist        - 获取用户地理分布
```

### 5.2 管理员账号 (4 用例)

```
admin_create_admin_user_success        - 创建管理员
admin_update_admin_status_success      - 更新管理员状态
admin_reset_admin_password_success     - 重置管理员密码
admin_check_admin_users_success        - 检查管理员存在
```

### 5.3 角色权限 (4 用例)

```
admin_create_role_success              - 创建角色
admin_update_role_success              - 更新角色
admin_delete_role_success              - 删除角色
admin_check_permissions_success        - 权限检查
```

### 5.4 系统设置 (8 用例)

```
admin_get_privacy_policy_success       - 获取隐私政策
admin_update_privacy_policy_success    - 更新隐私政策
admin_get_user_agreement_success       - 获取用户协议
admin_update_user_agreement_success    - 更新用户协议
admin_get_user_account_limit_success   - 获取账号限制
admin_update_user_account_limit_success- 更新账号限制
admin_update_app_name_success          - 更新应用名称
admin_update_captcha_setting_success   - 更新验证码设置
```

### 5.5 系统监控 (3 用例)

```
admin_get_chat_history_success         - 获取聊天记录
admin_get_room_chat_history_success    - 获取房间聊天记录
admin_get_performance_metrics_success  - 获取性能指标
```

### 5.6 其他 (1 用例)

```
admin_update_me_success                - 更新管理员信息
```

## 6. 验收标准

| 指标 | 当前 | 目标 |
|------|------|------|
| admin 相关用例 | 27 | **52** (+25) |
| API 测试总数 | 182 | **207** (+25) |

## 7. 文件结构

```
backend/tests/api/
└── admin_tests.rs   [EXPAND] +25 用例
```
