# Desktop EL Go Service Test Expansion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的 Go core 补齐 `user` / `friend` / `settings` service 的独立测试，并修复 `user.UpdateMe` 在成功空数据响应下污染当前用户快照的边界问题。

**Architecture:** 保持现有 Go core service 结构不变，继续通过 `httptest.Server` 覆盖请求路径、方法、query/body 和 session 副作用。`user.UpdateMe` 的修复只做最小保护，不改变正常成功响应下的 session 更新路径。

**Tech Stack:** Go 1.25、testing、httptest、httpclient、session service

---

### Task 1: 先用 user service 测试钉住 session 污染边界

**Files:**
- Create: `desktop-el/go-core/internal/user/service_test.go`
- Modify: `desktop-el/go-core/internal/user/service.go`

- [x] **Step 1: 先写失败测试**

覆盖：
- `UpdateMe` 成功且返回用户数据时会更新当前用户快照
- `UpdateMe` 成功但 `data = null` 时不会清空既有当前用户
- `SearchUsers` 会正确透传 `keyword` 与 `limit`

- [x] **Step 2: 运行定向测试确认先失败**

Run: `cd desktop-el/go-core && go test ./internal/user -run TestServiceUpdateMePreservesCurrentUserWhenResponseDataIsNull -count=1`
Expected: FAIL，当前实现会把 session current user 清成零值。

- [x] **Step 3: 写最小修复**

实现点：
- 仅在 `UpdateMe` 成功且解码出有效用户 ID 时更新 session current user

- [x] **Step 4: 回跑 user 包测试**

Run: `cd desktop-el/go-core && go test ./internal/user -count=1`
Expected: PASS

### Task 2: 补 friend / settings service 契约测试

**Files:**
- Create: `desktop-el/go-core/internal/friend/service_test.go`
- Create: `desktop-el/go-core/internal/settings/service_test.go`

- [x] **Step 1: 为 friend service 补测试**

覆盖：
- `ListFriendRequests` 正确透传 query
- `CreateFriendRequest` 正确透传请求体
- `UpdateFriendRemark` 与 `DeleteFriend` 正确命中路径与方法

- [x] **Step 2: 为 settings service 补测试**

覆盖：
- 各设置接口命中正确路径
- `InjectToken` 被显式关闭

- [x] **Step 3: 运行定向测试**

Run: `cd desktop-el/go-core && go test ./internal/friend ./internal/settings -count=1`
Expected: PASS

### Task 3: 完整验证、回填 backlog、提交推送与清理

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-go-service-test-expansion-plan.md`

- [x] **Step 1: 回填 backlog**

实现点：
- 在 `P2-3` 当前进度中记录 `user` / `friend` / `settings` service 测试覆盖扩充

- [x] **Step 2: 运行完整验证**

Run: `cd desktop-el/go-core && go test ./...`
Expected: PASS

Run: `make desktop-el-verify`
Expected: PASS

- [x] **Step 3: 提交、推送与清理**

```bash
git add docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-26-desktop-el-go-service-test-expansion-plan.md \
  desktop-el/go-core/internal/user/service.go \
  desktop-el/go-core/internal/user/service_test.go \
  desktop-el/go-core/internal/friend/service_test.go \
  desktop-el/go-core/internal/settings/service_test.go
git commit -m "test(desktop-el): expand go service coverage"
git push
make desktop-el-down
pgrep -fl "desktop-el|electron|go-core" || true
```
