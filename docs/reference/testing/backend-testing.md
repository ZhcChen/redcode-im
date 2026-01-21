# Backend 测试说明（Rust）

> 目标：明确 backend 的测试分层、集成测试写法与补齐方向，为后续"按功能补测试、提高覆盖率"提供统一口径。

## 快速入口

```bash
# 一键回归（推荐）
./tests/run.sh

# 覆盖率报告
./tests/coverage.sh
FORMAT=lcov ./tests/coverage.sh
```

## 测试目录结构

```
backend/tests/
├── api.rs                    # API 测试入口
├── api/
│   ├── common.rs             # API 测试共享工具
│   ├── auth_tests.rs         # 认证 API 测试
│   ├── rooms_tests.rs        # 房间 API 测试
│   └── messages_tests.rs     # 消息 API 测试
├── stores.rs                 # Store 测试入口
├── stores/
│   ├── common.rs             # Store 测试共享工具
│   ├── user_store_tests.rs   # 用户 Store 测试
│   ├── friend_store_tests.rs # 好友 Store 测试
│   ├── room_store_tests.rs   # 房间 Store 测试
│   └── message_store_tests.rs# 消息 Store 测试
├── ws_tests.rs               # WebSocket 集成测试
├── e2ee_key_store_tests.rs   # E2EE 密钥测试
└── file_upload_test.rs       # 文件上传测试
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
cargo test --lib
```

## 2. 集成测试（Integration Test）

### 2.1 数据库/存储层集成测试（DB Store）

**目的**：验证 SQLx 存储层（CRUD、事务、一致性约束）在真实 PostgreSQL 上工作正常。

**目录**：`backend/tests/stores/`（按 Store 类型拆分为独立模块）

运行：
```bash
# 全部 Store 测试
cargo test --test stores

# 单个 Store 测试
cargo test --test stores user_store
cargo test --test stores friend_store
cargo test --test stores room_store
cargo test --test stores message_store
```

### 2.2 HTTP API 集成测试（Axum In-Process）

**目的**：覆盖 Router + Middleware + Handler + DB/Redis 的组合行为，但不需要真正监听端口（更快、更稳定）。

**目录**：`backend/tests/api/`（按业务域拆分为独立模块）

> `in-process` 不是独立"测试框架"，而是一种测试方式：把 `axum::Router` 当作 `tower::Service`，
> 用 `tower::ServiceExt::oneshot` 直接发请求并断言响应。

运行：
```bash
# 全部 API 测试
cargo test --test api

# 单个模块测试
cargo test --test api auth
cargo test --test api rooms
cargo test --test api messages
```

**写法示例**：
```rust
use super::common::{test_state, test_router, json_request, read_json};

#[tokio::test]
async fn test_login_success() {
    let state = test_state().await;
    let app = test_router(state);

    let body = json!({"username": "...", "password": "..."});
    let response = app
        .oneshot(json_request(Method::POST, "/auth/login", None, body))
        .await
        .unwrap();

    let (status, json) = read_json(response).await;
    assert_eq!(status, StatusCode::OK);
}
```

注意：
- `/ws` 路由使用 `ConnectInfo` 提取 client addr，不适合 in-process 方式；WebSocket 请用 2.3 的"真端口"方式测试。

### 2.3 WebSocket/跨进程集成测试（Axum 真端口）

**目的**：覆盖真实 WebSocket 握手、`auth/join/ping` 协议与推送分发（包含 Redis Pub/Sub 路径）。

**目录**：`backend/tests/ws_tests.rs`

运行：
```bash
# 运行 WebSocket 测试
cargo test --test ws_tests
```

**已实现的测试用例**：
- `ws_auth_and_ping_pong` - 认证与心跳
- `ws_join_room_and_receive_message` - 加入房间并接收消息推送
- `ws_join_without_auth_returns_error` - 未认证时加入房间返回错误
- `ws_invalid_auth_returns_error` - 无效 token 认证返回错误
- `ws_join_nonmember_room_returns_error` - 非成员加入房间返回错误

**写法**：使用 `tokio-tungstenite` 作为 WebSocket 客户端，启动 axum server 监听随机端口（`127.0.0.1:0`）。

其他可用脚本（适合手工验证）：
- `docs/reference/testing/websocket-test.md`
- `cd backend && npm run test:ws`（需提供账号、room_id）

### 2.4 Go HTTP/WS 契约测试（`tests/go`）如何写

**目的**：用“黑盒”的方式验证后端 API/WS 的对外行为，作为 Flutter/Desktop/Admin 的跨端回归基线。

目录约定：
- `tests/go/`：单一 go module
- `tests/go/internal/testutil/`：统一 fixtures / http client / ws client（复用）
- `tests/go/backend/<domain>/`：按业务域分包（auth/messages/rooms/...）

常用环境变量：
- `API_BASE_URL`：后端地址（默认 `http://localhost:8010`；在 `./tests/run.sh` 的容器内会自动设为 `http://backend:8010`）
- `ADMIN_USERNAME` / `ADMIN_PASSWORD`：需要管理员权限的用例会读取；缺失时会 `t.Skip`（`./tests/run.sh` 会自动注入默认值）

推荐写法（示例）：
```go
c := testutil.NewClient()
pass := "Passw0rd!"

u := testutil.RegisterUser(t, c, testutil.UniquePhone(), pass)
login := testutil.Login(t, c, u.Username, pass)

resp, body, err := c.DoJSON("GET", "/users/me", nil, login.Token)
// 断言 status code + 关键字段即可，避免对“易变字段”做脆弱断言。
```

## 3. 除了集成测试，还需要哪些测试类型（Backend 视角）

建议补齐以下类型来支撑“质量”而不仅是“覆盖率”：

1) **契约测试（Contract Test）**（推荐 Go 1.25）
   - 目标：确保 `docs/reference/api/*` 与真实响应不漂移；防止前端/管理端/桌面端被回归破坏
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
