---
status: archived
archived_at: 2026-08-04
archived_reason: 2.0 主线未包含多语言需求，tail 收尾不再续期
---

# I18N 收尾收口 Implementation Plan

> **For agentic workers:** REQUIRED WORKFLOW: Use `ce:work` to execute this plan task-by-task. If the remaining i18n scope changes, revisit assumptions with `ce:brainstorm` and refresh the implementation path with `ce:plan`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `codex/i18n-rollout` 分支完成 Backend 剩余多语言长尾、补齐契约测试与验收文档，使 `backend + admin` 的 i18n 改造达到可合流状态。

**Architecture:** 不在当前脏 `main` 上继续施工，改为基于 `codex/i18n-rollout` 独立 worktree 收尾。Backend 采用“先补 catalog、再改 handler/service、最后补测试与文档”的顺序，成功消息尽量最小化，错误消息统一改为 `message_key + message_params`。本计划只覆盖 Backend 尾项与测试/文档收口，不展开 Frontend / Desktop 新工程。

**Tech Stack:** Rust 2021、Axum、Serde JSON、Vue 3、vue-i18n、Bun、Docker Compose、Go 1.25 黑盒测试

---

### Task 1: 建立隔离施工面并冻结范围

**Files:**
- Reference: `docs/plans/2026-03-26-i18n-backend-plan.md`
- Reference: `docs/plans/2026-03-26-i18n-admin-plan.md`
- Reference: `docs/reports/2026-03-26-admin-i18n-acceptance.md`（分支内）

- [ ] **Step 1: 从 `codex/i18n-rollout` 创建隔离 worktree**
  - Run: `git worktree add ../redcode-im-i18n-tail codex/i18n-rollout`
  - Expected: 新目录 `../redcode-im-i18n-tail` 可用，避免污染当前 `main` 脏工作区。

- [ ] **Step 2: 在新 worktree 再做一次尾项扫描**
  - Run: `rg -n 'AppError::|message:\s*"|[一-龥]' backend/src/{handlers,services,storage} admin/src/{hooks,utils,components,api}`
  - Expected: 只保留本计划列出的尾项文件；若发现 Frontend / Desktop 文案，不在本轮处理。

- [ ] **Step 3: 冻结本轮不做项**
  - 明确不处理：`frontend/`、`desktop/` 正式 i18n 落地。
  - 明确不扩展：成功响应全面 message_key 化；本轮只保证错误路径与少量关键 success 文案可追踪。

### Task 2: Backend 第一批尾项 —— `upload` / `emoji` / `report` / `push` / `e2ee`

**Files:**
- Create: `backend/i18n/zh-CN/upload.json`
- Create: `backend/i18n/en-US/upload.json`
- Create: `backend/i18n/zh-CN/emoji.json`
- Create: `backend/i18n/en-US/emoji.json`
- Create: `backend/i18n/zh-CN/report.json`
- Create: `backend/i18n/en-US/report.json`
- Create: `backend/i18n/zh-CN/push.json`
- Create: `backend/i18n/en-US/push.json`
- Create: `backend/i18n/zh-CN/e2ee.json`
- Create: `backend/i18n/en-US/e2ee.json`
- Modify: `backend/src/i18n/catalog.rs`
- Modify: `backend/src/handlers/multipart_upload.rs`
- Modify: `backend/src/handlers/emoji_pack.rs`
- Modify: `backend/src/handlers/report.rs`
- Modify: `backend/src/handlers/push_settings.rs`
- Modify: `backend/src/handlers/push.rs`
- Modify: `backend/src/handlers/e2ee.rs`
- Modify: `backend/src/i18n/tests.rs`

- [ ] **Step 1: 先写 Rust i18n 失败测试覆盖新 catalog**
  - 在 `backend/src/i18n/tests.rs` 新增代表性断言：
    - `upload.invalid_session_id`
    - `emoji.pack_name_required`
    - `report.content_type_required`
    - `push.device_token_invalid`
    - `e2ee.target_user_not_initialized`
  - Run: `cargo test i18n --lib -- --test-threads=1`
  - Expected: 因 catalog/key 尚不存在而失败。

- [ ] **Step 2: 新增 5 组中英文 catalog 并接入 `catalog.rs`**
  - `Catalog::load_builtin()` 必须显式 `load_locale_messages(...)`，不能假设自动扫描。
  - key 统一沿用 `domain.snake_case`，不要把新 key 堆进 `common.*`。

