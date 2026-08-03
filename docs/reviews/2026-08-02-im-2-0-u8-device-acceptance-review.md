# Flutter 2.0 U8 移动设备验收记录

## 当前结论

U8 尚未完成。Android 15 Emulator 已通过 Flutter 静态检查、全量单测、Patrol 登录与四 Tab 主导航，以及真实 API 认证和核心合同测试，可作为 Android 补充证据；但它不替代仓库规定的默认设备验收。

iPhone 17 Pro Simulator 已通过 Flutter integration smoke。此前 Xcode 26.6 build service 在构建描述阶段持续卡住的问题已定位并使用窄范围 compiler probe wrapper 绕过；iPhone 17 Pro 与 iPhone 17 Pro Max 的双账号私聊和群聊实时互发已通过。系统键盘、安全区、权限拒绝/恢复、前后台切换和离线恢复等完整设备场景仍待验收。

## 验收环境

- 日期：2026-08-02；双设备编排复核：2026-08-03
- 默认设备：iPhone 17 Pro，`EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`，iOS 26.3
- 双端设备：iPhone 17 Pro Max，`C0BAADF7-6F47-457C-A06A-893D0251B8CB`，iOS 26.3
- 补充设备：Android 15 Emulator，`emulator-5554`，API 35，arm64
- API：`http://10.0.2.2:8010`
- WebSocket：`ws://10.0.2.2:8010/ws`
- iPhone 17 Pro Simulator 已启动并被 `flutter devices` 识别；Android 15 Emulator 用作跨端联调设备

## 已通过证据

- `make app.check`：通过，无 analyze 问题。
- `make app.test`：335 项通过。
- `make app.test.integration.smoke APP_TEST_DEVICE=emulator-5554`：2 项通过。
- `make app.test.integration.smoke APP_TEST_DEVICE=EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`：通过，2 项 integration smoke 全部执行。
- `make app.test.integration.device.auth APP_TEST_DEVICE=EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`：真实 API 注册、登录、刷新和登出通过。
- `make app.test.integration.device.contract APP_TEST_DEVICE=EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`：三账号认证、好友、群、消息、设置、隐私协议、反馈和上传策略合同通过。
- `make app.test.patrol.harness PATROL_DEVICE=EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`：1 项通过。
- `make app.test.patrol.login PATROL_DEVICE=EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`：1 项通过；覆盖账号密码输入、mock 登录、四 Tab、联系人固定入口、设置与账号安全二级路由、iOS 路由返回，以及 Home 后重新激活。
- `make app.test.patrol.harness PATROL_DEVICE=emulator-5554`：1 项通过。
- `make app.test.patrol.login PATROL_DEVICE=emulator-5554`：1 项通过；覆盖账号密码输入、mock 登录、聊天/联系人/发现/我的四 Tab、联系人固定入口、设置与账号安全二级路由、两次 Android 系统返回，以及 Home/最近任务前后台恢复。
- `make app.test.integration.device.auth APP_TEST_DEVICE=emulator-5554`：真实 API 注册、登录、刷新和登出通过。
- `make app.test.integration.device.contract APP_TEST_DEVICE=emulator-5554`：三账号认证、好友、群、消息、设置、隐私协议、反馈和上传策略合同通过。
- `dual_device_chat_test.dart`：iPhone 17 Pro 与 iPhone 17 Pro Max 同时运行 Patrol，账号 A/B 均通过真实 UI 登录并进入同一私聊；A 发送 `dual-a-1785724561`，B 实时可见后回复 `dual-b-1785724561`，A 实时可见回复，两端测试均通过。
- `group_chat_test.dart`：2026-08-03 在同一组双 iOS Simulator 上通过真实 UI 创建包含 B 的群聊；A 发送带唯一 marker 的群消息，B 从群目录进入新群并实时可见后回复，A 实时可见回复。通过 marker 为 `1785750765-55728-7609`，证据保存在本地 `app/build/patrol-dual/1785750765-55728-7609/`。
- API 运行时证据：两个账号分别完成 protobuf WebSocket 认证并订阅房间 `019fc568-5800-7783-877c-448008bc95ed`；两次 `POST /rooms/{room_id}/messages` 均记录“1 个订阅者”，证明消息经在线 WebSocket 链路送达对端，而非仅靠历史消息刷新。
- `make app.test.patrol.dual` 连续两轮通过：marker 分别为 `1785745629-39354-344`、`1785745896-54948-13521`。两轮 A/B 日志的首条 `DUAL_IDENTITY` 均与各自角色、账号、marker 和 `dual-a-`/`dual-b-` 消息前缀一致，证明没有复用上一轮或对端的编译参数。
- 两轮日志和 `xcresult` 分别归档到 `app/build/patrol-dual/<marker>/`。该目录是本地验收证据，不纳入 Git。
- `make app.test.patrol.layout`：2026-08-03 在 iPhone 17 Pro Simulator 上通过，真实账号 A 登录并进入账号 B 私聊，验证长 composer、发送按钮设备边界和焦点优先返回；`xcresult` 为本地 `app/build/ios_results_1785747584703.xcresult`。
- 横竖屏尺寸自动化发现并修复 `flutter_screenutil` 的手机横屏放大问题：横屏时不再启用会把逻辑高度强制抬到 700 的 `splitScreenMode`，动态旋转测试通过。
- `make app.test.patrol.permission`：2026-08-03 在 iPhone 17 Pro Simulator 上通过。宿主真实撤销照片和麦克风权限后，聊天相册与录音入口均显示“前往设置”，`xcresult` 为本地 `app/build/ios_results_1785749306738.xcresult`。
- 权限状态已统一为可测试的 `PermissionService`，覆盖 granted/limited/denied/permanentlyDenied/restricted，并接入聊天附件、语音、资料头像、群头像、聊天背景、举报凭证和本地通知请求。

