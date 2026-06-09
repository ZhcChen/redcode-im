---
title: "refactor: 后端模块 backend → api 完整重命名"
type: refactor
status: active
date: 2026-06-09
---

# refactor: 后端模块 backend → api 完整重命名

## Overview

把后端模块从 `backend` 完整统一重命名为 `api`：目录、Rust crate 名、二进制名、Docker Compose 服务名、Makefile 目标，以及所有活跃文档/路径引用一次性对齐，做到无残留不一致。

这是「对所有模块做功能/架构调整」的第一步。本计划同时沉淀为一套**可复用的模块重命名 SOP**（见末尾），后续模块（frontend/admin/desktop/website）照搬。

> 关键现实：`backend` 不是一个孤立模块。`desktop` 在**编译期**通过 `redcode-im-backend = { path = "../../backend" }` 依赖它，`admin` e2e、`frontend` proto 脚本也按路径引用它。因此「只改后端」会连带影响 desktop/admin/frontend 的构建与脚本——这些引用更新属于本次重命名的**必需收尾**，不算「改其它模块」。

## Problem Frame

仓库现以 `backend/` 作为后端模块目录、`redcode-im-backend` 作为 crate/二进制名、`backend` 作为 compose 服务名与 Makefile 目标前缀。用户希望统一为 `api` 命名，使模块语义更直观，并为后续全模块命名/架构调整开路。改动横跨构建、容器、命令入口、文档与跨模块依赖，约 70+ 处引用，改不全会留下「目录叫 api、服务/构建仍叫 backend」的不一致。

## Requirements Trace

- R1. 目录 `backend/` → `api/`（保留 git 历史）
- R2. Rust crate 名 `redcode-im-backend` → `redcode-im-api`（含二进制名与所有消费方）
- R3. Docker Compose 服务名 `backend` → `api`（含 container_name、服务间 hostname、depends_on）
- R4. Makefile 目标 `backend.*` → `api.*`（含变量与既有 `api-*` 兼容别名的收口）
- R5. 所有**活跃**文档与路径引用同步（权威规范 `AGENTS.md`、兼容入口 `CLAUDE.md`、`README.md`、活跃 reference/operations/api/testing 文档、`docs/reports/task-list.md`）
- R6. 跨模块对后端的引用不破：desktop（crate 依赖 + `use` 语句）、admin（e2e fixture 路径）、frontend（proto 脚本路径）
- R7. 全流程保持「每层独立可验证、可回滚」，产出可复用 SOP

## Scope Boundaries

- **不改后端任何业务逻辑/行为/API 路由路径**（`/api/...` HTTP 路由本就如此，与模块目录名无关，不动）。本次是纯命名重构。
- **不重写历史性文档**：带日期的验收报告（`docs/reports/2026-03-0*-batch-*`、`docs/reports/2026-03-04-*`）、已被取代的历史计划（`docs/plans/2026-03-05-backend-wave-*`、`docs/plans/2026-03-26-i18n-*` 等）、`docs/solutions/` 复盘——这些是时间点记录，改写会失真，保持原样。
- **不手改构建产物**：`backend/Cargo.lock`、`desktop/src-tauri/Cargo.lock` 由 cargo 自动重生成；`frontend/build/**`（xcresult/intermediates）、`target/` 为产物，随构建重建，不手动编辑。
- **不顺手重命名其它模块目录**（frontend/admin/desktop/website 的目录名）——本轮只动 backend→api，其它模块仅更新「指向后端」的引用。
- 不引入 cargo workspace（当前 backend 为独立 crate，维持独立）。

## Context & Research

### Relevant Code and Patterns

