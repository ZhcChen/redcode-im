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
| 有测试的文件 | 8 个 (9%) |
| 测试用例总数 | 23 个 |
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
| tests/ | `file_upload_test.rs` | 3 | 文件上传类型限制 |

### 2.3 缺失测试模块

| 目录 | 文件数 | 当前测试 | 说明 |
|------|--------|----------|------|
| `handlers/` | 24 | 1 | API 处理器 |
| `database/` | 22 | 0 | 数据库存储层 |
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

### 3.2 P0 - 核心业务 (第一阶段)

#### handlers/ 模块

| 文件 | 测试内容 | 预计用例数 |
|------|----------|------------|
| `auth.rs` | 登录验证、注册流程、Token 刷新、密码校验 | 8-10 |
| `friend.rs` | 好友申请、接受、拒绝、删除、列表 | 6-8 |
| `room.rs` | 房间创建、加入、退出、信息获取 | 6-8 |
| `user.rs` | 用户信息获取、更新、头像 | 4-6 |

#### database/ 模块

| 文件 | 测试内容 | 预计用例数 |
|------|----------|------------|
| `user_store.rs` | 用户 CRUD、查询、更新 | 6-8 |
| `friend_store.rs` | 好友关系存储、查询 | 4-6 |
| `room_store.rs` | 房间 CRUD、成员管理 | 6-8 |
| `message_store.rs` | 消息存储、查询、分页 | 6-8 |

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

### 阶段一：P0 核心业务 (预计 2-3 天)

- [ ] `handlers/auth.rs` 测试
- [ ] `handlers/friend.rs` 测试
- [ ] `handlers/room.rs` 测试
- [ ] `handlers/user.rs` 测试
- [ ] `database/user_store.rs` 测试
- [ ] `database/friend_store.rs` 测试
- [ ] `database/room_store.rs` 测试
- [ ] `database/message_store.rs` 测试

### 阶段二：P1 重要功能 (预计 2 天)

- [ ] `handlers/group_management.rs` 测试
- [ ] `services/upload_policy.rs` 测试
- [ ] `websocket/protocol.rs` 测试

### 阶段三：P2 辅助功能 (预计 1 天)

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

# 生成覆盖率报告（需要 cargo-tarpaulin）
cargo tarpaulin --out Html
```

---

## 七、目标

| 阶段 | 测试覆盖率目标 | 预计测试数 |
|------|----------------|------------|
| 当前 | 9% | 23 |
| 阶段一完成 | 40% | 70+ |
| 阶段二完成 | 60% | 100+ |
| 阶段三完成 | 75% | 120+ |

---

**文档更新**: 2025-01-13