## 默认设备复核

- 2026-08-02 双端复核：同时启动 iPhone 17 Pro 与 iPhone 17 Pro Max 后，两台设备均完成系统启动并被 Flutter 识别；API Compose 开发栈保持 healthy。
- `make app.test.integration.smoke APP_TEST_DEVICE=EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`：再次停在 `Running Xcode build...`；进程链稳定复现为 `xcodebuild -> SWBBuildService -> clang -v -E -dM`，测试用例尚未开始执行。
- 仓库构建目录中没有可复用的 iOS `.app`，两台 Simulator 也未安装 RedCode IM，因此不能绕过本轮构建直接进行双账号 UI 联调。
- `make app.test.patrol.harness PATROL_DEVICE=EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`：iPhone 17 Pro Simulator 构建持续 119.1 秒未进入测试执行阶段，终止后报告 `xcodebuild was interrupted`，本次没有测试通过证据。
- 终止后未残留 `xcodebuild`、`XCBBuildService` 或 Patrol 测试进程。

### iOS 构建阻塞定位

- Xcode 26.6（17F113）、iPhoneSimulator 26.5 SDK、`xcrun clang` 和 `xcodebuild -showBuildSettings` 均可在 1 秒内完成，排除 SDK 缺失、基础 clang 故障和工程无法解析。
- Patrol CLI 4.3.0 的实际命令停在 `xcodebuild build-for-testing` 的 `CreateBuildDescription`，现场子进程为多条 `clang -v -E -dM` capability probe。
- 对 clang 子进程采样显示主线程持续阻塞在 `llvm::raw_fd_ostream::write_impl -> write`；同一条 clang 命令脱离 SwiftBuild 后约 0.02 秒完成。
- 去掉 Patrol 固定的 `-quiet`、使用 `2>&1 | tee` 持续排空输出、通过 launchd 洁净 FD 启动，以及增加 `-jobs 1 ONLY_ACTIVE_ARCH=YES ARCHS=arm64` 并指定具体 Simulator，均在同一阶段复现。
- 该行为与 Xcode 26.x 已公开的 SwiftBuild planning pipe deadlock 特征一致：<https://github.com/getsentry/XcodeBuildMCP/issues/492>。当前证据指向本机 Xcode Build Service，而不是 RedCode IM 源码、Pods 或 Patrol 测试逻辑。
- 进一步通过 `lsof` 确认两个 capability probe 的 stdout/stderr 均为 16 KB 管道，`SWBBuildService` 持有读取端；`sample` 显示 clang 卡在 `Command::Print -> raw_fd_ostream::write_impl -> write`。直接日志文件、重启 CoreSimulator 服务和 legacy build flag 均不改变结果。
- 将 Xcode build setting `CC` 指向临时 wrapper，仅对含 `-dM` 的 capability probe 去掉 `-v` 后，构建立即越过 `CreateBuildDescription` 并完成 Pods、Runner 编译；正式 Flutter integration smoke 随后 2 项通过。该规避已固化为 `app/scripts/xcode_clang_probe_wrapper.sh`，仅在 Xcode 26.6 下由 app 脚本自动启用。

## 本轮修复

