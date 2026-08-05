---
title: "feat: U10 E2EE 原生客户端最终收口计划"
date: 2026-08-05
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md
execution: code
status: superseded
current_unit: C6
last_progress_update: 2026-08-05
superseded_by: docs/plans/2026-08-05-u10-e2ee-native-clients-acceptance-closure-plan.md
---

# feat: U10 E2EE 原生客户端最终收口计划

> [!IMPORTANT]
> 本计划已由
> `docs/plans/2026-08-05-u10-e2ee-native-clients-acceptance-closure-plan.md`
> 取代，仅保留 C1-C7 的历史实施记录，不再作为任务入口。

## 1. 计划定位

本文曾作为原生客户端 E2EE 的执行入口，记录从提交 `17c235ec` 开始的全仓门禁、
三端 live 和重审规划。当前进度与剩余任务以 superseding 计划为准。

固定执行顺序：

`C5-iOS（已完成） -> C5-Gate（已完成） -> C7 -> C6 -> C8`

生产 E2EE 在 C8 完成后仍须服从 U7 其他 P0 裁决，当前始终保持 **No-Go**。

## 2. 文档职责

| 文档 | 职责 | 执行入口 |
| --- | --- | --- |
| 本计划 | 当前进度、剩余顺序、完成标准和恢复点 | 是 |
| `2026-08-05-u10-e2ee-native-clients-closure-plan.md` | C1-C4 与早期 C5 设计记录，已 superseded | 否 |
| `2026-08-05-u10-e2ee-native-clients-plan.md` | N1-N7 原始专项范围，已 superseded | 否 |
| `2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` | U10 服务端契约与总范围；仅在发现契约缺口时回查 | 否 |
| U5/U6/U7 三份专项计划 | 附件、Admin 门禁与首轮安全审查历史设计，已 superseded | 否 |
| `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md` | 已发生的验收事实和后续证据汇总 | 否 |
| `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` | U7 安全裁决和 P0-1 重审 | 否 |

本文冻结为历史记录，不再更新进度表或恢复点。

## 3. 当前进度

### 3.1 状态看板

| 单元 | 状态 | 结论或下一动作 |
| --- | --- | --- |
| C1-C5 | 已完成并推送 | 功能与双端门禁已冻结，不重做 |
| C7 全仓回归门禁 | 已完成并推送 | `make test.all`、`make test.live`、WASM 3 项全绿 |
| C6 三端 E2EE live | 进行中 | 盘点并补齐 Android、iOS、H5 正式路径互解入口 |
| C8 证据与重审 | 待开始 | 汇总 live/marker 证据并重审 U7 P0-1 |

当前唯一队列：`C6 -> C8`。不得从已 superseded 的 N1-N7 或 C1-C5
计划重新派生任务。

### 3.2 已完成基线

| 范围 | 状态 | 提交与验证事实 |
| --- | --- | --- |
| N1-N3 基础能力 | 已完成 | FFI、安全状态存储、设备生命周期与 KeyPackage 已在双端落地 |
| C1 Android 装配 | 已完成 | `30940f4e` |
| C2 Android 消息主链 | 已完成 | 文本 `565d6482`、附件 `20672eeb` |
| C3 iOS 装配 | 已完成 | `881d662e`、`4a1ed113` |
| C4 iOS 消息主链 | 已完成 | 文本 `a5d42f6f`、附件 `4fc971b4`；223 项通过，7 项 live 跳过，Simulator build 通过 |
| C5 API 批准设备 rekey | 已完成 | `b27a5cea`；API 184 项通过，新增批准幂等集成测试 |
| C5 Android 群事件 | 已完成 | `27e62fdd`；群成员 mutation 与 `group_member_changed` 统一 reconcile |
| C5 Android 设备入口 | 已完成 | `d50a9f84`；批准/撤销入口、当前设备阻断和其他设备撤销后 reconcile；248 项通过、4 项跳过，`lintDebug` 通过 |
| C5 iOS 群事件 | 已完成 | `380ef019`；群成员 mutation、`group_member_changed`、活跃成员刷新及按房间 single-flight reconcile |
| C5 iOS 设备入口 | 已完成 | `17c235ec`；设备列表、批准/撤销、严格指纹校验、当前设备阻断及逐房 reconcile |
| C5 双端门禁 | 已完成 | Android JDK 21 全量通过；iOS 240 项通过、7 项 live 跳过及 Simulator build 通过；core host/四目标检查通过 |
| C7 全仓回归门禁 | 已完成 | Desktop 修复 `7753f119`、Admin live 修复 `939e416d`；`make test.all`、`make test.live` 全绿；Chrome for Testing 147 + 匹配 ChromeDriver 下 WASM 3 项通过 |

