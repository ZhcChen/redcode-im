---
title: U10 E2EE U3 多设备批准、同步与撤销验收
date: 2026-08-05
status: partial
scope: e2ee-core,h5-app,api
---

# U10 E2EE U3 多设备批准、同步与撤销验收

## 结论

U3（R5/R6）的共享核心、API 与 H5 侧已形成自动化闭环：第二设备必须经可信
设备签名批准才能发布 KeyPackage；撤销设备会将其参与的全部房间置为
`rekey_required`，被撤销设备不能拉取或提交控制消息；可信设备提交 rekey
Commit 后房间恢复 `active`。批准与撤销均为幂等操作。共享核心新增成员移除
Commit 与设备批准签名能力，WASM 产物已重建并随本单元提交。

原生双端尚未接入 E2EE 协议链，按
`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` 边界交由原生
E2EE 专项落地；因此 U3 保持 `partial`，生产 E2EE 继续 No-Go。

## 直接证据

| 门禁 | 证据 | 结果 |
| --- | --- | --- |
| 批准前不能发布/领取 KeyPackage | `api/tests/e2ee_mls_api_integration.rs` 既有 `mls_device_approval_and_key_package_api_are_fail_closed` | 未批准设备发布/领取/解密被拒绝 |
| 第二设备注册进入 `pending_approval` | 同文件新测试 | 注册后状态为 `pending_approval`，首台为 `active` |
| 重复批准幂等 | `device_revocation_marks_rooms_rekey_required_and_is_idempotent` | 连续两次 approve 均返回 `active`，不误判冲突 |
| 撤销触发房间 `rekey_required` | 同文件新测试 | 撤销 A2 后 epoch 保持 1、状态 `rekey_required` |
| 已撤销设备失去控制消息权限 | 同文件新测试 | 撤销设备拉取返回 `403`、提交返回 `403` |
| rekey Commit 恢复 `active` | 同文件新测试 | A1 提交 epoch 2 后状态恢复 `active` |
| 待批准设备撤销明确冲突 | 同文件新测试 | 返回 `409`，不静默进入 `revoked` |
| API 全量回归 | `docker compose run rust-tests cargo test --tests` | 全通过 |
| 共享核心成员移除 | `e2ee-core/src/session.rs` `remove_member` + `tests/member_removal.rs` | 生成已合并 Remove Commit；被移除成员不能消费新 epoch，未知成员拒绝 |
| 共享核心批准签名 | `sign_device_approval` + 同测试 | OpenMLS signer 生成 Ed25519 签名并验签通过 |
| WASM 命令面 | `e2ee-core/src/command.rs` `REMOVE_MEMBER=10`/`SIGN_DEVICE_APPROVAL=11` + `tests/command_api.rs` | 命令级编码/解码通过 |
| e2ee-core 回归 | `cargo fmt --check && cargo test`（WASM 产物已 `bun run e2ee:build` 重建） | 全通过 |
| H5 rekey 协调 | `h5-app/test/e2ee-direct-message-coordinator.test.ts` | `rekey_required` 时逐设备 `removeMember` 提交 rekey；`member not found` 跳过；提交冲突且服务端 `activeEpoch >= targetEpoch` 时回滚 `previousState` 重新收敛 |
| H5 待批准设备不发布 | `h5-app/test/e2ee-device-lifecycle.test.ts` | `pending_approval` 不 publish KeyPackage；批准后恢复发布 |
| H5 设备管理 UI | `h5-app/test/settings-view.test.ts` | 账户安全页渲染设备列表、批准待批准设备 |
| H5 批准签名字节契约 | `h5-app/test/e2ee-device-manager.test.ts` | payload 与 Rust `device_approval_payload` 逐字节一致，pending 不能批准 |
| H5 全量回归 | `npx vue-tsc --noEmit` + `VITE_USE_MOCK_DATA=true npx vitest run` | 类型检查通过；247 项通过、8 项跳过 |

## 实现边界

- 撤销设备会给该用户参与的全部房间置 `rekey_required`，即使设备从未加入某个
  房间的 MLS group；数据库无法直接判断设备是否在具体房间 group，客户端对每个
  房间执行 `removeMember` 并以 `member not found` 跳过，避免重复 rekey 误报。
- rekey 复用 pending operation 机制：写 `{kind:'rekey', previousState, controls}`
  后逐个提交控制消息；竞争失败且服务端 epoch 已前进时回滚 `previousState` 并
  删除 pending，重新 `syncControls` 收敛，不允许半提交状态。
- 设备批准签名在 H5 侧由 `signDeviceApproval` 走 WASM `SIGN_DEVICE_APPROVAL`
  命令，不直接使用浏览器原生 Ed25519 实现，保证与 Rust 验签字节序一致。
- H5 设备状态新增 `deviceStatus: 'active' | 'pending_approval'`，旧数据反序列化
  默认 `active`，避免既有存储升级后误锁设备。
- 原生双端（`android-app/` / `ios-app/`）的 E2EE 设备生命周期与 UI 未接入，
  属于原生 E2EE 专项范围；本次不宣称 U3 端到端完成。

## 环境说明

- API 测试在 `tests/docker-compose.test.yml` 的 rust-tests 容器内执行，未映射
  PG/Redis 宿主端口。
- 未切换 E2EE runtime；`persist/plaintext` 保持不变，本单元不涉及 live 联调。
- Android 测试需 `JAVA_HOME=<zulu-21>`（仓库默认 JDK 26 与 Gradle 8.12 不兼容）。

## 结论

- 结论：有条件通过（API + H5 自动化证据通过；原生端 E2EE 专项未落地前 U3
  整体保持 partial）。
- 下一步：进入 U4 群聊；U4 需先映射群成员 ↔ MLS leaf，推荐每设备
  identity=`${userId}/${deviceId}`，被移出群成员对应 leaf 通过
  `removeMember` 移除并复用 U3 rekey 机制。
