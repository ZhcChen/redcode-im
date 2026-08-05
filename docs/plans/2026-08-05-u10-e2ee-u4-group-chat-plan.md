---
title: "feat: U10 E2EE U4 群聊与成员变化 rekey 执行计划"
date: 2026-08-05
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
execution: code
status: superseded
---

# feat: U10 E2EE U4 群聊与成员变化 rekey 执行计划

## Goal Capsule

- **目标：** 在 U3 多设备批准/撤销与 rekey 机制之上，把单聊协调器泛化为房间级
  协调：三成员群互发、邀请、退出、管理员移除、并发变化与 Commit 补拉，均保持
  fail closed，旧成员不能解密新内容，新成员不能读取加入前历史。
- **前置状态：** U3 已完成（`docs/reviews/2026-08-05-u10-e2ee-u3-multi-device.md`）：
  API 具备 revision 触发器与 epoch 门禁，共享核心具备 add/remove/join/process
  Commit，H5 具备 pending operation 与 rekey 竞争回滚。
- **权威顺序：** 运行时与跨端验收 > API/数据库/WS 捕获 > 自动化测试 > 本计划 >
  `docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md`。
- **当前状态：** 本细化计划已执行完成并标记 superseded；证据见
  `docs/reviews/2026-08-05-u10-e2ee-u4-group-chat.md`（partial：原生端 E2EE
  专项未落地，生产 No-Go）。
- **发布约束：** 原生双端 E2EE 专项未落地前 U4 保持 partial；生产 E2EE No-Go，
  runtime 保持 `persist/plaintext`。

## 关键设计决策

- K1. **设备 identity = `${userId}/${deviceId}`**，作为 MLS leaf 的唯一身份；群成员
  变化统一映射为 leaf 集合变化，复用 U3 的 `removeMember` 与 rekey pending 机制，
  不维护第二套成员变化逻辑。
- K2. **房间成员设备集合由服务端提供。** 新增
  `GET /rooms/{room_id}/e2ee/members`（仅房间成员可访问），返回当前成员及其
  active 设备；客户端以此集合与本地 group leaf 集合做差集，决定 add/remove，
  避免复用仅好友可见的 identities 端点。
- K3. **共享核心新增成员列表能力。** `LIST_MEMBERS` 命令返回当前 group 各 leaf 的
  identity，客户端才能计算差集并泛化 rekey。
- K4. **rekey 泛化为 reconcile。** `rekey_required` 时执行一次收敛：
  removed/revoked 设备 → `removeMember`；新增成员设备 → claim KeyPackage +
  `addMember`；commit 与 welcome 按“先 commit 推进 epoch，再提交同 epoch
  welcome”的顺序提交，冲突且服务端 epoch 已前进时回滚 previousState 重新收敛。
- K5. **群聊身份信任沿用 TOFU/变化阻断。** 发送前对房间全部成员
  `fetchRootIdentity` + `observe` + `requireTrusted`，任一成员身份变化即拒绝发送。

## Implementation Units

### U4-A. 共享核心成员列表

- `e2ee-core/src/session.rs`：`list_members(group_id)` 返回全部 leaf 的 identity。
- `e2ee-core/src/command.rs`：`LIST_MEMBERS = 12`；`lib.rs` 导出。
- 测试：三成员 add 后列表一致；remove 后列表收敛；未知 group 明确报错。
- 验证：`cargo fmt --check && cargo test`，重建 WASM 并提交产物。

### U4-B. API 房间成员设备端点与群聊门禁测试

- `api/src/handlers/e2ee.rs` + `api/src/database/e2ee_mls_store.rs`：
  `GET /rooms/{room_id}/e2ee/members`，仅房间当前成员可访问，返回
  `[{user_id, devices: [{id, protocol_version, credential_fingerprint}]}]`。
- `api/src/routes.rs`：注册路由。
- `api/tests/e2ee_mls_api_integration.rs`：新增三账号至少四设备群聊集成测试：
  - A1/B1/C1 房间 bootstrap 与互发；
  - 邀请 D：revision 推进 → rekey_required → add commit + welcome 后恢复 active；
  - 退出/移除 C：revision 推进 → remove commit 后恢复 active，C 不能拉取控制消息；
  - 旧 revision 提交返回 40902；已移除成员访问 e2ee/members 返回 403。
- 验证：`docker compose run rust-tests cargo test --tests`。

### U4-C. H5 房间级协调

- `h5-app/src/services/e2ee-mls-api-service.ts`：`listRoomMemberDevices`。
- `h5-app/src/e2ee/session.ts`：`listMembers` 操作（WASM LIST_MEMBERS）。
- `h5-app/src/e2ee/direct-message-coordinator.ts`：
  - `bootstrapRoom` 接收房间成员设备集合（单聊传对端设备，群聊传房间全部成员设备）；
  - `reconcileGroup` 替代仅处理 revoked 的 `rekeyIfRequired`：差集 add/remove，
    按 commit→welcome 顺序提交；
  - `prepare` 增加 `memberUserIds`，对群聊全部成员做身份信任校验。
- `h5-app/src/stores/chat-detail.ts`：E2EE 群聊发送传递房间成员集合。
- 测试：群 bootstrap、邀请 add、移除/撤销 remove、revision 冲突回滚收敛、群成员
  身份变化阻断、新成员 join 补拉。
- 验证：`npx vue-tsc --noEmit` + `VITE_USE_MOCK_DATA=true npx vitest run`。

## Definition of Done

- D1. 三成员至少四设备群可通过 H5 协调器完成 bootstrap、互发、邀请、移除与恢复。
- D2. 被移除/撤销设备不能解密新 epoch；新成员不能读取加入前历史（epoch 门禁 +
  welcome 仅覆盖新状态）。
- D3. 并发成员变化或 rekey 提交冲突时，任一客户端可回滚并收敛，不产生半提交状态。
- D4. 新增端点到文档：`docs/reference/api/e2ee.md`。
- D5. `docs/reviews/2026-08-05-u10-e2ee-u4-group-chat.md` 记录自动化证据；U4 保持
  partial（原生端专项未落地），生产 No-Go。
