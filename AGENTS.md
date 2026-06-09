# RedCode IM 全局导航与代理规则 (AGENTS.md)

> [!IMPORTANT]
> 本文件定义 AI 代理在 **RedCode IM** 仓库中的全局行为准则与 **Compound Engineering (CE)** 工作流入口。

## 1. 全局行为准则
- **语言**: 默认使用 **简体中文** 回复，保留专业技术词汇原文。
- **提交规范**: 遵循 **Conventional Commits**；完成功能或修复后立即提交并推送。
- **数据库**: 禁止修改已有迁移文件；新增变更使用 `YYYYMMDDHHMMSS_desc.sql`；禁用 PostgreSQL 枚举。
- **测试**: 核心逻辑修改后必须运行测试（后端 `cargo test`，移动端 `flutter test`；全栈回归入口见 `docs/reference/testing/README.md`）。
- **App 设备验收顺序**: 默认优先使用 `Pixel 8 Pro (3A091FDJG001DN)` 进行 app 模块的 smoke、integration 与联调验证；如果该设备未连接，自动切换到本机 iOS Simulator；除非用户明确指定其他设备。
- **App 真机测试网络**: 每次真机 smoke、integration、联调前，必须先重新检测当前本机局域网 IP，并用该 IP 生成 `API_BASE_URL` / `WS_URL`，禁止复用历史局域网地址；切换到本机 iOS Simulator 时使用 `127.0.0.1`。
- **工具**: 优先使用项目内 `docs/` 文档建立上下文；需要官方库或框架资料时优先使用 Context7；需要浏览器行为排查时优先使用 Chrome DevTools MCP。
- **文档结构**: `docs/` 根目录仅保留 `index.md`，其余文档按主题放在子目录（如 `docs/brainstorms/`、`docs/plans/`、`docs/solutions/`、`docs/reference/`、`docs/reports/`）。
- **Docker Compose**: 本机统一使用 `docker compose`；API 开发、测试与验收默认走 Compose-first；测试栈要求 PostgreSQL/Redis 不映射宿主端口（避免冲突）。
- **端口占用处理**: 启动模块遇到端口冲突时，必须先停止占用进程再启动，禁止改用其他端口。
- **本地 API 环境**:
  - 开发调试（dev）：`api/docker/dev/docker-compose.yml`（源码挂载 + 容器内 `cargo run`，默认开发入口）
  - 发布构建验证（release）：`api/docker/release/docker-compose.yml`（多阶段构建 + 二进制运行）
  - 数据库迁移：由 api 自身执行，不在 PostgreSQL 容器挂载 init SQL
  - 端口策略：PG/Redis 不映射宿主端口；API 可映射 `8010:8010`
- **本地开发重启规则（dev）**:
  - 修改 Rust 代码：`docker compose -f api/docker/dev/docker-compose.yml restart api`
  - 修改依赖（`Cargo.toml`/Dockerfile）：`docker compose -f api/docker/dev/docker-compose.yml up -d --build api`
  - 需要全新数据库：`docker compose -f api/docker/dev/docker-compose.yml down -v`
- **本地 Admin 开发**:
  - 启动：`screen -dmS admin bash -c 'cd admin && npm run dev'`
  - 查看日志：`screen -r admin`（`Ctrl+A D` 退回后台）
  - 停止：`screen -S admin -X quit`
  - 开发端口：`8011`
  - 重启流程：
    1. `screen -S admin -X quit`
    2. `lsof -ti:8011 | xargs kill -9`
    3. `screen -dmS admin bash -c 'cd admin && npm run dev'`
- **测试栈（不要复用 dev）**:
  - api 集成依赖栈：`tests/docker-compose.test.yml`（pg/redis/external-mock，映射宿主端口供本机 `cargo test`）
  - 入口：`make api.test`（Rust 单元 `--lib` + 集成 `--tests`，axum oneshot 进程内）；详见 `docs/reference/testing/README.md`

## 2. AI 工作流（Compound Engineering, CE）
- 当前仓库统一采用 **Compound Engineering (CE)** 作为默认 AI 工作流。
- 在没有用户明确要求切换流程的情况下，优先使用 CE 的工作流。
- **同一项任务默认只采用一套主工作流。** 若当前任务已明确选择 CE，就不要再混入其他工作流的设计、计划、执行流程，除非用户明确要求。
- 默认工作流顺序：
  1. `ce:brainstorm`
  2. `ce:plan`
  3. `ce:work`
  4. `ce:review`
  5. `ce:compound`
- 产物目录约定：
  - 需求/方向讨论：`docs/brainstorms/`
  - 技术计划：`docs/plans/`
  - 解决方案/经验沉淀：`docs/solutions/`
  - CE 运行期中间产物：`.context/compound-engineering/`
- 全局安装位置约定：
  - `~/.codex/prompts/ce-*.md`
  - `~/.codex/skills/ce-*`
  - `~/.codex/CE_AGENTS.md`
  - `~/.codex/scripts/ce-init`
- 若任务已经有现成的 brainstorm、plan 或 solution 文档，优先续写与复用，不要重复生成平行文档。
- 仓库工作流以本节和 CE 目录约定为准。

## 3. Compound Codex Tool Mapping (Claude Compatibility)

此节用于给未来代理说明 CE 在 Codex 中的常见工具映射。

Tool mapping:
- Read: 使用 shell 读取（`cat`/`sed`）或 `rg`
- Write: 使用 shell 重定向或 `apply_patch`
- Edit/MultiEdit: 使用 `apply_patch`
- Bash: 使用 shell 命令
- Grep: 使用 `rg`（必要时回退 `grep`）
- Glob: 使用 `rg --files` 或 `find`
- LS: 使用 `ls`
- WebFetch/WebSearch: 优先 `curl`、Context7 或合规 Web 工具
- AskUserQuestion/Question: 在对话中列编号选项并等待用户回答
- Task/Subagent/Parallel: 默认在主线程顺序执行；仅在用户明确要求 delegation 时再启用子代理
- TodoWrite/TodoRead: 使用计划/待办文档或本地文件跟踪
- Skill: 打开对应 `SKILL.md` 并遵循其流程

## 4. 核心入口 (Entry Points)
- 项目索引：`docs/index.md`
- 需求/方向讨论：`docs/brainstorms/`
- 技术计划：`docs/plans/`
- 解决方案沉淀：`docs/solutions/`
- 任务清单：`docs/reports/task-list.md`
- 项目评估报告：`docs/reports/project-status-assessment-report-2025-11-08.md`
- 测试流程总览：`docs/reference/testing/README.md`

## 5. 技术栈速查
- 后端: Rust (Axum, SQLx, Redis) -> `api/src/`
- 桌面端: TypeScript (Vue 3, Tauri) -> `desktop/src/`
- 移动端: Dart (Flutter) -> `app/lib/`
- 管理后台: Vue 3 (Arco Design) -> `admin/src/`

---
*上次更新: 2026-04-04（迁移到 Compound Engineering 工作流）*
