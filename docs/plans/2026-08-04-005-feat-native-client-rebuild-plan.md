---
title: "feat: 原生客户端重建执行计划（android-app + ios-app，弃用 Flutter app/）"
date: 2026-08-04
type: feat
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
execution: code
status: active
---

# feat: 原生客户端重建执行计划（android-app + ios-app，弃用 Flutter app/）

## Goal Capsule

- **目标：** 将 RedCode IM 2.0 客户端主线从 Flutter `app/` 切换为原生
  `android-app/`（Kotlin + Jetpack Compose）与 `ios-app/`（Swift + SwiftUI）：
  恢复已被 `e0bd4bfa` 移除的原生基座，下线 Flutter 相关工具链、CI 与文档入口，
  并让本计划成为 2.0 客户端侧唯一活跃执行主线。
- **权威顺序：** 运行时与 API 合同 > 自动化和设备验收 > 当前源码 > `im-ui-html/`
  冻结文档 > 本计划 > 历史 Flutter 实现与历史原生迁移文档。
- **首个里程碑：** 原生双端基座恢复且本机构建/单测通过；Flutter `app/` 从
  AGENTS.md、Makefile、CI 与活跃文档中全部下线。
- **执行策略：** 先恢复可编译基座，再下线 Flutter 入口，最后清理文档与目录；
  按最小可解释业务闭环拆分提交，每个闭环先验证再继续。
- **停止条件：** 本机 Android/iOS 工具链不可用且无法在合理时间补齐、基座构建
  失败且无法快速修复、或恢复过程中发现需要变更 API 合同 / WS 协议 / 共享核心
  契约时，停止对应单元并转入子计划，不在本计划内临时发明协议。
- **尾部归属：** 原生端功能迁移（聊天、联系人、群治理、E2EE 接入等）、
  `e2ee-core` JNI / xcframework 绑定（必做项，且必须在服务端 E2EE active
  前完成）、`ws.proto` 生成 Kotlin/Swift（生成细节随 Android/iOS 实际工程
  方案在后续专项落地）、双端发布链路均不在本轮范围，由后续专项计划承接。

---

## 背景与决策记录

### 决策 1：弃用 Flutter，客户端主线切换为原生

- **原因（用户裁决，2026-08-04）：** Flutter 大量 UI 写法在不同手机上触发
  GPU 兼容层问题，影响设备覆盖与稳定性，不再作为移动客户端实现方案。
- **结果：** 新增 `android-app` + `ios-app` 两个原生模块作为 2.0 客户端主线；
  移除 `app`（Flutter）模块；`h5-app/` 保留，继续作为 Web 形态与跨端验收基准。

### 决策 2：技术选型

| 维度 | Android | iOS |
|---|---|---|
| 语言 / UI | Kotlin + Jetpack Compose + Material 3 | Swift 6 + SwiftUI |
| 架构 | Single Activity + MVVM/UDF | MVVM + feature modules |
| 并发 / 网络 | Coroutines + Flow/StateFlow；Retrofit/OkHttp + OkHttp WebSocket | Swift Concurrency（async/await）+ URLSession + URLSessionWebSocketTask |
| 本地存储 | Room + Preferences DataStore + Android Keystore | GRDB/SQLite + Keychain |
| 依赖管理 | Gradle（Kotlin DSL） | Swift Package Manager |
| 测试 | JUnit + Compose UI Test + Android Lint | XCTest + XCUITest |
| 共享核心 | `e2ee-core`（Rust/OpenMLS）编译为 `.so`（JNI） | `e2ee-core` 编译为 `.xcframework` |
| 协议 | `ws.proto` 经 protoc 生成 Kotlin | `ws.proto` 经 protoc 生成 Swift |

- **跨端策略：** 不共享 UI、不引入 KMP；共享 API 契约（2.0）、`ws.proto`、
  `e2ee-core` 与视觉规范（`im-ui-html/`）。

### 决策 6：共享加密核心接入约束（必做项）

