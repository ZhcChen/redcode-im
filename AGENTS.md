# RedCode IM 全局导航与代理规则 (AGENTS.md)

> [!IMPORTANT]
> 本文件定义 AI 代理在 **RedCode IM** 仓库中的全局行为准则，以及基于
> `agent-light-workflow` 的轻量工作流入口。仓库保留 Compound Engineering（CE）
> 命名作为 Codex 技能兼容层。

## 1. 全局行为准则
- **语言**: 默认使用 **简体中文** 回复，保留专业技术词汇原文。
- **Git 提交与推送**: 遵循 **Conventional Commits** 与“最小可解释业务闭环”提交；每轮任务开始和提交前必须检查 `git status --short`，只 stage 本轮相关文件，commit 后立即 push 当前分支。完整细则见 `docs/standards/git-workflow.md`。
- **数据库**: 禁止修改已有迁移文件；新增变更使用 `YYYYMMDDHHMMSS_desc.sql`；禁用 PostgreSQL 枚举。
- **测试**: 核心逻辑修改后必须运行测试（API 使用 `make api.test`，由 Docker Compose 在容器内执行 Rust 测试；移动端 `flutter test`；全栈回归入口见 `docs/reference/testing/README.md`）。
- **App 设备验收顺序**: Flutter `app/` 模块默认使用本机 iOS Simulator 进行 smoke、integration 与联调验证；除非用户明确指定其他设备。相机、麦克风、APNs、后台通知等 Simulator 无法完整验证的能力，单独安排 iPhone 真机验证。
- **App 真机测试网络**: 每次真机 smoke、integration、联调前，必须先重新检测当前本机局域网 IP，并用该 IP 生成 `API_BASE_URL` / `WS_URL`，禁止复用历史局域网地址；切换到本机 iOS Simulator 时使用 `127.0.0.1`。
- **工具**: 优先使用项目内 `docs/` 文档建立上下文；需要官方库或框架资料时优先使用 Context7；需要浏览器行为排查时优先使用 Chrome DevTools MCP。
- **文档结构**: `docs/` 根目录仅保留 `index.md`，其余文档按主题放在子目录（如 `docs/brainstorms/`、`docs/plans/`、`docs/reviews/`、`docs/solutions/`、`docs/prompts/`、`docs/reference/`、`docs/reports/`）。
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
- **测试环境部署（im-test-1）**:
  - 测试环境服务器别名：`im-test-1`（单机测试环境：PostgreSQL/Redis/RustFS/API/Admin）
  - 部署配置与完整步骤以 `deploy/im-test-1/README.md` 为准；公网入口：
    API `https://im-test-1.codelib.cc`、Admin `https://im-test-admin-1.codelib.cc`
  - 首次部署：`cd deploy/im-test-1 && cp .env.example .env`，至少替换
    `POSTGRES_PASSWORD` / `REDIS_PASSWORD` / `RUSTFS_ACCESS_KEY` /
    `RUSTFS_SECRET_KEY` / `JWT_SECRET` / `DATA_ENCRYPTION_KEY` 后再启动
  - 镜像加载：API 正式版产物 `./load-api-image.sh <tar.gz>`；Admin / RustFS
    走 `./load-admin-image.sh` / `./load-rustfs-image.sh` 离线加载
  - 启动与验证：`docker compose up -d`，然后
    `curl https://im-test-1.codelib.cc/healthz`、`curl -I https://im-test-admin-1.codelib.cc`
  - 关键约束：`RUSTFS_INTERNAL_ENDPOINT` 必须保持容器网络内地址 `rustfs:9000`，
    不要改成公网域名，否则 API 生成/校验 S3 签名会把对象存储流量绕回反代，
    导致附件上传与下载链路异常；`.env` 含密钥，禁止提交入库
- **本地回归入口**:
  - `make test.all`：自包含回归，不启动 live dev 联调服务。
  - `make test.live`：启动 API dev 与 Admin dev，并执行 app/admin/desktop 真实后端联调 smoke。
- **API 性能基线**:
  - 入口：`make api.perf.smoke` / `make api.perf.healthz` / `make api.perf.readyz` / `make api.perf.auth` / `make api.perf`
  - 性能测试必须走 `tests/docker-compose.test.yml`，由 Compose 限制 API/PG/Redis/mock 资源；压测容器在 Compose 网络内访问 `http://api:8010`，不要映射 PG/Redis/mock 宿主端口。

