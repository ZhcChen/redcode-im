---
title: "feat: U10 E2EE U6 Admin prepare/active 门禁执行计划"
date: 2026-08-05
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
execution: code
status: superseded
superseded_by: docs/plans/2026-08-05-u10-e2ee-native-clients-final-closure-plan.md
---

# feat: U10 E2EE U6 Admin prepare/active 门禁执行计划

> 本计划的 Admin/API 实施单元已完成；全仓门禁与最终发布裁决由
> `docs/plans/2026-08-05-u10-e2ee-native-clients-final-closure-plan.md` 的 C7/C8
> 承接。本文仅保留设计与历史证据，不再作为 active 执行入口。

## Goal Capsule

- **目标：** 实现 R12/R13 的 Admin E2EE 启用门禁：`plaintext -> prepare -> active`
  状态机，prepare 返回最低客户端版本、活跃设备覆盖、KeyPackage 库存与阻断
  原因；active 重新校验并原子切换；rollback 原子回滚，历史密文保持可读。
- **前置状态：** U5 已完成（`docs/reviews/2026-08-05-u10-e2ee-u5-attachment-boundary.md`）；
  服务端已有 E2EE 设备、KeyPackage 库存、房间 epoch 与 runtime 模式。
- **发布约束：** U6 通过前只允许测试环境 prepare；生产 E2EE No-Go，runtime
  保持 `persist/plaintext`。

## 关键设计决策

- K1. **设备能力由服务端持久化。** 认证设备注册时上报 `client_platform` /
  `client_version` / `client_build`（可空兼容存量设备），readiness 按服务端
  `min_client_versions` 规则计算版本达标覆盖，不采信一次性布尔值。
- K2. **prepare 是状态不是设置开关。** `e2ee_runtime_gate` 单行表保存
  `state`（plaintext/prepare/active）、readiness revision 与最近预检时间；
  active 时重新计算 readiness，任一阻断原因存在即拒绝，不能由 UI 分步拼装。
- K3. **active/rollback 原子化。** 每次 active 在单事务内完成门禁校验与
  `content_audit_mode=e2ee` 写入；rollback 单事务切回 plaintext，不清历史
  密文；E2EE 模式下普通明文发送接口继续 fail closed。
- K4. **Admin 不能绕过 readiness。** 原 message-runtime 直接 PUT `e2ee` 拒绝，
  只能走 prepare/active；安全审查标记默认 false 阻断 active，U7 前由审查流程
  显式批准，测试通过 DB 直改验证。
- K5. **兼容增量。** 设备注册新增字段可空，现有客户端与测试夹具不传时仍可
  注册；readiness 将无能力字段的 active 设备计为不达标，倒逼客户端上报。

## Implementation Units

### U6-A. 数据库与设备能力

- `api/sql/migrations/20260805120000_e2ee_runtime_admin_gate.sql`：`e2ee_devices`
  增加 platform/version/build；新增单行 `e2ee_runtime_gate`（state、readiness
  revision/computed_at、min_client_versions、覆盖率阈值、库存低水位、
  security_review_approved）。
- `api/src/database/mod.rs` MIGRATIONS 追加条目。
- `api/src/database/e2ee_runtime_store.rs`：gate 表读写、active 设备能力统计、
  每设备库存统计。
- `api/src/handlers/e2ee.rs` / `e2ee_mls_store.rs`：注册设备接受可空能力字段。

### U6-B. 门禁服务与 API

- `api/src/services/e2ee_runtime_gate.rs`：版本比较、readiness 计算、prepare /
  active / rollback 原子流转。
- `api/src/handlers/settings.rs` + `routes.rs`：
  `GET/POST /api/admin/settings/message-runtime/e2ee/gate|prepare|active|rollback`；
  原 PUT message-runtime 直接切 `e2ee` 拒绝。

### U6-C. 客户端与 Admin

- `h5-app/src/services/e2ee-mls-api-service.ts`：注册设备上报
  `detectReleasePlatform()` + `appVersion` + build。
- `admin/src/services/general-settings.ts` + `general-settings-page.vue`：门禁
  状态卡片、预检/启用/回滚按钮与阻断原因展示。

### U6-D. 测试与文档

- `api/tests/admin_e2ee_gate_integration.rs`：无设备/低版本/库存不足/待批准/
  安全审查未通过时 active 拒绝；prepare 后新增不达标设备 active 重新校验拒绝；
  成功 active；旧客户端明文发送拒绝；rollback 后历史密文可读。
- 单元测试：版本比较、readiness 计算、直接 PUT e2ee 拒绝。
- `docs/reference/api/e2ee.md` 补 Admin 门禁章节；计划与验收记录同步。

## Definition of Done

- D1. prepare 返回最低版本、设备覆盖、库存与阻断原因；任一条件不满足 active
  返回明确阻断。
- D2. active/rollback 原子化；E2EE 模式普通明文发送拒绝；历史密文回滚后仍可读。
- D3. Admin 无法直接 PUT e2ee 绕过门禁。
- D4. `make api.test`、H5 类型检查/单元、Admin type-check 全通过；U6 保持
  partial（生产 No-Go，U7 独立安全审查前不得生产启用）。

## 执行状态（2026-08-05）

- U6-A（数据库与设备能力）：完成。migration
  `20260805120000_e2ee_runtime_admin_gate.sql` 已注册；设备注册接受可空
  platform/version/build，H5 已上报。
- U6-B（门禁服务与 API）：完成。`e2ee_runtime_gate` 服务提供 prepare/active/
  rollback 原子流转；直接 PUT `e2ee` 返回 409。
- U6-C（客户端与 Admin）：完成。H5 注册上报能力；Admin 门禁卡片展示状态、
  readiness、阻断原因与预检/启用/回滚按钮。
- U6-D（测试与文档）：API 全量 `make api.test` 通过（新增 admin gate 集成测试
  4 项），H5 261 通过/8 跳过，Admin type-check + 生产构建通过；验收记录见
  `docs/reviews/2026-08-05-u10-e2ee-u6-admin-gate.md`。
- U6 保持 `partial`：安全审查默认 false 阻断 active，U7 独立安全审查前不得
  生产启用；测试环境可 prepare。
