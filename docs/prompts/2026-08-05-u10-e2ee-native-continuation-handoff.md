# u10 E2EE 原生双端接入：N4–N7 续接提示词

> 用途：将 redcode-im 仓库的 E2EE 原生双端剩余工作（N4–N7）交接给新的
> AI 会话。直接复制下方「任务提示词」整段给新会话即可。

## 任务提示词（复制此段）

你是 redcode-im 仓库的 AI 工程师。请先阅读 `AGENTS.md`（全局行为准则、提交
规范、测试入口）和 `docs/plans/2026-08-05-u10-e2ee-native-clients-plan.md`
（u10 E2EE 原生双端接入专项执行计划，含 Implementation Units N1–N7 与
DoD D1–D7）。当前工作区目录：`/Users/chen/code/redcode-im`。

### 当前进度（N1–N3 已完成并推送，不要重做）

- N1 FFI 集成与命令封装：`1b4c49b0`、`c06c4056`、`29f75d47`
- N2 安全状态存储：`801d0bc7`（Android Keystore+AES-GCM）、
  `71fa0f76`（iOS Keychain+CryptoKit）
- N3 设备生命周期与 KeyPackage 补充：`9695150b`（Android）、
  `dbd879cb`（iOS）
- 验证基线：Android JVM 单测 188/188 通过；iOS `swift test` 174/174 通过
  （7 项 live 跳过）；`make e2ee-core.check` 与 `make e2ee-core.check.targets`
  四目标构建通过。

### 剩余任务（按计划文档顺序执行）

1. **N4 单聊直接消息**：创建/恢复 MLS group、claim 对端 KeyPackage、
   encrypt/decrypt、commit/welcome 处理、WS 与历史统一解密入口、按消息 ID
   去重、身份变化阻断；第二个新会话、重启恢复、离线补拉、重复帧、历史混排、
   损坏密文 fail closed。对齐参考：
   `h5-app/src/e2ee/direct-message-coordinator.ts`、
   `h5-app/src/services/e2ee-mls-api-service.ts`、
   `h5-app/src/services/e2ee-identity-service.ts`。
2. **N5 多设备与群聊**：第二设备批准/撤销后 rekey、add/remove member、
   成员变化 commit/welcome 消费、epoch 缺口补拉、撤销设备不可读新 epoch。
   对齐参考：`h5-app/src/e2ee/device-manager.ts`、`h5-app/src/e2ee/group-*.ts`。
3. **N6 附件与外围边界**：每附件随机 DEK/nonce 加密上传、下载内存解密、
   AAD 绑定 room/part/object key；Push 占位、搜索/转发/引用降级；本地搜索
   只索引解密内容。对齐参考：`h5-app/src/e2ee/attachment-crypto.ts`。
4. **N7 跨端 live 验收与发布证据**：Android × iOS × H5 三端互解；DB/Redis/
   log/Push marker 抽检；更新 `docs/reviews/` 与 U7 重审材料（P0-1 关闭
   证据）。生产 E2EE 保持 No-Go 直至 U7 其余 P0 关闭。

### 已就绪的关键资产（不要重复造）

- 共享核心 C ABI：`e2ee-core/include/e2ee_core.h`；构建：
  `./e2ee-core/build-mobile.sh host|android|ios|all`；Android `.so` 已拷入
  `android-app/app/src/main/jniLibs/`
- Android：`E2eeCommandClient`、`E2eeSecureStateStore`、
  `E2eeDeviceLifecycle`、`HttpE2eeMlsApi`（`android-app/.../e2ee/`）
- iOS：`E2eeCommandClient`、`E2eeSecureStateStore`、`E2eeDeviceLifecycle`、
  `E2eeMLSAPIClient`（`ios-app/Sources/RedCodeCore|Storage|Networking`）
- 命令编号与字段契约：`e2ee-core/src/command.rs`（Initialize 7 字段、
  GenerateKeyPackage 2 字段、PublicMaterial 6 字段、CreateGroup/AddMember/
  JoinGroup/Encrypt/Decrypt/ProcessCommit/RemoveMember 详见该文件）
- RCCQ/RCCR 编解码：`h5-app/src/e2ee/session.ts` 与两端 `E2eeCommandClient`
- API 端点：`api/src/routes.rs` 中 `/e2ee/mls/*` 全部已就绪
  （devices/identities/key-packages/claim/control-messages/epoch）

### 硬性约束与已知坑

- 语言：文档、讨论、提交说明用简体中文，技术术语保留原文。
- 禁止修改已有迁移文件：Android Room 新增变更用 `MIGRATION_x_y` 追加；
  iOS GRDB 用新的 `registerMigration("vN-...")`（已存在 v1、v2-e2ee-blobs）。
- 双设备加密往返测试必须使用两个不同 device identity；单设备自解密会报
  `Cannot decrypt own messages`。
- Android 单元测试必须用 JDK21：
  `JAVA_HOME=/Users/chen/Library/Java/JavaVirtualMachines/azul-21.0.10/Contents/Home`
  （JDK26 会直接失败）。
- JNA 5.17 的 `Pointer.NULL` 实为 `null`，Kotlin 平台类型空检查会抛
  `NULL must not be null`；传 `Pointer(0)` 代替。
- iOS GRDB 7 在 async 上下文里 `dbQueue.read/write` 会解析到 async 重载，
  需要 `try await`。
- 不扩展服务端契约：发现缺口先回
  `docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md` 评估。
- 提交：Conventional Commits，按模块/平台拆分最小可解释闭环；提交前跑
  `git diff --check`、对应模块测试；commit 后立即 push。

### 每单元验收命令

- Android：`JAVA_HOME=... ./android-app/gradlew -p android-app testDebugUnitTest`
- iOS：`cd ios-app && swift test`
- 核心：`make e2ee-core.check && make e2ee-core.check.targets`
- 全量：`make test.all`

按 N4 → N5 → N6 → N7 顺序执行，每个单元完成测试、提交、推送后再进入下一个。

## 上下文速查

- 计划文档：`docs/plans/2026-08-05-u10-e2ee-native-clients-plan.md`
- 上游契约基线：`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md`
- 跨端互操作 fixture：`e2ee-core/interop/fixtures/native_to_wasm.bin` 与
  `e2ee-core/examples/cross_runtime_fixture.rs`
- 测试流程总览：`docs/reference/testing/README.md`
- 任务清单：`docs/reports/task-list.md`
