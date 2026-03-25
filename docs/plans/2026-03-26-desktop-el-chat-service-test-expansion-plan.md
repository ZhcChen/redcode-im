# Desktop EL Chat Service Test Expansion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 `desktop-el` 的 Go core `chat` service 补齐一组独立契约测试，覆盖群设置与附件上传/下载相关方法的路径、query 和可选字段裁剪行为。

**Architecture:** 保持现有 `chat.Service` 结构不变，只补 `httptest.Server` 驱动的 service-level 测试，不改 renderer 或 Electron。若测试暴露真实边界问题，只做最小修复，避免在测试扩充阶段顺带重构超大 `service.go`。

**Tech Stack:** Go 1.25、testing、httptest、httpclient、chat service

---

### Task 1: 先为群设置与附件链路写 service 测试

**Files:**
- Create: `desktop-el/go-core/internal/chat/service_test.go`

- [x] **Step 1: 写群设置相关测试**

覆盖：
- `UpdateGroupGlobalMute` 只在有值时发送 `reason` / `duration_minutes`
- `UpdateGroupSettings` 只透传非 nil 的设置字段

- [x] **Step 2: 写附件链路相关测试**

覆盖：
- `GetAttachmentDownloadURL` 正确透传 `key` 和可选 `expires_in_seconds`
- `RequestAttachmentSignature` / `InitiateAttachmentMultipartUpload` 只发送非空可选字段
- `GenerateMultipartPartSignature` / `CommitMultipartPart` / `CompleteMultipartUpload` / `AbortMultipartUpload` / `CommitAttachmentUpload` 命中正确路径、方法和 body

- [x] **Step 3: 运行定向测试**

Run: `cd desktop-el/go-core && go test ./internal/chat -count=1`
Expected: PASS，若发现真实边界问题则进入最小修复。

### Task 2: 完整验证、回填 backlog、提交推送与清理

**Files:**
- Modify: `docs/plans/2026-03-24-desktop-el-migration-backlog.md`
- Modify: `docs/plans/2026-03-26-desktop-el-chat-service-test-expansion-plan.md`

- [x] **Step 1: 回填 backlog**

实现点：
- 在 `P2-3` 当前进度中记录 `chat service` 群设置与附件链路测试覆盖扩充

- [x] **Step 2: 运行完整验证**

Run: `cd desktop-el/go-core && go test ./...`
Expected: PASS

Run: `make desktop-el-verify`
Expected: PASS

- [x] **Step 3: 提交、推送与清理**

```bash
git add docs/plans/2026-03-24-desktop-el-migration-backlog.md \
  docs/plans/2026-03-26-desktop-el-chat-service-test-expansion-plan.md \
  desktop-el/go-core/internal/chat/service_test.go
git commit -m "test(desktop-el): cover chat service contracts"
git push
make desktop-el-down
pgrep -fl "desktop-el|electron|go-core" || true
```
