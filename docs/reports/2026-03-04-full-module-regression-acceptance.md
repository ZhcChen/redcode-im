# 全模块回归验收报告

**日期**: 2026-03-04  
**补充更新**: 2026-03-05（Admin 全路由冒烟增强）  
**范围**: Backend / Frontend / Admin / Desktop / Website 全模块回归  
**执行分支**: `feat/full-test-rebuild`  
**关联提交**: `d451295`、`5b19065`

## 1. 验收目标

- 基于 `docs/reference/testing/README.md` 的分层与模块矩阵，完成一次全模块可执行回归。
- 验证真机 Frontend 联调链路（同局域网，本机内网 IP 访问 Backend）。
- 输出可追溯的命令、结果、修复点与剩余风险。

## 2. 验收环境

- 本机系统: macOS（Apple Silicon）
- Flutter: `3.35.5`
- Go: `1.25.5`
- Rust/Cargo: `cargo 1.90.0`
- Bun: `1.3.6`
- pnpm: `10.20.0`
- Android 真机: `Mi MIX 2S (2b252911)`
- Backend 联调地址:
  - API: `http://192.168.31.248:8010`
  - WS: `ws://192.168.31.248:8010/ws`

## 3. 全模块结果总览

| 模块 | 命令 | 结果 |
|------|------|------|
| Backend（Rust 单元） | `cargo test --lib` | 通过（`126 passed`） |
| Backend（Rust 集成） | `cargo test --tests -- --test-threads=1` | 通过 |
| Backend（Go 黑盒） | `go test ./... -v`（`tests/go`） | 通过（全部业务域） |
| Frontend（单测） | `flutter test` | 通过 |
| Frontend（真机集成） | `flutter test integration_test -d 2b252911 ...` | 通过（`network_connectivity_test` + `smoke_test`） |
| Desktop | `bun run test` | 通过（`9 files, 22 tests`） |
| Website | `bun run test` | 通过（`1 file, 9 tests`） |
| Admin E2E（全量） | `ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test --workers=1` | 通过（`61 passed`） |
| Admin 全路由冒烟（default） | `ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 ADMIN_ROUTE_PROFILE=default pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1` | 通过（`54 passed`） |
| Admin 全路由冒烟（data-cleanup） | `ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 ADMIN_ROUTE_PROFILE=data-cleanup pnpm exec playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1` | 通过（`56 passed`） |

结论：按当前测试矩阵口径，本次全模块执行项通过率为 **100%**，满足当前阶段验收标准。

## 4. 本次为通过回归所做的测试稳定性修复

### 4.1 Frontend 真机联调补测

- 新增: `frontend/integration_test/network_connectivity_test.dart`
  - 覆盖 `API_BASE_URL/healthz` 可达性
  - 覆盖 `WS_URL` 握手可达性

### 4.2 Go 黑盒测试环境兼容修复

- 修改: `tests/go/internal/testutil/admin_flow.go`
  - 存储 provider 的 `endpoint` 从写死 `external-mock:19080` 改为从 `EXTERNAL_MOCK_BASE_URL` 推导 host。
  - 解决本机执行（非 docker service DNS）下的上传链路失败。
- 修改: `tests/go/internal/testutil/auth_flow.go`
  - `UniqueUsername` 改为随机手机号生成，避免持久化数据库下重复用户名导致 `409`。

### 4.3 Admin Playwright 全路由可达 + 异常恢复重构

- 新增可复用测试支撑层：
  - `admin/playwright-tests/support/route-cases.ts`（default/data-cleanup 路由清单）
  - `admin/playwright-tests/support/mock-server.ts`（统一 mock + 4xx/5xx 注入）
  - `admin/playwright-tests/support/test-context.ts`（环境变量与 profile 入口）
- 新增 `admin/playwright-tests/specs/route-smoke.spec.ts`：
  - 覆盖 `dashboard/operations/settings/user-management/versions` 全可达路由集合
  - 每条路由均验证“可达 + 锚点 + 关键交互 + 4xx/5xx 可恢复”
- 复用改造旧脚本：
  - `core-flows.spec.ts`、`smoke-login.spec.ts` 统一复用 `test-context`
- 命令入口补充：
  - `pnpm test:e2e:routes`
  - `pnpm test:e2e:routes:default`
  - `pnpm test:e2e:routes:data-cleanup`

## 5. 执行过程中的关键问题与处理

- 问题 1：`tests/run.sh` 依赖的 Docker 镜像构建在本机出现 `apk add` 长时间阻塞。  
  处理：采用等价本机执行路径（本机启动 external-mock + backend，连接本地 PostgreSQL/Redis）完成回归。

- 问题 2：Admin Playwright 首次使用 `127.0.0.1:8011` 出现连接拒绝。  
  处理：固定使用 `http://localhost:8011` 并确认 dev server 监听后重跑，全部通过。

## 6. 可追溯性

- 测试策略文档: `docs/reference/testing/README.md`
- 模块功能清单: `docs/reports/module-function-inventory-2026-03-01.md`
- 本次验收报告: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

## 7. 后续建议（下一步）

1. 将本次“本机等价执行路径”补充进 `docs/reference/testing/README.md` 的故障分支。  
2. 在 CI 增加最小门禁组合（backend Rust+Go / frontend unit / desktop+website vitest / admin e2e smoke）。  
3. 下一轮回归优先验证 `tests/run.sh` 的 Docker 原生路径可用性并恢复单入口执行。  