**目录与 crate（R1/R2）**
- `backend/Cargo.toml` → `name = "redcode-im-backend"`（crate 定义）
- `backend/build.rs`、`backend/.env.example`、`backend/README.md`、`backend/sql/base.sql`、`backend/sql/README.md`、`backend/sql/migrations/README.md`、`backend/scripts/test-ip-geolocation-switch.sh` 等含 `backend/` 自路径引用（git mv 后需核实是否需改）
- 二进制名 `redcode-im-backend` 出现在：`backend/docker/Dockerfile`、`backend/docker/release/Dockerfile`、`backend/scripts/upload.sh`、`backend/deploy.sh`、`backend/scripts/build-linux-zig.sh`

**跨模块消费方（R6）**
- `desktop/src-tauri/Cargo.toml:55` → `redcode-im-backend = { path = "../../backend" }`
- `desktop/src-tauri/src/account/commands.rs:4`、`desktop/src-tauri/src/account/mod.rs:7-8` → `use redcode_im_backend::...`（3 处；crate 名连字符在 `use` 中为下划线：`redcode_im_backend` → `redcode_im_api`）
- `admin/playwright-tests/support/live-backend-fixtures.ts:25` → `'../../../backend/docker/dev/docker-compose.yml'`
- `frontend/scripts/gen_ws_proto.sh:5` → `PROTO_DIR="$ROOT_DIR/backend/proto"`

**Compose（R3）**
- `backend/docker/dev/docker-compose.yml`、`backend/docker/release/docker-compose.yml`、`tests/docker-compose.yml`
- 服务键 `backend:`、`container_name: redcode-{dev,release}-backend`、`command: ["cargo","run","--bin","redcode-im-backend"]`
- `tests/docker-compose.yml`：`working_dir: /workspace/backend`、卷 `../backend:/workspace/backend` 与 `cargo_target:/workspace/backend/target`、`API_BASE_URL: http://backend:8010`、`depends_on: backend`

**Makefile（R4）**
- `API_COMPOSE_FILE := $(ROOT_DIR)/backend/docker/dev/docker-compose.yml`、`API_SERVICE := backend`
- 目标：`backend.up/down/restart/reset/logs/ps/test/test.unit/test.integration/test.smoke`，`.PHONY` 列表，`status`/`dev.up`/`dev.down`/`help` 文案
- **已存在** `api-up/api-down/api-logs/api-ps`（连字符）作为「兼容旧命令」别名，当前委托到 `backend.*`——重命名后需收口（见 KTD5）

**活跃文档（R5）**
- `AGENTS.md`(7)、`CLAUDE.md`(3)、`README.md`(3)、`docs/index.md`
- `docs/reference/api/{api-overview,api-reference,websocket}.md`、`docs/reference/architecture/{end-to-end-encryption-design,push-notification-design,redis-setup}.md`、`docs/reference/guides/sql-development.md`
- `docs/reference/operations/{dev-and-build,docker-deploy,deployment-env,troubleshooting,upgrade-migration}.md`
- `docs/reference/testing/README.md`、`docs/reference/testing/matrix/backend.csv`（文件名改 `api.csv`）、`docs/reference/testing/matrix/admin.csv`（内容引用）
- `docs/reports/task-list.md`

### Institutional Learnings

- `docs/solutions/` 暂无重命名相关沉淀（已检索 `rename/重命名/改名`，无命中）。本计划执行后应经 `ce:compound` 把 SOP 落 `docs/solutions/`。

### External References

- 跳过外部研究：纯内部机械重命名，无外部最佳实践依赖。

## Key Technical Decisions

