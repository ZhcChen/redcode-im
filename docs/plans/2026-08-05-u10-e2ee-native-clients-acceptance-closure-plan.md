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
current_unit: A2.3
last_progress_update: 2026-08-05
---

# test: U10 E2EE 原生客户端验收收口计划

## 1. 计划定位

本文是 U10 E2EE 原生客户端剩余工作的**唯一执行入口、唯一进度总账和唯一恢复点**。
后续不得创建平行收口计划；每个实施单元只有在实现、验证、提交并推送后才更新为
“已完成”。

当前执行链：

`A2.3 跨端附件 -> A3 泄漏与恢复抽检 -> A4 证据重审`

N1-N6、C1-C5、A1、A2.1 和 A2.2 已完成，不再重复实施。生产 E2EE 始终保持
**No-Go**；本计划最终只裁决 U7 P0-1，不能替代 U7 其余 P0 的发布裁决。

## 2. 文档边界

| 文档 | 当前职责 | 是否派发任务 |
| --- | --- | --- |
| 本计划 | 当前进度、恢复点、剩余单元、提交边界与 DoD | 是 |
| `docs/plans/2026-08-05-u10-e2ee-native-clients-final-closure-plan.md` | C1-C7 历史实施记录 | 否，已 superseded |
| `docs/plans/2026-08-05-u10-e2ee-native-clients-plan.md` | N1-N7 原始设计 | 否，已 superseded |
| `docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` | U10 产品合同及服务端契约来源 | 仅发现契约缺口时回查 |
| `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md` | N7 验收事实 | A4 更新 |
| `docs/reviews/2026-08-05-u10-e2ee-u7-security-review.md` | U7 安全裁决 | A4 只更新 P0-1 |

## 3. 当前进度

### 3.1 已完成并推送

| 单元 | 状态 | 提交与关键证据 |
| --- | --- | --- |
| N1-N6 / C1-C5 | 已完成 | FFI、安全存储、设备生命周期、消息主链、多设备、群聊、附件及应用装配均已接入 |
| 三端基础 live | 已完成 | `3d8a47d6`、`3850229e`、`0ed7e126`；H5 与 Android/iOS 正式路径互解，受控入口自动恢复 runtime |
| A1 原生双端直接互解 | 已完成 | `c4cfb0c6`；Android 与 iOS 使用不同 account/device identity 双向互解，历史无 marker |
| A2.1 恢复与异常边界 | 已完成 | `88d994cd`；安全状态恢复、离线历史补拉、消息 ID 去重、损坏密文 fail closed |
| A2.2 设备与群成员 rekey | 已完成 | `5669870f`；设备批准/撤销、成员 add/remove、epoch 推进及旧成员不可读新 epoch |

### 3.2 当前在途：A2.3 跨端附件

当前工作区的十个修改文件和一个新增 migration 全部属于 A2.3，禁止丢弃、重置或
混入无关提交：

- API：`api/sql/migrations/20260805193000_message_attachment_commits.sql`、
  `api/src/database/file_upload_store.rs`、`api/src/database/message_store.rs`、
  `api/src/database/mod.rs`、`api/src/handlers/message.rs`、
  `api/tests/database_migration_smoke.rs`、`api/tests/websocket_integration.rs`。
- H5：`h5-app/src/services/message-attachment-upload-service.ts`、
  `h5-app/test/message-attachment-upload-service.test.ts`、
  `h5-app/test/e2ee-live-backend.test.ts`。
- Android：
  `android-app/app/src/test/java/com/redcode/im/androidapp/live/AndroidE2eeCrossClientLiveTest.kt`。

已完成但尚未提交的实现：

1. H5 E2EE 附件签名和 commit 使用 AES-GCM 密文大小，消息展示仍保留明文大小。
2. API 追加 `message_attachment_commits` 持久授权；下载仅接受当前 room 前缀及已
   commit 的 object key，GC 引用检查同步纳入该表。
3. H5 上传密文并通过 MLS payload 传递 DEK/nonce/AAD 元数据；Android 使用正式
   历史入口取得附件信息、下载密文并在内存解密；错误 object key AAD 必须失败。
4. API migration manifest 已更新至 12；`make api.test` 已全量通过，包含 unit
   184/184、migration、E2EE marker 和 WebSocket integration。
5. `make h5-app.check` 及附件上传定向测试 3/3 已通过；A2.3 最终提交前仍须按
   第 5 节重跑完整验证。

### 3.3 未开始

| 单元 | 状态 | 依赖 |
| --- | --- | --- |
| A3 外围泄漏抽检与失败恢复 | 待开始 | A2.3 三个提交均已推送 |
| A4 N7 证据与 U7 P0-1 重审 | 待开始 | A3 完成且无未解决 P0/P1 |

## 4. 剩余实施单元

### A2.3：跨端附件闭环

**目标**

证明 H5 上传的 E2EE 附件只以密文进入 S3 兼容存储，Android 经正式历史链下载并
在内存解密，同时服务端能在不解析 MLS payload、不扩展 E2EE API 契约的前提下
执行 room 级下载授权和对象回收保护。

**执行顺序**

1. 重启 API dev 容器以应用新增 migration，确认 `/healthz` 正常且 runtime 为
   `persist/plaintext`。
