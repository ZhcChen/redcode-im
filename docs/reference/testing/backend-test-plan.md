# Backend 测试补齐计划（可执行清单）

> 目标：把“要测什么、怎么测、从哪里开始跑”写清楚，避免只追求数字导致测试不可维护。
>
> 说明：本文档不写“当前覆盖率/测试数量”等易过时统计口径；覆盖率以 `cargo llvm-cov` 的结果为准。

## 1. 当前推荐入口（先能稳定跑通）

### 1.1 一键回归（本地）

同时跑：
- Rust 单元测试（`cargo test --lib`）
- Rust 集成测试（`cargo test --tests`，串行）
- Go 黑盒/契约测试（`tests/go`）

```bash
./tests/run.sh
```

如需保留测试栈用于排查：
```bash
KEEP_STACK=1 ./tests/run.sh
```

如需跳过 Rust 集成测试（仅跑单测 + Go）：
```bash
RUN_RUST_INTEGRATION_TESTS=0 ./tests/run.sh
```

### 1.2 只跑 Rust 集成测试（需要 PG/Redis）

推荐直接在测试栈容器内跑（PG/Redis 不映射宿主端口）：
```bash
export COMPOSE_PROJECT_NAME="redcode_im_rusttests_$(date +%s)"
docker-compose -f tests/docker-compose.yml up -d --build postgres redis-session redis-cache
docker-compose -f tests/docker-compose.yml run --rm rust-tests cargo test --tests -- --test-threads=1
docker-compose -f tests/docker-compose.yml down -v
```

### 1.3 Go 黑盒/契约测试（需要 Backend 已启动）

```bash
cd tests/go
API_BASE_URL=http://localhost:<BACKEND_HOST_PORT> go test -v ./...
```

> 更推荐用 `./tests/run.sh`（会自动起后端并跑 Go 测试，且不依赖宿主端口固定为 8010）。

## 2. 现有测试覆盖（按分层）

### 2.1 Rust 单元测试（`backend/src/**`）

重点位置：
- `backend/src/handlers/*`：参数校验、权限判断等（高回归风险）
- `backend/src/services/*`：业务规则（如 Push @mention 解析）
- `backend/src/models/*`：模型转换、序列化/反序列化
- `backend/src/crypto/*`：纯算法/加解密（应可在容器/本机稳定运行）

### 2.2 Rust 集成测试（`backend/tests/**`）

现有入口（以仓库现状为准）：
- `backend/tests/database_store_tests.rs`：Store 层（真实 PostgreSQL）
- `backend/tests/file_upload_test.rs`：上传类型/限制等规则
- `backend/tests/auth_api_tests.rs`：HTTP in-process（Router/Handler/DB/Redis）
- `backend/tests/e2ee_key_store_tests.rs`：E2EE KeyStore（仅 key 管理，不涉及加密消息）

### 2.3 Go 黑盒/契约（`tests/go/**`）

现有入口（以仓库现状为准）：
- `tests/go/backend/admin/*`：管理后台关键回归（权限/日志/文件/存储/反馈/举报）
- `tests/go/backend/activity/*`：活动日志（heartbeat/login-history）
- `tests/go/backend/messages/*`
- `tests/go/backend/rooms/*`
- `tests/go/backend/group_management/*`：群管理（群设置/群规等）
- `tests/go/backend/emoji_packs/*`：贴纸（可用/添加/移除/下载 URL）
- `tests/go/backend/reports/*`：举报（用户端创建 + 管理端查询）
- `tests/go/backend/uploads/*`：上传（分片会话：签名/提交/完成/中止）
- `tests/go/backend/system/*`

## 3. 补齐策略（按优先级推进）

### P0（先补：回归收益最大）

1) **鉴权与权限边界**
- 未登录/过期 token/越权访问（401/403）
- 房间成员权限（owner/admin/member）

2) **消息核心链路**
- 发消息 → WS 推送 → 多端一致性（至少 1 条核心旅程）
- `since_id`/分页边界、撤回/删除（如存在）

3) **WebSocket 协议稳定性**
- auth/join/ping/pong、断线重连
- Redis Pub/Sub 路径（若后端依赖）

### P1（重要功能）

- 文件上传：policy、分片上传关键校验
- 搜索：权限隔离、索引/边界输入
- 管理后台关键接口：管理员初始化、权限保护

### P2（增强质量）

- 迁移升级测试（空库/已有数据升级）
- 并发一致性（多用户同时操作：加群/发消息/已读）
- 性质测试/模糊测试（解析器、搜索、富文本 parts）
- 性能基线（WS 延迟、消息吞吐）

## 4. 覆盖率（以工具结果为准）

Rust（推荐 `cargo-llvm-cov`）：

推荐：使用测试容器生成覆盖率（无需本机安装）：
```bash
./tests/coverage.sh
FORMAT=lcov ./tests/coverage.sh
```

或：本机安装后在 backend/ 目录运行：
```bash
cd backend
cargo llvm-cov --html
cargo llvm-cov --lcov --output-path lcov.info
```

> `lcov.info` 是覆盖率数据文件；`--html` 会生成可浏览的报告页面（更适合人工定位“哪没测到”）。

---

## 5. API 路由测试覆盖清单（Go+Rust）

用于追踪 `backend/src/routes.rs` 中注册的路由，哪些已被：
- Go 黑盒/契约测试（`tests/go`）
- Rust in-process 集成测试（`backend/tests`）

生成/更新清单：

```bash
go -C tests/go run ./cmd/route_coverage
```

输出文件：
- `docs/reports/api-test-coverage.json`（Dashboard 读取）

> 说明：该清单基于静态扫描（匹配 `DoJSON(method, path, ...)` / `json_request/empty_request` 调用），用于规划补齐方向；
> 不等同于真实运行覆盖率，最终仍以 `cargo llvm-cov` 与实际回归结果为准。

---

**文档更新**: 2026-01-17
