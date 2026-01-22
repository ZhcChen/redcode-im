# SPEC-002: Backend Rust 代码测试覆盖率 100% - 技术方案

## 1. 关联文档

- PRD：[PRD-002](../requirements/PRD-002.md)

## 2. 技术决策

### 2.1 测试语言选择

| 选项 | 优点 | 缺点 | 结论 |
|------|------|------|------|
| Go 集成测试 | 已有 252 路由覆盖 | 不计入 llvm-cov | 不采用 |
| **Rust 单元测试** | 计入 llvm-cov | 需新增测试代码 | **采用** |

**原因**：目标是提升 `cargo llvm-cov` 报告的覆盖率，Go 测试无法计入。

### 2.2 测试架构

```
backend/tests/
├── api.rs                    # API 测试入口
├── stores.rs                 # Store 测试入口（新增）
├── api/
│   ├── common.rs             # 共享 fixtures
│   ├── auth_tests.rs         # 已有
│   ├── rooms_tests.rs        # 已有
│   ├── messages_tests.rs     # 已有
│   ├── health_tests.rs       # PRD-001 新增
│   ├── settings_tests.rs     # PRD-001 新增
│   ├── users_tests.rs        # PRD-001 新增
│   ├── friends_tests.rs      # Phase 2 新增
│   ├── admin_tests.rs        # Phase 3 新增
│   └── ...
└── stores/
    ├── common.rs             # Store 测试共享 fixtures
    ├── user_store_tests.rs   # Phase 4 新增
    ├── room_store_tests.rs   # Phase 4 新增
    └── ...
```

### 2.3 测试框架

- **API 测试**：`axum::test` + `tower::ServiceExt`（in-process 测试）
- **Store 测试**：直接调用 store 函数 + 真实数据库
- **Mock 策略**：trait 抽象 + 条件编译（`#[cfg(test)]`）

## 3. 代码行数统计

### 3.1 Handlers（19,921 行）

| 文件 | 行数 | 覆盖阶段 | 测试文件 |
|------|------|---------|---------|
| admin.rs | 5,328 | Phase 3 | admin_tests.rs |
| message.rs | 2,644 | Phase 2 | messages_tests.rs（扩展） |
| auth.rs | 1,645 | Phase 2 | auth_tests.rs（扩展） |
| version.rs | 1,360 | Phase 3 | version_tests.rs |
| room.rs | 1,322 | Phase 2 | rooms_tests.rs（扩展） |
| group_management.rs | 1,213 | Phase 3 | group_tests.rs |
| user.rs | 977 | Phase 1 ✓ | users_tests.rs |
| emoji_pack.rs | 662 | Phase 3 | emoji_tests.rs |
| friend.rs | 645 | Phase 2 | friends_tests.rs |
| report.rs | 623 | Phase 3 | report_tests.rs |
| multipart_upload.rs | 498 | Phase 3 | upload_tests.rs |
| 其他 | ~3,000 | Phase 3-4 | - |

### 3.2 Database Stores（7,900 行）

| 文件 | 行数 | 覆盖阶段 |
|------|------|---------|
| room_store.rs | 836 | Phase 4 |
| group_management_store.rs | 748 | Phase 4 |
| message_store.rs | 737 | Phase 4 |
| version_store.rs | 628 | Phase 4 |
| emoji_pack_store.rs | 561 | Phase 4 |
| 其他 | ~4,400 | Phase 4 |

### 3.3 其他模块

| 模块 | 行数 | 覆盖阶段 |
|------|------|---------|
| websocket/ | ~800 | Phase 3 |
| redis/ | ~600 | Phase 4 |
| services/ | ~1,500 | Phase 4 |
| utils/ | ~500 | Phase 5 |

## 4. Phase 2 详细设计（50% 目标）

### 4.1 新增测试文件

#### friends_tests.rs

```rust
// 测试用例清单
- send_friend_request_success
- send_friend_request_to_self_fails
- send_friend_request_duplicate_fails
- respond_friend_request_accept
- respond_friend_request_reject
- get_friends_list
- get_friend_requests
- update_friend_remark
- delete_friend
- create_friend_chat
```

**预计行数**：~300 行

#### rooms_tests.rs 扩展

```rust
// 新增测试用例
- create_private_room
- join_public_room
- join_private_room_with_password
- leave_room
- invite_member
- respond_invitation_accept
- respond_invitation_reject
- get_room_detail
- update_room_info
- get_room_members
```

**预计行数**：+200 行

#### messages_tests.rs 扩展

```rust
// 新增测试用例
- send_text_message
- send_image_message
- get_room_messages_pagination
- delete_message
- edit_message
- pin_message
- unpin_message
- add_reaction
- remove_reaction
- mark_messages_read
```