- `e2ee-core` 是 IM 2.0 端到端加密的唯一协议核心，原生双端是正式客户端，
  **必须接入**，不存在“是否引入”的取舍。
- 接入形态已定：Android 编译 `.so` 经 JNI 调用，iOS 编译 `.xcframework`
  经 Swift 调用；同一 Rust 核心，只换绑定层。
- 时间约束：服务端 E2EE 切 `active` 后，不支持 E2EE 的客户端发送会被拒绝
  （U10 R13）；因此原生端接入必须**在服务端 E2EE active 之前**完成，接入
  计划以 U10 门禁时间线为准，本轮重建只保留接口预留，不实现接入。
- `ws.proto` 生成方案不提前决策：protoc 生成 Kotlin/Swift 是方向，具体工具链、
  产物提交策略随 Android/iOS 实际工程方案在后续原生功能专项中落地。

### 决策 3：JDK 选型

- **结论：** 使用 **JDK 21 LTS** 作为 Gradle 运行版本（主流稳定，AGP 9 默认
  JBR 21、Gradle 8.14+ 支持、Kotlin 2.2 推荐）；`compileOptions` 字节码 target
  使用 **17**（保守）或 21（激进），本计划默认 17。
- 本机 / CI 统一安装 JDK 21；不引入 JDK 25 等过新工具链。

### 决策 4：版本与系统要求

- **版本号：** `android-app` / `ios-app` 按 **2.0.0** 与 App 2.0 版本面对齐
  （API 文档版本基线已是 2.0.0）。
- **最低系统：** Android `minSdk 24`（Android 7.0，覆盖约 98% 活跃设备）；
  iOS Deployment Target **15**（Xcode 26 官方支持下限，覆盖 iPhone 6s /
  SE 第一代 / 7 / 8 / X 及以后，即 2015 年后机型）。
- **iOS 存储裁决：** 因最低版本降至 iOS 15，本地存储不再使用 SwiftData
  （iOS 17+ 专属），改用 **GRDB/SQLite + Keychain**；恢复基座后需完成
  存储层替换（基座已重度使用 SwiftData）。
- **iPhone 6 明确不支持：** iPhone 6 / 6 Plus 最高只能升到 iOS 12，无法运行
  iOS 15 应用；支持 iPhone 6 需要 iOS 12，与 SwiftUI / Swift Concurrency /
  URLSessionWebSocketTask 选型硬冲突，因此不在支持范围。
- **DI：** Android 采用手动 DI（沿用恢复基座的组装方式），不引入 Hilt/Koin。

### 决策 5：基座来源

- 直接恢复提交 `e0bd4bfa` 移除前的 `android-app/`（约 200+ 文件）与
  `ios-app/`（约 80 个文件，含 RedCodeIM.xcodeproj）源码，以及 Makefile 中被
  删除的 `ios-app.*` / `android-app.*` 目标，避免重新搭骨架。
- 历史规划文档保留可复用：`docs/plans/2026-07-02-002-feat-ios-app-native-migration-plan.md`、
  `2026-07-03-001-feat-ios-app-full-flutter-parity-plan.md`、
  `2026-07-04-001-ios-app-remaining-parity-execution-list.md`、
  `2026-07-04-002-feat-android-app-native-migration-plan.md`。

> 假设说明：以上决策基于交接时已给出的推荐方案，用户答复“那可以”后按推荐值
> 写入。若审查计划时对某一条有异议，在进入执行前修改对应决策记录即可。

---

## Problem Frame

- **现状矛盾：** `docs/plans/2026-08-02-001` 是 IM 2.0 唯一活跃客户端执行计划，
  但主线是 Flutter `app/`；用户裁决弃用 Flutter 后，该主线不再成立。
- **遗留依赖：** AGENTS.md（App 设备验收顺序、真机网络规则、技术栈速查、
  H5 定位、测试命令）、Makefile（`app.*` 目标、`test.all`/`test.live` 依赖
  Flutter）、`.github/workflows/release-artifacts.yml`（Flutter app-check /
  app-build job）均以 Flutter 为客户端入口。
