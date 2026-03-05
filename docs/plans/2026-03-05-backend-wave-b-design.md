# Backend Wave B（消息搜索 / 系统设置）测试设计

**日期**: 2026-03-05  
**范围**: `tests/go/backend/messages`、`tests/go/backend/admin`

## 1. 目标

补齐 Backend 剩余 TODO 的第二批：

1. `BE-MSG-005`：`/messages/search` 搜索契约与权限隔离。
2. `BE-ADM-004`：`/api/admin/settings/*` 管理设置链路与鉴权。

## 2. 策略

- 测试类型：Go 黑盒契约测试。
- 重点覆盖：
  - 搜索接口按房间成员关系过滤（越权不可见）。
  - 搜索分页基础行为（`limit/has_more`）。
  - 管理设置接口的输入校验与管理员权限边界。

## 3. 用例设计

### 3.1 messages/search

- 构造 A-B 与 A-C 两个房间，写入相同关键词消息。
- B 搜索关键词时仅能看到 A-B 房间消息，`total_results` 与 `room_id` 不越权。
- 使用 `limit=1` 时验证 `has_more=true`。
- 空查询（空白字符串）返回 400 + 校验错误码。

### 3.2 admin/settings

- 管理员获取 `user-account-limit` 成功。
- 管理员提交“所有规则都关闭”返回 400。
- 管理员回写当前有效配置成功（契约稳定）。
- 管理员读取 `upload-policy` 成功，关键字段非空。
- 普通用户访问 `api/admin/settings/*` 返回 403。

## 4. 验收标准

1. 两组测试全部通过。
2. `backend.csv` 对应两条从 `todo` 变更为 `done`。
3. 测试指南与回归报告同步更新。
