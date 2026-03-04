# 测试工作流程指南（重构版）

> 本文档定义 RedCode IM 的统一测试分层、目录规范与执行入口。
>
> 当前策略：**先保证稳定可执行，再逐模块扩充深度**。

## 1. 测试分层

### L0：快速反馈（开发者本地）

- Backend 单元测试：`cargo test --lib`
- Frontend 单元测试：`flutter test`

目标：分钟级反馈，阻断明显回归。

### L1：PR 门禁（默认）

- Backend 集成测试（Rust）：`cargo test --tests`
- Backend 黑盒契约测试（Go）：`go test ./...`

目标：验证后端对外契约和核心链路稳定。

### L2：发版前/夜间（扩展）

- Admin E2E（Playwright）
- Frontend 集成/E2E（Flutter integration / Patrol）

目标：跨端关键用户旅程验证。

## 2. 模块测试矩阵

| 模块 | 单元测试 | 集成测试 | 端到端测试 |
|------|----------|----------|------------|
| Backend | Rust (`backend/src`) | Rust (`backend/tests`) + Go (`tests/go`) | WebSocket/关键业务链路（Go） |
| Frontend (Flutter) | `frontend/test` | `frontend/integration_test` | `frontend/patrol_test` |
| Admin (Vue) | 复用契约 + 页面级断言 | API 契约复用 Go | Playwright (`admin/playwright-tests/specs`) |
| Desktop (Vue + Tauri) | Vitest (`desktop/test`) | API/Store/Utils 集成（Vitest） | 复用 Backend Go 契约 |
| Website (Nuxt) | Vitest (`website/test`) | 下载链路逻辑集成（Vitest） | 复用 Playwright/页面手动验收 |

## 3. 统一入口

### 3.1 一键回归（推荐）

```bash
./tests/run.sh
```

该入口会：
1. 启动测试依赖（External Mock / PostgreSQL / Redis）
2. 运行 Backend Rust 单元测试
3. 运行 Backend Rust 集成测试
4. 启动 Backend 服务
5. 运行 Go 黑盒契约测试

### 3.2 模块独立执行

```bash
# Backend
cd backend && cargo test --lib
cd backend && cargo test --tests -- --test-threads=1

# Go 契约
cd tests/go && go test ./... -v

# Frontend
cd frontend && flutter test
# 先设置本机局域网 IP（确保与真机在同一网段）
LAN_IP=$(ipconfig getifaddr en0)
# 默认 smoke（推荐，真机：Pixel 8 Pro）
cd frontend && flutter test integration_test/smoke_test.dart -d 3A091FDJG001DN \
  --dart-define=API_BASE_URL=http://${LAN_IP}:8010 \
  --dart-define=WS_URL=ws://${LAN_IP}:8010/ws
# 发布前真机联调（包含 network_connectivity_test）
cd frontend && flutter test integration_test -d 3A091FDJG001DN \
  --dart-define=API_BASE_URL=http://${LAN_IP}:8010 \
  --dart-define=WS_URL=ws://${LAN_IP}:8010/ws \
  --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true

# Admin E2E
# 先在另一个终端启动 Admin
cd admin && pnpm dev
# 再执行真实联调 E2E
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test --workers=1
# 仅执行 Admin 全路由冒烟（default 可达集合）
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  ADMIN_ROUTE_PROFILE=default pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1
# 执行 data-cleanup 可达集合（需 dev 以 VITE_ENABLE_DATA_CLEANUP=true 启动）
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  ADMIN_ROUTE_PROFILE=data-cleanup pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1

# Desktop
cd desktop && bun run test

# Website
cd website && bun run test
```

## 4. 目录规范

```
backend/tests/                  # Rust 集成测试
tests/go/                       # Go 黑盒契约测试
tests/mocks/external/           # 外部依赖模拟 + Go 测试
frontend/test/                  # Flutter 单元测试
frontend/integration_test/      # Flutter 集成测试
frontend/patrol_test/           # Flutter E2E（Patrol）
admin/playwright-tests/specs/   # Admin E2E（Playwright）
docs/reference/testing/matrix/  # 功能-测试-验收追踪矩阵
```

矩阵文件：
- `docs/reference/testing/matrix/backend.csv`
- `docs/reference/testing/matrix/admin.csv`
- `docs/reference/testing/matrix/frontend.csv`
- `docs/reference/testing/matrix/desktop.csv`
- `docs/reference/testing/matrix/website.csv`

## 5. 本次重构决策

- 已移除测试可视化 Dashboard 模块，测试执行不再依赖额外可视化服务。
- 已清理旧测试与旧覆盖率统计脚本，改为“单入口 + 分层执行”的基础架构。
- 已引入第三方依赖本地模拟（External Mock），用于在无公网/无云资源场景下回归 OAuth、Push、COS/CI、IP 地理位置链路。

---

**最后更新**: 2026-03-05
