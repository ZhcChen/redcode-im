---
date: 2026-04-09
topic: admin-rbac-architecture-refactor
status: completed
updated: 2026-04-10
branch: feat/storage-b2-admin
---

# Admin 架构重构与 RBAC 迁移计划

## 当前状态快照

### 已完成
- Backend RBAC 已真实化，`auth/admin/login` 与 `auth/admin/me` 已返回 `roleCodes / permissionKeys / isSuperAdmin`。
- Admin 已完成 `app/providers`、`app/layouts`、`app/router`、`features/*/routes` 收口。
- RBAC 页面已落地：
  - `admin/src/features/access-control/pages/admin-users-page.vue`
  - `admin/src/features/access-control/pages/roles-page.vue`
  - `admin/src/features/access-control/pages/permissions-page.vue`
- 首个超级管理员已切为运行时 bootstrap 初始化，默认 seed 已移除：
  - `backend/src/handlers/auth.rs`
  - `backend/sql/migrations/20260410093000_remove_default_admin_seed.sql`
- Admin 共享认证与 HTTP 层已收口：
  - `admin/src/services/auth.ts`
  - `admin/src/services/auth-runtime.ts`
  - `admin/src/services/http.ts`
- legacy route page 已迁到 `app` 模块：
  - `admin/src/app/pages/not-found-page.vue`
  - `admin/src/app/pages/redirect-page.vue`

### 最近已落地提交
- `434fb2dd` `refactor(admin): move settings pages into feature module`
- `9c81c286` `refactor(admin): move version pages into feature module`
- `754deb74` `refactor(admin): move user management pages into feature module`
- `331037ab` `refactor(admin): move operations pages into feature module`
- `8feafb4b` `refactor(admin): move dashboard pages into feature module`
- `214374e0` `refactor(admin): align app shell around providers and layouts`
- `73ee7c44` `refactor(admin): consolidate router shell under app module`
- `5c650616` `refactor(admin): centralize auth services and runtime`
- `4ae0ac63` `refactor(admin): unify http access through shared service`
- `736c2796` `refactor(admin): move legacy route pages into app module`

### 当前验证基线
- `cd admin && npm run type:check`
- `cd admin && ADMIN_E2E_ENABLED=true ADMIN_LIVE_BACKEND_ENABLED=true npx playwright test playwright-tests/specs/auth-bootstrap.spec.ts playwright-tests/specs/core-flows.spec.ts playwright-tests/specs/auth-resilience.spec.ts playwright-tests/specs/rbac-pages.spec.ts playwright-tests/specs/rbac-management.spec.ts playwright-tests/specs/storage-provider-b2.spec.ts playwright-tests/specs/live-backend-smoke.spec.ts playwright-tests/specs/live-backend-rbac-management.spec.ts playwright-tests/specs/live-backend-message-runtime.spec.ts playwright-tests/specs/live-backend-data-cleanup.spec.ts --workers=1`

> 2026-04-10 最近一轮结果：`18 passed`

## Problem Frame
当前 `admin` 主体架构已经从旧 `views + router module + meta.roles` 模板式结构迁到了 feature-based 结构，但还有三类工作没有收口：

1. **Admin 自身还有遗留兼容层**：`src/api/*`、`meta.roles` fallback、legacy auth alias、开发期 mock 与旧模板残留仍在。
2. **Backend / Admin 合同链路还需补验证**：B2、bootstrap、message runtime、SQL 基线整理虽然已有代码，但还缺统一验收与文档闭环。
3. **当前分支存在大量跨模块脏改动**：需要把“当前主执行线”与“暂挂工作流”明确分开，避免后续继续推进时混线。

本计划从现在起作为 **当前分支的主执行文档**。后续默认沿本计划继续，不再反复口头确认。

## Scope Boundaries
- 当前主线优先完成 **admin / backend-admin / SQL / 测试闭环**，不主动把移动端、桌面端大规模改动混入同一批提交。
- 本轮不重写 Admin 技术栈，不切 React。
- 本轮不引入新的权限模型层级（如 page/action/tree permission schema）。
- `relay_only / e2ee` 的完整业务落地属于下一层工作；本轮先完成后台配置、后端约束、测试和文档闭环。

## 需求追踪

| 编号 | 需求 | 当前状态 |
| --- | --- | --- |
| R1 | Admin 采用更清晰的 feature-based / app-based 架构 | 部分完成，待清理兼容层 |
| R2 | RBAC 必须基于真实权限快照而不是静态角色判断 | 已完成 |
| R3 | 第一个超级管理员改为手动 bootstrap 初始化 | 已完成 |
| R4 | 对象存储切换并对齐 B2 配置与后台管理 | 基本完成，待合同验证与文档闭环 |
| R5 | SQL 迁移逻辑要整合，base.sql 与迁移目录要自洽 | 进行中 |
| R6 | 后续推进必须以可重复验证的测试证据为准 | 进行中 |

