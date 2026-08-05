---
title: U10 E2EE 原生客户端 N7 验收记录
date: 2026-08-05
status: complete
scope: android-app,ios-app,h5-app,e2ee-core,api
verdict: client-p0-closed
---

# U10 E2EE 原生客户端 N7 验收记录

## 结论

原生客户端 N1-N6、Android/iOS 应用主链装配以及 Android、iOS、H5 三端正式
路径互操作已经闭环。2026-08-05 的最终 live run `r21785933828` 覆盖 H5-H5、
Android-H5、iOS-H5，并通过 DB、Redis、log 和 S3 泄漏扫描；成功、失败、INT、
TERM 后 runtime 均恢复 `persist/plaintext`。

据此，U7 P0-1（原生双端聊天主链接入与三端 E2EE live 缺失）具备关闭证据。
本结论不关闭 U7 其余 P0，生产 E2EE 继续 **No-Go**。R4 已从已推送代码完成
最终三场景 live、core 四目标、JDK21 `test.all` 与 JDK21 `test.live` 门禁。

## 实现证据

| 范围 | 关键提交 | 结果 |
| --- | --- | --- |
| N1 FFI 与命令封装 | `1b4c49b0`、`c06c4056`、`29f75d47` | Android/iOS 使用共享 C ABI |
| N2 安全状态存储 | `801d0bc7`、`71fa0f76` | Keystore/Keychain 包装，篡改 fail closed |
| N3 设备生命周期 | `9695150b`、`dbd879cb` | 注册、审批、撤销与 KeyPackage 补充 |
| N4-N6 协调能力 | `b51f2315`、`6d66e830`、`2ba81b95`、`19d73b61`、`94a62c05`、`565432ab` | 单聊、多设备、群聊、附件边界 |
| 应用主链与三端 live | `3d8a47d6`、`3850229e`、`0ed7e126` | Android/iOS/H5 正式路径互解 |
| 恢复与 rekey | `c4cfb0c6`、`88d994cd`、`5669870f` | 新会话、恢复、离线、重复、损坏、成员变化 |
| 跨端附件 | `ed272b41`、`e5125b8b`、`91f062bd` | H5 加密上传、Android 内存解密、AAD fail closed |
| 泄漏门禁与审查修复 | `30bc6995`、`22cb78f2`、`a4a703d7` | grant lease、GC 串行化、三场景 scanner |

## 最终 live 场景

| 场景 | Room | Message 数 | 结果 |
| --- | --- | ---: | --- |
| H5-H5 | `019fd1f3-ac5a-7760-95fb-5ee2f11ca43a` | 2 | 双向密文互解，历史无 marker |
| Android-H5 | `019fd1f3-ac7f-7303-868d-c1deba318557` | 3 | 双向文本与附件互解，错误 AAD fail closed |
| iOS-H5 | `019fd1f3-e4dc-7e81-a2bf-e668d7e2265a` | 2 | 双向密文互解，历史无 marker |

附件对象：

- Object key：`messages/019fd1f3-ac7f-7303-868d-c1deba318557/files_20260805/2540f805.txt`
- S3 SHA-256：`2a9e30e180a652df7e6871a8035fbe6f851e33e4caf8d3b1899053407643abaa`
- 对象内容：ciphertext-only；未包含 plaintext marker、raw DEK 或 nonce。

## 外围边界

| 边界 | 证据 | 结果 |
| --- | --- | --- |
| PostgreSQL messages | 7 个 evidence message 与各自 room 逐一绑定 | 固定占位 + encrypted content，无 marker/密钥字段 |
| PostgreSQL control messages | 三个 evidence room 均有控制消息，按 envelope hex 扫描 | 无 plaintext marker |
| 附件记录 | commit/upload record 与 object key 对齐 | 无 marker，grant lease 状态有效 |
| Redis | MONITOR 先确认 `OK`，捕获三个 `room:<uuid>` 正向流量 | 无 plaintext marker |
| API logs | live marker + denylist 双重扫描，420 条日志调用 | 敏感字段命中 0 |
| Push live | 本次没有可观察的 live device job | `not-observed-live`，不伪称 live 已验证 |
| Push integration | `api/tests/e2ee_marker_scan.rs` 实际产生 queued job | payload 使用占位且无 marker/密钥字段 |
| S3 | 下载对象并校验内容与 SHA-256 | ciphertext-only |

## 异常与恢复

- 新会话、重启恢复、离线历史补拉、消息 ID 去重和历史混排均有自动化证据。
- 损坏密文、错误 AAD、未知/缺失状态均 fail closed，不回退 plaintext。
- 第二设备批准/撤销、群成员 add/remove 推进 epoch，失权设备/成员不可读新 epoch。
- live 正常完成、故意失败、SIGINT 和 SIGTERM 均恢复 `persist/plaintext`；信号路径
  分别返回 130/143，不以退出码 0 掩盖中断。

## 独立复审

R1 修复先后经过 correctness 与 security 独立审查，发现并关闭：永久 grant、GC
竞态、跨 provider 锁、control envelope hex 扫描、message-room 绑定、Redis 正向
流量、Push 证据表述和 signal 退出码问题。最终复审结论：无未解决 P0/P1。

## R4 最终门禁

| 门禁 | 结果 |
| --- | --- |
| `make e2ee.cross-client.live` | 通过；run `r41785934114`，三场景与边界扫描全绿 |
| `make e2ee-core.check` | 通过 |
| `make e2ee-core.check.targets` | 通过，四目标构建成功 |
| JDK21 `make test.all` | 通过；API、Android、iOS、Admin、Desktop、H5、Website 与 tooling 全绿 |
| JDK21 `make test.live` | 通过；Android、iOS、Admin、Desktop live smoke 全绿 |

R4 最终附件对象为
`messages/019fd1f8-07a9-75f3-868f-58a799ccdf06/files_20260805/58370c00.txt`，
S3 SHA-256 为
`c0ff04f5ad3fc5ccaa5c0be2ef05cc826994beb74426291cb25c9b0953da21a2`。
未显式设置 JDK21 的首次 `make test.live` 因 JDK26 在 Gradle 配置阶段失败；按
仓库固定 JDK21 约束重跑后通过，不计为代码回归。

## 发布边界

- U7 P0-1：关闭。
- U7 其余 P0：保持打开。
- 生产：E2EE **No-Go**，`content_audit_mode` 保持 `plaintext`。
- 测试环境：只允许受控验收窗口临时启用，结束必须自动恢复。
