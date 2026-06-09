# RedCode IM 兼容入口（CLAUDE.md）

> [!IMPORTANT]
> 本文件仅为兼容部分会读取 `CLAUDE.md` 的代理或工具而保留。**当前仓库现行规范以根目录 `AGENTS.md` 为准**；如两者出现差异，应始终以 `AGENTS.md` 为最终规范。

## 1. 全局行为准则（与 AGENTS.md 对齐）
- **语言**：默认使用 **简体中文** 回复，保留专业技术词汇原文。
- **提交规范**：遵循 **Conventional Commits**；完成功能或修复后立即提交并推送。
- **数据库**：禁止修改已有迁移文件；新增变更使用 `YYYYMMDDHHMMSS_desc.sql`；禁用 PostgreSQL 枚举。
- **测试**：核心逻辑修改后必须运行测试（后端 `cargo test`，移动端 `flutter test`；全栈回归入口见 `docs/reference/testing/README.md` 与 `tests/run.sh`）。
- **Frontend 真机测试设备**：默认使用 `Pixel 8 Pro (3A091FDJG001DN)` 进行 frontend 模块的真机 smoke、integration 与联调验证；除非用户明确指定其他设备。
- **Frontend 真机测试网络**：每次真机 smoke、integration、联调前，必须先重新检测当前本机局域网 IP，并用该 IP 生成 `API_BASE_URL` / `WS_URL`，禁止复用历史局域网地址。
- **工具**：优先使用项目内 `docs/` 文档建立上下文；需要官方库或框架资料时优先使用 Context7；需要浏览器行为排查时优先使用 Chrome DevTools MCP。
- **文档结构**：`docs/` 根目录仅保留 `index.md`，其余文档按主题放在子目录（如 `docs/brainstorms/`、`docs/plans/`、`docs/solutions/`、`docs/reference/`、`docs/reports/`）。
- **Docker Compose**：本机统一使用 `docker compose`；API 开发、测试与验收默认走 Compose-first；测试栈要求 PostgreSQL/Redis 不映射宿主端口（避免冲突）。
- **端口占用处理**：启动模块遇到端口冲突时，必须先停止占用进程再启动，禁止改用其他端口。

## 2. 当前默认 AI 工作流（Compound Engineering, CE）
- 当前仓库统一采用 **Compound Engineering (CE)** 作为默认 AI 工作流。
- 默认工作流顺序：
  1. `ce:brainstorm`
  2. `ce:plan`
  3. `ce:work`
  4. `ce:review`
  5. `ce:compound`
- 产物目录约定：
  - `docs/brainstorms/`
  - `docs/plans/`
  - `docs/solutions/`
  - `.context/compound-engineering/`
- 全局安装位置约定：
  - `~/.codex/prompts/ce-*.md`
  - `~/.codex/skills/ce-*`
  - `~/.codex/CE_AGENTS.md`
  - `~/.codex/scripts/ce-init`
- 仓库工作流以 CE 目录约定与根目录 `AGENTS.md` 为准。

## 3. 本地开发约定（关键项）
- **API 开发调试（dev）**：`api/docker/dev/docker-compose.yml`
- **API 发布构建验证（release）**：`api/docker/release/docker-compose.yml`
- **API 修改 Rust 代码后重启**：
  - `docker compose -f api/docker/dev/docker-compose.yml restart api`
- **Admin 开发端口**：`8011`
- **Admin 启动**：
  - `screen -dmS admin bash -c 'cd admin && npm run dev'`
- **Admin 重启流程**：
  1. `screen -S admin -X quit`
  2. `lsof -ti:8011 | xargs kill -9`
  3. `screen -dmS admin bash -c 'cd admin && npm run dev'`

## 4. 核心入口
- 项目索引：`docs/index.md`
- 现行规范：`AGENTS.md`
- 测试流程总览：`docs/reference/testing/README.md`

---
*上次更新: 2026-04-09（同步到 CE 工作流并转为兼容入口）*