## 执行规则
- 后续默认只推进本计划中的 **Active Units**，不把其它脏改动顺手混进当前提交。
- 每完成一个 Unit，必须先跑对应验证，再提交。
- 若执行中发现新的跨模块需求，先补到本计划或 `docs/reports/task-list.md`，再继续。

## Implementation Units

### Unit 1: Backend RBAC 真实化
- **状态**: done
- **目标**: 后端 RBAC API、登录态快照、角色与权限分配全部走真实数据。
- **关键文件**:
  - `backend/src/handlers/auth.rs`
  - `backend/src/handlers/admin.rs`
  - `backend/src/database/models.rs`
  - `admin/src/features/access-control/`
- **验证**:
  - `admin/playwright-tests/specs/rbac-pages.spec.ts`
  - `admin/playwright-tests/specs/rbac-management.spec.ts`
  - `admin/playwright-tests/specs/live-backend-rbac-management.spec.ts`

### Unit 2: Admin 权限基础设施重构
- **状态**: done
- **目标**: 路由、菜单、守卫、按钮显隐统一基于权限快照。
- **关键文件**:
  - `admin/src/app/router/`
  - `admin/src/shared/access/`
  - `admin/src/store/modules/user/`
  - `admin/src/directive/permission/`
- **验证**:
  - `admin/playwright-tests/specs/core-flows.spec.ts`
  - `admin/playwright-tests/specs/auth-resilience.spec.ts`

### Unit 3: Admin 页面模块化迁移
- **状态**: done
- **目标**: settings / version / user-management / operations / dashboard / access-control 页面都从旧 `views` 迁到 `features/*`。
- **关键文件**:
  - `admin/src/features/**/pages/*.vue`
  - `admin/src/features/**/routes.ts`
- **验证**:
  - `admin/playwright-tests/specs/route-smoke.spec.ts`
  - `admin/playwright-tests/specs/core-flows.spec.ts`

### Unit 4: App shell / auth / http 收口
- **状态**: done
- **目标**: App Providers、Layouts、Router shell、Auth Runtime、HTTP client 已统一到 `app/` 与 `services/`。
- **关键文件**:
  - `admin/src/app/providers/`
  - `admin/src/app/layouts/`
  - `admin/src/services/auth.ts`
  - `admin/src/services/auth-runtime.ts`
  - `admin/src/services/http.ts`
- **验证**:
  - `cd admin && npm run type:check`
  - 关键 Playwright 回归 18 条

### Unit 5: Admin 领域服务继续收口
- **状态**: done
- **目标**: 把还停留在 `admin/src/api/*.ts` 的调用层按领域迁到 `admin/src/services/*`，让 `src/api` 退出主架构。
- **执行说明**: 先迁高频领域，再迁低频工具域，保持每次变更可独立验证。
- **关键文件**:
  - `admin/src/api/*.ts`
  - `admin/src/services/http.ts`
  - `admin/src/services/auth.ts`
  - `admin/src/features/access-control/pages/*.vue`
  - `admin/src/features/settings/pages/*.vue`
  - `admin/src/features/operations/pages/*.vue`
  - `admin/src/features/user-management/pages/*.vue`
  - `admin/src/features/version/pages/*.vue`
- **模式参考**:
  - 共享基础设施保留在 `admin/src/services/http.ts`
  - 认证留在 `admin/src/services/auth.ts`
  - 页面只直接依赖领域服务，不再依赖杂糅的 `src/api`
- **测试场景**:
  1. 迁移后所有页面请求仍命中统一的 token / refresh / interceptor 流程。
  2. RBAC、settings、storage-provider、user-management 页面可正常加载与保存。
  3. `auth-bootstrap`、`auth-resilience`、`storage-provider-b2` 不能回退。
- **验证**:
  - `cd admin && npm run type:check`
  - `admin/playwright-tests/specs/auth-bootstrap.spec.ts`
  - `admin/playwright-tests/specs/core-flows.spec.ts`
  - `admin/playwright-tests/specs/rbac-management.spec.ts`
  - `admin/playwright-tests/specs/storage-provider-b2.spec.ts`

### Unit 6: 删除兼容层与模板残留
- **状态**: done
- **目标**: 去掉 Admin 当前仍保留的 legacy compatibility，缩小维护面。
- **关键文件**:
  - `admin/src/shared/access/route-access.ts`
  - `admin/src/services/auth-runtime.ts`
  - `admin/src/mock/`
  - `admin/src/features/dashboard/workplace/mock.ts`
  - `admin/src/features/dashboard/monitor/mock.ts`
  - `admin/src/main.ts`
  - `admin/src/components/tab-bar/`
- **待处理项**:
  - 删除 `meta.roles` fallback，仅保留 `perm + superAdminOnly`
  - 删除 auth-runtime 里的 legacy alias export
  - 评估并清理 dashboard / message-box / user mock 是否仍有必要
  - 清掉空的 legacy 目录与无用说明文件
- **测试场景**:
  1. 路由访问控制只由新权限模型决定。
  2. 登录、刷新、退出、不登录跳转都不依赖 legacy auth alias。
  3. `npm run dev` 不因移除 mock 造成首页白屏。
