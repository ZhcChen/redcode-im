---
title: "refactor: 重建 api 测试架构为 Rust 原生轻量"
type: refactor
status: completed
date: 2026-06-09
---

# refactor: 重建 api 测试架构为 Rust 原生轻量

## Overview

api 模块当前的测试架构偏重且失衡：装了一整套重型 Rust 测试依赖却几乎没用，真正的集成/契约测试放在**独立 Go 模块 + Docker compose 全栈**里。本计划删除过重部分，重建为 **Rust 原生轻量**架构：单元测试 + 基于 `axum` `oneshot` 的进程内集成测试，对单一测试 DB 运行；保留 `external-mock` 与迁移一致性校验；砍掉 Go 黑盒契约层、吃灰依赖与重编排。

## Problem Frame

实测现状（2026-06-09）：

| 层 | 内容 | 规模/问题 |
|----|------|----------|
| Rust 单元测试 | `api/src` 内 `#[cfg(test)]` | 21 文件，正常，保留 |
| Rust 集成测试 | `api/tests/` | **仅 2 个**：`database_migration_smoke.rs`（真实、有价值）+ `smoke_test.rs`（59 字节占位） |
| Go 黑盒契约 | `tests/go/api/*` | 27 `_test.go` / 11 域；跑任何集成都要 Docker compose 全栈 + Go mock + 300s 健康等待 |
| 编排 + mock | `tests/docker-compose.yml`、`tests/run.sh`(195 行)、`tests/rust-tests.Dockerfile`、`tests/mocks/external`（Go） | 操作成本高 |

**核心问题**：
1. **重型 Rust 测试依赖几乎全吃灰**：`testcontainers / mockall(+derive) / wiremock / jsonpath-rust / tokio-tungstenite / tokio-test` 在 `api` 源码与测试中使用次数均为 **0**；仅 `tower` 在用。装备很重、实际很薄。
2. **集成/契约是跨语言的**：真正覆盖在独立 Go 模块（`go.mod` + 27 文件 + `internal/testutil`），跑一次集成要拉起 compose 全栈 + Go mock。维护与运行成本高。
3. **双 DB 供给 / 多套 mock**：testcontainers（吃灰）与 compose PG 两套思路并存；mockall + wiremock + Go external-mock 三套 mock。

## Requirements Trace

- R1. 删除 Go 黑盒契约层（`tests/go/api` + compose `go-tests` + `run.sh` 的 Go 编排）
- R2. 建立 Rust 原生集成测试骨架：`axum` `oneshot` 进程内打 Router + **单一**测试 DB
- R3. 用 Rust 重建关键契约覆盖（右尺寸，非与 27 个 Go 文件 1:1）
- R4. 保留 `external-mock`（B2/IPInfo/FCM）与迁移一致性校验（`database_migration_smoke`）
- R5. 砍掉吃灰的 Rust 测试 dev-deps，仅留集成所需
- R6. canonical 验证从「Docker 全栈 + Go 契约」改为 `cargo test`（单元 + 集成）；同步 Makefile/docs/matrix
- R7. 删除可逆（`git rm` 保历史）、分层提交；先建 Rust 覆盖再删 Go，避免覆盖真空

## Scope Boundaries

- **不动** `api` 业务逻辑、HTTP 路由路径、SQL 迁移文件、`.sqlx` offline 数据（编译期需要）。
- **不删** `tests/go/tooling`（Makefile/脚本守护测试，**仓库级、非 api**）与其依赖；保留精简后的 `tests/go/go.mod`。
- **不追求** 把 27 个 Go 契约 1:1 移植；按关键路径右尺寸重建（见 KTD8）。
- **不引入** 新的测试框架/DSL；用 axum + sqlx + tower 既有能力。
- 其它模块（admin/desktop/app/website）测试不在本轮范围。

## Context & Research

### Relevant Code and Patterns