- **已移除基座：** `e0bd4bfa`（2026-08-04）删除了 `android-app/`、`ios-app/`
  与全部原生 Makefile 入口；源码可从 `e0bd4bfa^` 恢复，git 历史完整。
- **活跃关联计划：** `docs/plans/2026-08-04-002`（U10 E2EE 剩余工作）仍 active，
  其中 U5 设备矩阵与 Flutter/H5 联调证据需要更新为原生两端；已完成证据保留。
- **目录规模：** `app/` 约 13GB（含 build/target），git 只跟踪源码；删除前需
  用户确认，避免误删。

---

## Product Contract

### 目标状态

1. `android-app/`、`ios-app/` 存在于仓库并可通过 Makefile 入口完成本机构建、
   lint/单测。
2. `app/`（Flutter）模块移除，Flutter 不再出现在任何工具链、CI 或活跃文档入口。
3. AGENTS.md / Makefile / CI 以原生双端为客户端主线，验收顺序与真机网络规则
   继续适用并标注原生实现。
4. 活跃计划文档不再指向 Flutter 主线；`2026-08-02-001` 标记 superseded 并由
   本计划承接客户端主线。

### 非目标

- 本轮不实现原生端功能迁移（聊天、联系人、群治理、E2EE 接入、扫一扫等）。
- 本轮不接入 `e2ee-core` JNI / xcframework，不引入 `ws.proto` protobuf 生成；
  两者作为后续原生功能计划的输入（e2ee-core 为必做约束，见决策 6）。
- 不引入 KMP，不共享跨端 UI 代码。
- 不删除 `h5-app/`；`desktop/` 继续仅作为历史实现参考。
- 不重写历史 review / report 文档；只在活跃计划与入口文档中修正指向。

---

## 影响区域

- **目录：** `android-app/`、`ios-app/`（恢复）、`app/`（移除）。
- **文件：** `AGENTS.md`、`Makefile`、`.github/workflows/release-artifacts.yml`、
  `docs/index.md`、`docs/reports/task-list.md`。
- **文档：** `docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md`
  （标记 superseded + 尾部指向本计划）、`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md`
  （设备矩阵与 Flutter 引用更新）、历史 4 份原生迁移计划（保留为参考）。
- **约束：** 不修改已有数据库迁移；不改变 API / WS 合同；Conventional Commits
  subject 小写开头；每 commit 后立即 push。

---

## 阶段拆分

### 阶段 0：恢复原生基座

- 目标：`android-app/`、`ios-app/` 源码与 Makefile 原生入口恢复，本机可构建。
- 边界：只恢复基座与入口，不做功能增强。
- 验收重点：`make android-app.check`、`make ios-app.check` 本机通过。

### 阶段 1：下线 Flutter 主线入口

- 目标：AGENTS.md、Makefile、CI 不再依赖 Flutter `app/`。
- 边界：只清理入口，不重写业务规则。
- 验收重点：`make test.all` 全绿且不再调用 Flutter；CI yaml 无 Flutter job。

### 阶段 2：文档对齐

- 目标：活跃计划与入口文档指向原生客户端主线。
- 边界：历史 review/report 文档保留原样。
- 验收重点：`rg -n "Flutter|app/"` 检查活跃文档无错误指向。

### 阶段 3：移除 `app/` 模块

- 目标：删除 Flutter 源码与 13GB 本地构建产物。
- 边界：用户明确确认后执行；git 历史保留 `app/` 源码可追溯。
- 验收重点：`rg` 无 `app/` 残留引用；`make test.all` 通过。

### 阶段 4：验证与收尾

- 目标：全量回归与 review 记录。
- 验收重点：`make test.all`（可选 `make test.live`）通过，产出
  `docs/reviews/` 审查记录。

---

## 执行单元

### 单元 0.1：恢复原生源码目录

- 所属阶段：阶段 0
- 目标：恢复 `android-app/`、`ios-app/` 全部源码与工程文件。
- 涉及文件 / 模块：`git checkout e0bd4bfa^ -- android-app ios-app`（约 284 个
  文件，含 Compose UI、SwiftPM sources、Xcode 工程与双端测试）。
