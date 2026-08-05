---
title: U10 E2EE U4 群聊与成员变化 rekey 验收
date: 2026-08-05
status: partial
scope: e2ee-core,h5-app,api
---

# U10 E2EE U4 群聊与成员变化 rekey 验收

## 结论

U4（R7/R8）的共享核心、API 与 H5 协调器已形成自动化闭环：房间成员设备集合由
服务端统一提供，客户端把本地 MLS group leaf 集合与服务端集合做差集收敛，
邀请/新设备 add（commit + welcome）、退出/移除/撤销 remove，成员变化后旧
revision 的 Commit 被服务端拒绝，被移除成员立即失去控制消息与成员视图权限。
共享核心新增 `LIST_MEMBERS` 命令并重建 WASM 产物随本单元提交。

原生双端尚未接入 E2EE 协议链，按
`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` 边界交由原生
E2EE 专项落地；因此 U4 保持 `partial`，生产 E2EE 继续 No-Go。

## 直接证据

| 门禁 | 证据 | 结果 |
| --- | --- | --- |
| 成员设备集合端点 | `api/tests/e2ee_mls_api_integration.rs` `group_chat_member_changes_advance_revision_and_gate_epochs` | 三成员房间返回 3 名成员各 1 设备；非成员 403 |
| 群初始 bootstrap | 同文件 | A1 提交初始 Commit 后房间 active |
| 邀请推进 revision | 同文件 | 邀请 D 后 revision +1、状态 `rekey_required` |
| 旧 revision 拒绝 | 同文件 | 用旧 revision 提交 Commit 返回 409 |
| add Commit + Welcome | 同文件 | 新 revision Commit 激活 epoch 2，Welcome 定向 D1 后 D 可拉取控制消息 |
| 退出/移除推进 revision | 同文件 | C 退出后 revision +1、`rekey_required`，remove Commit 后恢复 active epoch 3 |
| 被移除成员权限收回 | 同文件 | C 拉取控制消息与成员设备视图均 403 |
| 同房间身份可见性 | 同文件 + `mls_device_approval_and_key_package_api_are_fail_closed` | 同房间非好友可查根身份；无关系 404；对端设备列表仍限好友 |
| 共享核心成员列表 | `e2ee-core/tests/member_removal.rs` + `tests/command_api.rs` | add 后 leaf 列表一致，remove 后收敛，未知 group 报错 |
| e2ee-core 回归 | `cargo fmt --check && cargo test`（WASM 已 `bun run e2ee:build` 重建） | 全通过 |
| H5 群 bootstrap | `h5-app/test/e2ee-direct-message-coordinator.test.ts` | 三成员房间 add 两个其他成员设备，commit/welcome 按序提交 |
| H5 邀请 reconcile | 同文件 | 服务端多出 C 设备 → claim + add + commit/welcome |
| H5 移除 reconcile | 同文件 | 服务端缺 C leaf → removeMember('account-c/device-c') |
| H5 rekey 竞争回滚 | 同文件 | 提交冲突且服务端 epoch 已前进时恢复 previousState 重新收敛 |
| H5 群身份变化阻断 | 同文件 | 任一成员根身份变化拒绝发送，不触碰 MLS API |
| H5 全量回归 | `npx vue-tsc --noEmit` + `VITE_USE_MOCK_DATA=true npx vitest run` | 类型检查通过；251 项通过、8 项跳过 |

## 实现边界

- 设备 identity 统一为 `${userId}/${deviceId}`（K1）；`reconcileGroup` 通过
  `listRoomMemberDevices` 与 `listMembers` 差集决定 add/remove，撤销设备、
  退出成员与被移除成员共用同一路径，不再维护第二套成员变化逻辑。
- 新成员加入前本地无 group leaf（`lastCommitMessageIds` 缺失）时跳过 reconcile，
  由控制消息同步完成 welcome join 后再收敛，避免对未加入状态生成无效 Commit。
- 群聊成员中存在无 E2EE 设备的成员时 bootstrap 明确失败，不建立不完整 group。
- H5 协调器不再依赖好友视角的 `listPeerDevices`，单聊与群聊统一使用房间成员
  设备端点；`listPeerDevices` 保留在 API 服务层供单聊界面使用。
- 服务端不校验 MLS Commit 内容，只按 revision/epoch/成员权限做外层门禁；密文
  安全由 OpenMLS 保证，被移除成员即使持有旧状态也不能消费新 epoch。

## 环境说明

- API 测试在 `tests/docker-compose.test.yml` 的 rust-tests 容器内执行，未映射
  PG/Redis 宿主端口。
- 未切换 E2EE runtime；`persist/plaintext` 保持不变，本单元不涉及 live 联调。
- Android 测试需 `JAVA_HOME=<zulu-21>`（仓库默认 JDK 26 与 Gradle 8.12 不兼容）。

## 结论

- 结论：有条件通过（e2ee-core/API/H5 自动化证据通过；原生端 E2EE 专项未落地前
  U4 整体保持 partial）。
- 下一步：进入 U5 附件与外围功能边界；群成员变化机制已与 U3 设备 rekey 合并为
  统一的 reconcile 状态机，U5 可直接建立在 active epoch 之上。
