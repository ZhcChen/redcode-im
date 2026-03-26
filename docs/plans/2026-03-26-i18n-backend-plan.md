# Backend 多语言迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `backend` 建立基于 `Accept-Language` 的服务端多语言基础设施，统一输出 `code + message_key + message`，并先覆盖高频业务域。

**Architecture:** 在 [2026-03-26-i18n-architecture-design.md](/Users/chen/code/redcode-im/docs/plans/2026-03-26-i18n-architecture-design.md) 基础上，新增 `backend/src/i18n/` 与请求级 locale 上下文，把 [error.rs](/Users/chen/code/redcode-im/backend/src/error.rs) 从“自由字符串”重构为“结构化消息描述 + 本地化渲染”。高频 handler 逐域迁移，验证采用 Rust 单元测试 + 测试栈中的 Go 黑盒契约测试。

**Tech Stack:** Rust 2021、Axum、Serde JSON、Docker Compose、Go 1.25 黑盒测试

---

### Task 1: 建立 `backend` i18n 基础设施与协议字段

**Files:**
- Create: `backend/src/i18n/mod.rs`
- Create: `backend/src/i18n/locale.rs`
- Create: `backend/src/i18n/catalog.rs`
- Create: `backend/src/i18n/localizer.rs`
- Create: `backend/src/i18n/message.rs`
- Create: `backend/src/i18n/tests.rs`
- Create: `backend/i18n/zh-CN/common.json`
- Create: `backend/i18n/en-US/common.json`
- Modify: `backend/src/error.rs`
- Modify: `backend/src/lib.rs`

- [ ] **Step 1: 先写失败的 Rust 单元测试**
  - 覆盖 `Accept-Language` 精确命中、语言族回退、默认回退到 `zh-CN`、缺失 key 时回退到 `message_key`。
  - 为 `ErrorResponse` 先写协议测试，要求响应结构包含 `code`、`message_key`、`message`、`message_params`。

- [ ] **Step 2: 新增 `i18n` 模块并实现 catalog 加载**
  - 在 `backend/src/i18n/` 下实现 locale 解析、语言包加载、消息查找与参数插值。
  - `backend/i18n/` 首批只落 `zh-CN` 与 `en-US`，先提供 `common.*` 基础文案。

- [ ] **Step 3: 重构 `AppError` 与 `ErrorResponse`**
  - 让 `AppError` 持有 `message_key` 与可选 `message_params`，不再将最终展示文案作为唯一真源。
  - 让 `ErrorResponse` 始终输出 `code + message_key + message + message_params + details`。

- [ ] **Step 4: 运行定向 Rust 测试**
  - Run: `docker compose -f tests/docker-compose.yml run --rm rust-tests cargo test i18n --lib -- --test-threads=1`
  - Expected: `i18n` 基础测试通过，缺失翻译场景返回 `message_key`。

- [ ] **Step 5: 提交基础设施改动**
  - Run: `git add backend/src/i18n backend/src/error.rs backend/src/lib.rs backend/i18n && git commit -m "feat(backend): add i18n error foundation"`

### Task 2: 接入请求级 locale 上下文与统一错误出口

**Files:**
- Create: `backend/src/middleware/locale.rs`
- Modify: `backend/src/middleware/mod.rs`
- Modify: `backend/src/main.rs`
- Modify: `backend/src/routes.rs`
- Modify: `backend/src/error.rs`

- [ ] **Step 1: 写失败测试验证请求语言注入**
  - 为中间件补测试，验证不同 `Accept-Language` 请求能在错误出口拿到正确 locale。
  - 增加“没有请求头时默认 `zh-CN`”测试。

- [ ] **Step 2: 实现 locale middleware**
  - 在请求进入时解析 `Accept-Language` 并写入 request extensions。
  - 保证现有 handler 签名仍可保持 `Result<_, AppError>`，不强制层层显式传 locale 参数。

- [ ] **Step 3: 在 `IntoResponse for AppError` 统一渲染文案**
  - 错误出口读取 request locale，上下文存在时按 locale 渲染 `message`。
  - 若语言包缺项，则直接输出 `message_key` 到 `message`。

- [ ] **Step 4: 运行 Rust 定向测试**
  - Run: `docker compose -f tests/docker-compose.yml run --rm rust-tests cargo test error --lib -- --test-threads=1`
  - Expected: `ErrorResponse` 序列化稳定，中间件与统一错误出口测试通过。

- [ ] **Step 5: 提交中间件与错误出口**
  - Run: `git add backend/src/middleware backend/src/main.rs backend/src/routes.rs backend/src/error.rs && git commit -m "feat(backend): localize app error responses"`

### Task 3: 迁移高频业务域一：`auth` / `user` / `friend`

**Files:**
- Modify: `backend/src/handlers/auth.rs`
- Modify: `backend/src/handlers/user.rs`
- Modify: `backend/src/handlers/friend.rs`
- Modify: `backend/i18n/zh-CN/auth.json`
- Modify: `backend/i18n/en-US/auth.json`
- Modify: `backend/i18n/zh-CN/user.json`
- Modify: `backend/i18n/en-US/user.json`
- Modify: `backend/i18n/zh-CN/friend.json`
- Modify: `backend/i18n/en-US/friend.json`

