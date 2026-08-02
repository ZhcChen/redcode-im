# Flutter 2.0 U8 移动设备验收记录

## 当前结论

U8 尚未完成。Android 15 Emulator 已通过 Flutter 静态检查、全量单测、Patrol 登录与四 Tab 主导航，以及真实 API 认证和核心合同测试，可作为 Android 补充证据；但它不替代仓库规定的默认设备验收。

Pixel 8 Pro `3A091FDJG001DN` 当前未连接。回退设备 iPhone 17 Pro Simulator 可被 Flutter 识别，但本机 Xcode 26 build service 在构建描述阶段持续卡住，因此目前不能证明系统键盘、安全区、权限拒绝/恢复、前后台切换和离线恢复已在默认设备策略下通过。

## 验收环境

- 日期：2026-08-02
- 补充设备：Android 15 Emulator，`emulator-5554`，API 35，arm64
- API：`http://10.0.2.2:8010`
- WebSocket：`ws://10.0.2.2:8010/ws`
- 默认 Android 真机：Pixel 8 Pro `3A091FDJG001DN`，未连接
- 回退设备：iPhone 17 Pro Simulator `EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`，构建阻塞

## 已通过证据

- `make app.check`：通过，无 analyze 问题。
- `make app.test`：324 项通过。
- `make app.test.integration.smoke APP_TEST_DEVICE=emulator-5554`：2 项通过。
- `make app.test.patrol.harness PATROL_DEVICE=emulator-5554`：1 项通过。
- `make app.test.patrol.login PATROL_DEVICE=emulator-5554`：1 项通过；覆盖账号密码输入、mock 登录、聊天/联系人/发现/我的四 Tab、联系人固定入口、设置与账号安全二级路由、两次 Android 系统返回，以及 Home/最近任务前后台恢复。
- `make app.test.integration.device.auth APP_TEST_DEVICE=emulator-5554`：真实 API 注册、登录、刷新和登出通过。
- `make app.test.integration.device.contract APP_TEST_DEVICE=emulator-5554`：三账号认证、好友、群、消息、设置、隐私协议、反馈和上传策略合同通过。

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

1. Pixel 8 Pro 重新连接后，按真机规则重新检测本机 LAN IP，再执行 device auth、device contract 和 Patrol P0。
2. Pixel 仍缺席时，先恢复 iOS Simulator 的 Xcode 构建能力，再按 `127.0.0.1` 地址执行同一组验收。
3. 上述默认设备证据和未完成场景关闭前，不得将 U8 标记完成或开始依赖 U8 完成态的 U9。
