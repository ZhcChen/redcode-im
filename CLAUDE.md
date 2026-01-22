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
- **通知**: 每次对话结束调用 **通知 skill**（`devflow-notifier`）发送"对话完成"提醒。
- **工具**: 优先使用项目内 `docs/` 文档建立上下文；所有测试除非特殊指定否则使用 **Go**。
- **文档结构**: `docs/` 根目录仅保留 `index.md`，其他文档需放在子目录（如 `docs/reference/`、`docs/workflow/`）。
- **Docker Compose**: 本机使用 `docker-compose`（不是 `docker compose`）；测试栈要求 PostgreSQL/Redis **不映射宿主端口**（避免端口冲突）。
- **面板端口**: Dashboard 启动遇到端口冲突时，必须先停止占用端口的进程再启动，**禁止**改用其他端口。

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

## 4. 任务工作流程（强制）

### 4.1 流程总览

```
PM（产品负责人） → [PRD确认] → Architect（架构师） → [方案确认] → Developer（开发） → Reviewer（审查） → Tester（测试）
```

- 每个任务必须按阶段流转执行，不得跳过
- PRD确认与方案确认是 **强制确认节点**，未获得明确确认不得进入下一阶段
- 产出物需落盘并可追溯

### 4.2 自动推进规则

- **仅 PRD确认 与 方案确认** 需要用户明确确认
- 一旦方案确认完成，**Developer → Reviewer → Tester 自动推进**，不再询问用户
- 测试未通过时 **自动回到 Developer 修复**，直到测试 100% 通过
- 若出现阻塞（缺少凭证/环境、外部依赖不可用、逻辑冲突），需记录并暂停，仅此类情况才请求用户确认
- **任务完成以测试 100% 通过为准**

### 4.3 阶段进入/退出条件

| 阶段 | 进入条件 | 退出条件 |
|------|----------|----------|
| 需求分析 | 任务已创建 | PRD 草案完成 |
| PRD确认 | PRD 已落盘且含验收矩阵 | 用户确认后进入技术设计 |
| 技术设计 | PRD 已确认 | 技术方案草案完成 |
| 方案确认 | 技术方案已落盘 | 用户确认后进入编码 |
| 编码 | 方案已确认 | 代码变更完成 |
| 审查 | 编码完成 | 审查通过进入测试 |
| 测试 | 审查通过 | 测试 100% 通过 |
| 完成 | 测试通过 | 任务关闭、提交推送 |

### 4.4 产出物命名

| 产出物 | 命名格式 | 存放目录 |
|--------|----------|----------|
| 需求文档 | `PRD-{id}.md` | `docs/requirements/` |
| 技术方案 | `SPEC-{id}.md` | `docs/specs/` |
| 测试报告 | `TEST-{id}.md` | `docs/reports/` |

---
*上次更新: 2026-01-22*