以上内容不得重做；执行中发现回归时按独立修复闭环处理。

### 3.3 当前恢复点

- 当前分支：`main`，远端基线：`origin/main`。
- 当前单元：**C6 Android、iOS、H5 三端 E2EE live**。
- C5/C7 已冻结；除非 C6 复现出明确回归，不再修改既有功能或放宽门禁。
- `make test.all` 与 `make test.live` 已全绿；后者只证明普通真实后端 smoke，禁止
  作为三端 E2EE live 证据。
- `make e2ee-core.test.wasm` 必须向 `CHROMEDRIVER` 传入与实际优先浏览器完全匹配
  的 driver。本机 ChromeDriver 会优先选择 Chrome for Testing 147；匹配
  147.0.7727.57 后 3 项通过。`wasm-pack` 自动下载最新 driver 会产生版本漂移。
- C6 先盘点已有 H5 E2EE live、Android/iOS live tests、夹具和 runtime 恢复脚本，
  再定义最小独立三端入口；不得重复实现客户端 coordinator 或扩展服务端契约。
- 当前工作区正在把 H5 live 中已下线的 Flutter 跨端进程替换为 Android 正式路径：
  `h5-app/test/e2ee-live-backend.test.ts` 已改为启动 Android live test，新增
  `android-app/app/src/test/java/com/redcode/im/androidapp/live/AndroidE2eeCrossClientLiveTest.kt`。
  这两个文件属于 C6.1/C6.2 的在途改动，不得丢弃、重置或混入其他提交。
- Android 定向编译当前尚未通过，已确认三个窄阻断：Android JVM 不提供
  `java.net.http.*`、`runTest` timeout 误用了 `java.time.Duration`、
  `E2eeCommandClient` 未直接实现 `E2eeDirectSessionCore`。下一步只修复测试适配层：
  coordination HTTP 改用 `HttpURLConnection`，timeout 改用
  `kotlin.time.Duration.Companion.seconds`，并增加委托给 `E2eeCommandClient` 的
  test-local `E2eeDirectSessionCore` adapter；生产代码暂不修改。
- 下一条验证命令为：
  `JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home ./android-app/gradlew -p android-app testDebugUnitTest --tests 'com.redcode.im.androidapp.live.AndroidE2eeCrossClientLiveTest'`。
  未设置 live 环境变量时必须编译通过并跳过，不得访问真实后端。
- 对实际复现的阻断按模块独立修复、验证、提交和 push；未复现的问题不做预防性修改。
- 开始实现前必须重新运行 `git status --short`；若工作区出现非本任务改动，只协同
  处理相关文件，不纳入本专项提交。

## 4. 剩余实施单元

### C5-iOS：设备、群成员与 epoch 事件闭环（已完成）

**目标**

将已有 iOS manager/reconcile 能力接入真实应用事件和设置入口，与 Android 已提交
语义一致，不新增服务端契约。

**实施范围**

1. 在应用级 `AppDependencies` 持有共享 `E2eeDeviceManager`、room event
   coordinator，并通过 factory 注入 Features controller。
2. 新增可测试的 room event 协调边界：plaintext runtime no-op；ready runtime
   校验 account/device 后 reconcile；blocked、signed-out、账号不匹配 fail closed。
3. `GroupManagementController` 在 create/add/remove 成功后触发同一 reconcile；
   leave 由剩余成员接收事件后处理，不让离开者推进新 epoch。
4. `ChatRealtimeController` 消费 `group_member_changed`，刷新成员数据并调用同一
   reconcile；重复、乱序事件不得重复推进 epoch。
5. 新增设备管理 controller 和 Settings 产品入口：列出设备、批准 pending 设备、
   撤销其他 active 设备；当前设备不展示撤销操作。
