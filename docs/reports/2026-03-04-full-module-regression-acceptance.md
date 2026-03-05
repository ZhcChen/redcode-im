# 全模块回归验收报告

**日期**: 2026-03-04  
**补充更新**: 2026-03-05（Admin 全路由冒烟增强；Frontend/Desktop/Website 测试扩展与真机链路；Backend 成本与生命周期清理链路补测）  
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
- Android 真机: `Mi MIX 2S (2b252911)`、`Pixel 8 Pro (3A091FDJG001DN)`
- Backend 联调地址:
  - API: `http://192.168.31.107:8010`
  - WS: `ws://192.168.31.107:8010/ws`

## 3. 全模块结果总览

| 模块 | 命令 | 结果 |
|------|------|------|
| Backend（Rust 单元） | `cargo test --lib` | 通过（`132 passed`） |
| Backend（Rust 集成） | `cargo test --tests -- --test-threads=1` | 通过 |
| Backend（Go 黑盒） | `docker-compose -f tests/docker-compose.yml run --rm go-tests` | 通过（全部业务域） |
| Frontend（单测） | `flutter test` | 通过（`27 passed`） |
| Frontend（真机 smoke） | `flutter test integration_test/smoke_test.dart -d 3A091FDJG001DN ...` | 通过（`2 passed`） |
| Frontend（真机网络） | `flutter test integration_test/network_connectivity_test.dart -d 3A091FDJG001DN ... --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true` | 通过（`2 passed`） |
| Desktop | `bun run test` | 通过（`12 files, 37 tests`） |
| Website | `bun run test` | 通过（`1 file, 12 tests`） |
| Admin E2E（全量） | `ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test --workers=1` | 通过（`64 passed`） |
| Admin 鉴权韧性 | `ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm exec playwright test playwright-tests/specs/auth-resilience.spec.ts --workers=1` | 通过（`3 passed`） |
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

### 4.4 Frontend 核心服务单元测试增强（TDD）

- 新增：
  - `frontend/test/core/token_storage_test.dart`
  - `frontend/test/core/app_config_service_test.dart`
  - `frontend/test/core/version_service_test.dart`
- 修复：
  - `frontend/lib/core/storage/token_storage.dart`
  - `readSession()` 在用户 JSON 损坏时同步清理 `refresh_token`，防止残留脏会话。
- 覆盖新增：
  - 会话存储完整性（token/user/refresh）
  - 应用名配置回退链路（内存 -> SQLite -> API）
  - 版本检查与下载链接契约（query 参数、异常映射）

### 4.5 Frontend/Desktop/Website 跨模块测试扩展

- Frontend 新增：
  - `frontend/test/core/settings_service_test.dart`
  - 覆盖 `fetchAppName`、`fetchPrivacyPolicy`、`fetchRequireCaptchaForLogin` 的成功/失败/格式异常分支。
- Desktop 新增：
  - `desktop/test/store/accounts.actions.test.ts`
  - `desktop/test/utils/cache.test.ts`
  - `desktop/test/api/message.transform-and-send.test.ts`
  - `desktop/test/api/message-search.test.ts`（新增错误分支与时间戳兜底用例）
- Website 增强：
  - `website/test/download-utils.test.ts` 扩展至 12 条用例
  - 覆盖商店链接缺失、安装包回退、默认错误文案、linux/unknown 平台边界。

### 4.6 Admin 鉴权韧性测试扩展

- 新增：
  - `admin/playwright-tests/specs/auth-resilience.spec.ts`
- 覆盖新增：
  - 登录失败后保持登录页且不写入 token
  - access token 过期 + refresh 成功自动续签并留在业务页
  - access token 过期 + 无 refresh token 时清理会话并回登录页

### 4.7 Backend 成本与生命周期清理链路补测

- 新增 Go 黑盒契约：
  - `tests/go/backend/admin/admin_cleanup_contract_test.go`
  - 覆盖 `POST /api/admin/logs/cleanup` 与 `POST /api/admin/push/logs/cleanup`
  - 覆盖 `retentionDays=2` 成功契约与 `retentionDays=0` 参数校验失败契约
- 新增 Rust 单测（配置边界）：
  - `backend/src/services/file_upload_cleanup.rs`
  - `backend/src/services/push.rs`
  - `backend/src/logging/writer.rs`
- 修复 1 处配置解析缺陷（测试驱动）：
  - `LogWriterConfig::from_env` 以前会接受 `0/-1` 等非法值；
  - 现改为仅接受 `>0`，非法值回退默认值，避免误配置导致清理策略异常。
- 测试基线结果：
  - `cargo test file_upload_cleanup_config --lib` -> `3 passed`
  - `cargo test log_writer_config --lib` -> `2 passed`
  - `cargo test push_db_queue_cleanup_config --lib` -> `2 passed`

### 4.8 Backend Wave A（readyz / 改密 / 未读计数）补测

- 新增 Go 黑盒用例：
  - `tests/go/backend/system/readyz_test.go`
  - `tests/go/backend/users/user_password_test.go`
  - `tests/go/backend/messages/unread_counts_test.go`
- 覆盖新增：
  - `/readyz` 的状态契约（`status/checks/latencyMs`）
  - `/users/me/password` 的错误旧密码校验 + 改密后新旧密码登录行为
  - `/unread_counts` 的多消息未读累计 + `read_until` 后清零
- 波次执行结果：
  - `go test ./backend/system -run 'Test(Healthz_OK|Readyz_OK)$' -v` 通过
  - `go test ./backend/users -run TestChangePassword_WrongOldThenSuccess -v` 通过
  - `go test ./backend/messages -run TestUnreadCounts_MultiMessageReadUntil_OK -v` 通过

## 5. 执行过程中的关键问题与处理

- 问题 1：本机 dev backend 未配置 OAuth client id，且历史默认存储 endpoint 为 `external-mock:19080`，直接执行 `go test ./...` 会出现 OAuth/COS 相关失败。  
  处理：使用隔离测试栈执行全量 Go 套件（`docker-compose -f tests/docker-compose.yml run --rm go-tests`），并增强 `EnsureDefaultStorageProvider` 自动修正 endpoint 到当前 `EXTERNAL_MOCK_BASE_URL` 对应 host。

- 问题 2：Admin Playwright 首次使用 `127.0.0.1:8011` 出现连接拒绝。  
  处理：固定使用 `http://localhost:8011` 并确认 dev server 监听后重跑，全部通过。

- 问题 3：Frontend 真机联调脚本在当前机器 `en0` 无地址（默认网卡为 `en1`）。  
  处理：改为“先解析默认路由网卡再取 IP”（`route -n get default` + `ipconfig getifaddr`），已写入测试文档。

- 问题 4：`LogWriterConfig::from_env` 会接受 `0/-1` 等非法值，可能导致日志清理策略异常。  
  处理：新增失败测试后修复解析逻辑，仅接受 `>0`，非法值回退默认值。

## 6. 可追溯性

- 测试策略文档: `docs/reference/testing/README.md`
- 模块功能清单: `docs/reports/module-function-inventory-2026-03-01.md`
- 本次验收报告: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

## 7. 后续建议（下一步）

1. 将本次“本机等价执行路径”补充进 `docs/reference/testing/README.md` 的故障分支。  
2. 在 CI 增加最小门禁组合（backend Rust+Go / frontend unit / desktop+website vitest / admin e2e smoke）。  
3. 下一轮回归优先验证 `tests/run.sh` 的 Docker 原生路径可用性并恢复单入口执行。  
