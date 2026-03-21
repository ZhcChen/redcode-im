# Backend 成本与生命周期清理链路测试设计

**日期**: 2026-03-05
**范围**: `backend` + `tests/go`

## 1. 背景与目标

围绕“降低部署成本”的关键清理链路，补齐可执行测试，避免清理策略回归导致存储与日志无限增长：

1. 管理端手动清理接口（系统日志 / push 日志）要有明确契约校验。
2. 文件上传对象清理配置要可通过环境变量稳定控制（支持 2 天策略）。
3. 后台日志清理配置要对非法值安全降级，避免误配置带来过清理或失效清理。
4. push 队列清理配置需要边界验证（保留天数、批次参数）。

## 2. 测试策略

### 2.1 Go 黑盒契约（API 层）

新增 `tests/go/backend/admin/admin_cleanup_contract_test.go`，覆盖：

- `POST /api/admin/logs/cleanup`
  - `retentionDays=2`：200 + `success/deletedCount/message` 响应契约。
  - `retentionDays=0`：400 + 统一错误结构（code/message）。
- `POST /api/admin/push/logs/cleanup`
  - 同上两类场景。

### 2.2 Rust 单元测试（配置层）

补充以下模块的配置解析/边界测试：

- `backend/src/services/file_upload_cleanup.rs`
  - `from_env` 正常读取 2 天配置（`172800` 秒）
  - 非法值（空串/负数/0/非数字）回退默认值
- `backend/src/logging/writer.rs`
  - `from_env` 对非法值回退默认值（并约束 >0）
- `backend/src/services/push.rs`
  - `PushDbQueueCleanupConfig::from_env` 的 clamp 边界行为

## 3. 验收标准

1. 新增 Go 黑盒测试通过，且不影响现有 admin 契约测试。
2. 新增 Rust 单测通过，覆盖“2 天保留”与“非法值回退”关键分支。
3. 文档追踪同步：
   - `docs/reference/testing/matrix/backend.csv`
   - `docs/reference/testing/matrix/admin.csv`
   - `docs/reference/testing/README.md`
   - `docs/reports/2026-03-04-full-module-regression-acceptance.md`
4. 结果可复现：给出精确执行命令与通过统计。