- 前置依赖：工作区干净（当前满足）。
- 验证方式：`git status` 显示新增目录；`git diff --cached --check` 通过。
- 完成标准：双端源码完整恢复，无部分文件遗漏。

### 单元 0.2：恢复 Makefile 原生入口

- 所属阶段：阶段 0
- 目标：恢复 `IOS_APP_DIR` / `ANDROID_APP_DIR` 变量、`.PHONY` 声明与全部
  `ios-app.*` / `android-app.*` 目标（`e0bd4bfa` 删除约 253 行）。
- 涉及文件 / 模块：`Makefile`。按 `git show e0bd4bfa -- Makefile` 的反向 diff
  手工应用，**不整体覆盖当前 Makefile**。
- 前置依赖：单元 0.1。
- 验证方式：`make help | rg "android-app|ios-app"` 能看到目标；`make -n
  android-app.check`、`make -n ios-app.check` 可解析。
- 完成标准：入口恢复且不影响现有 api/admin/h5-app/desktop 目标。

### 单元 0.3：更新原生模块 README 定位

- 所属阶段：阶段 0
- 目标：两模块 README 从“Flutter 并行迁移”更新为“2.0 原生主线”，记录版本
  2.0.0、JDK 21、minSdk 24 / iOS 15+、手动 DI、GRDB/SQLite 与原生验收规则。
- 涉及文件 / 模块：`android-app/README.md`、`ios-app/README.md`。
- 前置依赖：单元 0.1。
- 验证方式：README 无“Flutter 并行开发”表述，无指向 `app/` 的错误命令。
- 完成标准：README 与决策记录一致。

### 单元 0.4：对齐 Android 构建配置

- 所属阶段：阶段 0
- 目标：恢复基座后把 `android-app/app/build.gradle.kts` 的 `minSdk` 从 26
  调整为 **24**；`compileSdk/targetSdk` 维持 36；Gradle 使用本机/CI 的
  **JDK 21** 运行，`jvmToolchain` / `compileOptions` 字节码 target 维持 17。
- 涉及文件 / 模块：`android-app/app/build.gradle.kts`。
- 前置依赖：单元 0.1、0.2。
- 验证方式：`make android-app.check`（unit + lint + debug APK）本机通过；
  `minSdk` 生效配置可通过 Gradle 输出确认。
- 完成标准：Android 侧构建配置与决策记录一致。

### 单元 0.5：iOS 存储层 SwiftData 替换为 GRDB/SQLite

- 所属阶段：阶段 0
- 目标：基座已重度使用 SwiftData（`App/RedCodeIOSApp.swift`、
  `Sources/RedCodeStorage` 中多个 `SwiftData*Store`、`RedCodeStorageSchema`
  与相关测试），iOS 15 无法编译 SwiftData；本单元将存储层替换为
  **GRDB/SQLite**，并设置 Xcode 工程 Deployment Target 为 **iOS 15**。
- 涉及文件 / 模块：`ios-app/App/`、`ios-app/Sources/RedCodeStorage/`、
  `ios-app/Tests/RedCodeStorageTests/`、`ios-app/RedCodeIM.xcodeproj`、
  `ios-app/docs/`（architecture 等引用同步更新）。
- 前置依赖：单元 0.1、0.2。
- 验证方式：`make ios-app.check`（SwiftPM unit tests + Simulator build）在
  Deployment Target 15 下通过；SwiftUI 新 API（如 NavigationStack）按
  `@available` 分支处理，编译无 iOS 15 不可用符号。
- 完成标准：iOS 侧不再引用 SwiftData，iOS 15 可编译、单测通过。

### 单元 1.1：更新 AGENTS.md

- 所属阶段：阶段 1
- 目标：App 设备验收顺序改为原生双端（Android Emulator + iOS Simulator，默认
  iOS Simulator 策略保留）；真机 LAN IP 规则注明适用原生双端；技术栈速查移动端
  改为 `android-app/`（Kotlin/Compose）与 `ios-app/`（Swift/SwiftUI）；H5 定位
  由“Flutter app/ 的 Web 版本”改为“以 `im-ui-html/` 设计源与原生双端为参考”；
  测试命令改为 `make android-app.test` / `make ios-app.test`。