- **KTD1：始终可编译的提交切分（路径先行、改名其后）。** 先 `git mv` + 改所有 `backend/` 路径引用（此时 crate 名不变，api/ 仍可编译、desktop 路径已修正），再单独改 crate/二进制名。每个 commit 落地后仓库均「绿」，便于 `git bisect`。
- **KTD2：用 `git mv backend api` 保留历史**，不要删旧建新。
- **KTD3：文档分级。** 只改活跃/权威文档（见 R5 清单），历史时间点文档保持原样（见 Scope）。如历史文档影响理解，仅在必要处加一行注记，不整体改写。
- **KTD4：产物不手改。** `Cargo.lock`（两处）、`frontend/build/**`、`target/` 交给工具重生成。
- **KTD5：Makefile 别名收口。** 规范目标统一为 `api.*`；移除现有冗余的 `api-*`（连字符）旧别名；可临时新增 `backend.* → api.*` 兼容别名照顾肌肉记忆，并在文档注明后续移除。最终 `API_SERVICE := api`、`API_COMPOSE_FILE` 指向 `api/docker/dev/...`。
- **KTD6：生产 systemd 服务名解耦。** `backend/deploy.sh` 引用 systemd 单元 `redcode-im-backend.service`（仓库外、生产主机）。本次改二进制文件名为 `redcode-im-api`，但**不假定**自动改名已部署的 systemd 单元；在 deploy.sh/运维文档中显式说明二者关系，避免「改了仓库、线上服务名没动」造成部署事故（见 Risks / Operational Notes）。

## Open Questions

### Resolved During Planning

- **改到哪一层？** → 完整统一为 api（目录 + crate + compose 服务 + Makefile + 活跃文档），用户已确认。
- **历史文档要不要一起改？** → 不改，仅改活跃/权威文档（KTD3）。供 review 时确认。
- **既有 `api-*` 别名怎么办？** → 收口为 `api.*` 规范目标，移除旧 `api-*`（KTD5）。
- **是否触及 SQL/迁移？** → 不触及业务 SQL；`backend/sql/` 内仅可能有 `backend/` 自路径字样（文档性），按路径引用处理，不动迁移逻辑、不新增迁移。

### Deferred to Implementation

- `git mv` 后 `api/` 内部各脚本/`.env.example`/`build.rs`/`sql/*.md` 中 `backend/` 自路径的逐一确认与替换（执行时按 grep 命中处理）。
- `desktop/src-tauri/Cargo.lock`、`backend/Cargo.lock` 重生成后的 diff 确认（执行时 `cargo build` 触发）。
- Makefile 兼容别名「临时保留还是直接移除」的最终取舍（执行时按 KTD5 默认实现，review 可调）。

## Implementation Units

- [ ] **Unit 1：目录迁移与所有 `backend/` 路径引用对齐**

**Goal:** `git mv backend api`，并把全仓所有指向 `backend/` 路径的引用改为 `api/`，crate 名暂不动，保证落地后即可编译、compose 可起、desktop 可构建。

**Requirements:** R1, R6（路径部分）

**Dependencies:** 无

**Files:**
- 移动：`backend/` → `api/`（`git mv`）
- 修改（compose 路径/卷/workingdir/compose-file 变量）：`api/docker/dev/docker-compose.yml`、`api/docker/release/docker-compose.yml`、`tests/docker-compose.yml`、`Makefile`（`API_COMPOSE_FILE`）
- 修改（跨模块路径）：`desktop/src-tauri/Cargo.toml`（`path = "../../api"`）、`admin/playwright-tests/support/live-backend-fixtures.ts`、`frontend/scripts/gen_ws_proto.sh`
- 修改（根）：`.gitignore`（`backend/coverage/` → `api/coverage/`）
- 修改（api 内部自路径，按 grep 命中）：`api/.env.example`、`api/build.rs`、`api/README.md`、`api/sql/base.sql`、`api/sql/README.md`、`api/sql/migrations/README.md`、`api/scripts/*.sh` 中的 `backend/` 字样
- Test: 无新增测试

**Approach:**
- 先 `git mv`，再用分类 grep（`backend/` 作为路径片段）逐文件替换，避开历史文档与构建产物。
- 此阶段**不动** crate 名 `redcode-im-backend`，故 `cargo build`、desktop 依赖（路径已修正、名未变）均应正常。

**Test scenarios:** Test expectation: none —— 纯路径/目录重命名，无行为变化；以构建与启动验证替代。

