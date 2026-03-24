# RedCode IM 全局导航与代理规则 (AGENTS.md)

> [!IMPORTANT]
> 本文件定义 AI 代理在 **RedCode IM** 仓库中的全局行为准则与 **Superpowers** 工作流入口。

## 1. 全局行为准则
- **语言**: 默认使用 **简体中文** 回复，保留专业技术词汇原文。
- **提交规范**: 遵循 **Conventional Commits**；完成功能或修复后立即提交并推送。
- **数据库**: 禁止修改已有迁移文件；新增变更使用 `YYYYMMDDHHMMSS_desc.sql`；禁用 PostgreSQL 枚举。
- **测试**: 核心逻辑修改后必须运行测试（后端 `cargo test`，移动端 `flutter test`；全栈回归入口见 `docs/reference/testing/README.md` 与 `tests/run.sh`）。
- **工具**: 优先使用项目内 `docs/` 文档建立上下文；所有测试除非特殊指定否则使用 Go。
- **文档结构**: `docs/` 根目录仅保留 `index.md`，其余文档按主题放在子目录（如 `docs/reference/`、`docs/reports/`、`docs/plans/`）。
- **Docker Compose**: 本机使用 `docker-compose`（不是 `docker compose`）；测试栈要求 PostgreSQL/Redis 不映射宿主端口（避免冲突）。
- **端口占用处理**: 启动模块遇到端口冲突时，必须先停止占用进程再启动，禁止改用其他端口。
- **本地 Backend 环境**:
  - 开发调试（dev）：`backend/docker/dev/docker-compose.yml`（源码挂载 + 容器内 `cargo run`）
  - 发布构建验证（release）：`backend/docker/release/docker-compose.yml`（多阶段构建 + 二进制运行）
  - 数据库迁移：由 backend 自身执行，不在 PostgreSQL 容器挂载 init SQL
  - 端口策略：PG/Redis 不映射宿主端口；Backend 可映射 `8010:8010`
- **本地开发重启规则（dev）**:
  - 修改 Rust 代码：`docker-compose -f backend/docker/dev/docker-compose.yml restart backend`
  - 修改依赖（`Cargo.toml`/Dockerfile）：`docker-compose -f backend/docker/dev/docker-compose.yml up -d --build backend`
  - 需要全新数据库：`docker-compose -f backend/docker/dev/docker-compose.yml down -v`
- **本地 Admin 开发**:
  - 启动：`screen -dmS admin bash -c 'cd admin && npm run dev'`
  - 查看日志：`screen -r admin`（`Ctrl+A D` 退回后台）
  - 停止：`screen -S admin -X quit`
  - 重启流程：
    1. `screen -S admin -X quit`
    2. `lsof -ti:5173 | xargs kill -9`
    3. `screen -dmS admin bash -c 'cd admin && npm run dev'`
- **本地 Desktop-EL 开发**:
  - 启动前必须先停止旧实例，禁止连续执行启动命令导致多个 Electron 客户端并存。
  - 启动/重启统一先执行：`make desktop-el-down`
  - 再执行：`make desktop-el-up`
  - 若手工调试 Electron，结束后也必须清理残留 `screen` 会话与 Electron 主进程，确认无旧实例后再重新启动。
- **测试栈（不要复用 dev）**:
  - `tests/docker-compose.yml` / `./tests/run.sh`
  - 测试栈默认不映射 PG/Redis 端口（详见 `docs/reference/testing/README.md`）

## 2. AI 工作流（Superpowers）
- 当前仓库统一采用 **Superpowers**，不再使用 devflow 角色流转。
- Superpowers 以 **全局安装** 方式使用，不在本仓库存放 `skills/` 与 `commands/`。
- 全局路径约定：
  - `~/.codex/superpowers`
  - `~/.agents/skills/superpowers -> ~/.codex/superpowers/skills`
- 标准执行链路：
  1. `using-superpowers`
  2. `brainstorming`
  3. `using-git-worktrees`
  4. `writing-plans`
  5. `subagent-driven-development` 或 `executing-plans`
  6. `test-driven-development`
  7. `requesting-code-review` / `receiving-code-review`
  8. `verification-before-completion` + `finishing-a-development-branch`
- 安装与升级：
  - 安装：按官方 `https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md` 执行
  - 升级：`cd ~/.codex/superpowers && git pull`
- 本仓库仅保留流程产出目录：`docs/plans/`

## 3. 核心入口 (Entry Points)
- 项目索引：`docs/index.md`
- 任务清单：`docs/reports/task-list.md`
- 项目评估报告：`docs/reports/project-status-assessment-report-2025-11-08.md`
- 测试流程总览：`docs/reference/testing/README.md`

## 4. 技术栈速查
- 后端: Rust (Axum, SQLx, Redis) -> `backend/src/`
- 桌面端: TypeScript (Vue 3, Tauri) -> `desktop/src/`
- 移动端: Dart (Flutter) -> `frontend/lib/`
- 管理后台: Vue 3 (Arco Design) -> `admin/src/`

---
*上次更新: 2026-03-24（补充 Desktop-EL 启停规则）*
