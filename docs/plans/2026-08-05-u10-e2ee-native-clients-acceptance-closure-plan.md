---
title: "test: U10 E2EE 原生客户端验收收口计划"
date: 2026-08-05
type: test
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
product_contract_preservation: "Product Contract unchanged"
execution: code
status: active
current_unit: A1
last_progress_update: 2026-08-05
---

# test: U10 E2EE 原生客户端验收收口计划

## 1. 计划定位

本文是 U10 E2EE 原生客户端剩余工作的**唯一执行入口和唯一进度快照**。
N1-N6、C1-C5、全仓回归门禁以及三端最小互操作均已完成，不再从旧计划派生任务。

当前只执行：

`A1 Android <-> iOS 闭环提交 -> A2 场景矩阵 -> A3 泄漏抽检 -> A4 证据重审`

生产 E2EE 在本计划完成后仍服从 U7 全部 P0 裁决，当前始终保持 **No-Go**；
本计划只裁决 U7 P0-1，不得将其完成解释为生产发布批准。

## 2. 文档边界

| 文档 | 当前职责 | 是否派发任务 |
| --- | --- | --- |
| 本计划 | 当前进度、剩余实施单元、恢复点与 DoD | 是 |
| `docs/plans/2026-08-05-u10-e2ee-native-clients-final-closure-plan.md` | C1-C7 历史实施记录 | 否，已 superseded |
| `docs/plans/2026-08-05-u10-e2ee-native-clients-plan.md` | N1-N7 原始专项设计 | 否，已 superseded |
| `docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` | U10 产品合同与服务端契约来源 | 仅发现契约缺口时回查 |
| `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md` | N7 验收事实 | A4 更新 |
| `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` | U7 安全裁决 | A4 只更新 P0-1 |

后续不得再创建平行的 E2EE 原生收口计划；进度和恢复点只更新本文。

## 3. 当前事实快照

### 3.1 状态看板

| 范围 | 状态 | 证据或下一动作 |
| --- | --- | --- |
| N1-N6 / C1-C5 原生能力 | 已完成并推送 | FFI、存储、生命周期、消息主链、多设备、群聊、附件均已接入 |
| 全仓回归门禁 | 已完成并推送 | `make test.all`、`make test.live`、core/WASM 门禁已通过 |
| H5 <-> Android | 已完成并推送 | `3d8a47d6`，双向互解、WS/历史和 marker 断言通过 |
| H5 <-> iOS | 已完成并推送 | `3850229e`，正式 iOS coordinator 双向互解通过 |
| API inventory 契约 | 已修复并推送 | `077b04ad`，统一 `max_available` |
| 受控 E2EE live 入口 | 已完成并推送 | `0ed7e126`，成功/失败均恢复 `persist/plaintext` |
| Android <-> iOS | 实现及 live 验证完成，待提交 | A1 只处理当前三个在途测试文件 |
| 完整场景与泄漏抽检 | 待执行 | A2、A3 |
| N7 证据与 U7 P0-1 重审 | 待执行 | A4 |

### 3.2 已验证基线

- `make e2ee.cross-client.live`：4 个场景通过，包括 H5/Android、H5/iOS、
  Android/iOS 双向互解及 H5 连续新会话；退出后 runtime 已恢复
  `persist/plaintext`。
- Android：`testDebugUnitTest lintDebug` 通过，固定使用 JDK 21。
- iOS：`swift test` 242 项通过，9 项 live 在默认环境跳过，0 失败。
- API：unit 184 项及 integration、migration guard 全部通过。
- core：host、Android、iOS、WASM 目标门禁已通过。
- H5：本轮提交前仍须重跑 `make h5-app.check` 和 `make h5-app.test.unit`，
  以最终工作区输出作为 A1 证据。

### 3.3 当前恢复点

- 分支：`main`；已推送基线：`0ed7e126`。
- 当前有三个 A1 在途文件，禁止丢弃、重置或混入无关提交：
  - `android-app/app/src/test/java/com/redcode/im/androidapp/live/AndroidE2eeCrossClientLiveTest.kt`
  - `ios-app/Tests/RedCodeFeaturesTests/IOSE2eeCrossClientLiveTests.swift`
  - `h5-app/test/e2ee-live-backend.test.ts`
