# RedCode IM 全局导航与代理规则 (AGENTS.md)

> [!IMPORTANT]
> 本文件定义了 AI 代理在 **RedCode IM** 仓库中的全局行为准则及核心架构入口。

## 1. 全局行为准则
- **语言**: 默认使用 **简体中文** 回复，保留专业技术词汇原文。
- **提交规范**: 遵循 **Conventional Commits**；完成功能或修复后**立即 commit 并 push**。
- **数据库**: 禁止修改已有迁移文件；新增变更使用 `YYYYMMDDHHMMSS_desc.sql`；**禁用 PostgreSQL 枚举**。
- **测试**: 核心逻辑修改后必须运行测试（后端 `cargo test`，移动端 `flutter test`；全栈回归入口见 `docs/reference/testing/README.md` 与 `tests/run.sh`）。
- **覆盖率**: Backend（Rust）覆盖率入口：`tests/coverage.sh`（输出到 `backend/coverage/`，已加入 gitignore）。
- **API 覆盖数据**: 路由测试覆盖数据：`docs/reports/api-test-coverage.json`（生成：`go -C tests/go run ./cmd/route_coverage`）。
- **通知**: 每次对话结束调用 **通知 skill**（`devflow-notifier`）发送“对话完成”提醒。
- **工具**: 优先使用项目内 `docs/` 文档建立上下文；所有测试除非特殊指定否则使用 **Go**。
- **文档结构**: `docs/` 根目录仅保留 `index.md`，其他文档需放在子目录（如 `docs/reference/`、`docs/workflow/`）。
- **Docker Compose**: 本机使用 `docker-compose`（不是 `docker compose`）；测试栈要求 PostgreSQL/Redis **不映射宿主端口**（避免端口冲突）。
- **端口占用处理**: 启动任意模块遇到端口冲突时，必须先停止占用端口的进程再启动，**禁止**改用其他端口（Dashboard 亦同）。
- **本地 Backend 环境**:  
  - **开发调试（dev）**：`backend/docker/dev/docker-compose.yml`（源码挂载 + 容器内 `cargo run`）  
  - **发布构建验证（release）**：`backend/docker/release/docker-compose.yml`（多阶段构建 + 二进制运行）  
  - **数据库迁移**：由 backend 自身执行，不在 PostgreSQL 容器挂载 init SQL  
  - **端口策略**：PG/Redis 不映射宿主端口；Backend 可映射 `8010:8010`
- **本地开发重启规则（dev）**：  
  - 修改 Rust 代码：仅重启 backend  
    `docker-compose -f backend/docker/dev/docker-compose.yml restart backend`  
  - 修改依赖（`Cargo.toml`/Dockerfile）：重新构建并启动  
    `docker-compose -f backend/docker/dev/docker-compose.yml up -d --build backend`  
  - 需要全新数据库：`docker-compose -f backend/docker/dev/docker-compose.yml down -v`
- **测试栈（不要复用 dev）**：  
  - `tests/docker-compose.yml` / `./tests/run.sh`  
  - 测试栈默认不映射 PG/Redis 端口，Backend 宿主端口可用 `BACKEND_HOST_PORT` 指定（详见 `docs/reference/testing/README.md`）

## 2. 核心架构入口 (Entry Points)
- **定义**: 现代化 IM 系统 (Rust + Axum + Vue/Tauri + Flutter + Nuxt)。
- **[项目索引 (docs/index.md)](docs/index.md)**: 了解项目全貌、技术栈及文档索引。
- **[任务清单 (docs/reports/task-list.md)](docs/reports/task-list.md)**: **AI 进场后首要查阅此处**，了解当前待办事项。
- **[项目评估报告](docs/reports/project-status-assessment-report-2025-11-08.md)**: 深入了解项目现状与待解决的核心问题。
- **[测试工作流程指南 (docs/reference/testing/README.md)](docs/reference/testing/README.md)**: 测试架构入口、如何起测试栈与运行回归。

## 3. 技术栈速查
- **后端**: Rust (Axum, SQLx, Redis) -> `backend/src/`
- **桌面端**: TypeScript (Vue 3, Tauri) -> `desktop/src/`
- **移动端**: Dart (Flutter) -> `frontend/lib/`
- **管理后台**: Vue 3 (Arco Design) -> `admin/src/`

---
*上次更新: 2026-01-23*
