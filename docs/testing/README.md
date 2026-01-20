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
- [测试数据与 Dashboard 集成](#测试数据与-dashboard-集成)

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

| 层级 | 职责 | 运行频率 | 覆盖目标 |
|------|------|----------|------------|
| 单元测试 | 验证单个函数/方法的逻辑正确性 | 每次提交 | 核心逻辑 100%（其余按风险推进） |
| 集成测试 | 验证模块间交互、数据库操作、API 调用 | 每次 PR | 核心 API 契约 100%（其余按功能推进） |
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

统一使用 `backend/test_flow.sh` 初始化（可重复运行，适合手工/联调）：

```bash
cd backend
./test_flow.sh
```

---

## 测试环境搭建

### 依赖服务

```bash
# 一键跑测试（推荐：同时跑 Rust 单测 + Go 契约/集成测试；并自动起测试栈）
./tests/run.sh

# 仅启动测试栈（PG/Redis 不暴露宿主端口；Backend 默认随机分配宿主端口）
docker-compose -f tests/docker-compose.yml up -d --build

# 验证服务状态
docker-compose -f tests/docker-compose.yml ps
```

`./tests/run.sh` 约定：
- 默认会自动生成独立 `COMPOSE_PROJECT_NAME`（避免与其他项目/历史残留栈冲突）
- 默认退出时执行 `docker-compose down -v` 清理（如需保留栈便于调试：`KEEP_STACK=1 ./tests/run.sh`）
- 默认会运行 Rust 集成测试（`cargo test --tests`，串行）；如需跳过：`RUN_RUST_INTEGRATION_TESTS=0 ./tests/run.sh`

### 依赖缓存（Docker volumes）

为避免每次回归都重新拉取 Rust/Go 依赖，测试栈会使用外部 Docker volumes 缓存依赖与构建产物：
- `redcode_im_tests_cargo_target` / `redcode_im_tests_cargo_registry` / `redcode_im_tests_cargo_git`
- `redcode_im_tests_go_mod_cache` / `redcode_im_tests_go_build_cache`

如需彻底清理缓存（会导致下次回归重新下载依赖）：
```bash
docker volume rm \
  redcode_im_tests_cargo_target \
  redcode_im_tests_cargo_registry \
  redcode_im_tests_cargo_git \
  redcode_im_tests_go_mod_cache \
  redcode_im_tests_go_build_cache
```

> 若你使用 Colima：默认 2GiB 容易导致 Rust 编译在容器内被 OOM kill；建议至少 6GiB。可通过 `colima list` 查看并调整：
> `colima stop && colima start --cpu 4 --memory 8`

### 环境变量

测试栈 Backend 默认会随机分配宿主端口（避免与其他项目冲突）。如需固定端口（便于手工联调/Flutter/桌面端配置），可指定 `BACKEND_HOST_PORT`：

```bash
# 固定到 18010（示例）
BACKEND_HOST_PORT=18010 docker-compose -f tests/docker-compose.yml up -d --build

# 或在一键回归时固定
BACKEND_HOST_PORT=18010 ./tests/run.sh
```

查看当前 Backend 映射到宿主的端口：

```bash
docker-compose -f tests/docker-compose.yml port backend 8010
```

> 若你通过 `KEEP_STACK=1 ./tests/run.sh` 保留了栈，请使用运行时输出的 `COMPOSE_PROJECT_NAME`：
> `COMPOSE_PROJECT_NAME=<name> docker-compose -f tests/docker-compose.yml port backend 8010`

后端 `.env`（`backend/.env`）仍可用于“在宿主机上 cargo run”的开发模式（与测试栈无强绑定），可从示例复制：

```bash
cd backend
cp .env.example .env
```

> 注意：`tests/docker-compose.yml` 中 PostgreSQL/Redis 默认不暴露宿主端口，因此**宿主机直接 `cargo run`** 并不能复用该测试栈的 DB/Redis；
> 若要联调/手工测试，推荐直接使用测试栈启动的 Backend（宿主 `http://localhost:<BACKEND_HOST_PORT>`）。

关键配置项（与 `backend/docker-compose.yml` 默认一致）：

```bash
DATABASE_URL=postgres://postgres:123456@localhost:5432/redcode_im
REDIS_SESSION_URL=redis://:123456@localhost:6381/0
REDIS_CACHE_URL=redis://:123456@localhost:6383/0
JWT_SECRET=dev-secret-change-me
RUST_LOG=debug
```

> 注意：`DATABASE_URL` 为必填项；Redis 若启用了密码，URL 必须包含 `:password@`。

### 外部副作用（Push/第三方）策略

- 默认测试栈（`tests/docker-compose.yml`）会设置 `PUSH_ENABLED=false`，避免跑测试时触发真实推送/外部网络依赖。
- 若需要验证 Push 行为：应启用专用测试配置（开启 `PUSH_ENABLED=true` 并提供测试用 provider 配置），并优先把第三方请求指向可控的 mock（如 `wiremock`）以保证可重复性。
- 默认测试栈会设置 `REDCODE_IM_STORAGE_DISABLE_NETWORK=true`，跳过 COS 的网络读写（仍保留签名算法/下载 URL 生成）；若要验证真实 COS 集成，请在单独的栈中关闭该开关并配置真实存储提供商。

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

# 运行数据库集成测试（需要 PostgreSQL 可用）
# 若不希望在宿主机暴露 PostgreSQL 端口，推荐在测试栈容器内运行：
docker-compose -f tests/docker-compose.yml run --rm rust-tests \
  cargo test --test database_store_tests -- --test-threads=1

# 覆盖率报告（Rust）
# - lcov：覆盖率数据文件格式（给工具/CI/报表读取）
# - html：可在浏览器打开的覆盖率报告
#
# 推荐（无需本机安装）：使用测试容器生成覆盖率
./tests/coverage.sh

# 生成 lcov 文件
FORMAT=lcov ./tests/coverage.sh

# 或：本机安装后在 backend/ 目录运行（需要：cargo install cargo-llvm-cov）
cargo llvm-cov --html

# 生成 lcov 文件（可用于上传或进一步生成报告）
cargo llvm-cov --lcov --output-path lcov.info
```

### 2. 前端开发流程

```bash
# 进入前端目录
cd frontend

# 运行单元测试
flutter test

# 本地运行（如需连本机后端）
flutter run --dart-define=API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> --dart-define=WS_URL=ws://localhost:<BACKEND_HOST_PORT>/ws

# 运行 E2E 测试 (需启动后端)
patrol test

# 运行特定测试文件
flutter test test/widget_test.dart
```

### 3. 桌面端开发流程

```bash
# 运行 Go 契约/集成测试（需要 Backend 已启动）
cd tests/go
API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> go test -v ./...

# 部分用例需要管理员账号（缺失 ADMIN_USERNAME / ADMIN_PASSWORD 会自动 skip）
ADMIN_USERNAME=admin ADMIN_PASSWORD=admin123 \
  API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> go test -v ./...
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
backend/src/**                    # Rust 单元测试（#[cfg(test)]）
backend/tests/**                  # Rust 集成测试（少量；优先 Go 做黑盒回归）
tests/go/                         # Go 契约/集成测试（单一 go module）
  ├── internal/testutil/          # 统一 fixtures/http client
  └── backend/                    # 后端黑盒回归（按业务域拆包）
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
- **查看覆盖率**: `cd backend && cargo llvm-cov --html`

---

## 测试数据与 Dashboard 集成

### 覆盖率数据类型

项目维护两种覆盖率数据，均以 JSON 格式存储供 Dashboard 读取：

| 类型 | 文件路径 | 生成命令 | Dashboard 端点 |
|------|----------|----------|----------------|
| API 覆盖率 | `docs/reports/api-test-coverage.json` | `go -C tests/go run ./cmd/route_coverage` | `GET /api/coverage` |
| 代码覆盖率 | `docs/reports/test-coverage.json` | `./tests/update-coverage-json.sh` | `GET /api/code-coverage` |
| 综合数据 | (实时合并) | - | `GET /api/coverage/all` |

### API 覆盖率 JSON 格式

统计 Go/Rust 测试对后端 API 路由的覆盖情况：

```json
{
  "updatedAt": "2026-01-19T18:09:37+08:00",
  "summary": {
    "total": 252,
    "goCovered": 194,
    "rustCovered": 5,
    "bothCovered": 4,
    "uncovered": 57,
    "percentage": 77.38
  },
  "routes": [
    {
      "method": "POST",
      "path": "/auth/login",
      "goHits": 5,
      "rustHits": 2,
      "status": "both"
    }
  ]
}
```

字段说明：
- `goHits` / `rustHits`：Go/Rust 测试中调用该路由的次数
- `status`：`go` | `rust` | `both` | `uncovered`

### 代码覆盖率 JSON 格式

统计 Rust 代码行覆盖率与各模块测试数量：

```json
{
  "updatedAt": "2026-01-19T14:00:00+08:00",
  "rust": {
    "lineCoverage": 45.2,
    "totalTests": 203,
    "modules": {
      "unit": 98,
      "api": 16,
      "stores": 79,
      "websocket": 5,
      "e2ee": 2,
      "fileUpload": 3
    }
  },
  "go": {
    "totalTests": 47
  },
  "summary": {
    "totalTests": 250,
    "rustTests": 203,
    "goTests": 47
  }
}
```

### Dashboard 使用说明

Dashboard 运行在 `http://localhost:20000`，提供测试数据可视化。

**启动 Dashboard**：

```bash
cd dashboard
bun run --watch src/index.ts
```

**更新覆盖率数据**：

可通过 Dashboard 界面点击命令，或手动执行：

```bash
# 更新 API 覆盖率（扫描测试代码中的 API 调用）
go -C tests/go run ./cmd/route_coverage

# 更新代码覆盖率（运行测试并收集覆盖率）
./tests/update-coverage-json.sh

# 仅解析现有数据（跳过测试运行）
SKIP_TESTS=1 ./tests/update-coverage-json.sh
```

### 数据更新规则

1. **提交前**：运行 `go run ./cmd/route_coverage` 确保 API 覆盖率数据最新
2. **发版前**：运行 `./tests/update-coverage-json.sh` 生成完整覆盖率报告
3. **CI 集成**（规划）：在 CI 流程中自动生成并归档覆盖率数据

### 文件存放约定

```
docs/reports/
├── api-test-coverage.json    # API 路由覆盖率
├── test-coverage.json        # 代码覆盖率 + 测试统计
└── task-list.md              # 任务清单
```

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

**文档最后更新**: 2026-01-19