6. 批准设备后不立即 reconcile，等待目标设备发布 KeyPackage；撤销其他设备后对
   当前房间执行 reconcile；逻辑入口撤销当前设备时立即刷新 lifecycle 并离开 Ready。
7. 严格校验 protocol version 1、32 字节 credential fingerprint；错误必须可见，
   禁止回退 plaintext 或伪造操作成功。

**主要文件**

- `ios-app/App/RedCodeIOSApp.swift`
- `ios-app/Sources/RedCodeCore/E2eeDeviceManager.swift`
- `ios-app/Sources/RedCodeFeatures/E2eeSessionLifecycle.swift`
- `ios-app/Sources/RedCodeFeatures/GroupManagementController.swift`
- `ios-app/Sources/RedCodeFeatures/ChatRealtimeController.swift`
- `ios-app/Sources/RedCodeFeatures/SettingsViews.swift`
- 对应 `ios-app/Tests/` 测试

**验证与提交边界**

1. 群成员 mutation、WS 重复/乱序事件和 runtime fail-closed 测试。
2. 设备 list/approve/revoke、当前设备撤销阻断和其他设备撤销 reconcile 测试。
3. `make ios-app.test`。
4. 在 `ios-app/` 执行 Simulator App build。
5. 群事件闭环与设备管理入口可拆成两个最小提交；每个提交前执行 diff 检查，提交后
   立即 push。

**完成信号**

iOS 群成员和设备事件均进入正式应用路径，全部测试与 Simulator build 通过，相关
提交已推送；随后更新本文 `current_unit` 为 `C5-Gate`。

### C5-Gate：双端设备与群聊闭环门禁（已完成）

**目标**

证明双端语义一致并冻结 C5，不在此阶段扩展功能。

**场景**

- 第二设备批准、KeyPackage 就绪后加入已有 group。
- 撤销其他设备后 rekey，被撤销设备不能读取新 epoch。
- 群成员加入、退出、移除触发 Commit/Welcome。
- 重复/乱序 `group_member_changed` 幂等。
- epoch 缺口补拉；旧成员不可读新内容，新成员不可读加入前历史。

**验证**

```bash
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home \
  make android-app.test
make ios-app.test
make e2ee-core.check
make e2ee-core.check.targets
```

验证全绿并更新计划后进入 C7。

### C7：全仓回归门禁（已完成）

**目标**

恢复并证明 N7 依赖的全仓回归可信，避免工具链或既有模块失败污染三端协议验收。

**执行步骤**

1. 先直接运行当前基线，重新确认 Desktop 下载目录、Admin 静态资源和
   ChromeDriver 是否仍是阻断；已不复现的问题不做预防性修改。
2. 对实际复现的阻断按模块独立修复，不放宽断言，不与 E2EE 功能混合提交。
3. 验证 Native/WASM fixture、API marker scan、`make test.all` 和
   `make test.live`。
4. 原生测试继续使用 JDK 21；普通 live 不得被记录为三端 E2EE live。

**完成信号**

`make test.all`、`make test.live` 和 E2EE core/WASM 门禁全绿，所有必要修复已按
模块提交并推送；随后进入 C6。

### C6：Android、iOS、H5 三端 E2EE live

**目标**

使用三套正式客户端路径和不同 device identity，形成可重放的真实 API 跨端证据。

**执行步骤**

1. **C6.1 Android live 编译闭环。** 完成 test-local coordination HTTP 和 core
   adapter，使新增 Android live test 在默认环境下可编译并安全跳过；只运行 Android
   定向测试，不启用 E2EE runtime。完成后与 C6.2 一并提交，避免提交不可执行夹具。
2. **C6.2 H5 ↔ Android 最小互解。** 由 H5 创建账号、私聊、WebSocket 和
   coordination server；Android 使用生产 `HttpE2eeMlsApi`、
   `E2eeDeviceLifecycle`、`E2eeDirectMessageCoordinator` 发送密文，H5 经 WS/历史
   解密；H5 发送后 Android 经历史解密。断言原始历史响应不含双方 marker。
3. **C6.3 H5 ↔ iOS 最小互解。** 复用同一 coordination protocol 新增 iOS live
   client，必须经过生产 `E2eeMLSAPIClient`、lifecycle 和 direct-message coordinator，
   不复制协议算法。验证通过后独立提交并 push。