- 涉及文件 / 模块：`AGENTS.md`。
- 前置依赖：单元 0.2。
- 验证方式：全文无 Flutter 客户端主线表述（保留 E2EE `e2ee-core` Flutter FFI
  历史说明时需标注为历史交付物）。
- 完成标准：AGENTS.md 与原生主线一致。

### 单元 1.2：清理 Makefile Flutter 入口

- 所属阶段：阶段 1
- 目标：移除 `app.*` Flutter 目标（`app.test.*`、`app.build.*`、`app.proto`
  等），`test.all` / `test.live` 依赖改为原生双端检查（`android-app.test.unit`、
  `ios-app.test` 等），保留 api/admin/h5-app/desktop 回归。
- 涉及文件 / 模块：`Makefile`。
- 前置依赖：单元 0.2、单元 1.1。
- 验证方式：`make test.all` 全绿；`make -n test.all` 输出无 `flutter`。
- 完成标准：仓库回归入口不再依赖 Flutter。

### 单元 1.3：更新 CI 发布工作流

- 所属阶段：阶段 1
- 目标：`release-artifacts.yml` 中 Flutter `app-check` / `app-build` job 替换为
  原生双端 job：Android（JDK 21 + Gradle `test`/`lint`/`assembleDebug`）、iOS
  （macOS runner `xcodebuild build-for-testing`；若 runner 资源不可用先按
  `desktop-check` 的 `if: false` 模式保留定义）。
- 涉及文件 / 模块：`.github/workflows/release-artifacts.yml`。
- 前置依赖：单元 0.1、0.2。
- 验证方式：yaml 语法可用（`ruby -e 'require "yaml"; YAML.load_file(...)'` 或
  GitHub Actions 校验）；无 Flutter 引用。
- 完成标准：CI 与原生主线一致，发布门禁不依赖 Flutter。

### 单元 2.1：迁移活跃客户端计划

- 所属阶段：阶段 2
- 目标：`2026-08-02-001` 标记 `status: superseded`，Goal Capsule 尾部归属改为
  “客户端主线已切换为原生，见 `2026-08-04-005`”；已完成 U1-U9 证据保留。
- 涉及文件 / 模块：`docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md`。
- 前置依赖：阶段 1 完成。
- 验证方式：文档状态与执行状态总账无冲突。
- 完成标准：活跃计划关系清晰，无两个 active 客户端主线。

### 单元 2.2：更新 E2EE 剩余计划

- 所属阶段：阶段 2
- 目标：`2026-08-04-002` 中 U5 之后的设备矩阵与联调表述从 Flutter/H5 更新为
  原生双端/H5；已完成证据（Flutter/H5 双向联调）标注为历史基线。
- 涉及文件 / 模块：`docs/plans/2026-08-04-002-feat-u10-e2ee-remaining-work-plan.md`。
- 前置依赖：无（可与 2.1 并行）。
- 验证方式：计划内设备矩阵无 Flutter 主线表述。
- 完成标准：E2EE 计划与原生主线一致，不阻塞 U4-U9 后续执行。

### 单元 2.3：清理全库入口文档

- 所属阶段：阶段 2
- 目标：`docs/index.md`、`docs/reports/task-list.md` 等技术栈/任务入口更新为
  原生双端；全库活跃文档中指向 `app/` Flutter 的引用修正。
- 涉及文件 / 模块：`docs/index.md`、`docs/reports/task-list.md` 及阶段 1、2
  未覆盖的活跃文档。
- 前置依赖：单元 2.1。
- 验证方式：`rg -n "Flutter|app/" docs AGENTS.md Makefile .github` 复核，仅
  允许历史/参考性表述。
- 完成标准：入口文档与原生主线一致。

### 单元 3.1：删除 `app/` 模块