- [ ] **Step 3: 把 6 个 handler 的自由字符串切到 `message_key`**
  - 统一替换模式：
    - `AppError::ValidationError(String::new()).with_message_key("domain.key")`
    - `AppError::ValidationError(String::new()).with_message_key_and_params("domain.key", Some(json!({...})))`
    - `AppError::NotFound(String::new()).with_message_key("domain.key")`
  - 重点替换：
    - `multipart_upload.rs`：`无效的 session_id` / `分片会话不存在` / `存储提供商不存在` / `etag 不能为空` / `parts 不能为空`
    - `emoji_pack.rs`：`贴纸名称不能为空` / `贴纸不存在` / `表情项不存在` / `缺少搜索关键词`
    - `report.rs`：`content_type 不能为空` / `举报截图尚未上传完成` / `不能举报自己` / `举报目标用户不存在`
    - `push_settings.rs` / `push.rs`：`暂不支持的 provider` / `device_token 无效` / `title 不能为空` / `body 不能为空`
    - `e2ee.rs`：`signed_pre_key.key_id 无效` / `目标用户未初始化 E2EE` / `identity_key 不存在`

- [ ] **Step 4: 跑定向验证**
  - Run: `cargo test i18n --lib -- --test-threads=1`
  - Run: `cargo test handlers::push --lib -- --test-threads=1`
  - Run: `cargo test handlers::e2ee --lib -- --test-threads=1`
  - Expected: 新 catalog 被加载；代表性 handler 定向测试不回归。

- [ ] **Step 5: 提交第一批尾项**
  - Run: `git add backend/i18n backend/src/i18n/catalog.rs backend/src/i18n/tests.rs backend/src/handlers/{multipart_upload,emoji_pack,report,push_settings,push,e2ee}.rs`
  - Run: `git commit -m "feat(backend): localize upload emoji report push and e2ee tails"`

### Task 3: Backend 第二批尾项 —— 服务层与次级 handler 长尾

**Files:**
- Modify: `backend/src/services/file_upload_audit.rs`
- Modify: `backend/src/storage/cos.rs`
- Modify: `backend/src/handlers/version.rs`
- Modify: `backend/src/handlers/room.rs`
- Modify: `backend/src/handlers/message_read.rs`
- Modify: `backend/src/handlers/chat_history.rs`
- Modify: `backend/src/handlers/feedback.rs`
- Modify: `backend/src/handlers/upload_policy.rs`
- Modify: `backend/src/handlers/activity_logs.rs`
- Modify: `backend/i18n/zh-CN/common.json`
- Modify: `backend/i18n/en-US/common.json`
- Modify: `backend/i18n/zh-CN/admin.json`
- Modify: `backend/i18n/en-US/admin.json`
- Modify: `backend/i18n/zh-CN/room.json`
- Modify: `backend/i18n/en-US/room.json`
- Modify: `backend/i18n/zh-CN/version.json`
- Modify: `backend/i18n/en-US/version.json`
- Modify: `backend/i18n/zh-CN/message.json`
- Modify: `backend/i18n/en-US/message.json`

- [ ] **Step 1: 先把共享底层错误抽成稳定 key**
  - `file_upload_audit.rs` 与 `storage/cos.rs` 里的可外显错误先落 key，避免上层接口继续透传中文自由字符串。
  - 建议优先补：
    - `common.http_client_create_failed`
    - `admin.storage_provider_not_found`
    - `admin.storage_provider_bucket_required`
    - `upload.audit_claim_failed`
    - `upload.audit_submit_failed`
    - `upload.audit_query_failed`
    - `upload.object_not_found`
    - `upload.multipart_init_failed`
    - `upload.multipart_upload_id_missing`

- [ ] **Step 2: 清理次级 handler 的剩余自由字符串**
  - `version.rs`：`无效的版本 ID` / `版本记录不存在` / `channel 不能为空` / `绑定的整包版本不存在`
  - `room.rs`：`Room updated successfully` / `Only image files are allowed` / `You are not a member of this room` / `Invalid object key`
  - `message_read.rs`：`您不是该房间成员`
  - `chat_history.rs`：`无效的用户ID` / `无效的房间ID`
  - `feedback.rs`：`反馈内容不能为空` / `反馈提交成功，感谢您的支持！`
  - `upload_policy.rs`：`version 不能为空` / `序列化 upload policy 失败`
  - `activity_logs.rs`：`地理位置服务未初始化`

- [ ] **Step 3: 保持成功消息最小化**
  - 对前端不依赖自然语言的 success `message`，优先统一为稳定短文案或沿用既有 `ok`，避免本轮扩散太多 success key。
  - 只有用户会直接看到且已有前端依赖的 success 文案，才补 locale key。

- [ ] **Step 4: 跑第二轮定向验证**
  - Run: `cargo test handlers::version --lib -- --test-threads=1`
  - Run: `cargo test handlers::room --lib -- --test-threads=1`
  - Run: `cargo test handlers::message_read --lib -- --test-threads=1`
  - Run: `cargo test handlers::feedback --lib -- --test-threads=1`
  - Expected: 次级 handler 和共享服务层不因 i18n 替换发生协议回退。

- [ ] **Step 5: 提交第二批尾项**
  - Run: `git add backend/src/services/file_upload_audit.rs backend/src/storage/cos.rs backend/src/handlers/{version,room,message_read,chat_history,feedback,upload_policy,activity_logs}.rs backend/i18n`
  - Run: `git commit -m "feat(backend): localize remaining service and handler tails"`

