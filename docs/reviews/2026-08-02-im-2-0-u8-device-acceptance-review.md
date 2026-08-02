# Flutter 2.0 U8 移动设备验收记录

## 当前结论

U8 尚未完成。Android 15 Emulator 已通过 Flutter 静态检查、全量单测、Patrol 登录与四 Tab 主导航，以及真实 API 认证和核心合同测试，可作为 Android 补充证据；但它不替代仓库规定的默认设备验收。

iPhone 17 Pro Simulator 可被 Flutter 识别，但本机 Xcode 26 build service 在构建描述阶段持续卡住，因此目前不能证明系统键盘、安全区、权限拒绝/恢复、前后台切换和离线恢复已在默认设备策略下通过。

## 验收环境

- 日期：2026-08-02
- 补充设备：Android 15 Emulator，`emulator-5554`，API 35，arm64
- API：`http://10.0.2.2:8010`
- WebSocket：`ws://10.0.2.2:8010/ws`
- 默认设备：iPhone 17 Pro Simulator `EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`，构建阻塞

## 已通过证据

- `make app.check`：通过，无 analyze 问题。
- `make app.test`：324 项通过。
- `make app.test.integration.smoke APP_TEST_DEVICE=emulator-5554`：2 项通过。
- `make app.test.patrol.harness PATROL_DEVICE=emulator-5554`：1 项通过。
- `make app.test.patrol.login PATROL_DEVICE=emulator-5554`：1 项通过；覆盖账号密码输入、mock 登录、聊天/联系人/发现/我的四 Tab、联系人固定入口、设置与账号安全二级路由、两次 Android 系统返回，以及 Home/最近任务前后台恢复。
- `make app.test.integration.device.auth APP_TEST_DEVICE=emulator-5554`：真实 API 注册、登录、刷新和登出通过。
- `make app.test.integration.device.contract APP_TEST_DEVICE=emulator-5554`：三账号认证、好友、群、消息、设置、隐私协议、反馈和上传策略合同通过。

## 默认设备复核

- `make app.test.patrol.harness PATROL_DEVICE=EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`：iPhone 17 Pro Simulator 构建持续 119.1 秒未进入测试执行阶段，终止后报告 `xcodebuild was interrupted`，本次没有测试通过证据。
- 终止后未残留 `xcodebuild`、`XCBBuildService` 或 Patrol 测试进程。

### iOS 构建阻塞定位

- Xcode 26.6（17F113）、iPhoneSimulator 26.5 SDK、`xcrun clang` 和 `xcodebuild -showBuildSettings` 均可在 1 秒内完成，排除 SDK 缺失、基础 clang 故障和工程无法解析。
- Patrol CLI 4.3.0 的实际命令停在 `xcodebuild build-for-testing` 的 `CreateBuildDescription`，现场子进程为多条 `clang -v -E -dM` capability probe。
- 对 clang 子进程采样显示主线程持续阻塞在 `llvm::raw_fd_ostream::write_impl -> write`；同一条 clang 命令脱离 SwiftBuild 后约 0.02 秒完成。
- 去掉 Patrol 固定的 `-quiet`、使用 `2>&1 | tee` 持续排空输出、通过 launchd 洁净 FD 启动，以及增加 `-jobs 1 ONLY_ACTIVE_ARCH=YES ARCHS=arm64` 并指定具体 Simulator，均在同一阶段复现。
- 该行为与 Xcode 26.x 已公开的 SwiftBuild planning pipe deadlock 特征一致：<https://github.com/getsentry/XcodeBuildMCP/issues/492>。当前证据指向本机 Xcode Build Service，而不是 RedCode IM 源码、Pods 或 Patrol 测试逻辑。

## 本轮修复

Patrol 登录 smoke 原先仍查找旧版“设置”Tab，且测试壳未注册正式命名路由。现已使用 `AppRouter.onGenerateRoute` 进入真实 App Shell，显式输入账号密码，并将断言更新为 2.0 的“聊天、联系人、发现、我的”信息架构。后续扩展覆盖联系人和发现页面、我的设置二级路由、Android 系统返回与前后台恢复。

`PatrolTester.enterText()` 只向 Flutter 输入控件注入文本，不会拉起原生软键盘，因此该流程不作为键盘遮挡验收证据。键盘行为继续保留为默认设备人工验收项。

对应提交包括 `14855f43 test(app): 对齐 2.0 登录设备巡检` 和本次 P0 巡检扩展提交。

## 未完成项

- 默认设备上的冷启动与登录主流程。
- 系统键盘弹出、收起和输入框遮挡检查。
- 顶部/底部安全区与长内容滚动检查。
- 相册、相机、麦克风和通知权限的拒绝、再次请求与恢复。
- 默认设备前后台切换后的真实会话、WebSocket 和页面状态恢复；Android mock Shell 状态恢复已通过。
- 断网、重连、待发送消息和离线缓存恢复。
- 默认设备系统返回、原生返回手势和多层路由回退；Android 两层二级路由返回已通过。
- 聊天附件、联系人、群治理和设置的完整可视化设备巡检。

## 阻塞与恢复条件

1. 重启 macOS 清理 Xcode/SwiftBuild 服务状态；若仍复现，安装可用的其他 Xcode 版本并切换 `xcode-select`，再运行最小 Patrol harness。
2. 最小 harness 通过后，按 `127.0.0.1` 地址执行 iOS device auth、device contract、Patrol P0 和人工设备场景。
3. 上述默认设备证据和未完成场景关闭前，不得将 U8 标记完成或开始依赖 U8 完成态的 U9。
