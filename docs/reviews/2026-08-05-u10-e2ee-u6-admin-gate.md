---
title: U10 E2EE U6 Admin prepare/active 门禁验收
date: 2026-08-05
status: partial
scope: api,h5-app,admin
---

# U10 E2EE U6 Admin prepare/active 门禁验收

## 结论

U6 已形成自动化闭环：`plaintext -> prepare -> active` 门禁由服务端原子裁决，
prepare 返回最低客户端版本、活跃设备覆盖、KeyPackage 库存与阻断原因；active
基于最新设备与库存重新计算 readiness，任一阻断存在即返回 409；active/rollback
在单事务内同步门禁状态与 `content_audit_mode`。Admin 不能直接 PUT `e2ee` 绕过
门禁，回滚只影响新发送，历史密文与设备/库存数据保留。H5 设备注册开始上报
平台/版本/构建号，Admin 页面可查看门禁状态、阻断原因并执行预检/启用/回滚。

安全审查默认 false 阻断 active（U7 独立安全审查前不得生产启用），因此 U6
保持 `partial`，生产 E2EE 继续 No-Go，runtime 保持 `persist/plaintext`。

## 直接证据

| 门禁 | 证据 | 结果 |
| --- | --- | --- |
| 无设备阻断 | `api/tests/admin_e2ee_gate_integration.rs` | 初始 GET gate 阻断「没有已激活的 E2EE 设备」「安全审查未通过」 |
| prepare 不切换模式 | 同文件 | prepare 后 `state=prepare`、`content_audit_mode=plaintext` |
| 未通过 readiness 禁止 active | 同文件 | active 返回 409 且 message 含「readiness 未通过」 |
| 达标后 active | 同文件 | 2 台达标设备 + 库存 12 + 安全审查通过 → active 成功、`content_audit_mode=e2ee` |
| 旧客户端明文发送拒绝 | 同文件 | active 后普通消息接口返回 409「后台已开启加密发送」 |
| 回滚原子 | 同文件 | rollback 后 `state=plaintext`、明文发送恢复 |
| active 重新校验 | 同文件 | prepare 后新增 0.0.9 设备 → active 409「设备覆盖不足」；升级版本后成功 |
| 直接 PUT 拒绝 | 同文件 + `admin_integration.rs` | PUT `content_audit_mode=e2ee` 返回 409「只能通过门禁预检」 |
| 待批准设备阻断 | 同文件 | `pending_approval_devices=1`、ready=false、阻断原因含「待批准设备」 |
| 库存低水位阻断 | 同文件 | 库存 3 < 10 → `low_inventory_devices=1`、ready=false |
| 版本比较 | `e2ee_runtime_gate.rs` 单元测试 | 0.1.0=0.1、0.2.0>0.1.9、非数字段低于任何数字 |
| 迁移链 | `api/tests/database_migration_smoke.rs` | 空库迁移与显式 adopt 均通过，migration 数 11 |
| API 全量回归 | `make api.test`（rust-tests 容器） | unit 184 + 全部 integration 通过 |
| H5 能力上报 | `h5-app/test/e2ee-mls-api-service.test.ts` | 注册请求含 `client_platform=h5`、`client_version`、`client_build=web` |
| H5 全量回归 | `vue-tsc --noEmit` + vitest | 261 通过 / 8 跳过 |
| Admin | `vue-tsc --noEmit --skipLibCheck` + `bun run build` | 类型检查与生产构建通过 |

## 实现边界

- 门禁单行表 `e2ee_runtime_gate`：state、readiness revision/computed_at、
  min_client_versions（JSONB，默认各平台 0.1.0）、覆盖率阈值 100%、KeyPackage
  低水位 10、`security_review_approved`（默认 false）。
- 设备注册新增可空 `client_platform`（android/ios/h5/desktop）、
  `client_version`、`client_build`；存量客户端不传仍可注册，readiness 将无能力
  字段的 active 设备判为不达标。
- active 不信任旧预检：每次都基于最新设备与库存重新计算并原子写入
  `e2ee_runtime_gate` 与 `general_settings`（单事务）。
- rollback 只改发送模式，不删除密文、设备或 KeyPackage 数据；支持 E2EE 的
  客户端仍可读取历史密文。
- 原 `PUT /api/admin/settings/message-runtime` 直接切 `e2ee` 返回 409；U5 的
  `e2ee_runtime_boundary` 与 `websocket_integration` 测试改为直接写 runtime，
  门禁行为由 U6 测试独立覆盖。
- `e2ee_runtime_gate.updated_by` 不设外键：Admin 操作者记录在 `admin_users`，
  普通用户记录在 `users`，不强制单一引用。

## 环境说明

- API 测试在 `tests/docker-compose.test.yml` 的 rust-tests 容器内执行，未映射
  PG/Redis 宿主端口。
- 未切换 E2EE runtime；`persist/plaintext` 保持不变；本单元不涉及 live 联调。
- U7 独立安全审查批准前，测试环境仅允许 prepare，生产保持 No-Go。