- **现有集成测试模式（直接复用）**：`api/tests/database_migration_smoke.rs` 已用「外部 PG（`DATABASE_URL`）+ 每测试 `CREATE DATABASE` 临时库 + 跑 `Database::migrate()` + 断言 + `DROP DATABASE`」模式，并有 `EnvGuard` / `ENV_LOCK` 串行化 env 改动。**这就是目标 DB 策略的样板**（且证明 testcontainers 无需存在）。
- **AppState / Router**：`api/src/lib.rs` 导出 `pub struct AppState`（`lib.rs:35`）与 `pub fn create_routes() -> axum::Router<AppState>`（`lib.rs:44`）；`api/src/main.rs:102` 示范 `AppState { ... }` 构造。集成 harness 据此构建测试态 AppState（temp DB pool + 测试 redis + 指向 external-mock 的配置）并 `create_routes().with_state(state)` 后 `oneshot`。
- **依赖**：`sqlx 0.8.6`（postgres/migrate/macros）、`axum 0.8`、`tower 0.5`（已用，`ServiceExt::oneshot`）、`http-body-util 0.1`（读 body，新 harness 会用）。
- **app 自带迁移器**：用 `redcode_im_api::Database::migrate()`（非 `sqlx::migrate!`），故不用 `sqlx::test` 的自动迁移，沿用 `Database::migrate()`。

### Institutional Learnings

- `docs/solutions/` 无直接测试经验可循（仅 i18n handler 与 ce dirty-main 两条）。本计划的轻量模式属净新，建议执行后经 `ce:compound` 沉淀。
- **Prior art**：当前重架构源自 2026-03 的「全模块测试重建」（`docs/plans/2026-03-01-full-module-test-rebuild*.md`、`docs/plans/2026-03-05-cross-module-test-expansion*`、批次验收报告）。本计划是对其中 **api 契约层** 的精简反转，非推翻其它模块。

### Dev-deps 审计（实测使用次数）

| dep | api 中使用 | 处置 |
|-----|-----------|------|
| testcontainers | 0 | 删 |
| mockall / mockall_derive | 0 | 删 |
| wiremock | 0 | 删 |
| jsonpath-rust | 0 | 删 |
| tokio-tungstenite | 0 | 删 |
| tokio-test | 0 | 删 |
| tower | 3 | **留**（oneshot 需要） |
| http-body-util | 0（现） | **留/用**（新 harness 读 body 需要） |

## Key Technical Decisions

- **KTD1 — DB 策略：外部 PG + 每测试临时库（复用现有模式）。** 把 `database_migration_smoke.rs` 的 `TempDatabase` 提取为共享 harness；PG/Redis/external-mock 由**瘦身 compose** 提供（仅这三者，去掉 api 服务容器、rust-tests-in-container、go-tests）。**单一供给**，删 testcontainers。
- **KTD2 — HTTP 集成用 `axum` `oneshot`（进程内）。** `create_routes().with_state(test_state)` + `tower::ServiceExt::oneshot(request)`，不起网络 server、不拉 api 容器；快、可调试。
- **KTD3 — 保留 external-mock。** 测试态 AppState 的对象存储/IPInfo/FCM 配置指向 `external-mock`（沿用 `REDCODE_IM_B2_ENDPOINT` 等环境变量），覆盖上传/推送/地理流程。
- **KTD4 — 保留 `tests/go/tooling` + 精简 `go.mod`。** tooling 守护的是 Makefile/脚本（仓库级），与 api 无关，保留；`internal/testutil`（仅 api 契约用，tooling 不依赖）随 `tests/go/api` 一起删。
- **KTD5 — 先建后删，避免覆盖真空。** 顺序：先建 Rust harness（Unit 1）+ 核心域 Rust 集成（Unit 2），再删 Go 契约层（Unit 3）。
- **KTD6 — 砍吃灰 dev-deps。** 删 testcontainers/mockall(+derive)/wiremock/jsonpath-rust/tokio-tungstenite/tokio-test；留 tower、用 http-body-util。
- **KTD7 — 验证入口右移到 `cargo test`。** 新 `make api.test` = `cargo test --lib`（单元）+ `cargo test --tests`（集成，对瘦身 compose 起的依赖）。删/改 `tests.go`、`tests.contract` 的 Go 部分；同步 `docs/reference/testing/README.md`、`docs/reference/testing/matrix/api.csv`、`AGENTS.md` 测试段。
- **KTD8 — 右尺寸重建覆盖。** 按域建少量高价值集成测试（健康检查、auth 注册/登录、1~2 个核心 CRUD/上传/ws 握手），保留 `database_migration_smoke`；不与 27 个 Go 文件 1:1。后续可增量补。

## Open Questions

