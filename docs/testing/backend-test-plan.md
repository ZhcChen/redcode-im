# Backend 单元测试计划

> 本文档记录 backend 模块的单元测试现状与补充计划。

## 一、技术栈

- **语言**: Rust
- **测试框架**: 内置 `#[test]` + `#[cfg(test)]`
- **数据库测试**: SQLx (需要测试数据库)
- **Mock**: 待引入 `mockall` 或手动 Mock

---

## 二、当前测试状态

### 2.1 概览

| 指标 | 数值 |
|------|------|
| 源文件总数 | 86 个 |
| 有测试的文件 | 16 个 (19%) |
| 测试用例总数 | 180 个 |
| 测试通过率 | 100% |

### 2.2 已有测试

| 模块 | 文件 | 测试数 | 覆盖内容 |
|------|------|--------|----------|
| crypto | `mod.rs` | 2 | 加解密基础功能 |
| crypto | `secret.rs` | 1 | 密钥加解密往返 |
| error | `error.rs` | 2 | 错误类型处理 |
| models | `convert.rs` | 4 | 数据模型转换 |
| storage | `cos.rs` | 5 | COS 签名、头部构建 |
| services | `push.rs` | 4 | @提及解析 |
| handlers | `message.rs` | 2 | 消息处理 |
| handlers | `auth.rs` | 24 | 密码验证、手机号/邮箱格式、用户名规则、自动注册 |
| handlers | `friend.rs` | 14 | 方向/状态参数解析、自身操作验证 |
| handlers | `room.rs` | 17 | 房间名称、类型、成员、通知设置、群主转让、头像验证 |
| handlers | `user.rs` | 23 | 头像扩展名推断、对象键验证、密码/搜索验证 |
| tests/ | `file_upload_test.rs` | 3 | 文件上传类型限制 |
| tests/ | `database_store_tests.rs` | 79 | 数据库存储层集成测试 |
| ↳ | `user_store_tests` | 24 | 用户创建/查询/认证/更新/删除/搜索/批量查询 |
| ↳ | `friend_store_tests` | 19 | 好友请求/响应/列表/删除/备注 |
| ↳ | `room_store_tests` | 23 | 房间创建/成员管理/私聊/置顶/更新/解散 |
| ↳ | `message_store_tests` | 13 | 消息创建/查询/更新/删除/置顶 |

### 2.3 待补充测试模块

| 目录 | 文件数 | 当前测试 | 说明 |
|------|--------|----------|------|
| `handlers/` | 24 | 5 | API 处理器（已完成核心模块） |
| `database/` | 22 | 4 | ✅ 数据库存储层（79 个测试） |
| `services/` | 7 | 1 | 业务服务 |
| `websocket/` | 2 | 0 | WebSocket 协议 |
| `redis/` | 5 | 0 | Redis 操作 |
| `middleware/` | 3 | 0 | 中间件 |

---

## 三、测试补充计划

### 3.1 优先级定义

| 级别 | 说明 | 目标 |
|------|------|------|
| P0 | 核心业务逻辑 | 必须覆盖 |
| P1 | 重要功能 | 应该覆盖 |
| P2 | 辅助功能 | 可选覆盖 |

### 3.2 P0 - 核心业务 (第一阶段) ✅ 部分完成

#### handlers/ 模块

| 文件 | 测试内容 | 实际用例数 | 状态 |
|------|----------|------------|------|
| `auth.rs` | 密码验证、手机号/邮箱格式、用户名规则、自动注册 | 24 | ✅ 完成 |
| `friend.rs` | 方向/状态参数解析、自身操作验证 | 14 | ✅ 完成 |
| `room.rs` | 房间名称、类型、成员、通知设置、群主转让、头像验证 | 17 | ✅ 完成 |
| `user.rs` | 头像扩展名推断、对象键验证、密码/搜索验证 | 23 | ✅ 完成 |

#### database/ 模块 ✅ 已完成

| 文件 | 测试内容 | 实际用例数 | 状态 |
|------|----------|------------|------|
| `user_store.rs` | 用户创建/重复检测/查询/认证/更新/删除/搜索/批量查询/密码更新 | 24 | ✅ 完成 |
| `friend_store.rs` | 好友请求创建/响应/列表/好友关系/删除/备注/计数 | 19 | ✅ 完成 |
| `room_store.rs` | 房间创建/成员管理/私聊/查询/置顶/更新/解散/转让/收藏夹 | 23 | ✅ 完成 |
| `message_store.rs` | 消息创建/回复/查询/更新/删除/置顶/权限验证 | 13 | ✅ 完成 |

### 3.3 P1 - 重要功能 (第二阶段)

#### handlers/ 模块

