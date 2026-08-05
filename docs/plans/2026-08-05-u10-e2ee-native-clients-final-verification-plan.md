---
title: "test: U10 E2EE 原生客户端最终验证与裁决计划"
date: 2026-08-05
type: test
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code
status: active
current_unit: R1
last_progress_update: 2026-08-05
---

# test: U10 E2EE 原生客户端最终验证与裁决计划

## 1. 计划定位

本文是 U10 E2EE 原生客户端专项剩余工作的**唯一执行入口和恢复点**。此前的
N1-N7、C1-C7、A1-A4 文档保留设计与历史证据，不再派发任务。

剩余执行链固定为：

`R1 审查修复 -> R2 三场景 live 复验 -> R3 N7/U7 裁决 -> R4 最终门禁`

本计划只负责关闭 U7 P0-1（原生客户端接入与跨端验收）。U7 其余 P0 不在本轮
范围内，因此即使本计划全部完成，生产 E2EE 仍保持 **No-Go**。

## 2. 当前事实基线

### 2.1 已完成并推送

| 范围 | 状态 | 关键提交或证据 |
| --- | --- | --- |
| N1-N6 原生能力 | 已完成 | FFI、安全存储、设备生命周期、单聊、多设备、群聊、附件边界均已接入 |
| 原生应用主链与三端文本 | 已完成 | Android、iOS、H5 正式路径互解；恢复、离线补拉、重复帧、损坏密文和 rekey 已覆盖 |
| A2.3 跨端附件首轮 | 已完成 | `ed272b41`、`e5125b8b`、`91f062bd` |
| A3 首轮泄漏与恢复门禁 | 已完成 | `30bc6995`；首轮 live 6/6 通过，failure/INT/TERM 恢复通过 |
| core 基线 | 已完成 | `make e2ee-core.check` 与 `make e2ee-core.check.targets` 通过 |

首轮 A3 证据可证明 DB/Redis/log/S3 未发现明文泄漏，但独立审查发现证据覆盖和
附件授权生命周期仍有 P1，故该结果只作为历史基线，不能直接用于最终裁决。

### 2.2 当前在途工作区

当前未提交改动全部属于 R1，不得丢弃、重置或混入无关提交：

- API grant lease：
  `api/sql/migrations/20260805201000_message_attachment_commit_leases.sql`、
  `api/src/database/file_upload_store.rs`、
  `api/src/database/message_store.rs`、`api/src/database/mod.rs`、
  `api/src/handlers/message.rs`、`api/tests/database_migration_smoke.rs`、
  `api/tests/websocket_integration.rs`。
- H5 文件大小边界：
  `h5-app/src/services/message-attachment-upload-service.ts`、
  `h5-app/test/message-attachment-upload-service.test.ts`。
- live 证据加固：
  `h5-app/test/e2ee-live-backend.test.ts`、
  `android-app/app/src/test/java/com/redcode/im/androidapp/live/AndroidE2eeCrossClientLiveTest.kt`、
  `tests/scripts/run-e2ee-cross-client-live.sh`、
  `tests/scripts/scan-e2ee-live-boundaries.sh`、
  `tests/scripts/test-e2ee-live-runtime-recovery.sh`、`Makefile`。

当前实现方向已经确定：pending grant 采用 30 天 lease，其他房间成员首次下载后
确认长期授权；上传者访问不确认；过期 grant 不保护对象；所有 commit 与复用路径
校验当前 room key 前缀。H5 签名使用 plaintext size，commit 使用实际 ciphertext
size。live evidence 必须包含 `h5-h5`、`android-h5`、`ios-h5` 三个场景。当前
`make api.test` 已通过，包括 184 个 unit、migration smoke、E2EE marker 和
WebSocket integration。

## 3. 审查发现与处置

| 级别 | 发现 | 处置单元 | 关闭条件 |
| --- | --- | --- | --- |
| P1 | 永久附件 grant 导致取消发送后永久授权及阻止 GC | R1 | lease、确认和过期测试通过 |
| P1 | live evidence 遗漏 H5-H5、iOS-H5 | R1/R2 | 三场景均产生独立 room/message evidence |
| P1 | Redis MONITOR 无 readiness 和正向流量断言 | R1/R2 | 捕获 `OK` 及每个 evidence room 流量 |
| P1 | Push 无 live 样本但结果被视为整体成功 | R2/R3 | live 明确记为 `not-observed-live`，API integration 单独证明占位 payload |
| P1 | DB scanner 未覆盖 control messages | R1/R2 | 扫描全部 evidence room 的控制消息 |
| P1 | H5 最大文件边界多计算 AES-GCM tag | R1 | signature/commit 大小职责测试通过 |
| P2 | room key 前缀校验不统一 | R1 | 所有 commit/复用路径拒绝跨 room key |
| P2 | evidence SQL 拼接风险 | R1 | UUID/object key 严格验证后才构造查询 |
| P2 | recovery test 未进入聚合门禁 | R1/R4 | `tests.tooling` 包含 recovery test |
| P2 | signal 后 driver 可能返回 0 | R1 | INT=130、TERM=143，且 runtime 恢复 |