2. 运行 `make e2ee.cross-client.live`；要求全部场景通过，附件 plaintext marker
   不出现在消息历史或对象密文中，错误 AAD fail closed，结束后 runtime 恢复。
3. 运行 H5、Android 和 API 门禁以及 diff 检查。
4. 按以下边界提交并在每个 commit 后立即 push：

| 顺序 | 提交闭环 | 文件边界 | 建议提交说明 |
| --- | --- | --- | --- |
| 1 | API room 附件持久授权 | migration、API store/handler 及 API tests | `feat(api): 持久化 E2EE 附件下载授权` |
| 2 | H5 密文大小修复 | upload service 及其 unit test | `fix(h5-app): 对齐 E2EE 附件密文大小` |
| 3 | H5 -> Android 跨端附件 live | H5 live test、Android live test | `test(e2ee): 覆盖 H5 Android 跨端附件` |

提交 1 与提交 2 都是提交 3 的前置依赖；不得为了制造独立提交而回退已验证行为。

### A3：泄漏抽检与 runtime 恢复

**目标**

证明文本和附件互解不以 DB、Redis、日志、Push 或对象存储泄漏明文及密钥材料为
代价，并证明成功、故意失败、INT、TERM 后 runtime 均恢复 `persist/plaintext`。

**实施范围**

1. 为文本和附件生成唯一 marker，记录 run ID、room、message、object key 和
   runtime 前后状态；禁止记录 token、DEK、nonce 或私钥。
2. 抽检 PostgreSQL 消息/控制消息、Redis cache/pubsub、API 日志、Push mock 和
   S3 兼容对象；对象存储只允许 ciphertext。
3. plaintext marker、附件明文、RCST、DEK、nonce 和 credential 私钥不得出现在
   非预期服务端位置。
4. 增加可重放的故意失败、INT、TERM 恢复验证；失败必须非零退出且不残留
   `persist/e2ee`。
5. 测试实现与验收证据分开提交并逐个 push。

**主要文件**

- `tests/scripts/run-e2ee-cross-client-live.sh`
- `tests/scripts/scan-e2ee-log-denylist.sh`
- `api/tests/e2ee_marker_scan.rs` 或现有等价 marker 测试
- `docs/reviews/2026-08-05-u10-e2ee-native-clients-n7-acceptance.md`

### A4：证据汇总与 U7 P0-1 重审

**目标**

以 A1-A3 和最终门禁的真实结果更新 N7，只裁决原生客户端 P0-1。

**实施范围**

1. 更新 N7 验收记录，写明命令、三端 identity、场景矩阵、runtime 前后状态、
   marker 与 S3 抽检结果。
2. 只更新 U7 安全审查中的 P0-1 证据，不改写其他 P0 状态。
3. 对最终 diff 执行 correctness、security、testing review；所有 P0/P1 必须修复并
   重跑相关门禁。
4. 运行最终全量门禁，确认提交均已 push、工作区无未解释改动。
5. 即使 P0-1 关闭，生产 E2EE 仍标记 **No-Go**，等待 U7 其余 P0 独立关闭。

## 5. 验证矩阵

### A2.3 提交前

```bash
docker compose -f api/docker/dev/docker-compose.yml restart api
curl -fsS http://127.0.0.1:8010/healthz
make e2ee.cross-client.live
make api.test
make h5-app.check
make h5-app.test.unit
JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home \
  ./android-app/gradlew -p android-app testDebugUnitTest lintDebug
git diff --check
```

### A4 最终门禁

```bash
make e2ee.cross-client.live
make e2ee-core.check
make e2ee-core.check.targets
make test.all
make test.live
git diff --check
git status --short
```

## 6. 执行约束

- 禁止修改已有 migration；新增持久化结构只能追加 migration。
- 不扩展服务端 E2EE API 契约；发现缺口先回产品合同评估。
- E2EE 错误、身份变化、状态损坏及未知 epoch 一律 fail closed，不回退 plaintext。
- 双端往返必须使用不同 device identity；禁止单设备自解密。
- Android 固定 JDK 21；JNA 空指针使用 `Pointer(0)`。
- iOS GRDB async 上下文使用 `try await dbQueue.read/write`。
- live 入口不得接入默认测试、commit hook、CI 或普通启动链。
- 每个提交前检查 status、unstaged/staged diff 及 `git diff --check`；只 stage 当前
  闭环文件，使用简体中文 Conventional Commits，commit 后立即 push。

## 7. Definition of Done

- D1. Android、iOS、H5 三端两两双向文本均经正式客户端路径互解。
- D2. 新会话、重启恢复、离线补拉、重复帧和损坏密文具有可重放证据。
- D3. 设备撤销和群成员变化正确推进 epoch，失权设备/成员不可读新内容。
- D4. 跨端附件使用随机 DEK/nonce 和绑定 AAD，错误绑定及损坏密文 fail closed。
- D5. DB、Redis、log、Push 和 S3 抽检不存在非预期明文或密钥材料。
- D6. live 成功、失败、INT 和 TERM 后 runtime 均恢复 `persist/plaintext`。
- D7. core、API、Android、iOS、H5、`make test.all` 和 `make test.live` 全绿。
- D8. N7 与 U7 P0-1 证据同真实结果一致，独立审查无未解决 P0/P1。
- D9. 所有提交均已推送，工作区无未解释改动；生产 E2EE 仍为 **No-Go**。
