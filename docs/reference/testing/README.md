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
| Admin (Vue) | （后续补 Vitest） | API 契约复用 Go | Playwright (`admin/playwright-tests/specs`) |
| Desktop (Vue + Tauri) | （后续补） | API 契约复用 Go | （后续补） |
| Website (Nuxt) | （后续补） | （后续补） | （后续补） |

## 3. 统一入口

### 3.1 一键回归（推荐）

```bash
./tests/run.sh
```

该入口会：
1. 启动测试依赖（PostgreSQL / Redis）
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

# Admin E2E
cd admin && ADMIN_E2E_ENABLED=true pnpm test:e2e
```

## 4. 目录规范

```
backend/tests/                  # Rust 集成测试
tests/go/                       # Go 黑盒契约测试
frontend/test/                  # Flutter 单元测试
frontend/integration_test/      # Flutter 集成测试
frontend/patrol_test/           # Flutter E2E（Patrol）
admin/playwright-tests/specs/   # Admin E2E（Playwright）
```

## 5. 本次重构决策

- 已移除测试可视化 Dashboard 模块，测试执行不再依赖额外可视化服务。
- 已清理旧测试与旧覆盖率统计脚本，改为“单入口 + 分层执行”的基础架构。

---

**最后更新**: 2026-03-01
