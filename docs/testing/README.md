# 测试工作流程指南

> RedCode IM 项目测试策略、流程与规范的统一入口文档。

## 目录

- [测试策略总览](#测试策略总览)
- [测试金字塔](#测试金字塔)
- [测试架构（五模块）](#测试架构五模块)
- [测试环境搭建](#测试环境搭建)
- [本地开发测试流程](#本地开发测试流程)
- [测试命名与组织规范](#测试命名与组织规范)
- [测试文档索引](#测试文档索引)

---

## 测试策略总览

### 测试目标

| 目标 | 描述 | 优先级 |
|------|------|--------|
| 核心功能稳定 | 认证、消息、WebSocket 等核心流程无回归 | P0 |
| API 契约保证 | 接口输入输出符合文档规范 | P0 |
| 数据一致性 | 数据库操作正确、事务完整 | P1 |
| 边界条件覆盖 | 异常输入、权限校验、并发场景 | P1 |
| 用户体验验证 | E2E 测试确保关键用户旅程畅通 | P2 |

### 测试原则

1. **测试先行** - 新功能开发前先定义测试用例
2. **快速反馈** - 单元测试应在秒级完成
3. **隔离性** - 测试之间互不影响，可并行执行
4. **可重复性** - 相同输入始终产生相同结果
5. **覆盖优先级** - 核心路径 > 边界条件 > 异常处理

---

## 测试金字塔

```
                    ┌─────────────┐
                    │   E2E 测试   │  ← 用户视角，全流程验证
                    │   (少量)     │     耗时长，维护成本高
                   ─┴─────────────┴─
                  ┌─────────────────┐
                  │   集成测试       │  ← API/数据库/外部服务
                  │   (适量)         │     验证模块间协作
                 ─┴─────────────────┴─
                ┌───────────────────────┐
                │      单元测试          │  ← 函数/方法级别
                │      (大量)            │     快速、隔离、稳定
                └───────────────────────┘
```

### 各层测试职责

| 层级 | 职责 | 运行频率 | 目标覆盖率 |
|------|------|----------|------------|
| 单元测试 | 验证单个函数/方法的逻辑正确性 | 每次提交 | ≥80% |
| 集成测试 | 验证模块间交互、数据库操作、API 调用 | 每次 PR | ≥60% |
| E2E 测试 | 验证完整用户旅程、跨端场景 | 每日/发版前 | 核心路径 100% |

---

## 测试架构（五模块）

详细说明见：[`docs/testing/test-architecture.md`](test-architecture.md)。

### 模块与测试框架

| 模块 | 目录 | 单元测试 | 集成测试 | E2E 测试 |
|------|------|----------|----------|----------|
| Backend | `backend/` | Rust `cargo test` | Rust 集成测试 + Go（`tests/go/`） | WebSocket/关键链路（Go/Node） |
| Frontend (Flutter) | `frontend/` | `flutter test` | 真 API 联调 | Patrol `patrol test` |
| Desktop (Vue+Tauri) | `desktop/` | Vitest（规划）+ `src-tauri` `cargo test` | Go（复用） | Playwright + Tauri Driver（规划） |
| Admin (Vue) | `admin/` | Vitest（规划） | Go（复用） | Playwright（已存在脚本，待标准化） |
| Website (Nuxt) | `website/` | Vitest + Nuxt Test Utils（规划） | - | Playwright（规划） |

### 统一测试数据（推荐）

多数跨端测试需要“真实账号 + 好友关系 + 房间”。

统一使用 `backend/test_flow.sh` 初始化（可重复运行）：

```bash
cd backend
./test_flow.sh
```

---

## 测试环境搭建

### 依赖服务

```bash
# 启动 PostgreSQL + Redis（仅依赖服务，后端建议本地 cargo run）
cd backend
docker compose up -d postgres redis-session redis-cache

# 验证服务状态
docker compose ps
```

### 环境变量

建议在 `backend/` 目录下创建 `.env`（可从示例复制）：

```bash
cd backend
cp .env.example .env
```

关键配置项（与 `backend/docker-compose.yml` 默认一致）：

```bash
DATABASE_URL=postgres://postgres:123456@localhost:5432/redcode_im
REDIS_SESSION_URL=redis://:123456@localhost:6381/0
REDIS_CACHE_URL=redis://:123456@localhost:6383/0
JWT_SECRET=dev-secret-change-me
RUST_LOG=debug
```

> 注意：`DATABASE_URL` 为必填项；Redis 若启用了密码，URL 必须包含 `:password@`。

### 测试数据初始化

```bash
# 创建测试用户与房间数据（可重复运行）
cd backend
./test_flow.sh
```

默认会确保以下账号存在并建立关系（脚本输出会包含 room_id）：
- `13800138000` / `Test123456`
- `13800138001` / `Test123456`
- `13800138002` / `Test123456`

---

## 本地开发测试流程

### 1. 后端开发流程

```bash
# 进入后端目录
cd backend

# 运行全部测试
cargo test

# 运行特定模块测试
cargo test --package backend --lib handlers::auth

# 运行并显示输出
cargo test -- --nocapture

# 运行数据库集成测试
cargo test --test database_store_tests

# 检查覆盖率 (需安装 cargo-tarpaulin)
cargo tarpaulin --out Html
```

### 2. 前端开发流程

```bash
# 进入前端目录
cd frontend

# 运行单元测试
flutter test

# 本地运行（如需连本机后端）
flutter run --dart-define=API_BASE_URL=http://localhost:8010 --dart-define=WS_URL=ws://localhost:8010/ws

# 运行 E2E 测试 (需启动后端)
patrol test

# 运行特定测试文件
flutter test test/widget_test.dart
```

### 3. 桌面端开发流程

```bash
# 进入桌面端测试目录
cd tests/go/desktop_add_member

# 运行 Go 集成测试
go test -v ./...

# 运行特定测试
go test -v -run TestAddMembers_Smoke
```

### 4. 快速验证流程

完整的手动验证流程请参考 [快速测试指南](quick-test.md)。

---

## 测试命名与组织规范

### 测试文件命名

| 模块 | 文件命名规范 | 示例 |
|------|--------------|------|
| Rust 单元测试 | 模块内 `#[cfg(test)]` | `auth.rs` 内 `mod tests` |
| Rust 集成测试 | `tests/<name>_tests.rs` | `tests/database_store_tests.rs` |
| Flutter 单元测试 | `test/<name>_test.dart` | `test/widget_test.dart` |
| Flutter E2E | `integration_test/<name>_test.dart` | `integration_test/app_test.dart` |
| Go 测试 | `<name>_test.go` | `add_member_test.go` |

### 测试函数命名

```rust
// Rust: test_<功能>_<场景>_<预期结果>
#[test]
fn test_login_with_valid_credentials_returns_token() { }

#[test]
fn test_login_with_wrong_password_returns_401() { }
```

```dart
// Flutter: <功能> <场景> <预期结果>
testWidgets('login button shows loading when tapped', (tester) async { });

test('AuthService returns token on successful login', () { });
```

### 测试组织结构

```
backend/tests/                    # Rust 集成测试
tests/go/                         # Go API 集成测试
  ├── backend_message_search/     # 消息搜索
  ├── desktop_add_member/         # 群聊添加成员
  └── upload_policy/              # 上传策略
```

---

## 测试文档索引

### 策略与规划

| 文档 | 说明 |
|------|------|
| [本文档](README.md) | 测试工作流程总纲 |
| [测试架构（五模块）](test-architecture.md) | 五模块测试边界与框架选择 |
| [Backend 测试说明](backend-testing.md) | 后端单元/集成/契约测试写法 |
| [Backend 单元测试计划](backend-test-plan.md) | 后端测试现状与补充计划 |

### 测试指南

| 文档 | 说明 | 适用模块 |
|------|------|----------|
| [快速测试指南](quick-test.md) | 5 分钟快速验证 | 全栈 |
| [E2E 测试指南](e2e-testing-guide.md) | Patrol 框架使用详解 | Flutter |
| [测试路径](test-paths.md) | 用户旅程测试设计 | Flutter |
| [WebSocket 测试](websocket-test.md) | WS 实时分发验证 | Backend/Frontend |
| [添加好友测试](add-friend.md) | 好友功能测试用例 | 全栈 |
| [桌面端测试架构](desktop-add-member-go-test-architecture.md) | Go 测试设计方案 | Desktop |

### 快速链接

- **运行后端测试**: `cd backend && cargo test`
- **运行前端测试**: `cd frontend && flutter test`
- **运行 E2E 测试**: `cd frontend && patrol test`
- **查看覆盖率**: `cd backend && cargo tarpaulin --out Html`

---

## 附录：测试检查清单

### PR 提交前检查

- [ ] 新增代码有对应的单元测试
- [ ] 所有测试通过 (`cargo test` / `flutter test`)
- [ ] 核心功能变更有集成测试覆盖
- [ ] 测试命名符合规范
- [ ] 无硬编码的测试数据（使用 fixtures）

### 发版前检查

- [ ] 全量单元测试通过
- [ ] 全量集成测试通过
- [ ] E2E 核心路径测试通过
- [ ] 覆盖率不低于上一版本
- [ ] 性能测试无明显退化

---

**文档最后更新**: 2026-01-15