Patrol 登录 smoke 原先仍查找旧版“设置”Tab，且测试壳未注册正式命名路由。现已使用 `AppRouter.onGenerateRoute` 进入真实 App Shell，显式输入账号密码，并将断言更新为 2.0 的“聊天、联系人、发现、我的”信息架构。后续扩展覆盖联系人和发现页面、我的设置二级路由、Android 系统返回与前后台恢复。

iOS 首次执行 P0 Patrol 时发现测试无条件调用 `AndroidAutomator.pressBack()` 和 Android 最近任务 API。现已按平台分流：Android 保留系统返回与最近任务切换，iOS 使用 Flutter 路由返回并通过 `MobileAutomator.openApp()` 恢复前台；同一用例已在 iPhone 17 Pro Simulator 通过。

`PatrolTester.enterText()` 只向 Flutter 输入控件注入文本，不会拉起原生软键盘，因此该流程不作为键盘遮挡验收证据。键盘行为继续保留为默认设备人工验收项。

双设备 Patrol 现统一由 `app/scripts/test_patrol_dual_device.sh` 编排。脚本为 A/B 创建两个临时工程副本，隔离 Patrol 固定的 `build/ios_integ`、Flutter build cache 和生成文件；使用四个独立端口，B 的真实身份与会话就绪后才启动 A，任一端失败或超时会递归清理另一端进程树。全新隔离构建实测可能超过两分钟，因此用例可见性超时调整为 300 秒。用例显式初始化协议同意状态，避免 Simulator 历史 `SharedPreferences` 导致登录分支不确定。

Patrol 4.3.0 在 iOS Simulator 上读取全局 macOS `log stream`，并发时一份日志可能同时出现另一台 Simulator 的后续结构化日志。因此身份门禁校验每份日志的首条 `DUAL_IDENTITY`，而不是只判断全文是否包含期望值。

R1.1 系统软键盘自动化尝试了 native index、native selector、native 坐标点击和 Flutter tap。当前 Patrol 4.3 XCTest native tree 不暴露 Flutter `TextField`，且无法稳定查询 `IOSElementType.keyboard`；因此软键盘遮挡没有记为 PASS，已按计划转入 `docs/reference/testing/app-ios-device-manual-checklist.md` 并标记 SKIPPED/PENDING。

R1.2 首次权限弹窗自动化也受到 Patrol 边界限制：权限 helper 不支持中文 Simulator，App/SpringBoard 原生树无法稳定枚举该 alert。因此自动化只记录 `simctl privacy revoke` 建立的真实永久拒绝状态和降级 UI；首次拒绝、设置恢复、通知、真实相机/麦克风与 APNs 均保留人工或真机 PENDING/SKIPPED。

R1.3 群聊用例复用了受控双设备编排，通过 `DUAL_TEST_TARGET` 选择 `patrol_test/group_chat_test.dart`，默认私聊入口保持不变。首次完整互发暴露 `ChatDetailPageV2` 在 `initState` 期间触发 `ChatProvider.notifyListeners()` 的 build-phase 异常；聊天室初始化移到首帧后执行后，双端创建群、发送和回复完整通过。

对应提交包括 `14855f43 test(app): 对齐 2.0 登录设备巡检` 和本次 P0 巡检扩展提交。

## 未完成项

- 默认设备上的冷启动与登录主流程；真实账号 Patrol 登录和进入私聊已通过，仍待进程级冷启动复核。
- 系统键盘弹出、收起和输入框遮挡检查。
- 顶部/底部安全区与长内容滚动检查。
- 相册、相机、麦克风和通知权限的拒绝、再次请求与恢复。
- 默认设备前后台切换后的真实会话、WebSocket 和页面状态恢复；Android mock Shell 状态恢复已通过。
- 断网、重连、待发送消息和离线缓存恢复。
- 默认设备系统返回、原生返回手势和多层路由回退；Android 两层二级路由返回已通过。
- 聊天附件、联系人、群治理和设置的完整可视化设备巡检。
- 两台 iOS Simulator 上的已读同步与前后台恢复；双账号登录、好友私聊、建群、群消息双向互发和 WebSocket 实时同步已通过。

## 阻塞与恢复条件

1. 在 iOS Simulator 与 Android Emulator 上执行双账号跨端 UI 联调，覆盖消息实时同步、已读和前后台恢复。
2. 补齐系统键盘、安全区、权限拒绝/恢复、断网重连和完整附件流程的人工设备场景。
3. 上述默认设备证据和未完成场景关闭前，不得将 U8 标记完成或开始依赖 U8 完成态的 U9。
