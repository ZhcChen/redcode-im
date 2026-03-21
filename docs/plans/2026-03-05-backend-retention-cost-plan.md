# Backend 成本与生命周期清理链路 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 backend 的日志/对象清理策略补齐契约与配置测试，确保“按保留期回收成本”路径可持续回归。

**Architecture:** 以 Go 黑盒测试覆盖管理员清理接口契约，以 Rust 单元测试覆盖后台清理配置解析与边界。对暴露出的配置安全问题采用最小代码修复并回归验证。

**Tech Stack:** Go 1.25、Rust（cargo test）、Axum handlers、Playwright 无依赖

---

### Task 1: 新增 Go 黑盒清理契约测试

**Files:**
- Create: `tests/go/backend/admin/admin_cleanup_contract_test.go`

**Step 1: 写失败测试（Red）**
- 新增系统日志清理、push 日志清理的成功/失败边界用例。

**Step 2: 运行失败（Red）**
- `cd tests/go && go test ./backend/admin -v`

**Step 3: 最小实现（Green）**
- 按后端真实契约调整请求体与断言。

**Step 4: 运行通过（Green）**
- `cd tests/go && go test ./backend/admin -v`

### Task 2: 补齐 Rust 清理配置边界单测

**Files:**
- Modify: `backend/src/services/file_upload_cleanup.rs`
- Modify: `backend/src/services/push.rs`
- Modify: `backend/src/logging/writer.rs`

**Step 1: 写失败测试（Red）**
- 新增 `from_env` 的 2 天配置解析与非法值回退测试。

**Step 2: 运行失败（Red）**
- `cd backend && cargo test file_upload_cleanup_config --lib`
- `cd backend && cargo test log_writer_config --lib`
- `cd backend && cargo test push_db_queue_cleanup_config --lib`

**Step 3: 最小实现（Green）**
- 若测试暴露缺陷，仅修复配置解析逻辑（不扩大行为变更面）。

**Step 4: 运行通过（Green）**
- 同 Step 2 命令。

### Task 3: 回归、文档、提交

**Files:**
- Modify: `docs/reference/testing/matrix/backend.csv`
- Modify: `docs/reference/testing/matrix/admin.csv`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

**Step 1: 执行回归**
- `cd tests/go && go test ./... -v`
- `cd backend && cargo test --lib`

**Step 2: 同步文档追踪**
- 更新矩阵状态、测试入口与回归统计。

**Step 3: 提交 + 推送**
- `git add ...`
- `git commit -m "test(backend): 补齐清理链路契约与配置边界测试"`
- `git push`