**Verification:**
- `cd api && cargo build` 成功
- `cd desktop/src-tauri && cargo build` 成功（路径已修正）
- `docker compose -f api/docker/dev/docker-compose.yml up -d` 起得来，`/healthz` 健康
- `grep -rn "backend/" --exclude-dir={target,node_modules,.git,build}` 仅剩历史文档等有意保留项

- [ ] **Unit 2：crate 与二进制改名 `redcode-im-backend` → `redcode-im-api`**

**Goal:** 重命名 crate 与产物二进制，并同步所有消费方（含 desktop 代码 `use` 语句、Dockerfile/脚本里的二进制名、compose `--bin`）。

**Requirements:** R2, R6（crate 部分）

**Dependencies:** Unit 1

**Files:**
- 修改：`api/Cargo.toml`（`name = "redcode-im-api"`）
- 修改（二进制名）：`api/docker/Dockerfile`、`api/docker/release/Dockerfile`、`api/scripts/upload.sh`、`api/deploy.sh`、`api/scripts/build-linux-zig.sh`、`api/docker/dev/docker-compose.yml`、`tests/docker-compose.yml`（`--bin redcode-im-api`）
- 修改（desktop 消费）：`desktop/src-tauri/Cargo.toml`（依赖名 `redcode-im-api`）、`desktop/src-tauri/src/account/commands.rs`、`desktop/src-tauri/src/account/mod.rs`（`use redcode_im_api::...`，3 处）
- 自动重生成（不手改）：`api/Cargo.lock`、`desktop/src-tauri/Cargo.lock`
- Test: 无新增测试

**Approach:**
- crate 名连字符 → `use` 下划线：`redcode_im_backend` → `redcode_im_api`。
- KTD6：在 `api/deploy.sh` 注明二进制名已变、生产 systemd 单元名需运维侧另行决定，不在脚本里隐式假定线上服务改名。

**Test scenarios:** Test expectation: none —— 改名重构，无行为变化；以编译 + 现有测试回归验证。

**Verification:**
- `cd api && cargo build && cargo test --lib` 通过，产物为 `target/release/redcode-im-api`
- `cd desktop/src-tauri && cargo build` 通过（依赖名 + use 已更新）
- `grep -rn "redcode.im.backend\|redcode_im_backend" --exclude-dir={target,node_modules,.git}` 仅剩 `Cargo.lock`（待重生成）与历史文档

- [ ] **Unit 3：Docker Compose 服务名 `backend` → `api`**

**Goal:** 三个 compose 文件的服务键、container_name、服务间 hostname、depends_on 全部改为 `api`。

**Requirements:** R3

**Dependencies:** Unit 1, Unit 2

**Files:**
- 修改：`api/docker/dev/docker-compose.yml`、`api/docker/release/docker-compose.yml`、`tests/docker-compose.yml`
  - 服务键 `backend:` → `api:`；`container_name: redcode-{dev,release}-backend` → `...-api`
  - `tests`：`API_BASE_URL: http://backend:8010` → `http://api:8010`；`depends_on: backend` → `api`；`working_dir`/卷 `/workspace/backend` → `/workspace/api`（若 Unit 1 未覆盖则在此对齐）
- Test: 无新增测试

**Approach:**
- 服务名作为容器 DNS hostname 被测试 runner 使用，务必同步 `API_BASE_URL` 与所有 `depends_on`。

**Test scenarios:** Test expectation: none —— 编排重命名；以栈启动 + 契约测试回归验证。

**Verification:**
- `docker compose -f api/docker/dev/docker-compose.yml up -d` 健康
- 测试栈可起、服务间 `http://api:8010` 可达
- `make tests.contract`（或 `./tests/run.sh`）通过

- [ ] **Unit 4：Makefile 目标 `backend.*` → `api.*` 并收口别名**

**Goal:** 规范命令入口统一为 `api.*`，变量与文案同步，收口既有 `api-*` 旧别名。

**Requirements:** R4

**Dependencies:** Unit 1, Unit 3