## 2. AI 工作流（agent-light-workflow + CE 兼容）
- 当前仓库默认采用 `agent-light-workflow` 风格的轻量五阶段工作流：
  `brainstorm -> plan -> execute -> review -> compound`。
- 在 Codex 中，五阶段与 CE 技能的默认映射为：
  1. `brainstorm` -> `ce:brainstorm`
  2. `plan` -> `ce:plan`
  3. `execute` -> `ce:work`
  4. `review` -> `ce:review`
  5. `compound` -> `ce:compound`
- **同一项任务默认只采用一套主工作流。** 若当前任务已经选择轻工作流/CE
  映射，就不要再混入其他流程，除非用户明确要求。
- `brainstorm` 只在需求不清、范围未定、方案分叉或未知项较多时启用；需求已经清晰时，可直接进入 `plan`。
- 非微小任务开始前，先确认已有正式 plan；缺少 plan 时，优先补 `docs/plans/`。
- `execute` 阶段按小步、可验证闭环推进；完成一个闭环后先验证，再决定继续执行或进入 `review`。
- `compound` 只沉淀可复用决策、复发坑点、稳定排查路径或长期模式，不把一次性执行日志原样搬入方案库。
- 产物目录约定：
  - 需求/方向讨论：`docs/brainstorms/`
  - 技术计划：`docs/plans/`
  - 审查/验证记录：`docs/reviews/`
  - 解决方案/经验沉淀：`docs/solutions/`
  - 可复制或改写给 Codex 的参考提示词：`docs/prompts/`
  - CE 运行期中间产物：`.context/compound-engineering/`（仅作临时上下文，不作为长期文档入口）
- `docs/*/TEMPLATE.md` 只作结构参考；正式内容优先写入同目录下的具体文件，例如 `docs/plans/YYYY-MM-DD-short-name.md`。
- `docs/prompts/*.md` 是参考提示词资产，不假设隐藏命令、后台调度器或专用 runtime。
- 全局 CE 资源（如 `~/.codex/prompts/ce-*.md`、`~/.codex/skills/ce-*`、`~/.codex/CE_AGENTS.md`、`~/.codex/scripts/ce-init`）仅作为本机 Codex 兼容入口；仓库内工作流事实以本节、`docs/index.md` 和 `docs/prompts/` 为准。
- 若任务已经有现成的 brainstorm、plan、review 或 solution 文档，优先续写与复用，不要重复生成平行文档。

### Code Review Graph 受控使用
- Code Review Graph（CRG）仅是 `plan` / `review` 阶段的可选旁路证据源，不构成第六个工作流阶段，也不替代源码阅读、测试或运行时验收。
- 仅在跨模块改动、公共符号/契约重构、调用链不明确或改动面较大时显式使用；小型文档、静态 CSS 和局部 UI 调整默认跳过。
- 使用前先冻结主线程依据源码得到的首轮候选文件，再查询 CRG，用于补充调用者、测试和影响范围；不得让图结果覆盖运行时、测试或当前源码证据。
- CRG 不可用、图数据陈旧或结果低置信时，立即降级到原 CE 流程、`rg`、源码、测试和运行时验证，不得阻塞计划、审查、提交或推送。
- 只允许手工运行 `make crg.build`、`make crg.update`、`make crg.status`、`make crg.review BASE=<git-ref>`，不得启用 install、hooks、daemon、watch、embeddings 或默认测试/提交链集成。
- 中文自然语言快捷映射：`构建代码图` -> `make crg.build`，`更新代码图` -> `make crg.update`，`查看代码图` -> `make crg.status`，`代码图审查` -> `make crg.review`；用户指定基准分支或提交时附加 `BASE=<git-ref>`。这些映射仍属于显式手工执行，不改变 CRG 的受控边界。
- 完整操作、触发矩阵、证据优先级与回滚方式见 `docs/reference/tooling/code-review-graph.md`。

## 4. 核心入口 (Entry Points)
- 项目索引：`docs/index.md`
- 需求/方向讨论：`docs/brainstorms/`
- 技术计划：`docs/plans/`
- 审查/验证记录：`docs/reviews/`
- 解决方案沉淀：`docs/solutions/`
- 参考提示词：`docs/prompts/`
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
*上次更新: 2026-08-04（对齐 agent-light-workflow 并保留 CE 兼容层；补充测试环境 im-test-1 部署指令）*
