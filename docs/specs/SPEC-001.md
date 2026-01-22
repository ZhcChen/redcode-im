# SPEC-001: Backend Rust 代码测试覆盖完善 - 技术方案

## 1. 概述

本方案旨在提升 Backend Rust 代码覆盖率从 12.42% 至 30%+。

**关键发现**：
- Go 集成测试已覆盖 100% API 路由（252 个），但 **不计入 Rust 代码覆盖率**
- Rust 代码覆盖率（`cargo llvm-cov`）仅统计 Rust 测试执行的代码路径
- 因此本方案需要 **Rust 测试** 来提升代码覆盖率（CLAUDE.md 特殊情况）

## 2. 需求映射

| PRD 需求 | 设计模块/接口 | 测试类型 | 说明 |
|----------|---------------|----------|------|
| Health API 测试 | `handlers/health.rs` | Rust API 测试 | 已有 Go 测试，需补 Rust |
| Settings API 测试 | `handlers/settings.rs` | Rust API 测试 | 已有 Go 测试，需补 Rust |
| User API 测试增强 | `handlers/user.rs` | Rust API 测试 | 部分已覆盖（22%），需增强 |
| Friend API 测试增强 | `handlers/friend.rs` | Rust API 测试 | 部分已覆盖（19%），需增强 |
| Database Stores 测试 | `database/*.rs` | Rust 单元测试 | 多个 store 为 0% |

## 3. 约束与假设

### 依赖系统
- PostgreSQL（测试数据库）
- Redis（Session/Cache）
- 测试栈：`tests/docker-compose.yml`

### 关键限制
- Go 测试不计入 `cargo llvm-cov` 覆盖率统计
- 部分 handler 依赖外部服务（COS），需跳过或 mock
- 测试需在容器内运行以访问测试栈数据库

### 特殊说明
根据 CLAUDE.md "所有测试除非特殊指定否则使用 Go" 规范：
- **本次任务属于特殊情况**：目标是提升 Rust 代码覆盖率，必须使用 Rust 测试
- Go 测试仍作为契约保证，但不影响覆盖率指标

## 4. 技术选型

| 类别 | 选择 | 理由 |
|------|------|------|
| API 测试框架 | Rust `axum::test` + `tower::ServiceExt` | 计入覆盖率，无需启动服务器 |
| 单元测试框架 | Rust `#[cfg(test)]` | 标准做法，快速反馈 |
| 数据库 | 测试栈 PostgreSQL | 隔离环境，可重复执行 |
| 覆盖率工具 | `cargo llvm-cov` | 项目已配置，输出 HTML/JSON |

## 5. 架构设计

### 测试目录结构

```
backend/
├── src/
│   └── handlers/
│       ├── user.rs        # 已有 #[cfg(test)] 模块
│       └── ...
└── tests/
    ├── api/
    │   ├── common.rs      # 共享测试工具（已有）
    │   ├── auth_tests.rs  # 认证测试（已有）
    │   ├── health_tests.rs    # [新增] Health API
    │   ├── settings_tests.rs  # [新增] Settings API
    │   └── users_tests.rs     # [新增] User API 增强
    ├── stores/
    │   ├── common.rs      # Store 测试工具（已有）
    │   ├── settings_store_tests.rs  # [新增]
    │   └── document_store_tests.rs  # [新增]
    └── api.rs             # 测试入口（需更新）
```

### 测试工具复用

现有 `tests/api/common.rs` 提供：
- `test_state()` - 构建 AppState
- `test_router()` - 构建 Router
- `json_request()` / `empty_request()` - 请求构造
- `read_json()` / `read_text()` - 响应解析
- `register_user()` / `login_user()` - 用户 fixtures

## 6. 接口设计

### 6.1 新增测试文件

#### health_tests.rs
```rust
// 覆盖 handlers/health.rs
#[tokio::test] async fn readyz_returns_ok_with_checks() { }
#[tokio::test] async fn readyz_checks_database_status() { }
#[tokio::test] async fn readyz_checks_redis_session_status() { }
#[tokio::test] async fn readyz_checks_redis_cache_status() { }
```

#### settings_tests.rs
```rust
// 覆盖 handlers/settings.rs
#[tokio::test] async fn get_general_settings_returns_app_name() { }
#[tokio::test] async fn get_privacy_policy_returns_document() { }
#[tokio::test] async fn get_user_agreement_returns_document() { }
#[tokio::test] async fn get_captcha_setting_returns_config() { }
```

#### users_tests.rs
```rust
// 增强 handlers/user.rs 覆盖率
#[tokio::test] async fn update_me_changes_nickname() { }
#[tokio::test] async fn change_password_success() { }
#[tokio::test] async fn change_password_wrong_old_password_fails() { }
#[tokio::test] async fn search_users_returns_results() { }
#[tokio::test] async fn search_users_empty_keyword_fails() { }
#[tokio::test] async fn get_user_by_id_success() { }
#[tokio::test] async fn get_user_by_id_not_found() { }
#[tokio::test] async fn deactivate_me_success() { }
```

## 7. 数据模型

无数据库变更，仅新增测试代码。

## 8. 关键逻辑与流程

### 测试执行流程

```
1. 启动测试栈（docker-compose up）
2. 运行 Rust 测试（cargo test --test api）
3. 生成覆盖率报告（cargo llvm-cov）
4. 验证覆盖率提升
```

### 测试数据策略

- 每个测试创建独立用户（`unique_phone_username()`）
- 使用 `register_user()` + `login_user()` 获取 token
- 测试结束后数据留存（不主动清理，避免影响其他测试）

## 9. 非功能目标

| 指标 | 目标 |
|------|------|
| 单测试执行时间 | < 5 秒 |
| 全量测试执行时间 | < 2 分钟 |
| 覆盖率提升 | 12% → 30%+ |

## 10. 安全与风险

- **风险**：测试数据可能残留在数据库
- **缓解**：使用独立测试数据库，定期清理

## 11. 兼容与版本策略

- 无 API 变更，仅新增测试代码
- 测试代码与现有架构兼容

## 12. 回滚与迁移

- 如测试导致问题，可直接删除测试文件
- 无数据库迁移

## 13. 影响范围

### 新增文件
- `backend/tests/api/health_tests.rs`
- `backend/tests/api/settings_tests.rs`
- `backend/tests/api/users_tests.rs`
- `backend/tests/stores/settings_store_tests.rs`
- `backend/tests/stores/document_store_tests.rs`

### 修改文件
- `backend/tests/api.rs` - 添加新模块引用

## 14. 实现计划

| 阶段 | 内容 | 预估测试数 | 覆盖率提升预估 |
|------|------|-----------|---------------|
| MVP | health_tests + settings_tests | +8 | +3% |
| V1 | users_tests | +8 | +5% |
| V2 | stores 单元测试 | +10 | +7% |

## 15. 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|----------|------|
| 2026-01-22 | 1.0 | 初稿 | Architect |
