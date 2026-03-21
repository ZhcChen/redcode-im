# Backend Wave D（分片上传 / 审核队列 / Push 发送）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成 Backend 最后 3 项待办能力的 Go 黑盒契约补测并更新测试矩阵到全量 done。

**Architecture:** 在 uploads/push 业务域新增独立黑盒用例，复用现有 testutil 与 external-mock。对涉及后台异步任务（审核、push）采用有上限轮询，确保结果可验证且避免脆弱的固定 sleep。

**Tech Stack:** Go 1.25、HTTP black-box tests、Docker Compose 隔离栈、external-mock（COS/CI/FCM）

---

### Task 1: 分片上传完整流程契约（BE-UPL-002）

**Files:**
- Create: `tests/go/backend/uploads/multipart_flow_test.go`

**Steps:**
1. 写失败测试：`initiate -> session -> per-part signature/upload/commit -> complete -> attachment commit/send/download` 全链路。
2. 运行：`cd tests/go && go test ./backend/uploads -run TestMessageAttachmentMultipartUploadAndDownload_OK -v`。
3. 修正断言与流程细节直到通过。

### Task 2: 上传审核链路契约（BE-UPL-003）

**Files:**
- Create: `tests/go/backend/uploads/file_audit_flow_test.go`

**Steps:**
1. 写失败测试：`admin test upload -> audit tasks list/detail -> rejected status -> requeue -> object exists check`。
2. 运行：`cd tests/go && go test ./backend/uploads -run TestFileUploadAuditTaskLifecycle_WithViolationMock -v`。
3. 对异步审核场景增加可复用轮询 helper 并稳定通过。

### Task 3: Push 设备注册与发送链路（BE-PUSH-001）

**Files:**
- Create: `tests/go/backend/push/push_device_flow_test.go`

**Steps:**
1. 写失败测试：配置 push + FCM、注册设备、发送消息触发 push、查询 push logs、注销设备。
2. 运行：`cd tests/go && go test ./backend/push -run TestPushDeviceRegisterSendAndUnregister_OK -v`。
3. 修正鉴权/配置/轮询细节直到通过。

### Task 4: 全量回归与文档矩阵同步

**Files:**
- Modify: `docs/reference/testing/matrix/backend.csv`
- Modify: `docs/reference/testing/README.md`
- Modify: `docs/reports/2026-03-04-full-module-regression-acceptance.md`

**Steps:**
1. 隔离栈执行全量 Go 套件：
   - `cd tests && COMPOSE_PROJECT_NAME=redcode_im_tests_local docker-compose -f docker-compose.yml up -d external-mock postgres redis-session redis-cache backend`
   - `cd tests && COMPOSE_PROJECT_NAME=redcode_im_tests_local docker-compose -f docker-compose.yml run --rm go-tests`
   - `cd tests && COMPOSE_PROJECT_NAME=redcode_im_tests_local docker-compose -f docker-compose.yml down -v --remove-orphans`
2. 更新 Wave D 状态、命令入口与执行结果。
3. 提交并推送：`test(backend): 覆盖分片上传审核与推送链路`。