## 4. 剩余实施单元

### R1. 关闭独立审查发现

**目标：** 修复附件授权生命周期、H5 大小边界和 live scanner 可信度问题，形成
可复验的小闭环。

**实现与测试范围：**

1. 追加 migration，不修改任何已有 migration；migration smoke 期望同步更新。
2. API 测试覆盖上传者访问不确认、其他成员确认、过期 grant 404、跨 room key
   commit 400，以及 GC 对 pending/confirmed/expired grant 的差异行为。
3. H5 测试分别断言签名 plaintext size 与 commit ciphertext size。
4. scanner 验证三场景 schema、UUID/object key、安全 SQL 输入、messages、control
   messages、附件记录、Redis 正向流量、日志和 S3 密文。
5. runtime recovery 覆盖 failure、INT、TERM 的非零退出和 `persist/plaintext` 恢复。

**提交边界：**

| 顺序 | 闭环 | 建议提交说明 |
| --- | --- | --- |
| 1 | API grant lease 与授权/GC 测试 | `fix(api): 收敛 E2EE 附件授权生命周期` |
| 2 | H5 大小边界与三端 live/scanner 加固 | `test(e2ee): 加固跨端泄漏验收` |

每个提交必须先通过对应测试、`git diff --check`，commit 后立即 push。

### R2. 重新生成最终 live 证据

**依赖：** R1 两个提交均已推送，API dev 已应用新 migration。

**场景：**

1. H5-H5 双向文本互解。
2. Android-H5 双向文本及附件互解，错误 AAD 和密文损坏 fail closed。
3. iOS-H5 双向文本互解。
4. 三个场景分别具备 room、message、plaintext marker；附件场景另含 object key。
5. DB messages/control messages/附件记录、Redis、API logs 和 S3 均无非预期明文、
   RCST、DEK、nonce 或私钥材料。
6. Push 若本次无 live job，必须诚实记录 `not-observed-live`；
   `api/tests/e2ee_marker_scan.rs` 作为 queued placeholder payload 的独立 integration
   证据，二者不得合并表述。
7. 成功、故意失败、INT、TERM 后 runtime 均恢复 `persist/plaintext`。

**验收输出：** 保存 run ID、各场景 room/message ID、对象 SHA-256、runtime 前后
状态和 scanner 摘要；不得保存 token、DEK、nonce 或私钥。

### R3. 更新 N7 与 U7 P0-1 裁决

**目标：** 让文档只陈述 R2 和自动化门禁实际证明的事实。

**文件：**

- `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md`
- `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md`

**规则：**

1. N7 记录三端 identity、场景矩阵、附件、泄漏扫描和 runtime 恢复证据。
2. U7 只更新 P0-1；备份恢复演练、CI 漏洞/许可证扫描和 H5 发布检查保持原状态。
3. Push 证据明确区分 live 未观察与 API integration 已验证。
4. 对 R1-R3 最终 diff 做 correctness、security、testing 独立复审；未解决 P0/P1
   时不得进入 R4。
5. 文档使用独立 `docs(e2ee): ...` 提交并立即 push。

### R4. 最终门禁与状态收口

**目标：** 从已推送代码重新执行完整门禁，排除只在局部测试成立的结果。

```bash
make e2ee.cross-client.live
make e2ee-core.check
make e2ee-core.check.targets
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home \
  make test.all
make test.live
git diff --check
git status --short
```

若门禁失败，只修复与失败直接相关的最小闭环，验证、提交并 push 后从受影响门禁
重新开始。`make test.all` 必须显式使用 JDK 21，不能把 JDK 26 的 Gradle 启动失败
记录为代码失败。

## 5. Definition of Done

- D1. R1 所列全部 P1 已关闭，并经独立复审确认无新增 P0/P1。
- D2. H5-H5、Android-H5、iOS-H5 三场景均从正式客户端路径通过。
- D3. 附件授权 lease、确认、过期、跨 room 拒绝和 GC 行为均有自动化测试。
- D4. DB、Redis、logs、S3 无非预期明文或密钥材料；Push 证据边界表述准确。
- D5. live 成功、失败、INT、TERM 后 runtime 均恢复 `persist/plaintext`。
- D6. core、API、Android、iOS、H5、`make test.all`、`make test.live` 全绿。
- D7. N7 与 U7 P0-1 已按真实证据更新并推送，其他 U7 P0 状态未被改写。
- D8. 所有本轮提交已 push，工作区无未解释改动。
- D9. 生产 E2EE 仍为 **No-Go**，直到 U7 其余 P0 由独立计划关闭。

## 6. 恢复点

下一步从 R1 继续：执行 shell 语法检查、H5/Android 定向门禁和
`git diff --check`，再按 R1 的两个提交边界提交并 push。API 全量测试已通过，
无需在没有 API 改动的情况下重复运行。不得返回 A2.3 或重复 N1-N6。