- 所属阶段：阶段 3
- 目标：`git rm -r app` 删除 Flutter 源码；`rm -rf app/build app/.dart_tool`
  等 13GB 本地构建产物；检查 `.gitignore` 无残留 app 规则。
- 涉及文件 / 模块：`app/`。
- 前置依赖：阶段 1、2 完成且用户明确确认。
- 验证方式：`rg -n "app/|flutter"` 入口文件无残留；`make test.all` 通过。
- 完成标准：Flutter 模块完全下线，git 历史可追溯。

### 单元 4.1：全量回归

- 所属阶段：阶段 4
- 目标：`make test.all` 全绿；可选 `make test.live` 验证原生端真实后端 smoke。
- 前置依赖：全部单元完成。
- 验证方式：命令退出码 0，报告落盘。
- 完成标准：仓库回归与发布门禁不依赖 Flutter。

### 单元 4.2：review 与方案沉淀

- 所属阶段：阶段 4
- 目标：产出 `docs/reviews/` 审查记录（对照本计划逐单元核验），必要时
  `docs/solutions/` 沉淀“Flutter -> 原生方向切换清理清单”。
- 前置依赖：单元 4.1。
- 验证方式：review 文档覆盖全部单元与验收标准。
- 完成标准：本计划标记 completed。

---

## 建议执行顺序

- **先做：** 单元 0.1 -> 0.2 -> 0.3 -> 0.4 -> 0.5（基座先回来，随时可回滚到
  `e0bd4bfa^`；Android 先对齐配置，iOS 先完成 SwiftData -> GRDB 存储替换，
  两端都能在本机构建后再进入阶段 1）。
- **再做成：** 单元 1.1 -> 1.2 -> 1.3（先让本地与 CI 不依赖 Flutter，再动文档）。
- **随后：** 单元 2.1 / 2.2 / 2.3；**单元 3.1 需用户确认后单独执行。**
- **收尾：** 单元 4.1 -> 4.2；完成 4.2 后进入 `review`。

## 提交拆分建议

1. `docs(plans): 新增原生客户端重建执行计划`（本 commit）
2. `feat(app): 恢复 android-app/ios-app 原生基座与 Makefile 入口`（阶段 0）
3. `chore(app): 下线 Flutter app 模块入口（AGENTS.md/Makefile/CI）`（阶段 1）
4. `docs(app): 客户端主线对齐原生并清理文档引用`（阶段 2）
5. `chore(app): 删除 Flutter app 模块目录`（阶段 3，用户确认后）

## 风险与回滚

- **Makefile 覆盖风险：** 恢复入口时不得整体覆盖当前 Makefile；用 `git show
  e0bd4bfa -- Makefile` 反向 diff 手工恢复，冲突时停止并核对。
- **`app/` 删除不可逆：** 删除前必须用户确认；git 历史中 `app/` 源码仍可恢复，
  本地 13GB 构建产物删除后不可恢复（确认后再删）。
- **本机工具链：** 需验证 JDK 21、Android SDK/Emulator、Xcode 26.6 / Swift
  6.3.3 可用；缺失时先补齐工具链再执行阶段 0 验收。
- **基座构建阻塞：** 恢复后若 Android/iOS 构建失败，先修复构建问题再进入阶段 1，
  不停顿主线；无法修复时回滚到本计划前状态并在文档记录阻塞点。
- **活跃计划冲突：** 若 2.1 中 `2026-08-02-001` 仍有未关闭执行项，先迁移到
  对应子计划（如 E2EE -> `2026-08-04-002`）再标记 superseded。

## Definition of Done

- [ ] `android-app/`、`ios-app/` 恢复且 `make android-app.check` /
  `make ios-app.check` 本机通过。
- [ ] `app/` 模块移除，Flutter 不出现于 AGENTS.md / Makefile / CI / 活跃文档入口。
- [ ] `make test.all` 全绿且不再依赖 Flutter。
- [ ] `2026-08-02-001` 标记 superseded，`2026-08-04-002` 设备矩阵已更新。
- [ ] review 记录产出，本计划按步骤完成并标记 completed。