**预计行数**：+250 行

#### auth_tests.rs 扩展

```rust
// 新增测试用例
- refresh_token_success
- refresh_token_expired_fails
- sms_send_code（Mock SMS provider）
- sms_login_success
- password_reset_request
- password_reset_confirm
```

**预计行数**：+150 行

### 4.2 common.rs 扩展

```rust
// 新增辅助函数
pub async fn send_friend_request(app: Router, token: &str, user_id: &str) -> String;
pub async fn accept_friend_request(app: Router, token: &str, request_id: &str);
pub async fn create_private_room(app: Router, token: &str, name: &str, password: &str) -> String;
pub async fn join_room(app: Router, token: &str, room_id: &str);
pub async fn send_message(app: Router, token: &str, room_id: &str, content: &str) -> String;
```

### 4.3 覆盖率预估

| 模块 | 当前覆盖 | Phase 2 后 | 新增行数 |
|------|---------|-----------|---------|
| friend.rs (645) | 0% | ~80% | ~500 |
| room.rs (1,322) | ~20% | ~60% | ~500 |
| message.rs (2,644) | ~15% | ~50% | ~800 |
| auth.rs (1,645) | ~30% | ~60% | ~400 |
| **总计** | 12.42% | **~50%** | ~2,200 |

## 5. Mock 策略

### 5.1 外部依赖处理

| 依赖 | 处理方式 | 实现位置 |
|------|---------|---------|
| COS 存储 | trait 抽象 + mock 实现 | `src/storage/mod.rs` |
| SMS 服务 | 环境变量开关 + 跳过发送 | `src/services/sms.rs` |
| 推送服务 | trait 抽象 + mock 实现 | `src/services/push.rs` |

### 5.2 Mock 实现示例

```rust
// src/storage/mod.rs
#[cfg(test)]
pub struct MockStorageProvider;

#[cfg(test)]
impl StorageProvider for MockStorageProvider {
    async fn upload(&self, _key: &str, _data: &[u8]) -> Result<String> {
        Ok("mock://uploaded".to_string())
    }
}
```

## 6. 测试执行方式

### 6.1 本地开发

```bash
# 启动测试栈
COMPOSE_PROJECT_NAME=tests docker-compose -f tests/docker-compose.yml up -d postgres redis

# 运行全部测试
COMPOSE_PROJECT_NAME=tests docker-compose -f tests/docker-compose.yml run --rm rust-tests

# 运行单个模块
COMPOSE_PROJECT_NAME=tests docker-compose -f tests/docker-compose.yml run --rm rust-tests cargo test --test api friends
```

### 6.2 覆盖率生成

```bash
# 生成覆盖率报告
./tests/coverage.sh

# 查看 HTML 报告
open backend/coverage/html/index.html
```

## 7. CI/CD 集成

### 7.1 GitHub Actions 工作流

```yaml
# .github/workflows/coverage.yml
- name: Run tests with coverage
  run: |
    cargo llvm-cov --lcov --output-path lcov.info

- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    files: lcov.info
```

### 7.2 覆盖率门槛

| 阶段 | 门槛 | 行为 |
|------|------|------|
| PR 检查 | 不降低覆盖率 | 阻止合并 |
| main 分支 | 当前阶段目标 | 警告 |

## 8. 实现映射（验收矩阵 → 实现）

| PRD 验收项 | 实现文件 | 测试用例 |
|-----------|---------|---------|
| Friend API | friends_tests.rs | 10 个用例 |
| Room API 基础 | rooms_tests.rs | +10 个用例 |
| Message API | messages_tests.rs | +10 个用例 |
| Auth API 完善 | auth_tests.rs | +6 个用例 |

## 9. 变更清单

### Phase 2 变更

| 文件 | 操作 | 说明 |
|------|------|------|
| `tests/api/friends_tests.rs` | 新增 | 好友 API 测试 |
| `tests/api/rooms_tests.rs` | 修改 | 扩展 Room 测试 |
| `tests/api/messages_tests.rs` | 修改 | 扩展 Message 测试 |
| `tests/api/auth_tests.rs` | 修改 | 扩展 Auth 测试 |
| `tests/api/common.rs` | 修改 | 新增辅助函数 |
| `tests/api.rs` | 修改 | 添加 friends_tests 模块 |

## 10. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 测试数据冲突 | 测试不稳定 | 每个测试创建唯一用户 |
| 外部依赖超时 | 测试失败 | Mock 或跳过 |
| 数据库连接池耗尽 | 并发测试失败 | 限制并行数 |

## 11. 变更记录

| 日期 | 版本 | 变更内容 | 作者 |
|------|------|----------|------|
| 2026-01-22 | 1.0 | 初稿 | Architect |