- A1 已通过受控 live，场景步骤为 `ios-native-ready`、
  `android-to-ios-sent`、`ios-native-received`、`ios-to-android-sent`、
  `android-native-received`。
- live tests 在未配置显式环境变量时必须安全跳过，禁止访问真实后端。
- 每次 live 前确认 runtime 为 `persist/plaintext`；外层入口临时切换并必须在
  成功、失败、INT、TERM 后恢复 `persist/plaintext`。

## 4. 剩余实施单元

### A1：冻结 Android <-> iOS 直接互解

**目标**

将已经通过 live 的原生双端直接互解整理为一个最小、可解释、可推送闭环。

**实施范围**

1. H5 仅承担账号、好友、私聊和 coordination server 编排，不参与明文转换。
2. iOS 使用正式安全状态存储、设备生命周期、API client 和 direct coordinator
   注册设备并发布 ready。
3. Android 创建 MLS group 并发送密文，iOS 通过正式历史入口解密。
4. iOS 回发密文，Android 通过正式历史入口解密。
5. Android 与 iOS 使用不同 account 和 device identity；原始历史不得包含双方
   marker、RCST、DEK 或明文消息。

**测试场景**

1. Android -> iOS 解密成功，消息 ID 与 marker 只出现一次。
2. iOS -> Android 解密成功，消息 ID 与 marker 只出现一次。
3. 未设置 live 环境变量时 Android/iOS 测试编译通过并跳过。
4. 受控 live 成功后 runtime 恢复 `persist/plaintext`。

**验证**

```bash
make e2ee.cross-client.live
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home \
  ./android-app/gradlew -p android-app testDebugUnitTest lintDebug
(cd ios-app && swift test)
make h5-app.check
make h5-app.test.unit
```

只 stage 当前三个在途测试文件，提交建议：
`test(e2ee): 补齐 Android iOS 直接互解`。提交后立即 push。

### A2：补齐三端行为场景矩阵

**目标**

在最小两两互解基础上验证恢复、乱序和状态变化行为。每类行为先选择最能覆盖
协议边界的一组正式客户端路径，不机械复制全部端组合；共享核心行为用现有
unit/fixture 作其余组合证据。

**实施范围与测试场景**

| 场景 | 最小 live 证明 | 必须断言 |
| --- | --- | --- |
| 第二个新会话 | 已有 H5 连续会话，补原生一侧恢复 | 新 group/key package 独立，不串用 epoch |
| 重启恢复 | Android 或 iOS 进程重启后继续收发 | 从安全存储恢复，禁止重新初始化为新 identity |
| 离线补拉 | 接收端离线后由历史入口补齐 | 顺序正确、消息 ID 去重、无明文回退 |
| 重复帧 | 同一 WS/历史密文重复进入 | 只渲染一次，不重复推进状态 |
| 损坏密文 | 篡改 ciphertext 或 metadata | fail closed，不产生占位明文或状态污染 |
| 设备撤销 | 第二设备批准、加入、撤销后 rekey | 被撤销设备不可读新 epoch |
| 群成员变化 | add/remove member 与 Commit/Welcome | 新成员不可读加入前历史，移除成员不可读新 epoch |
| 附件 | 跨端上传、下载和内存解密 | AAD 绑定 room/part/object key，错误绑定 fail closed |

**主要文件**

- `h5-app/test/e2ee-live-backend.test.ts`
- `android-app/app/src/test/java/com/redcode/im/androidapp/live/AndroidE2eeCrossClientLiveTest.kt`
- `ios-app/Tests/RedCodeFeaturesTests/IOSE2eeCrossClientLiveTests.swift`
- 必要时扩展 `tests/scripts/run-e2ee-cross-client-live.sh`

**提交边界**

- A2.1：恢复类场景（新会话、重启、离线、重复帧、损坏密文）。
- A2.2：成员状态类场景（设备撤销、群成员变化）。
- A2.3：附件跨端场景。

