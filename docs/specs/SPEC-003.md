# SPEC-003: Backend Rust 测试覆盖率 Phase 3 技术方案

## 1. 概述

本文档为 PRD-003 Phase 3（70% 覆盖率）的技术实现方案。

## 2. 架构设计

### 2.1 测试文件结构

```
backend/tests/
├── api.rs                    # API 测试入口
├── api/
│   ├── common.rs             # 公共工具（扩展）
│   ├── admin_tests.rs        # 新增：Admin API 测试
│   ├── group_tests.rs        # 新增：群组管理测试
│   ├── auth_tests.rs         # 扩展
│   ├── messages_tests.rs     # 扩展
│   └── ...                   # 现有测试
└── ws_tests.rs               # 新增：WebSocket 测试
```

### 2.2 认证机制

#### 2.2.1 普通用户认证（现有）

```rust
// common.rs 已有
pub async fn login_user(app, username, password) -> String  // token
```

#### 2.2.2 管理员认证（新增）

```rust
// common.rs 扩展
pub async fn create_admin_user(app: Router<AppState>) -> (String, String) {
    // 调用 /api/admin/init-default-admin 创建默认管理员
    // 返回 (username, password)
}

pub async fn login_admin(app: Router<AppState>, username: &str, password: &str) -> String {
    // POST /auth/admin/login
    // 返回 admin token
}
```

## 3. 测试用例设计

### 3.1 Admin API 测试 (admin_tests.rs)

#### 3.1.1 仪表盘统计

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `dashboard_stats_success` | `/api/dashboard/stats` | GET | 200 + 统计数据 |
| `dashboard_storage_stats_success` | `/api/dashboard/storage-stats` | GET | 200 |
| `dashboard_emoji_stats_success` | `/api/dashboard/emoji-stats` | GET | 200 |
| `dashboard_requires_admin` | `/api/dashboard/stats` | GET (user token) | 403 |

#### 3.1.2 用户管理

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `admin_list_users_success` | `/api/admin/users` | GET | 200 + 分页列表 |
| `admin_get_user_detail` | `/api/admin/users/{id}` | GET | 200 |
| `admin_create_user_success` | `/api/admin/users` | POST | 200 |
| `admin_update_user_success` | `/api/admin/users/{id}` | PATCH | 200 |
| `admin_delete_user_success` | `/api/admin/users/{id}` | DELETE | 200 |
| `admin_reset_user_password` | `/api/admin/users/{id}/password/reset` | POST | 200 |

#### 3.1.3 管理员用户管理

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `admin_list_admin_users` | `/api/admin/admin-users` | GET | 200 |
| `admin_create_admin_user` | `/api/admin/admin-users` | POST | 200 |
| `admin_update_admin_status` | `/api/admin/admin-users/{id}/status` | PATCH | 200 |

#### 3.1.4 权限角色

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `admin_get_permissions` | `/api/admin/permissions` | GET | 200 |
| `admin_list_roles` | `/api/admin/roles` | GET | 200 |
| `admin_create_role` | `/api/admin/roles` | POST | 200 |
| `admin_update_role` | `/api/admin/roles/{id}` | PATCH | 200 |

#### 3.1.5 文件管理

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `admin_list_files` | `/api/admin/files` | GET | 200 |
| `admin_get_file_stats` | `/api/admin/files/stats` | GET | 200 |
| `admin_delete_file_not_found` | `/api/admin/files/{fake_id}` | DELETE | 404 |

#### 3.1.6 系统设置

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `admin_get_captcha_setting` | `/api/admin/settings/captcha` | GET | 200 |
| `admin_list_storage_providers` | `/api/admin/storage-providers` | GET | 200 |
| `admin_get_default_storage` | `/api/admin/storage-providers/default` | GET | 200 |

#### 3.1.7 Token 管理

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `admin_list_tokens` | `/api/admin/ipinfo-tokens` | GET | 200 |
| `admin_create_token` | `/api/admin/ipinfo-tokens` | POST | 200 |
| `admin_delete_token` | `/api/admin/ipinfo-tokens/{id}` | DELETE | 200 |

#### 3.1.8 系统日志

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `admin_list_logs` | `/api/admin/logs` | GET | 200 |
| `admin_get_log_stats` | `/api/admin/logs/stats` | GET | 200 |

### 3.2 Group Management 测试 (group_tests.rs)

