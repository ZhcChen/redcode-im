# Backend 测试说明（Rust）

> 目标：明确 backend 的测试分层、集成测试写法与补齐方向，为后续“按功能补测试、提高覆盖率”提供统一口径。

推荐入口（自动起测试栈并跑回归）：
```bash
./tests/run.sh
```

## 1. 单元测试（Unit Test）

**范围**：不依赖真实外部资源（DB/Redis/网络），聚焦纯逻辑与确定性规则。

推荐覆盖：
- 参数校验与业务规则（如 `handlers/*` 中的校验函数、权限判断）
- 模型转换（如 `models/convert`）
- 工具函数（如 ID/加密/序列化）
- 复杂解析逻辑（如 @mention 解析、搜索关键词处理）

**写法**：在同文件内添加 `#[cfg(test)] mod tests { ... }`，使用 `#[test]` 或 `#[tokio::test]`（仅当需要 async）。

运行：
```bash
cd backend
cargo test
```

## 2. 集成测试（Integration Test）如何写

在本项目中，建议把“集成测试”拆成 3 类（从快到慢）：

### 2.1 数据库/存储层集成测试（DB Store）

**目的**：验证 SQLx 存储层（CRUD、事务、一致性约束）在真实 PostgreSQL 上工作正常。

现状入口：
- `backend/tests/database_store_tests.rs`
- `backend/tests/file_upload_test.rs`

特点：
- 直接调用 `database/*_store.rs`，不走 HTTP
- 对于复杂业务（消息、房间、好友），优先把“数据一致性”用这一层测试固化

运行（建议串行，避免连接/锁竞争）：
```bash
docker-compose -f tests/docker-compose.yml run --rm rust-tests \
  cargo test --test database_store_tests -- --test-threads=1
```

### 2.2 HTTP 路由/处理器集成测试（Axum In-Process）

**目的**：覆盖 Router + Middleware + Handler + DB/Redis 的组合行为，但不需要真正监听端口（更快、更稳定）。

> `in-process` 不是独立“测试框架”，而是一种测试方式：把 `axum::Router` 当作 `tower::Service`，
> 用 `tower::ServiceExt::oneshot` 直接发请求并断言响应。

推荐写法：
- 在 `backend/tests/` 下新增 `*_api_tests.rs`（例如 `auth_api_tests.rs`、`friends_api_tests.rs`）
- 测试中直接构造 `AppState`，再调用 `backend::create_routes()` 生成 Router
- 使用 `tower::ServiceExt::oneshot` 发送请求并断言响应（JSON、状态码、错误码）

现有落地：
- `backend/tests/api_test_utils.rs`：共享的测试工具（构建 `AppState`、构造请求、读取响应）
- `backend/tests/auth_api_tests.rs`：首批示例用例（healthz、注册/登录、鉴权）

适合覆盖：
- 权限/鉴权（401/403）
- 参数校验（422/400）
- 业务流程（注册→登录→建房→发消息）
- 幂等性与边界条件

注意：
- `/ws` 路由使用 `ConnectInfo` 提取 client addr，不适合 in-process 方式；WebSocket 请用 2.3 的“真端口”方式测试。

### 2.3 WebSocket/跨进程集成测试（Axum 真端口）

**目的**：覆盖真实 WebSocket 握手、`auth/join/ping` 协议与推送分发（包含 Redis Pub/Sub 路径）。

推荐写法（两种任选其一）：
1) **Rust**：测试里启动 axum server 监听 `127.0.0.1:0`（随机端口），用 `tokio-tungstenite` 连接并断言收到的帧。
2) **Go 1.25**：在 `tests/go/` 新增 `ws_smoke/`，用 `nhooyr.io/websocket` 做黑盒验证（更贴近“跨端契约”）。

已有可用脚本（适合先做连通性回归）：
- `docs/testing/websocket-test.md`
- `cd backend && npm run test:ws`（需提供账号、room_id）

## 3. 除了集成测试，还需要哪些测试类型（Backend 视角）

建议补齐以下类型来支撑“质量”而不仅是“覆盖率”：

1) **契约测试（Contract Test）**（推荐 Go 1.25）
   - 目标：确保 `docs/api/*` 与真实响应不漂移；防止前端/管理端/桌面端被回归破坏
   - 落点：`tests/go/`（单一 go module，按业务域拆包）

2) **迁移/升级测试（Migration Test）**
   - 目标：验证新迁移可从“空库”与“已有数据”平滑升级；避免生产升级事故
   - 可用方式：testcontainers 起库 → 运行 `Database::migrate` → 断言关键表/索引存在

3) **性质测试/模糊测试（Property/Fuzz）**
   - 目标：对解析器/边界输入（搜索、@mention、富文本 parts）做高强度随机覆盖
   - Rust 可用：`proptest`/`cargo fuzz`（后续按需引入）

4) **并发与一致性测试（Concurrency）**
   - 目标：多用户同时发消息/标记已读/加群，验证不会产生越权/重复/脏读

5) **性能/压测（Performance/Load）**
   - 目标：消息收发吞吐、WS 推送延迟、搜索性能基线（适合用 k6/hey/自研脚本）

6) **安全回归测试（Security Regression）**
   - 目标：IDOR、权限绕过、token 刷新边界、管理员接口保护等（以“固定用例”长期跑）

---

## 4. 建议的落地顺序（后续执行）

1. 先补齐 **HTTP in-process 集成测试**（覆盖权限/校验/核心流程，回归收益最大）
2. 再补齐 **WebSocket 真端口集成测试**（至少 1-2 条核心链路：auth→join→message push）
3. 最后用 **Go 契约测试** 把跨端依赖的 API 全量兜底（与 docs/api 对齐）
