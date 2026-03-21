# Backend Wave B（消息搜索 / 系统设置）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成消息搜索与管理设置两项 Go 黑盒契约补测并更新矩阵。

**Architecture:** 在 messages/admin 两个测试域新增独立 spec，复用已有 testutil 登录/建房流程；完成后更新文档与报告。

**Tech Stack:** Go 1.25、HTTP black-box tests

---

### Task 1: 消息搜索契约测试

**Files:**
- Create: `tests/go/backend/messages/message_search_test.go`

**Steps:**
1. 写失败测试：成员隔离、`limit/has_more`、空查询校验。
2. 运行：`cd tests/go && go test ./backend/messages -run TestMessageSearch_MembershipIsolationAndValidation_OK -v`
3. 调整断言并通过。

### Task 2: 管理设置契约测试

**Files:**
- Create: `tests/go/backend/admin/admin_settings_test.go`

**Steps:**
1. 写失败测试：管理员更新校验、读取上传策略、非管理员403。
2. 运行：`cd tests/go && go test ./backend/admin -run 'TestAdminSettings_(UserAccountLimitAndUploadPolicy_OK|NonAdminShouldBeForbidden)$' -v`
3. 调整断言并通过。

### Task 3: 矩阵与报告

**Files:**
- Modify: `docs/reference/testing/matrix/backend.csv`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

**Steps:**
1. 更新 `BE-MSG-005`、`BE-ADM-004` 为 done。
2. 补充 Wave B 执行命令与结果记录。
3. 执行定向回归并写入报告。
