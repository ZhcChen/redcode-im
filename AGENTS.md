# RedCode IM 全局导航与代理规则 (AGENTS.md)

> [!IMPORTANT]
> 本文件定义 AI 代理在 **RedCode IM** 仓库中的全局行为准则与 **Compound Engineering (CE)** 工作流入口。

## 1. 全局行为准则
- **语言**: 默认使用 **简体中文** 回复，保留专业技术词汇原文。
- **Git 提交与推送**: 遵循 **Conventional Commits** 与“最小可解释业务闭环”提交；每轮任务开始和提交前必须检查 `git status --short`，只 stage 本轮相关文件，commit 后立即 push 当前分支。完整细则见 `docs/standards/git-workflow.md`。
- **数据库**: 禁止修改已有迁移文件；新增变更使用 `YYYYMMDDHHMMSS_desc.sql`；禁用 PostgreSQL 枚举。
- **测试**: 核心逻辑修改后必须运行测试（API 使用 `make api.test`，由 Docker Compose 在容器内执行 Rust 测试；移动端 `flutter test`；全栈回归入口见 `docs/reference/testing/README.md`）。
- **App 设备验收顺序**: 默认优先使用 `Pixel 8 Pro (3A091FDJG001DN)` 进行 app 模块的 smoke、integration 与联调验证；如果该设备未连接，自动切换到本机 iOS Simulator；除非用户明确指定其他设备。
- **App 真机测试网络**: 每次真机 smoke、integration、联调前，必须先重新检测当前本机局域网 IP，并用该 IP 生成 `API_BASE_URL` / `WS_URL`，禁止复用历史局域网地址；切换到本机 iOS Simulator 时使用 `127.0.0.1`。
- **工具**: 优先使用项目内 `docs/` 文档建立上下文；需要官方库或框架资料时优先使用 Context7；需要浏览器行为排查时优先使用 Chrome DevTools MCP。
- **文档结构**: `docs/` 根目录仅保留 `index.md`，其余文档按主题放在子目录（如 `docs/brainstorms/`、`docs/plans/`、`docs/solutions/`、`docs/reference/`、`docs/reports/`）。
- **Docker Compose**: 本机统一使用 `docker compose`；API 开发、测试与验收默认走 Compose-first；测试栈要求 PostgreSQL/Redis 不映射宿主端口（避免冲突）。
- **端口占用处理**: 启动模块遇到端口冲突时，必须先停止占用进程再启动，禁止改用其他端口。
- **Git 提交与推送默认策略**:
  - 用户明确要求实现、修复、调整、完善、联调或继续任务时，视为授权在任务达到稳定可验收状态后自行提交并推送；提交单位是最小可解释业务闭环，不是消息次数。
  - “继续”“开始吧”“可以”“按照建议继续”等泛化回复只继承当前明确任务的提交范围，不授权把工作区所有未提交改动一起提交。
  - 一次任务包含多个相对独立功能点时，按功能边界、风险边界或可验证阶段拆分多个 commit；migration、SQL baseline、生成代码、部署配置、lockfile 默认单独成组。
  - 提交说明默认使用简体中文，保留 `feat:`、`fix:`、`refactor:`、`test:`、`docs:`、`chore:`、`perf:` 等 Conventional Commits 前缀。
  - 提交前必须运行与改动范围匹配的测试、构建、格式检查或页面验证；最低要求执行 `git diff --check`、`git diff --cached --check` 并查看 staged diff。
  - 不提交明显编译失败、测试失败或半成品状态，除非用户明确要求保存现场；这种情况下 commit message 必须标明 `WIP` 与阻塞点，并仍需及时 push。
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
- **本地 H5 App 开发**:
  - 模块目录：`h5-app/`（Vue 3 + Vite 8 + Vue Router + Pinia）
  - 启动：`make h5-app.up`
  - 停止：`make h5-app.down`
  - 日志：`make h5-app.logs`
  - 开发端口：`8016`
  - H5 App 是 Flutter `app/` 的 Web 版本，视觉 token 优先复用 Flutter 移动端的颜色、圆角、间距和登录/App Shell 结构。
- **测试栈（不要复用 dev）**:
  - api 测试栈：`tests/docker-compose.test.yml`（pg/redis/external-mock/rust-tests/api-smoke；PG/Redis/external-mock 均不映射宿主端口）
  - 入口：`make api.test`（Rust 单元 `--lib` + 集成 `--tests` 均在 Compose 容器内执行；axum oneshot 进程内）；详见 `docs/reference/testing/README.md`
- **本地回归入口**:
  - `make test.all`：自包含回归，不启动 live dev 联调服务。
  - `make test.live`：启动 API dev 与 Admin dev，并执行 app/admin/desktop 真实后端联调 smoke。
- **API 性能基线**:
  - 入口：`make api.perf.smoke` / `make api.perf.healthz` / `make api.perf.readyz` / `make api.perf.auth` / `make api.perf`
  - 性能测试必须走 `tests/docker-compose.test.yml`，由 Compose 限制 API/PG/Redis/mock 资源；压测容器在 Compose 网络内访问 `http://api:8010`，不要映射 PG/Redis/mock 宿主端口。

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
- H5 App: TypeScript (Vue 3, Vite 8, Vue Router, Pinia) -> `h5-app/src/`
- 管理后台: Vue 3 (Arco Design) -> `admin/src/`

---
*上次更新: 2026-04-04（迁移到 Compound Engineering 工作流）*
