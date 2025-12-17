# 仓库指引

## 项目结构与模块组织
本仓库包含多套应用：Rust API 位于 `backend/src`，Flutter 客户端位于 `frontend/lib`，Vue 3 管理端位于 `admin/src`，Nuxt.js 官网页面位于 `website/app`。

- 数据库初始化与增量迁移脚本位于 `backend/sql`（`backend/sql/base.sql` 为数据库 v1 基线脚本；后续结构演进全部通过 `backend/sql/migrations/` 下的增量脚本完成，并需同步追加到 `backend/src/database/mod.rs` 的 `MIGRATIONS` 列表中；空库场景推荐直接启动 backend 执行 `Database::migrate` 完成初始化与迁移）。
- 后端辅助脚本位于 `backend/scripts/`（如清库、SQL 校验等）。
- Flutter 资源位于 `frontend/assets`，测试位于 `frontend/test`；管理后台的 Vite 配置在 `admin/config`。
- 本仓库的 Docker/Compose 编排主要位于 `backend/docker-compose*.yml`（包含 PostgreSQL/Redis/后端容器等）；根目录的 `nginx/` 为部署相关配置。

管理后台相关任务必须同步阅读 [管理后台开发规范](../../admin/docs/开发规范.md)（MUST）。

## 构建、测试与开发命令
- `cd backend && docker compose up -d postgres redis-session redis-cache` 启动 PostgreSQL 与 Redis（session/cache 多实例）。
- `cd backend && RUST_LOG=debug cargo run` 启动 API（默认监听 `8010`）；打包前请运行 `cd backend && cargo build --release`。
- `cd frontend && flutter pub get && ./scripts/run.sh` 启动 Flutter 客户端；测试：`cd frontend && flutter test`。
- `cd admin && pnpm install && pnpm dev` 本地启动管理端；类型检查：`cd admin && pnpm type:check`。
- `cd desktop && bun install && bun run tauri dev` 启动桌面端开发模式，CI 使用 `cd desktop && bun run build` 进行构建。
- `cd website && bun install && bun run dev` 启动官网页面开发模式（默认运行在 `http://localhost:8015`），`bun run build` 构建生产版本。

## 代码风格与命名规范
Rust 模块遵循 `cargo fmt --all` 与 `cargo clippy --all-targets -- -D warnings`，模块名使用 `snake_case`，类型名使用 `PascalCase`。Flutter 代码需跑 `dart format .` 与 `dart analyze`，文件命名保持 `snake_case.dart`，组件使用 `PascalCase`。Vue 代码采用两个空格缩进，脚本标识符使用 `camelCase`，组件文件名保持 `PascalCase.vue`；所有格式化与 lint 通过 lint-staged 与 Prettier 自动执行。Nuxt.js 官网项目遵循 Vue 3 代码规范，使用 TypeScript，组件命名采用 `PascalCase.vue`。

## 测试规范
- 后端修改后优先执行：`cd backend && cargo test`。
- Flutter 的组件测试与 golden 测试放在 `frontend/test/<feature>_test.dart` 下，网络请求请复用现有的 mock 服务。
- 管理端依赖 `pnpm type:check`（以及开启时的 `pnpm lint`），出现 UI 回归时请补充模拟器截图或日志；桌面端使用 `bun run type-check`。

## Commit 与 Pull Request 规范
遵循由 commitlint 强制的 Conventional Commits 格式，例如 `feat(frontend-chat): enable reactions` 或 `fix(backend-auth): trim token scope`。保持单次提交聚焦、与 main 分支保持 rebase，并在推送前确保格式化与单元测试通过。Pull Request 需描述变更、关联相关 issue、列出验证步骤（若执行过冒烟/回归脚本需写明），UI 变更需附带截图。

**重要规则：每次代码改动完成后，必须立即执行 Git 提交并推送到远端仓库，确保远端历史及时同步。不允许在本地累积多次未提交的改动。**

## 配置与安全提示
复制 `backend/.env.example` 为 `backend/.env`，定期轮换 JWT 密钥，将凭据存放在共享保险库；禁止提交生成的 `.env` 文件。部署到 staging 或生产时优先使用 `backend/docker-compose.prod.yml`，并为不同环境覆写 Redis 密码。开发完毕后运行 `cd backend && docker compose down` 释放端口，避免遗留旧的 Redis 数据。

## 数据库约定
- 自 2025-10-20 起，数据库中的业务状态字段统一使用整数类型，禁止新增或扩展 PostgreSQL 枚举；对应取值及含义需在代码端集中维护（使用枚举或常量并写明注释）。
- 值域由业务代码约束，数据库层无需额外 `CHECK` 约束；请确保代码常量与文档保持同步，所有入口在写入前都需校验值是否合法。
- 若要变更结构或基础数据，需在 `backend/sql` 目录新增按时间戳命名的 SQL 文件（`YYYYMMDDHHMMSS_desc.sql`），禁止直接修改既有快照。

---

## 相关任务文档

- [桌面端：对齐清单与任务拆解](../desktop/desktop-remaining-tasks.md)
- [项目任务清单](../reports/task-list.md)
- [API 概览](../api/api-overview.md) / [API 参考](../api/api-reference.md)
