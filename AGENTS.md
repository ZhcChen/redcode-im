# RedCode IM 全局导航与代理规则 (AGENTS.md)

> [!IMPORTANT]
> 本文件定义了 AI 代理在 **RedCode IM** 仓库中的全局行为准则及核心架构入口。

## 1. 全局行为准则
- **语言**: 默认使用 **简体中文** 回复，保留专业技术词汇原文。
- **提交规范**: 遵循 **Conventional Commits**；完成功能或修复后**立即 commit 并 push**。
- **数据库**: 禁止修改已有迁移文件；新增变更使用 `YYYYMMDDHHMMSS_desc.sql`；**禁用 PostgreSQL 枚举**。
- **测试**: 核心逻辑修改后必须运行测试（后端 `cargo test`，移动端 `flutter test`；全栈回归入口见 `docs/testing/README.md` 与 `tests/run.sh`）。
- **覆盖率**: Backend（Rust）覆盖率入口：`tests/coverage.sh`（输出到 `backend/coverage/`，已加入 gitignore）。
- **工具**: 优先使用项目内 `docs/` 文档建立上下文；所有测试除非特殊指定否则使用 **Go**。
- **Docker Compose**: 本机使用 `docker-compose`（不是 `docker compose`）；测试栈要求 PostgreSQL/Redis **不映射宿主端口**（避免端口冲突）。

## 2. 核心架构入口 (Entry Points)
- **定义**: 现代化 IM 系统 (Rust + Axum + Vue/Tauri + Flutter + Nuxt)。
- **[项目索引 (docs/README.md)](docs/README.md)**: 了解项目全貌、技术栈及文档索引。
- **[任务清单 (docs/reports/task-list.md)](docs/reports/task-list.md)**: **AI 进场后首要查阅此处**，了解当前待办事项。
- **[项目评估报告](docs/reports/project-status-assessment-report-2025-11-08.md)**: 深入了解项目现状与待解决的核心问题。
- **[测试工作流程指南 (docs/testing/README.md)](docs/testing/README.md)**: 测试架构入口、如何起测试栈与运行回归。

## 3. 技术栈速查
- **后端**: Rust (Axum, SQLx, Redis) -> `backend/src/`
- **桌面端**: TypeScript (Vue 3, Tauri) -> `desktop/src/`
- **移动端**: Dart (Flutter) -> `frontend/lib/`
- **管理后台**: Vue 3 (Arco Design) -> `admin/src/`

---
*上次更新: 2026-01-17*
