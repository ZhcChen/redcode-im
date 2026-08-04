# 原生客户端重建执行计划 Review（2026-08-04-005）

- 审查日期：2026-08-04
- 审查对象：`docs/plans/2026-08-04-005-feat-native-client-rebuild-plan.md`
- 审查方式：对照计划执行单元逐项核验（构建/单测/回归/文档扫描）
- 结论：**completed**，客户端主线已切换为原生双端，Flutter `app/` 已下线并移除。

## 提交记录

| commit | 范围 |
| --- | --- |
| `dca34e7f` | 新增原生客户端重建执行计划 |
| `a9dfa54b` | Android 最低系统调整为 Android 7（minSdk 24） |
| `655133b6` | iOS 最低支持调整为 15 并改用 GRDB/SQLite |
| `a1f5da52` | 明确 e2ee-core 原生接入为必做约束 |
| `4f218ea5` | 阶段 0：恢复原生基座并对齐 2.0 技术决策 |
| `345d0f56` | 阶段 1：下线 Flutter 入口（AGENTS.md/Makefile/CI） |
| `5b684516` | 阶段 2：客户端主线对齐原生并清理文档引用 |
| `cb2d399d` | 阶段 3：删除 Flutter app 模块目录 |

## 逐单元核验

### 阶段 0：恢复原生基座

- 单元 0.1 恢复源码：`android-app/` + `ios-app/` 共 284 文件恢复，git 历史核对完整。
- 单元 0.2 恢复 Makefile 入口：`ios-app.*` / `android-app.*` 目标与变量恢复，未影响
  api/admin/h5-app/desktop 目标。
- 单元 0.3 README：两模块 README 已更新为 2.0 原生主线。
- 单元 0.4 Android 配置：`minSdk=24`、JDK 21 运行 Gradle、字节码 target 17、
  core library desugaring、Gradle wrapper 8.12。
- 单元 0.5 iOS 存储：SwiftData 全部替换为 GRDB/SQLite，Deployment Target 15，
  iOS 15 兼容改造（ObservableObject、NavigationView 回退、PHPicker 等）。
- 验证：`JAVA_HOME=azul-21 make android-app.check` BUILD SUCCESSFUL；
  `make ios-app.check` SwiftPM 154 tests + Simulator BUILD SUCCEEDED。

### 阶段 1：下线 Flutter 主线入口

- 单元 1.1 AGENTS.md：移动端测试命令、设备验收顺序、真机 LAN IP 规则、H5 定位、
  技术栈速查全部切换为原生双端。
- 单元 1.2 Makefile：删除全部 `app.*` 目标与 FLUTTER/PATROL 变量；
  `test.all` 改用 `android-app.test.unit` + `ios-app.test`；
  `test.live` 改用原生双端 live smoke；`e2ee-core.test.flutter` 标注历史交付物。
- 单元 1.3 CI：移除 Flutter `app-check`/`app-build`，新增 `android-app-check`
  （JDK 21 + Gradle test/lint/assembleDebug）与 `ios-app-check`（`if: false` 预留）。
- 验证：`make -n test.all` 无 flutter 调用；YAML 解析通过。

### 阶段 2：文档对齐

- 单元 2.1：`2026-08-02-001` 标记 `status: superseded`，尾部归属指向
  `2026-08-04-005`，U1-U9 证据保留。
- 单元 2.2：`2026-08-04-002` 全部未来验收表述改为原生双端/H5，Flutter 证据标注
  历史基线。
- 单元 2.3：`docs/index.md`、`docs/reports/task-list.md`、测试/构建/架构等活跃
  入口全部对齐；`remaining-task-breakdown` 标注历史归档。
- 验证：`rg` 全库复核，剩余 Flutter 引用均为历史/参考语义；active 计划无冲突
  （客户端主线仅 `2026-08-04-005`）。

### 阶段 3：移除 `app/` 模块

- 单元 3.1：`git rm -r app` 删除 475 个跟踪文件（87,868 行）；13GB 本地构建产物
  `mv` 到 `/tmp/redcode-app-trash-20260804`（可恢复暂存）；根 `.gitignore` 无残留
  app 规则；入口文件无 `app/` 残留引用。
- 已提交推送：`cb2d399d`。

### 阶段 4：全量回归

- 单元 4.1：`make test.all` 实跑。api.test / api.test.smoke / api.migration.guard /
  android-app.test.unit / ios-app.test / admin.check / admin.test.routes /
  desktop.check / h5-app.check / h5-app.test.unit（218 passed） / website.test.unit /
  tests.compose.config / tests.mocks.external / tests.tooling / tests.perf.check
  全部通过。
- 已知问题（与本计划无关）：`desktop.test.unit` 的
  `test/utils/download-settings.test.ts` 1 项失败（`getDownloadDir` 返回
  `Desktop/Chatly` 而非保存目录）。已在 HEAD 基线复现，属 main 上既有失败；
  用户裁决 desktop 暂不处理，未纳入本计划。

## Definition of Done 核验

- [x] `android-app/`、`ios-app/` 恢复且 `make android-app.check` /
  `make ios-app.check` 本机通过。
- [x] `app/` 模块移除，Flutter 不出现于 AGENTS.md / Makefile / CI / 活跃文档入口。
- [x] `make test.all` 不再依赖 Flutter（唯一失败为既有 desktop 测试，与本次无关）。
- [x] `2026-08-02-001` 标记 superseded，`2026-08-04-002` 设备矩阵已更新。
- [x] review 记录产出，本计划按步骤完成并标记 completed。

## 后续输入（不在本轮范围）

- 原生双端功能迁移（聊天、联系人、群治理、扫一扫等）。
- `e2ee-core` JNI / xcframework 接入（必做，须在服务端 E2EE active 前完成）。
- `ws.proto` 生成 Kotlin/Swift 方案落地。
- iOS `ios-app-check` CI 恢复与双端发布链路。
- desktop 既有测试失败修复（用户裁决暂缓）。
