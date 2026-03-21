# Backend Wave C（短信登录 / 头像上传）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成短信登录和用户头像上传两项 Go 黑盒契约补测并更新矩阵。

**Architecture:** 在 auth/users 两个测试域新增独立用例，复用 testutil；通过 external-mock 验证头像直传链路；完成后同步文档。

**Tech Stack:** Go 1.25、HTTP black-box tests、external-mock

---

### Task 1: 短信登录契约测试

**Files:**
- Create: `tests/go/backend/auth/sms_login_test.go`

**Steps:**
1. 写失败测试：验证码开关、错误验证码、通用验证码成功路径。
2. 运行：`cd tests/go && go test ./backend/auth -run TestSMSLogin_WithCaptchaSetting_OK -v`
3. 修正断言并通过。

### Task 2: 头像上传链路测试

**Files:**
- Create: `tests/go/backend/users/user_avatar_flow_test.go`

**Steps:**
1. 写失败测试：非法 key、direct-upload、commit、download 全链路。
2. 运行（隔离栈）：`docker-compose -f tests/docker-compose.yml run --rm go-tests`
3. 修正断言并通过。

### Task 3: 矩阵与报告

**Files:**
- Modify: `docs/reference/testing/matrix/backend.csv`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

**Steps:**
1. 更新 `BE-AUTH-003`、`BE-USER-004` 为 done。
2. 增补 Wave C 入口命令和执行结果。
3. 回归验证并提交推送。