### Task 4: 补 Backend 多语言契约测试

**Files:**
- Modify: `backend/src/i18n/tests.rs`
- Create: `tests/go/backend/system/locale_contract_test.go`
- Modify: `tests/go/backend/versions/version_latest_download_test.go`
- Modify: `tests/go/backend/rooms/room_lifecycle_test.go`
- Modify: `tests/go/backend/messages/unread_counts_test.go`
- Modify: `tests/go/README.md`

- [ ] **Step 1: 新增 Go 代表性错误路径契约**
  - `tests/go/backend/system/locale_contract_test.go` 至少覆盖：
    - `Accept-Language: en-US` 时返回英文 `message`
    - 不支持语言时回退 `zh-CN`
    - 缺失翻译时回退 `message_key`
  - 优先选容易制造错误的接口：
    - `/versions/latest/download-url?platform=bad&channel=test`
    - `/rooms/{id}/messages/read_until` 非成员访问

- [ ] **Step 2: 在现有黑盒用例旁补最小断言**
  - `version_latest_download_test.go`：增加非法 `platform` 或缺失 `channel` 的错误响应断言。
  - `room_lifecycle_test.go`：补一个非成员访问群头像/群消息读取的错误断言。
  - `unread_counts_test.go`：补 `read_until` 非成员场景，断言 `message_key` 稳定。

- [ ] **Step 3: 运行 Rust + Go 最小闭环**
  - Run: `cd backend && cargo test i18n --lib -- --test-threads=1`
  - Run: `cd tests/go && go test ./backend/system ./backend/versions ./backend/rooms ./backend/messages -v`
  - Expected: 语言协商、回退规则和代表性错误路径都可验证。

- [ ] **Step 4: 提交测试**
  - Run: `git add backend/src/i18n/tests.rs tests/go/backend/system/locale_contract_test.go tests/go/backend/{versions,rooms,messages} tests/go/README.md`
  - Run: `git commit -m "test(backend): cover i18n locale contracts"`

### Task 5: 更新错误处理文档与验收报告

**Files:**
- Modify: `docs/reference/guides/error-handling.md`
- Modify: `docs/reference/testing/README.md`
- Create: `docs/reports/2026-04-01-backend-i18n-tail-acceptance.md`
- Create: `docs/reports/2026-04-01-i18n-rollout-acceptance.md`

- [ ] **Step 1: 更新错误协议文档**
  - 将示例响应从旧格式：`code + message + details`
  - 更新为新格式：`code + message_key + message + message_params + details`
  - 明确：客户端优先依赖 `message_key` 做稳定判断，`message` 只做展示。

- [ ] **Step 2: 更新测试文档入口**
  - 在 `docs/reference/testing/README.md` 增加：
    - Rust i18n 定向命令
    - Go locale contract 测试命令
    - 全量回归入口与适用时机

- [ ] **Step 3: 写 2 份验收文档**
  - `2026-04-01-backend-i18n-tail-acceptance.md`：记录本轮新增 catalog、覆盖域、测试结果、已知剩余项。
  - `2026-04-01-i18n-rollout-acceptance.md`：从全局视角写清楚 `backend/admin 已完成`、`frontend/desktop 未开始`，防止误判为“全仓库已完成多语言”。

- [ ] **Step 4: 提交文档**
  - Run: `git add docs/reference/guides/error-handling.md docs/reference/testing/README.md docs/reports/2026-04-01-backend-i18n-tail-acceptance.md docs/reports/2026-04-01-i18n-rollout-acceptance.md`
  - Run: `git commit -m "docs(i18n): record backend tail acceptance and rollout status"`

### Task 6: 最终验证与收口

**Files:**
- Reference only

- [ ] **Step 1: 跑 Backend Rust 定向验证**
  - Run: `cd backend && cargo test i18n --lib -- --test-threads=1`
  - Run: `cd backend && cargo test handlers::version --lib -- --test-threads=1`
  - Run: `cd backend && cargo test handlers::room --lib -- --test-threads=1`

- [ ] **Step 2: 跑 Go 黑盒代表集**
  - Run: `cd tests/go && go test ./backend/system ./backend/uploads ./backend/push ./backend/versions ./backend/rooms ./backend/messages -v`

- [ ] **Step 3: 跑 Admin 最小验证**
  - Run: `cd admin && bun test src/utils/i18n.test.ts`
  - Expected: Admin 的 `message_key -> locale 文案` 解析器仍可用。

- [ ] **Step 4: 形成最终提交序列**
  - 推荐提交顺序：
    1. `feat(backend): localize upload emoji report push and e2ee tails`
    2. `feat(backend): localize remaining service and handler tails`
    3. `test(backend): cover i18n locale contracts`
    4. `docs(i18n): record backend tail acceptance and rollout status`