#### 3.2.1 群设置

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `get_group_settings_success` | `/rooms/{id}/settings` | GET | 200 |
| `update_group_settings_success` | `/rooms/{id}/settings` | PATCH | 200 |
| `group_settings_requires_member` | `/rooms/{id}/settings` | GET (非成员) | 403 |

#### 3.2.2 群管理员

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `list_group_admins` | `/rooms/{id}/admins` | GET | 200 |
| `appoint_admin_success` | `/rooms/{id}/admins` | POST | 200 |
| `remove_admin_success` | `/rooms/{id}/admins/{id}` | DELETE | 200 |

#### 3.2.3 加群管理

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `create_join_request` | `/rooms/{id}/join-requests` | POST | 200 |
| `list_join_requests` | `/rooms/{id}/join-requests` | GET | 200 |
| `review_join_request_approve` | `/rooms/{id}/join-requests/{id}/review` | PATCH | 200 |
| `create_invitation` | `/rooms/{id}/invitations` | POST | 200 |

#### 3.2.4 禁言管理

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `mute_user_success` | `/rooms/{id}/mutes` | POST | 200 |
| `list_muted_users` | `/rooms/{id}/mutes` | GET | 200 |
| `unmute_user_success` | `/rooms/{id}/mutes/{id}` | DELETE | 200 |

#### 3.2.5 群规则

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `list_rules` | `/rooms/{id}/rules` | GET | 200 |
| `create_rule` | `/rooms/{id}/rules` | POST | 200 |
| `update_rule` | `/rooms/{id}/rules/{id}` | PATCH | 200 |
| `delete_rule` | `/rooms/{id}/rules/{id}` | DELETE | 200 |

### 3.3 Message API 扩展 (messages_tests.rs)

| 用例 | 端点 | 方法 | 预期 |
|------|------|------|------|
| `delete_message_success` | `/rooms/{id}/messages/{id}` | DELETE | 200 |
| `edit_message_success` | `/rooms/{id}/messages/{id}` | PATCH | 200 |
| `mark_messages_read` | `/rooms/{id}/messages/read` | POST | 200 |
| `add_reaction_success` | `/rooms/{id}/messages/{id}/reactions` | POST | 200 |
| `pin_message_success` | `/rooms/{id}/messages/{id}/pin` | POST | 200 |

### 3.4 WebSocket 测试 (ws_tests.rs)

| 用例 | 描述 | 预期 |
|------|------|------|
| `ws_connect_requires_token` | 无 token 连接 | 连接失败 |
| `ws_connect_invalid_token` | 无效 token | 连接失败 |
| `ws_connect_success` | 有效 token | 连接成功 |

## 4. 实现计划

### 4.1 common.rs 扩展

```rust
// 新增管理员相关函数
pub async fn init_default_admin(app: Router<AppState>) -> (String, String);
pub async fn login_admin(app: Router<AppState>, username: &str, password: &str) -> String;
pub async fn create_group_room_for_test(app: Router<AppState>, token: &str, name: &str, members: &[String]) -> String;
```

### 4.2 新增测试文件

1. **admin_tests.rs** (~500 行)
   - 25+ 测试用例
   - 覆盖 Admin API 核心功能

2. **group_tests.rs** (~400 行)
   - 17 测试用例
   - 覆盖群组管理功能

3. **ws_tests.rs** (~100 行)
   - 3 测试用例
   - WebSocket 连接基础测试

### 4.3 扩展测试文件

1. **messages_tests.rs** (+5 用例)
   - 消息删除/编辑/已读/反应/置顶

## 5. 依赖说明

### 5.1 现有依赖

- `tokio` - 异步运行时
- `axum::test` - HTTP 测试
- `tower::ServiceExt` - 请求处理

### 5.2 WebSocket 测试依赖

```toml
# backend/Cargo.toml [dev-dependencies]
tokio-tungstenite = "0.21"  # WebSocket 客户端
```

## 6. 测试执行

```bash
# 全部测试
cargo test --test api

# Admin 测试
cargo test --test api admin

# Group 测试
cargo test --test api group

# WebSocket 测试
cargo test --test api ws
```

## 7. 风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| Admin API 需要初始化管理员 | 使用 `/api/admin/init-default-admin` |
| 部分 Admin API 依赖外部服务 | 跳过需要外部服务的测试 |
| WebSocket 测试复杂度 | 仅测试连接建立 |

## 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|----------|------|
| 2026-01-22 | 1.0 | 初稿 | Architect |