4. **C6.4 三端场景矩阵。** 在三个不同 device identity 上覆盖三端两两双向文本、
   第二会话、重启恢复、离线补拉、重复帧、损坏密文、设备撤销、群成员变化和附件；
   每类场景先证明一个最小端到端路径，再扩展到其余端组合。
5. **C6.5 runtime 与泄漏边界。** 提供独立、显式的 E2EE live 入口，不接入普通
   unit、commit hook 或默认启动链。外层驱动负责 runtime 前置检查、受控启用、
   失败清理，并以 trap/finally 在成功或失败后恢复 `persist/plaintext`。同步抽检
   DB、Redis、log、Push 和对象存储 marker，不得出现消息明文、RCST、DEK 或敏感
   身份材料。

**提交边界**

- C6.1 + C6.2：H5 ↔ Android 最小跨端闭环。
- C6.3：iOS live client 与 H5 ↔ iOS 最小跨端闭环。
- C6.4 + C6.5：完整场景矩阵、runtime 驱动和泄漏抽检；若文件跨度过大，可按
  “场景矩阵”和“验收驱动”拆成两个最小提交。
- 每个边界都必须先完成对应测试、diff 检查、commit 和 push，才进入下一边界。

**完成信号**

三端正式路径互解与泄漏抽检全部通过，命令、identity、runtime 前后状态和失败恢复
均可重放；随后进入 C8。

### C8：证据汇总与 U7 P0-1 重审

**目标**

只基于已重放的证据裁决原生客户端 P0-1，不扩大到 U7 其他 P0。

**执行步骤**

1. 更新 `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md`。
2. 更新 `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` 的 P0-1 证据。
3. 对实现和证据执行正确性、安全性、测试覆盖独立 review。
4. 只有 C5、C7、C6 全部满足时关闭 P0-1；否则保持 partial，并准确记录阻断。
5. 复核 runtime 为 `persist/plaintext`、工作区清洁、提交均已推送。

**完成信号**

验收记录与实际命令一致，P0-1 有明确裁决；即使 P0-1 关闭，U7 其余 P0 未关闭前
生产 E2EE 仍为 No-Go。

## 5. 全局约束

- 不修改已有 migration；新增持久化结构只能追加 migration。
- 不扩展服务端 E2EE API 契约；发现缺口先回 U10 总计划评估。
- E2EE 失败、身份变化、状态损坏和未知 epoch 一律 fail closed，不回退 plaintext。
- 双设备加密往返必须使用两个不同 device identity；禁止使用单设备自解密做证据。
- Android 测试固定 JDK 21；JNA 空指针传 `Pointer(0)`，不传 `Pointer.NULL`。
- iOS GRDB async 上下文使用 `try await dbQueue.read/write`。
- 每个最小闭环开始和提交前检查 `git status --short`；只 stage 本轮文件。
- 提交前执行 `git diff --check`、`git diff --cached --check` 并检查 staged diff；
  Conventional Commits 使用简体中文说明，commit 后立即 push。

## 6. Definition of Done

- D1. iOS 与 Android 均通过正式产品入口处理设备批准/撤销及群成员事件。
- D2. Commit/Welcome、epoch 缺口、重复/乱序事件和撤销设备边界均 fail closed 且有测试。
- D3. 双端测试、核心四目标、WASM、`make test.all`、`make test.live` 全绿。
- D4. Android、iOS、H5 使用不同 device identity 的三端 E2EE live 可重放。
- D5. DB、Redis、log、Push、S3 抽检不存在非预期明文或密钥材料。
- D6. runtime 在成功和失败路径后均恢复 `persist/plaintext`。
- D7. N7 验收和 U7 P0-1 重审材料更新且通过独立审查。
- D8. 所有相关提交均已推送，工作区无未解释改动；生产状态仍符合 U7 No-Go 裁决。

## 7. 进度更新规则

只有在实现、验证、提交和 push 四项全部完成后，才更新单元为“已完成”。本地代码或
单测已通过但尚未推送时仍记为“进行中”，并在“当前恢复点”写清未提交文件、已执行
命令和下一条命令。每次只保留一个 `current_unit`，不在 review、task list 或其他
plan 中维护并行进度副本。
