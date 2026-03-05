# Backend Wave A（readyz / 改密 / 未读计数）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成 readyz、修改密码、未读计数三项 Go 黑盒契约测试并落矩阵。

**Architecture:** 在现有 tests/go 分层中补充 3 个独立测试文件，复用 testutil；完成后同步矩阵与报告，并跑定向回归。

**Tech Stack:** Go 1.25、HTTP black-box tests

---

### Task 1: Readyz 契约测试

**Files:**
- Create: `tests/go/backend/system/readyz_test.go`

**Steps:**
1. 写失败测试：校验 `status/checks/latencyMs`。
2. 运行：`cd tests/go && go test ./backend/system -run TestReadyz_OK -v`
3. 修正断言并确保通过。

### Task 2: 改密链路测试

**Files:**
- Create: `tests/go/backend/users/user_password_test.go`

**Steps:**
1. 写失败测试：错误旧密码 -> 400；正确改密后旧密码失败/新密码成功。
2. 运行：`cd tests/go && go test ./backend/users -run TestChangePassword_WrongOldThenSuccess -v`
3. 修正断言并确保通过。

### Task 3: 未读计数链路测试

**Files:**
- Create: `tests/go/backend/messages/unread_counts_test.go`

**Steps:**
1. 写失败测试：2 条未读 -> read_until -> 0。
2. 运行：`cd tests/go && go test ./backend/messages -run TestUnreadCounts_MultiMessageReadUntil_OK -v`
3. 修正断言并确保通过。

### Task 4: 文档与矩阵

**Files:**
- Modify: `docs/reference/testing/matrix/backend.csv`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

**Steps:**
1. 更新状态为 done。
2. 补执行命令与结果。
3. 回归执行并记录。