**Files:**
- 修改：`Makefile`
  - `API_SERVICE := api`；确认 `API_COMPOSE_FILE` 指向 `api/docker/dev/...`（Unit 1 已改）
  - 目标 `backend.* → api.*`（up/down/restart/reset/logs/ps/test/test.unit/test.integration/test.smoke）
  - `.PHONY` 列表、`status`/`dev.up`/`dev.down`/`help`/`test.all` 文案中的 backend 字样
  - 按 KTD5 处理 `api-*`（连字符）旧别名：移除冗余项；可临时加 `backend.* → api.*` 兼容别名并注明后续移除
- Test: 无新增测试

**Approach:**
- 注意区分 `api.`（点，新规范目标）与历史 `api-`（连字符，旧别名），避免误改。

**Test scenarios:** Test expectation: none —— 命令入口重命名；以 make 目标可用性验证。

**Verification:**
- `make api.up`、`make api.logs`、`make api.ps`、`make api.down` 均可用
- `make status`、`make help` 文案一致无残留 `backend.`
- `make api.test.unit` 可跑

- [ ] **Unit 5：活跃文档与权威规范同步**

**Goal:** 更新活跃/权威文档中的 `backend`/`redcode-im-backend`/路径引用为 `api`，历史文档保持原样。

**Requirements:** R5, R6（admin.csv 等引用）

**Dependencies:** Unit 1–4（命令/路径定稿后再改文档，避免回改）

**Files:**
- 修改：`AGENTS.md`、`CLAUDE.md`、`README.md`、`docs/index.md`
- 修改：`docs/reference/operations/{dev-and-build,docker-deploy,deployment-env,troubleshooting,upgrade-migration}.md`、`docs/reference/api/{api-overview,api-reference,websocket}.md`、`docs/reference/architecture/{end-to-end-encryption-design,push-notification-design,redis-setup}.md`、`docs/reference/guides/sql-development.md`
- 修改 + 改名：`docs/reference/testing/matrix/backend.csv` → `api.csv`（`git mv`），`docs/reference/testing/README.md`、`docs/reference/testing/matrix/admin.csv` 内引用
- 修改：`docs/reports/task-list.md`
- 不改：`docs/plans/2026-03-05-backend-wave-*`、`docs/plans/2026-03-26-i18n-*`、`docs/reports/2026-03-0*`、`docs/solutions/*`（历史记录）
- Test: 无新增测试

**Approach:**
- AGENTS.md 为权威规范，需把「本地 Backend 环境/重启规则」等命令路径同步为 `api/docker/dev/...` 与 `api.*`，并与 CLAUDE.md 兼容入口保持一致。

**Test scenarios:** Test expectation: none —— 文档同步。

**Verification:**
- 活跃文档内命令/路径与 Unit 1–4 实际一致（抽查 dev-and-build、docker-deploy、AGENTS.md 可照做）
- `grep -rn "backend" AGENTS.md CLAUDE.md README.md docs/index.md docs/reports/task-list.md` 无残留（历史文档除外）

## System-Wide Impact