### Resolved During Planning
- **DB 策略？** → 外部 PG + 临时库（复用 `database_migration_smoke` 模式）+ 瘦身 compose 供给；删 testcontainers。
- **tooling/testutil 去留？** → 保留 tooling + 精简 go.mod；删 `tests/go/api` + `internal/testutil`。
- **run.sh/compose 去留？** → compose 瘦身为 pg+redis+external-mock；`run.sh` 的 Go 编排删除（验证改走 `make api.test` / `cargo test`），`run.sh` 是否整体删除见 Unit 5。
- **砍哪些 dep？** → 见 KTD6（审计已确认 0 使用）。

### Deferred to Implementation
- 每个域具体测哪些用例（happy/error）——执行时按 KTD8 右尺寸落地。
- 瘦身 compose 的最终文件形态（复用 `tests/docker-compose.yml` 瘦身 vs 新建 `tests/docker-compose.test.yml`）——执行时定。
- 哪些集成测试需要 redis（部分纯 HTTP 校验可能不需要）——执行时按用例定。
- `run.sh` 整体删除 vs 瘦身保留为「拉起依赖 + cargo test」薄封装——执行时按 Makefile 收口结果定。

## High-Level Technical Design

> *以下示意目标架构与集成 harness 数据流，是评审用的方向性指引，不是实现规范。实现者按上下文处理，勿照抄。*

```
新架构分层：
  api/src/**          #[cfg(test)] 单元测试        ── cargo test --lib（无需 DB）
  api/tests/support/  共享 harness                 ── 建临时库→migrate→建测试 AppState→Router
  api/tests/*.rs      集成测试（oneshot 打 Router）  ── cargo test --tests（需 PG/Redis/external-mock）
  tests/              瘦身 compose: pg + redis + external-mock（仅供集成依赖）
  tests/go/tooling    仓库级 Makefile/脚本守护（保留）

集成 harness 数据流（oneshot，进程内）：
  TempDatabase::create()      // CREATE DATABASE <uuid>，复用 database_migration_smoke 模式
    -> Database::migrate()     // 跑 app 自带迁移器
    -> build AppState{ pool, redis(test), config->external-mock }
    -> create_routes().with_state(state)
    -> router.oneshot(Request::...)   // tower::ServiceExt
    -> assert status / body(http-body-util)
    -> TempDatabase::cleanup() // DROP DATABASE
```

## Implementation Units

- [ ] **Unit 1：Rust 集成测试 harness（共享支撑）**

**Goal:** 提供可复用的集成测试支撑：临时库生命周期 + 测试态 AppState 构造 + oneshot 辅助。

**Requirements:** R2, R4

**Dependencies:** 无

**Files:**
- Create: `api/tests/support/mod.rs`（或 `api/tests/common/mod.rs`）— harness
- Modify: `api/tests/database_migration_smoke.rs`（把 `TempDatabase`/`EnvGuard` 提取/复用到 support，避免重复）
- Modify: `api/Cargo.toml`（确保 `http-body-util` 可用于 dev）

**Approach:**
- 复用 `database_migration_smoke.rs` 的临时库模式（外部 `DATABASE_URL` → `CREATE DATABASE <uuid>` → `Database::migrate()` → 用毕 `DROP`）。
- harness 暴露：`spawn_app()`/`test_router()` 返回可 `oneshot` 的 `Router` + 测试上下文（pool、配置）；测试态配置把对象存储/IPInfo/FCM 指向 external-mock 环境变量。
- 用 `tower::ServiceExt::oneshot` + `http-body-util` 读响应体。

**Patterns to follow:** `api/tests/database_migration_smoke.rs`（TempDatabase/EnvGuard/ENV_LOCK）；`api/src/main.rs:102` 的 AppState 构造。

**Test scenarios:**
- Happy path：harness `oneshot` `GET /healthz` 返回 200（证明 Router+state 装配成功）。
- Edge case：临时库在测试结束（含 panic 路径）能清理（`Drop`/显式 cleanup）。
- Integration：`GET /readyz` 在 DB/Redis 就绪时 200（证明 state 真连到依赖）。

**Verification:** `cargo test --tests` 下该 harness 的 healthz/readyz 用例通过（依赖由瘦身 compose 提供）。

- [ ] **Unit 2：核心域 Rust 集成测试重建**

**Goal:** 用 harness 重建关键契约覆盖（右尺寸），替代 Go 契约的核心价值。

**Requirements:** R3, R4

**Dependencies:** Unit 1

