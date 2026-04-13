# Backend Wave D（分片上传 / 审核队列 / Push 发送）测试设计

**日期**: 2026-03-05  
**范围**: `tests/go/backend/uploads`、`tests/go/backend/push`

## 1. 目标

完成 Backend 矩阵剩余 3 项 TODO：

1. `BE-UPL-002`：分片上传完整流程 `/multipart/*`。
2. `BE-UPL-003`：上传审核流程 `/file-audit/*`（管理员审核任务接口 + CI 模拟链路）。
3. `BE-PUSH-001`：设备注册与推送发送 `/push/devices + push service`。

## 2. 测试策略

- 测试类型：Go 黑盒契约（对外 HTTP API + 后台异步任务结果）。
- 执行环境：隔离测试栈 `tests/docker-compose.yml`（含 external-mock / postgres / redis / backend）。
- 依赖模拟：
  - B2 / S3 兼容对象存储：`tests/mocks/external`。
  - FCM 发送：`tests/mocks/external/fcm/*`。

## 3. 用例设计

### 3.1 BE-UPL-002 分片上传完整流程

用例：`TestMessageAttachmentMultipartUploadAndDownload_OK`

覆盖链路：
- 用户创建房间并发起 `POST /rooms/{room_id}/messages/attachments/multipart/initiate`。
- 获取会话详情 `GET /uploads/multipart/sessions/{session_id}`。
- 逐片执行：
  - `POST /uploads/multipart/sessions/{session_id}/parts/signature`
  - 直传 external-mock（PUT）
  - `POST /uploads/multipart/sessions/{session_id}/parts/commit`
- `POST /uploads/multipart/sessions/{session_id}/complete` 完成合并。
- `POST /rooms/{room_id}/messages/attachments/commit` + 发消息 + 下载 URL 回读校验。

验收重点：
- 会话、分片、合并状态契约正确。
- 下载内容与上传原始内容一致。

### 3.2 BE-UPL-003 上传审核流程

用例：`TestFileUploadAuditTaskLifecycle_WithViolationMock`

覆盖链路：
- 管理员通过 `POST /api/admin/storage-providers/test/upload` 上传测试对象（key 含 `violation`，触发 external-mock 审核违规结果）。
- 轮询 `GET /api/admin/file-upload-audit/tasks` 获取任务状态推进。
- `GET /api/admin/file-upload-audit/tasks/{task_id}` 校验详情（`vendor_job_id`、`rejected_reason`、`result`）。
- `POST /api/admin/file-upload-audit/tasks/{task_id}/requeue` 校验可重新入队。
- `POST /api/admin/storage-providers/test/exists` 校验违规对象已被删除。

验收重点：
- 审核任务从待处理推进到违规拒绝（含原因）。
- 审核运维接口 list/detail/requeue 契约稳定。

### 3.3 BE-PUSH-001 设备注册与推送发送

用例：`TestPushDeviceRegisterSendAndUnregister_OK`

覆盖链路：
- 管理员配置并启用 push：
  - `PUT /api/admin/settings/push`
  - `PUT /api/admin/settings/push/providers/fcm`
- 目标用户注册设备 `POST /push/devices`。
- 构造房间消息触发 push 异步发送（message push job）。
- 管理员轮询 `GET /api/admin/push/logs` 校验对应设备 push 日志落库且成功。
- 目标用户注销设备 `DELETE /push/devices/{device_id}`。

验收重点：
- 设备注册/注销契约正确。
- push service 经 external-mock FCM 实际完成发送并形成可查询日志。

## 4. 验收标准

1. 三项用例在隔离栈稳定通过（包含异步轮询等待）。
2. `backend.csv` 中 `BE-UPL-002`、`BE-UPL-003`、`BE-PUSH-001` 均更新为 `done`。
3. `docs/reference/testing/README.md` 与回归报告新增 Wave D 执行入口与结果记录。