- **Interaction graph：** desktop Tauri 编译期依赖 api crate（Cargo path + 3 处 `use`）；admin Playwright e2e 按相对路径引用 api compose；frontend proto 生成脚本读 `api/proto`；compose 服务名作为容器 DNS 被测试 runner 解析。
- **Error propagation：** 任一引用漏改 → 编译失败（desktop/api）、compose 起不来、e2e/proto 脚本路径报错。以每单元后的 grep 清扫 + 构建/启动验证拦截。
- **State lifecycle risks：** `Cargo.lock` 与 `target/` 缓存陈旧——交由 cargo 重生成；compose 卷名 `cargo_target` 指向 `/workspace/api/target` 需对齐。
- **API surface parity：** HTTP 路由 `/api/...`、WebSocket 协议、DB schema **不变**——本次仅模块命名，无对外契约变化。
- **Unchanged invariants：** 后端业务逻辑、路由路径、SQL 迁移、端口（8010）均不变；生产 systemd 单元名是否随之改名属仓库外决策（KTD6）。

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| desktop crate 依赖漏改导致 Tauri 编不过 | Unit 2 必须同步 Cargo.toml 依赖名 + 3 处 `use`；以 `cd desktop/src-tauri && cargo build` 验证 |
| compose 服务名/hostname 漏改致测试栈断连 | Unit 3 同步 `API_BASE_URL`/`depends_on`；以测试栈启动 + 契约测试验证 |
| Makefile `api.`(点) 与历史 `api-`(连字符) 误改混淆 | KTD5 明确区分；逐目标核对 |
| 生产 systemd 单元 `redcode-im-backend.service` 未同步改名 → 部署/重启失效 | KTD6：deploy.sh/运维文档显式说明，二进制名与线上服务名解耦决策交运维 |
| 误改历史文档造成时间点记录失真 | KTD3：历史文档不动，仅改活跃文档 |
| 误伤无关单词（如散文里的 "backend"/"后端"） | 用带分隔符的精确 pattern（`backend/`、`redcode-im-backend`、`backend:`、`backend.`），按命中逐处确认，不做无差别全局替换 |

## Documentation / Operational Notes

- **运维（KTD6）：** 二进制改名 `redcode-im-api` 后，生产主机若已存在 `redcode-im-backend.service` systemd 单元，需运维侧决定：保持单元名不变（仅换二进制路径/内容）或同步改名 `redcode-im-api.service`（涉及 stop/disable 旧、enable/start 新）。`api/deploy.sh` 与 `docs/reference/operations/docker-deploy.md`/`deployment-env.md` 应注明此点。
- **提交切分：** 建议每个 Unit 一个 Conventional Commit（如 `refactor(api): rename backend dir to api`、`refactor(api): rename crate to redcode-im-api` …），便于 `git bisect`。
- **SOP 沉淀：** 执行完成后经 `ce:compound` 将下方 SOP 落 `docs/solutions/`，供后续模块复用。

## 可复用：模块重命名 SOP（草案，执行后经 ce:compound 定稿）

1. **枚举影响面**（分类 grep，排除 `target/`、`node_modules/`、`.git/`、`build/`）：
   - 目录路径片段 `<old>/`；crate/包名 `<old-crate>`（连字符）与代码内下划线形式；compose 服务键 `<old>:` 与 hostname；Makefile 目标 `<old>.`；文档散文。
   - 标注跨模块编译期依赖（其它模块的 Cargo path/`use`、相对路径脚本、e2e fixture）。
2. **按「始终可编译」切层提交**：① `git mv` + 路径引用 → ② crate/二进制名 + 消费方 → ③ compose 服务名/hostname → ④ Makefile 目标/别名 → ⑤ 活跃文档。
3. **每层后验证**：相关 crate `cargo build`、依赖方 `cargo build`、`docker compose up` 健康、契约/集成测试回归、`grep` 清扫确认仅剩有意保留项。
4. **分级文档**：只改活跃/权威文档，历史时间点记录不动。
5. **产物交工具重生成**：`Cargo.lock`、`target/`、平台 `build/` 不手改。
6. **识别仓库外耦合**：systemd 单元名、CI、外部消费者——显式记录并交对应负责人，不在仓库内隐式假定。

## Sources & References

- 关键跨模块依赖：`desktop/src-tauri/Cargo.toml`、`desktop/src-tauri/src/account/{commands,mod}.rs`、`admin/playwright-tests/support/live-backend-fixtures.ts`、`frontend/scripts/gen_ws_proto.sh`
- 命令入口：`Makefile`（`API_SERVICE`/`API_COMPOSE_FILE`/`backend.*`/既有 `api-*`）
- 容器：`backend/docker/dev/docker-compose.yml`、`backend/docker/release/docker-compose.yml`、`tests/docker-compose.yml`
- 权威规范：`AGENTS.md`（§本地 Backend 环境/重启规则/技术栈速查）、兼容入口 `CLAUDE.md`