- [ ] **Step 1: 先做硬编码扫描并列出待迁移 key**
  - 用 `rg '[一-龥]|[A-Za-z].*Error|Unauthorized|Forbidden' backend/src/handlers/{auth,user,friend}.rs` 收口当前直接写死的错误文案。
  - 为高频路径先定一轮稳定 key，例如 `auth.invalid_verify_code`、`user.not_found`、`friend.already_added`。

- [ ] **Step 2: 把自由字符串替换为结构化错误**
  - 将 `ValidationError("xxx".to_string())`、`NotFound("xxx".to_string())` 这类调用改为统一的 key 化构造器。
  - 保留必要 `message_params`，不要在业务层预拼接文案。

- [ ] **Step 3: 补齐中英文语言包**
  - `zh-CN` 与 `en-US` 同步落地，不能只补中文。
  - 保证同一 key 在两份语言包语义一致。

- [ ] **Step 4: 运行业务域验证**
  - Run: `docker compose -f tests/docker-compose.yml run --rm rust-tests cargo test handlers::auth --lib -- --test-threads=1`
  - Run: `docker compose -f tests/docker-compose.yml run --rm rust-tests cargo test handlers::user --lib -- --test-threads=1`
  - Run: `docker compose -f tests/docker-compose.yml run --rm rust-tests cargo test handlers::friend --lib -- --test-threads=1`
  - Run: `KEEP_STACK=1 ./tests/run.sh`
  - Expected: Rust 定向测试通过；Go 黑盒主栈仍通过，未引入协议回归。

- [ ] **Step 5: 提交业务域一改动**
  - Run: `git add backend/src/handlers/auth.rs backend/src/handlers/user.rs backend/src/handlers/friend.rs backend/i18n && git commit -m "feat(backend): localize auth user and friend errors"`

### Task 4: 迁移高频业务域二：`message` / `group` / `search` / `admin`

**Files:**
- Modify: `backend/src/handlers/message.rs`
- Modify: `backend/src/handlers/message_search.rs`
- Modify: `backend/src/handlers/group_management.rs`
- Modify: `backend/src/handlers/room.rs`
- Modify: `backend/src/handlers/admin.rs`
- Modify: `backend/src/handlers/version.rs`
- Modify: `backend/i18n/zh-CN/message.json`
- Modify: `backend/i18n/en-US/message.json`
- Modify: `backend/i18n/zh-CN/group.json`
- Modify: `backend/i18n/en-US/group.json`
- Modify: `backend/i18n/zh-CN/admin.json`
- Modify: `backend/i18n/en-US/admin.json`

- [ ] **Step 1: 为消息/群组/后台域补 key 清单**
  - 先清点消息发送失败、群成员限制、搜索失败、后台资源缺失等高频错误。
  - 统一按 `message.*`、`group.*`、`admin.*` 命名，不再混杂自由字符串。

- [ ] **Step 2: 按域逐文件迁移**
  - 每改一个 handler，同步补两份语言包。
  - 对参数化文案使用 `message_params`，例如群人数上限、搜索结果数量等。

- [ ] **Step 3: 增加回归测试**
  - 为最关键接口补 Rust 或 Go 契约断言，确认语言协商后 `message` 正确变化而 `message_key` 稳定不变。

- [ ] **Step 4: 运行测试栈**
  - Run: `./tests/run.sh`
  - Expected: Rust 单测、集成测试与 Go 黑盒测试全部通过，`backend` 主域接口无回归。

- [ ] **Step 5: 提交业务域二改动**
  - Run: `git add backend/src/handlers backend/i18n tests/go && git commit -m "feat(backend): localize message group and admin domains"`

### Task 5: 补 Go 黑盒契约测试与文档

**Files:**
- Create: `tests/go/backend/system/locale_fallback_test.go`
- Create: `tests/go/backend/auth/auth_i18n_test.go`
- Create: `tests/go/backend/messages/message_i18n_test.go`
- Modify: `docs/reference/guides/error-handling.md`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reports/2026-03-26-backend-i18n-acceptance.md`

- [ ] **Step 1: 编写语言协商与缺失翻译 Go 契约测试**
  - 覆盖 `zh-CN`、`en-US`、不支持语言头、语言包缺项回退 `message_key`。
  - 断言优先看 `code/message_key`，文案仅验证代表性样例。

- [ ] **Step 2: 更新错误处理与测试文档**
  - 在错误处理文档中明确 `message_key/message/message_params` 协议。
  - 在测试文档中增加多语言契约测试入口与断言规则。

- [ ] **Step 3: 运行全量测试与记录结果**
  - Run: `./tests/run.sh`
  - Expected: 测试栈全绿，并在验收文档中记录多语言协议已生效。

- [ ] **Step 4: 提交文档与验收结果**
  - Run: `git add tests/go docs/reference/guides/error-handling.md docs/reference/testing/README.md docs/reports/2026-03-26-backend-i18n-acceptance.md && git commit -m "test(backend): cover i18n error contracts"`
