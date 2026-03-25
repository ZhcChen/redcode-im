# Desktop EL Verification Entrypoint Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 固化一套可重复执行的验收入口，把 Go core 测试、Bun 测试与构建收口到固定脚本和根 `Makefile` 命令。

**Architecture:** 保持现有 `desktop-el` 模块结构不变，不引入新的测试框架，也不启动额外 Electron 客户端。验收入口只负责串联现有 `go test ./...`、`bun test` 与 `bun run build`，并通过根 `Makefile` 暴露统一命令。

**Tech Stack:** Bash、Makefile、Bun、Go 1.25、README、迁移 backlog

---

### Task 1: 固化 `desktop-el` 模块内部验收脚本

**Files:**
- Create: `desktop-el/scripts/verify.sh`
- Modify: `desktop-el/package.json`

- [x] **Step 1: 新增固定验收脚本**

实现点：
- 串联 `cd go-core && go test ./...`
- 串联 `bun test`
- 串联 `bun run build`
- 使用 `set -euo pipefail`

- [x] **Step 2: 暴露 package scripts**

实现点：
- 增加 `test`
- 增加 `test:core`
- 增加 `verify`

### Task 2: 暴露根 Makefile 与 README 入口

**Files:**
- Modify: `Makefile`
- Modify: `desktop-el/README.md`

- [x] **Step 1: 在根 Makefile 增加 desktop-el 校验命令**

实现点：
- `desktop-el-test`
- `desktop-el-core-test`
- `desktop-el-build`
- `desktop-el-verify`

- [x] **Step 2: 更新 README**

实现点：
- 模块内 `bun run test` / `bun run test:core` / `bun run verify`
- 根目录 `make desktop-el-test` / `make desktop-el-core-test` / `make desktop-el-build` / `make desktop-el-verify`

### Task 3: 完整验证、回填 backlog、提交推送与清理

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-verification-entrypoint-plan.md`

- [x] **Step 1: 运行验证**

Run: `make desktop-el-core-test`
Expected: PASS

Run: `make desktop-el-test`
Expected: PASS

Run: `make desktop-el-build`
Expected: PASS

Run: `make desktop-el-verify`
Expected: PASS

- [x] **Step 2: 回填 backlog、提交并推送**

```bash
git add Makefile \
  desktop-el/README.md \
  desktop-el/package.json \
  desktop-el/scripts/verify.sh \
  docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-26-desktop-el-verification-entrypoint-plan.md
git commit -m "build(desktop-el): add verification entrypoints"
git push
```

- [x] **Step 3: 运行清理**

Run: `make desktop-el-down`
Expected: 无残留开发实例。

Run: `pgrep -fl "desktop-el|electron|go-core" || true`
Expected: 无输出。