每个子单元先运行受控 live、对应平台测试和 diff 检查，再独立提交并 push。

### A3：外围泄漏抽检与 runtime 失败恢复

**目标**

证明三端互解成功不以服务端、日志、Push 或对象存储泄漏明文和密钥材料为代价。

**实施范围**

1. 使用唯一 marker 执行文本和附件 live，记录账号、room、message、object key 与
   runtime 前后状态，不记录 token 或密钥。
2. 抽检 PostgreSQL 消息/控制消息、Redis cache/pubsub、API 日志、Push mock 和
   S3 兼容对象存储。
3. 文本 marker、附件明文、RCST、DEK、nonce、credential 私钥不得出现在非预期
   服务端位置；对象存储只允许密文对象。
4. 用故意失败场景验证外层驱动非零退出，并再次确认 runtime 恢复
   `persist/plaintext`。

**主要文件**

- `tests/scripts/run-e2ee-cross-client-live.sh`
- `tests/scripts/scan-e2ee-log-denylist.sh`
- `api/tests/e2ee_marker_scan_integration.rs`
- `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md`

**完成标准**

成功与故意失败路径均可重放；所有抽检位置无非预期敏感材料；runtime 最终为
`persist/plaintext`。测试代码与证据文档应拆分提交。

### A4：汇总证据并重审 U7 P0-1

**目标**

以 A1-A3 和既有门禁的真实结果替换过时验收结论，只裁决原生客户端 P0-1。

**实施范围**

1. 更新 `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md`，记录
   精确命令、场景、identity 边界、runtime 前后状态和 marker 抽检结果。
2. 更新 `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` 的 P0-1 证据，
   不改写其他 P0 状态。
3. 对最终 diff 分别执行 correctness、security、testing review；高严重度发现必须
   修复并重跑相关门禁，不能只写入风险列表。
4. 复跑全量门禁，确认工作区无未解释改动且所有提交已 push。

**最终验证**

```bash
make e2ee.cross-client.live
make e2ee-core.check
make e2ee-core.check.targets
make test.all
make test.live
git diff --check
```

只有 A1-A3 全部通过且审查无未解决 P0/P1 时，才可将 U7 P0-1 标记关闭。
生产 E2EE 仍保持 **No-Go**，直到 U7 其余 P0 另行关闭。

## 5. 执行约束

- 不修改已有 migration；新增持久化结构只能追加 migration。
- 不扩展服务端 E2EE API 契约；发现缺口先回产品合同评估。
- E2EE 错误、身份变化、状态损坏和未知 epoch 一律 fail closed，不回退 plaintext。
- 双端往返必须使用不同 device identity；禁止用单设备自解密作为证据。
- Android 固定 JDK 21；JNA 空指针使用 `Pointer(0)`。
- iOS GRDB async 上下文使用 `try await dbQueue.read/write`。
- live 入口不得接入默认测试、commit hook、CI 或普通启动链。
- 每个提交前运行 `git status --short`、`git diff --check`、
  `git diff --cached --check` 并审查 staged diff；只 stage 当前闭环文件。
- Conventional Commits 使用简体中文说明；每个闭环提交后立即 push。

## 6. Definition of Done

- D1. Android、iOS、H5 三端两两双向文本均经过正式客户端路径互解。
- D2. 新会话、重启恢复、离线补拉、重复帧和损坏密文均有可重放证据。
- D3. 第二设备撤销和群成员变化正确推进 epoch，失去权限的设备/成员不可读新内容。
- D4. 跨端附件使用随机 DEK/nonce 和绑定 AAD，错误绑定与损坏密文 fail closed。
- D5. DB、Redis、log、Push 和 S3 抽检不存在非预期明文或密钥材料。
- D6. live 成功、失败和信号中断后 runtime 均恢复 `persist/plaintext`。
- D7. core、Android、iOS、H5、`make test.all` 和 `make test.live` 门禁全绿。
- D8. N7 验收与 U7 P0-1 重审材料和真实结果一致，独立审查无未解决 P0/P1。
- D9. 所有相关提交均已推送，工作区无未解释改动；生产状态仍为 **No-Go**。