**Files:**
- Create: `api/tests/auth_integration.rs`、`api/tests/users_integration.rs`、`api/tests/uploads_integration.rs`、`api/tests/ws_integration.rs`、`api/tests/admin_integration.rs`（域命名示意，最终域集执行时定）
- Keep: `api/tests/database_migration_smoke.rs`

**Approach:**
- 每域 1 个集成文件，覆盖关键 happy-path + 关键 error；通过 harness 的 oneshot 打真实 Router。
- 上传/推送/地理相关用例经 external-mock 验证（KTD3）。
- 优先级：健康检查（Unit 1 已含）、auth 注册/登录、users 资料、uploads 直传 commit、ws 握手鉴权、admin bootstrap/RBAC 快照。

**Execution note:** 先为每个域写一个失败的请求/响应契约集成测试，再让其通过（test-first 收口契约）。

**Test scenarios:**
- Happy path（每域）：核心请求 → 期望状态码 + 关键响应字段。例：`POST /auth/register` 新邮箱 → 201/200 + 返回 token；`POST /auth/login` 正确密码 → 200 + token。
- Error path：`POST /auth/login` 错误密码 → 401；缺字段 → 400/422；未鉴权访问 user 路由 → 401。
- Integration：上传 commit 触发 external-mock 对象写入；ws 握手携带非法 token → Unauthorized（对齐原 `tests/go/api/ws` 行为）。

**Verification:** `cargo test --tests` 全绿；覆盖到上述每域至少 happy + 1 error。

- [ ] **Unit 3：删除 Go 黑盒契约层 + 编排瘦身**

**Goal:** 移除 Go 契约层与重编排，compose 瘦身到只供集成依赖。

**Requirements:** R1, R4

**Dependencies:** Unit 2（先有 Rust 覆盖再删）

**Files:**
- Delete（`git rm`）：`tests/go/api/`（27 文件）、`tests/go/internal/testutil/`（仅 api 契约用）
- Keep：`tests/go/tooling/`、`tests/go/go.mod`（精简 require）
- Modify：`tests/docker-compose.yml`（删 `go-tests`、`rust-tests`、`api` 服务，仅留 `postgres`/`redis`/`external-mock`）、`tests/run.sh`（删 Go 编排；整体删除或瘦身见 Unit 5）、`tests/rust-tests.Dockerfile`（评估删除——集成改本机 `cargo test`，不再容器内跑）

**Approach:**
- 先确认 `tooling` 不依赖 `internal/testutil`（已核实不依赖），安全删 testutil。
- compose 留三依赖供 `cargo test --tests` 连接（DATABASE_URL/REDIS/external-mock）。

**Test scenarios:** Test expectation: none —— 删除/编排瘦身，无新行为；以「tooling 仍通过 + 瘦身 compose config 有效 + cargo test 仍能连依赖」验证。

**Verification:** `cd tests/go && go test ./tooling/` 通过；`docker compose -f <瘦身 compose> config -q` 有效；Unit 2 集成测试仍能对瘦身 compose 起的依赖跑绿；全仓无对已删 `tests/go/api`/`testutil` 的悬挂引用。

- [ ] **Unit 4：砍未用 Rust 测试 dev-deps**

**Goal:** 移除吃灰依赖，缩小测试依赖面与编译开销。

**Requirements:** R5

**Dependencies:** Unit 1, Unit 2（确认 harness/测试只用 tower + http-body-util 后再砍）

**Files:**
- Modify: `api/Cargo.toml`（删 `testcontainers`、`mockall`、`mockall_derive`、`wiremock`、`jsonpath-rust`、`tokio-tungstenite`、`tokio-test`；留 `tower`、`http-body-util`）
- 自动重生成：`api/Cargo.lock`

**Test scenarios:** Test expectation: none —— 依赖裁剪；以编译与测试回归验证。

**Verification:** `SQLX_OFFLINE=true cargo check --tests` 通过；`cargo test --lib` 与 `--tests` 全绿；`cargo tree` 不再含已删 crate。

- [ ] **Unit 5：Makefile / 文档 / 矩阵 / 验证入口收口**

**Goal:** 把 canonical 验证从「Docker 全栈 + Go」改为 `cargo test`，并同步文档与守护测试。

**Requirements:** R6

**Dependencies:** Unit 1–4