| 文件 | 测试内容 | 预计用例数 |
|------|----------|------------|
| `group_management.rs` | 群管理、成员操作、权限 | 8-10 |
| `message_read.rs` | 消息已读状态 | 3-4 |
| `emoji_pack.rs` | 表情包管理 | 3-4 |
| `multipart_upload.rs` | 分片上传流程 | 4-6 |

#### services/ 模块

| 文件 | 测试内容 | 预计用例数 |
|------|----------|------------|
| `file_upload_audit.rs` | 文件审计逻辑 | 3-4 |
| `upload_policy.rs` | 上传策略验证 | 4-6 |
| `geolocation.rs` | IP 地理位置解析 | 2-3 |

#### websocket/ 模块

| 文件 | 测试内容 | 预计用例数 |
|------|----------|------------|
| `protocol.rs` | 消息协议解析、序列化 | 6-8 |

### 3.4 P2 - 辅助功能 (第三阶段)

| 模块 | 文件 | 测试内容 |
|------|------|----------|
| redis | `session.rs` | 会话管理 |
| redis | `cache.rs` | 缓存操作 |
| redis | `pubsub.rs` | 发布订阅 |
| middleware | `security.rs` | 安全检查 |
| handlers | `admin.rs` | 管理接口 |
| handlers | `version.rs` | 版本管理 |

---

## 四、测试策略

### 4.1 单元测试

```rust
// 纯逻辑测试示例（无外部依赖）
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_password_strength() {
        assert!(validate_password("Test123456!"));
        assert!(!validate_password("weak"));
    }
}
```

### 4.2 数据库测试

```rust
// 需要测试数据库的测试
#[cfg(test)]
mod tests {
    use sqlx::PgPool;

    #[sqlx::test]
    async fn test_create_user(pool: PgPool) {
        let user = create_user(&pool, "test@example.com").await;
        assert!(user.is_ok());
    }
}
```

### 4.3 Mock 测试

```rust
// 使用 mockall 进行依赖注入测试
#[cfg(test)]
mod tests {
    use mockall::predicate::*;

    #[test]
    fn test_handler_with_mock_store() {
        let mut mock_store = MockUserStore::new();
        mock_store.expect_find_by_id()
            .returning(|_| Ok(Some(test_user())));
        // ...
    }
}
```

---

## 五、执行计划

### 阶段一：P0 核心业务 ✅ 已完成

- [x] `handlers/auth.rs` 测试 (24 个用例)
- [x] `handlers/friend.rs` 测试 (14 个用例)
- [x] `handlers/room.rs` 测试 (17 个用例)
- [x] `handlers/user.rs` 测试 (23 个用例)
- [x] `database/user_store.rs` 测试 (24 个用例)
- [x] `database/friend_store.rs` 测试 (19 个用例)
- [x] `database/room_store.rs` 测试 (23 个用例)
- [x] `database/message_store.rs` 测试 (13 个用例)

### 阶段二：P1 重要功能

- [ ] `handlers/group_management.rs` 测试
- [ ] `services/upload_policy.rs` 测试
- [ ] `websocket/protocol.rs` 测试

### 阶段三：P2 辅助功能

- [ ] `redis/` 模块测试
- [ ] `middleware/` 模块测试

---

## 六、运行测试

```bash
# 运行所有测试
cargo test

# 运行指定模块测试
cargo test handlers::auth

# 运行并显示输出
cargo test -- --nocapture

# 运行数据库集成测试（需要数据库运行）
cargo test --test database_store_tests

# 数据库测试建议单线程运行（避免连接竞争）
cargo test --test database_store_tests -- --test-threads=1

# 生成覆盖率报告（需要 cargo-tarpaulin）
cargo tarpaulin --out Html
```

### 6.1 数据库测试说明

数据库集成测试位于 `backend/tests/database_store_tests.rs`，需要：

1. **环境要求**：PostgreSQL 数据库运行中
2. **配置**：`.env` 文件中设置 `DATABASE_URL` 或 `DATABASE_URL_TEST`
3. **测试隔离**：使用唯一 UUID 生成测试数据，无需清空表
4. **测试模块**：
   - `user_store_tests` - 用户存储测试 (24 个)
   - `friend_store_tests` - 好友存储测试 (19 个)
   - `room_store_tests` - 房间存储测试 (23 个)
   - `message_store_tests` - 消息存储测试 (13 个)

---

## 七、目标

| 阶段 | 测试覆盖率目标 | 预计测试数 | 当前状态 |
|------|----------------|------------|----------|
| 初始 | 9% | 23 | ✅ 已完成 |
| 阶段一（handlers） | 25% | 100+ | ✅ 已达成 (101) |
| 阶段一（database） | 40% | 130+ | ✅ 已达成 (180) |
| 阶段二完成 | 60% | 200+ | ⏳ 待开始 |
| 阶段三完成 | 75% | 220+ | ⏳ 待开始 |

---

**文档更新**: 2026-01-13