- **验证**:
  - `cd admin && npm run type:check`
  - `admin/playwright-tests/specs/core-flows.spec.ts`
  - `admin/playwright-tests/specs/auth-resilience.spec.ts`
  - `admin/playwright-tests/specs/live-backend-smoke.spec.ts`

### Unit 7: B2 后台 / 后端合同闭环
- **状态**: done
- **目标**: 让 B2 的 Admin 表单、后端 provider 解析、文档与回归测试完全对齐。
- **关键文件**:
  - `admin/src/features/operations/components/storage-provider-form-modal.vue`
  - `admin/src/features/operations/helpers/storage-provider.ts`
  - `admin/playwright-tests/specs/storage-provider-b2.spec.ts`
  - `backend/src/storage/b2.rs`
  - `backend/src/storage/mod.rs`
  - `backend/src/handlers/admin.rs`
  - `docs/reference/api/api-overview.md`
  - `docs/reference/api/file-upload-hash.md`
- **测试场景**:
  1. B2 provider 新建/编辑时字段约束与默认文案一致。
  2. 编辑已有 provider 时 secret 不回填明文。
  3. 后端对 bucket / endpoint / provider_type 的校验与前台一致。
  4. 网络关闭模式下（如 `REDCODE_IM_STORAGE_DISABLE_NETWORK=1`）测试链路可重复执行。
- **验证**:
  - `admin/playwright-tests/specs/storage-provider-b2.spec.ts`
  - 后端对应 admin / storage 测试（新增到 `tests/go/` 或 `backend/tests/`）

### Unit 8: SQL 迁移体系整合
- **状态**: done
- **目标**: 把当前 SQL 基线、迁移目录、legacy 归档与校验脚本整理成自洽体系。
- **关键文件**:
  - `backend/sql/base.sql`
  - `backend/sql/migrations/`
  - `backend/sql/migrations/README.md`
  - `backend/sql/migrations_legacy_20260409/`
  - `backend/scripts/verify-base-sql.sh`
  - `backend/tests/database_migration_smoke.rs`
- **待处理项**:
  - 明确哪些迁移已经折叠进 `base.sql`
  - legacy 迁移目录只保留归档价值，不再让执行入口混淆
  - 校验脚本输出与 CI / 本地执行说明统一
- **测试场景**:
  1. 从 `base.sql` 初始化与从迁移链初始化结果一致。
  2. bootstrap admin 种子移除后，新库仍可通过运行时初始化首管。
  3. 旧迁移目录不会再被误当成主执行入口。
- **验证**:
  - `backend/scripts/verify-base-sql.sh`
  - `cargo test --test database_migration_smoke`

### Unit 9: Admin / Backend 合约测试补齐
- **状态**: done
- **目标**: 让当前分支的关键链路不只依赖 Playwright UI 证明，还要有后端合约层证明。
- **关键文件**:
  - `tests/go/`
  - `tests/run.sh`
  - `tests/README.md`
  - `admin/playwright-tests/specs/*.spec.ts`
- **优先补齐用例**:
  1. admin bootstrap
  2. RBAC role / permission / admin-user role assignment
  3. storage provider B2
  4. message runtime settings
- **验证**:
  - `./tests/run.sh`
  - `go test ./...`（`tests/go/` 下）

### Unit 10: Message runtime 全链路收口
- **状态**: transferred（已移交 U10 E2EE 专项承接，见 2026-08-04-002 的 U6/U7）
- **目标**: 当前后台已支持 `persist / relay_only` 与 `plaintext / e2ee` 配置，但客户端与全部消息链路还没有完全按模式降级。
- **关键文件**:
  - `backend/src/services/message_runtime.rs`
  - `backend/src/handlers/message.rs`
  - `backend/src/handlers/chat_history.rs`
  - `backend/src/handlers/message_search.rs`
  - `backend/src/handlers/message_read.rs`
  - `frontend/lib/core/services/message_service.dart`
  - `frontend/lib/core/services/room_service.dart`
  - `desktop/src/`
- **说明**: 这是下一层工作，先排队，不并入当前最小闭环。

## 当前剩余任务的执行顺序
1. 当前主线 Unit 1-9 已完成并完成验证。
2. Unit 10（message runtime 全链路收口）已移交 U10 E2EE 专项计划（2026-08-04-002 的 U6/U7）承接，本计划收口。
3. Unit 7：补完 B2 合同验证与 API 文档。
4. Unit 8：整理 SQL 迁移体系并跑一致性校验。
5. Unit 9：补 Go / backend 合约测试。
6. Unit 10：已移交 U10 E2EE 专项计划执行，见第 2 条。

## 完成判定
- Admin 不再依赖 `src/api` 作为主调用层。
- Admin 权限判断不再保留 `meta.roles` fallback。
- B2、bootstrap、RBAC、message runtime settings 都有可重复验证的测试入口。
- `backend/sql/base.sql`、`backend/sql/migrations/`、legacy 迁移目录职责清晰。
- 当前分支的后续推进能够直接以本计划为准，不再依赖零散对话上下文。