**Files:**
- Modify: `Makefile`（`api.test` = 单元 + 集成；新增/改 `api.test.integration` 起瘦身依赖 + `cargo test --tests`；删/改 `tests.go`、`tests.contract` 的 Go 部分；`test.all` 同步）
- Modify: `docs/reference/testing/README.md`、`docs/reference/testing/matrix/api.csv`（去 Go 契约口径，换 Rust 单元/集成）、`AGENTS.md`（测试段：api 走 `cargo test`）
- Modify: `tests/go/tooling/workflow_targets_test.go`（若 `api.test.*` 目标名变化，同步断言）

**Approach:** 守护测试断言要与最终 Makefile 目标一致（已知 go 可用，可真实跑验证）。

**Test scenarios:**
- Happy path：`make api.test`（或 `api.test.unit`/`api.test.integration`）能跑通。
- Integration：`tests/go/tooling` 守护测试断言的 api 目标与 Makefile 实际一致 → `go test ./tooling/` 通过。

**Verification:** `make api.test.unit` 通过；`make api.test.integration` 在瘦身依赖下通过；`go test ./tooling/` 通过；`docs/reference/testing/README.md` 与 `matrix/api.csv` 口径与实际一致，无 Go 契约残留口径。

## System-Wide Impact

- **Interaction graph:** harness 复用 app 的 `Database`/`AppState`/`create_routes`；测试经 external-mock 触达对象存储/推送/地理 mock；`tests/go/tooling` 仍读 Makefile。
- **Error propagation:** 集成测试经 oneshot 验证错误响应码/体；DB 连接失败应让测试快速失败并清理临时库。
- **State lifecycle risks:** 临时库务必在成功/失败/panic 路径都清理（`Drop` + 显式 cleanup）；env 改动用 `EnvGuard`/`ENV_LOCK` 串行化避免串扰（沿用现有模式）。
- **API surface parity:** 不改 HTTP 路由/契约；仅替换"验证手段"（Go 黑盒 → Rust oneshot）。
- **Integration coverage:** Go 契约删除前必须由 Rust 集成覆盖关键路径（KTD5 先建后删），否则出现覆盖真空。
- **Unchanged invariants:** 业务逻辑、SQL 迁移、`.sqlx`、external-mock 行为、`tests/go/tooling` 守护均不变。

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| 删 Go 契约造成覆盖真空 | KTD5 先建 Rust harness+核心覆盖，再删 Go；Unit 顺序强制依赖 |
| 临时库泄漏（测试中断未清理） | `Drop` + 显式 cleanup；CI/本地用独立 admin 连接 DROP WITH FORCE（沿用现有） |
| 集成测试需要的依赖（PG/Redis/mock）未起 | `make api.test.integration` 负责拉起瘦身 compose 再 `cargo test --tests`；文档写清前置 |
| 砍 dep 误删仍被某处用到的 crate | Unit 4 在 harness/测试落地后再砍，并以 `cargo check --tests` 兜底（审计已确认 0 使用） |
| 本机无 Docker 时无法跑集成 | 单元测试（`cargo test --lib`）不需依赖可单独跑；集成需 Docker（与原架构一致，甚至更轻） |
| 迁移一致性校验价值丢失 | `database_migration_smoke.rs` 保留并纳入新集成层（R4） |

## Documentation / Operational Notes

- `docs/reference/testing/README.md` 与 `matrix/api.csv` 改为 Rust 单元/集成口径，移除 Go 契约栈描述。
- `AGENTS.md` 测试段：api 验证 = `cargo test`（单元 + 集成），集成前置 = 瘦身 compose 起 pg/redis/external-mock。
- 提交切分：建议每 Unit 一个 Conventional Commit，先建（Unit 1-2）后删（Unit 3），便于 bisect 与必要时回退。
- 执行完成后经 `ce:compound` 把「Rust 原生轻量测试架构」沉淀到 `docs/solutions/`。

## Sources & References

- 现有集成样板：`api/tests/database_migration_smoke.rs`
- AppState/Router：`api/src/lib.rs`、`api/src/main.rs`、`api/src/routes.rs`
- 现编排：`tests/docker-compose.yml`、`tests/run.sh`、`tests/rust-tests.Dockerfile`、`tests/mocks/external`
- 待删 Go 契约：`tests/go/api/*`、`tests/go/internal/testutil`
- 保留守护：`tests/go/tooling/workflow_targets_test.go`
- Prior art（当前重架构来源）：`docs/plans/2026-03-01-full-module-test-rebuild*.md`、`docs/plans/2026-03-05-cross-module-test-expansion*.md`
