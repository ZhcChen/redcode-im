# Frontend 测试架构重建 Implementation Plan

> **For agentic workers:** REQUIRED WORKFLOW: Use `ce:work` to execute this plan task-by-task. If execution发现需求或范围变化，先回到 `ce:brainstorm` / `ce:plan` 更新文档；变更完成后使用 `ce:review` 审查。Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 基于 Frontend 功能分析补齐高价值单元测试与真机集成链路，并输出完整测试链路汇总。

**Architecture:** 采用“先设计后执行”的方式：先固化功能与测试链路，再按 TDD 为核心服务补齐单元测试，最后在真机执行集成链路验证并更新矩阵文档，保证结果可追溯。

**Tech Stack:** Flutter Test、Dart、integration_test、Android 真机（Pixel 8 Pro）

---

### Task 1: 补齐 TokenStorage 会话与损坏数据回收测试

**Files:**
- Create: `frontend/test/core/token_storage_test.dart`
- Modify: `frontend/lib/core/storage/token_storage.dart`

**Step 1: 写失败测试（Red）**
- 覆盖：
  - save/read session（含 refresh token）
  - updateUser 仅在 token 存在时更新
  - user JSON 损坏后会话清理（token/user/refresh_token 一并清理）

**Step 2: 运行测试确认失败（Red）**
- Run: `cd frontend && flutter test test/core/token_storage_test.dart`
- Expected: FAIL（当前损坏 JSON 仅清理 token/user）

**Step 3: 实现最小修复（Green）**
- 在 `readSession()` 异常分支同步清理 refresh token。

**Step 4: 运行测试确认通过（Green）**
- Run: `cd frontend && flutter test test/core/token_storage_test.dart`
- Expected: PASS

### Task 2: 补齐 AppConfigService 回退链路测试

**Files:**
- Create: `frontend/test/core/app_config_service_test.dart`

**Step 1: 写失败测试（Red）**
- 覆盖：
  - 内存缓存优先
  - SQLite（storage）优先于 API
  - API 刷新成功后写入 storage
  - API 异常时回退 storage

**Step 2: 运行测试确认失败（Red）**
- Run: `cd frontend && flutter test test/core/app_config_service_test.dart`
- Expected: FAIL（初始无测试桩）

**Step 3: 实现最小代码（Green）**
- 仅在测试中补 fake storage/service，不改生产逻辑。

**Step 4: 运行测试确认通过（Green）**
- Run: `cd frontend && flutter test test/core/app_config_service_test.dart`
- Expected: PASS

### Task 3: 补齐 VersionService 契约测试

**Files:**
- Create: `frontend/test/core/version_service_test.dart`

**Step 1: 写失败测试（Red）**
- 覆盖：
  - `checkLatest` query 参数拼装
  - `checkLatest` 在 `has_update=true 但 version 缺失` 时返回 false
  - `fetchDownloadUrl` 成功/失败分支

**Step 2: 运行测试确认失败（Red）**
- Run: `cd frontend && flutter test test/core/version_service_test.dart`
- Expected: FAIL（初始无测试代码）

**Step 3: 实现最小代码（Green）**
- 仅补测试代码与 mock client，不改业务实现。

**Step 4: 运行测试确认通过（Green）**
- Run: `cd frontend && flutter test test/core/version_service_test.dart`
- Expected: PASS

### Task 4: 执行 Frontend 全量单元与真机集成测试

**Files:**
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reference/testing/matrix/frontend.csv`
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

**Step 1: 运行 Frontend 全量单元测试**
- Run: `cd frontend && flutter test`
- Expected: PASS

**Step 2: 运行真机 smoke**
- Run:
  - `LAN_IP=$(ipconfig getifaddr en0)`
  - `cd frontend && flutter test integration_test/smoke_test.dart -d 3A091FDJG001DN --dart-define=API_BASE_URL=http://${LAN_IP}:8010 --dart-define=WS_URL=ws://${LAN_IP}:8010/ws`
- Expected: PASS

**Step 3: 运行真机网络连通测试**
- Run:
  - `LAN_IP=$(ipconfig getifaddr en0)`
  - `cd frontend && flutter test integration_test/network_connectivity_test.dart -d 3A091FDJG001DN --dart-define=API_BASE_URL=http://${LAN_IP}:8010 --dart-define=WS_URL=ws://${LAN_IP}:8010/ws --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true`
- Expected: PASS

**Step 4: 更新文档与矩阵**
- 写入新增测试链路、命令、结果与验收口径。

### Task 5: 提交与推送

**Step 1: 本轮变更检查**
- Run: `git status --short`

**Step 2: 提交**
```bash
git add frontend/test/core/token_storage_test.dart frontend/test/core/app_config_service_test.dart frontend/test/core/version_service_test.dart frontend/lib/core/storage/token_storage.dart docs/plans/2026-03-05-frontend-test-architecture-design.md docs/plans/2026-03-05-frontend-test-architecture-plan.md docs/reference/testing/README.md docs/reference/testing/matrix/frontend.csv docs/reports/2026-03-04-full-module-regression-acceptance.md
git commit -m "test(frontend): 补齐核心服务测试并完成真机链路回归"
```

**Step 3: 推送**
- Run: `git push`
