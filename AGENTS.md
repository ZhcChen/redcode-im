# Repository Guidelines

## Project Structure & Module Organization
The repository hosts three applications: the Rust API under `backend/backend/src`, the Flutter client in `frontend/lib`, and the Vue 3 admin console inside `admin/src`. SQLx migrations stay in `backend/migrations`, while command-line integration scripts are grouped as `backend/test_*.sh`. Flutter assets are stored in `frontend/assets`, tests in `frontend/test`, and Vue configuration helpers sit under `admin/config`. Infrastructure files—`docker-compose*.yml`, `services.sh`, `docker-start.sh`—reside at the root.

## Build, Test, and Development Commands
- `cd backend && docker-compose up -d` spins up PostgreSQL 17 and the three Redis instances on 6381/6382/6383.
- `cd backend && cargo run` launches the API (default port 8010) and serves static docs on port 8011; use `cargo build --release` before packaging.
- `cd frontend && flutter run` or `./run_flutter.sh` boots the client after `flutter pub get`; `flutter test` covers widget suites.
- `cd admin && pnpm install && pnpm dev` runs the dashboard locally, while `pnpm build` emits optimized bundles; invoke `./test_all.sh` for a full-stack smoke test.

## Coding Style & Naming Conventions
Rust modules follow `cargo fmt --all` and `cargo clippy --all-targets -- -D warnings`, keeping modules `snake_case` and types `PascalCase`. Flutter code adheres to `dart format .` and `dart analyze`, with files in `snake_case.dart` and widgets in `PascalCase`. Vue code uses two-space indentation, `camelCase` script identifiers, and `PascalCase.vue` components; formatting and linting run automatically through lint-staged and Prettier.

## Testing Guidelines
- Run `cargo test` before calling integration helpers like `backend/test_flow.sh` or `backend/test_friend_api.sh`.
- Place Flutter widget and golden tests under `frontend/test/<feature>_test.dart`, stubbing network calls with existing mock services.
- Rely on `pnpm type:check` (and `pnpm lint` when enabled) for the admin console, and capture emulator screenshots or logs for UI regressions.

## Commit & Pull Request Guidelines
We follow Conventional Commits enforced by commitlint, e.g., `feat(frontend-chat): enable reactions` or `fix(backend-auth): trim token scope`. Keep commits focused, rebase with main, and ensure formatters and unit tests pass before pushing. Pull requests should describe the change, link related issues, list verification steps (including `./test_all.sh` when used), and attach screenshots for UI updates.

## Configuration & Security Tips
Copy `backend/.env.example` to `backend/.env`, rotate JWT secrets, and store credentials in the shared vault; never commit generated `.env` files. Prefer `backend/docker-compose.prod.yml` for staging or production deployments and override Redis passwords per environment. Tear down local containers with `cd backend && docker-compose down` to free ports and avoid stale Redis data.

## Database Conventions
- 从 2025-10-20 起，业务状态字段在数据库中统一使用整数型表示，禁止新增或扩展 PostgreSQL 枚举；对应取值及含义须在代码侧集中维护（使用枚举/常量并写明注释）。
- 整个取值域由业务代码约束，数据库层无需额外 `CHECK` 约束；请确保代码常量与文档同步更新，所有入口在写入前都需校验值是否属于枚举定义。
- 所有结构或基础数据变更需在 `backend/sql` 目录新增时间戳命名的 SQL 文件（`YYYYMMDDHHMMSS_desc.sql`），不得直接修改现有快照文件。
