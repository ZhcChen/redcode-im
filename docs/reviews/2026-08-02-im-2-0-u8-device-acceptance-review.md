# Flutter 2.0 U8 移动设备验收记录

## 当前结论

U8 尚未完成。Android 15 Emulator 已通过 Flutter 静态检查、全量单测、Patrol 登录与四 Tab 主导航，以及真实 API 认证和核心合同测试，可作为 Android 补充证据；但它不替代仓库规定的默认设备验收。

iPhone 17 Pro Simulator 已通过 Flutter integration smoke。此前 Xcode 26.6 build service 在构建描述阶段持续卡住的问题已定位并使用窄范围 compiler probe wrapper 绕过；iPhone 17 Pro 与 iPhone 17 Pro Max 的双账号私聊、群聊实时互发，以及前后台重连和离线消息恢复已通过。附件失败、手动重试和缓存恢复状态机已由单元测试覆盖，真实 API contract 已补齐签名、直传、commit、消息 parts、对端可见与下载断言；双 iOS 图片、文件和语音附件上传、广播和下载已通过，系统 PHPicker 与系统文件选择器打开/取消均已完成原生 XCTest 验收。真实麦克风采集仍待 iPhone 真机验收。

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
- `make app.test`：2026-08-04 复核，354 项通过。
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
- `dual_device_chat_test.dart` 已扩展双向已读断言：2026-08-03 修复已读回执早于发送消息服务端 ID 落地时被丢弃的竞态后，A/B 均观察到自己发送消息更新为“已读”。通过 marker 为 `1785752697-35409-26502`，证据保存在本地 `app/build/patrol-dual/1785752697-35409-26502/`。
- `group_chat_test.dart`：2026-08-03 在同一组双 iOS Simulator 上通过真实 UI 创建包含 B 的群聊；A 发送带唯一 marker 的群消息，B 从群目录进入新群并实时可见后回复，A 实时可见回复。通过 marker 为 `1785750765-55728-7609`，证据保存在本地 `app/build/patrol-dual/1785750765-55728-7609/`。
- `group_chat_test.dart` 群治理扩展：2026-08-03 的 marker `1785756268-69892-13172` 中，A 通过真实 UI 任命 B 为管理员并看到“移除”，B 在不离开群设置页的情况下实时看到“禁言管理”，两端业务断言均显示成功。B 端 `xcodebuild` 在成功行输出后卡于结果收尾，最终由编排超时清理；因此该 marker 只作为群角色实时刷新的双端业务证据，不记为编排器完整 PASS。
- `offline_recovery_test.dart`：2026-08-03 在同一组双 iOS Simulator 上通过。A 发送握手消息后主动断开 WebSocket 并退到后台，B 在离线窗口发送消息；A 回前台后重新认证、恢复当前聊天并仅展示一条离线消息。通过 marker 为 `1785753847-83687-3109`，证据保存在本地 `app/build/patrol-dual/1785753847-83687-3109/`。
- `contact_lifecycle_test.dart`：2026-08-03 在同一组双 iOS Simulator 上可重复通过。A 设置 B 的备注并验证联系人列表优先展示，删除 B 后重新搜索、发送申请，B 接受后双方联系人关系恢复。最终通过 marker 为 `1785759388-7518-29000`，证据保存在本地 `app/build/patrol-dual/1785759388-7518-29000/`。
- `group_chat_test.dart` 已读详情与角色一致性扩展：2026-08-03 的 marker `1785761553-93924-11879` 中，A 打开自己发送消息的已读详情并看到 B、`已读 1 / 未读 0`；A 任命 B 后，B 停留在群设置页实时出现“禁言管理”。A/B 均输出独立 `DUAL_GROUP_COMPLETE`，编排器完整 PASS。
- `group_mute_test.dart`：2026-08-03 的 marker `1785767143-32104-25273` 中，A 通过真实 UI 禁言/解禁 B，并开启/关闭全体禁言；B 实时出现“你已被管理员禁言”和“当前群聊已开启全体禁言”，两次恢复后分别发送确认消息。A/B 均输出 `DUAL_GROUP_MUTE_COMPLETE`，两端各 1 项成功、0 失败；API 同时记录两次 `POST /rooms/{room_id}/mutes/global` 返回 200。
- `group_member_removal_test.dart`：2026-08-03 的 marker `1785769167-867-8278` 中，A 通过真实群设置 UI 移除 B 并看到成功提示；B 停留在群聊详情时收到 WebSocket 成员变更，实时退页并看到“你已被移出群聊”。A/B 均输出 `DUAL_GROUP_MEMBER_REMOVAL_COMPLETE`，编排器完整 PASS。
- API 运行时证据：两个账号分别完成 protobuf WebSocket 认证并订阅房间 `019fc568-5800-7783-877c-448008bc95ed`；两次 `POST /rooms/{room_id}/messages` 均记录“1 个订阅者”，证明消息经在线 WebSocket 链路送达对端，而非仅靠历史消息刷新。
- `make app.test.patrol.dual` 连续两轮通过：marker 分别为 `1785745629-39354-344`、`1785745896-54948-13521`。两轮 A/B 日志的首条 `DUAL_IDENTITY` 均与各自角色、账号、marker 和 `dual-a-`/`dual-b-` 消息前缀一致，证明没有复用上一轮或对端的编译参数。
- 两轮日志和 `xcresult` 分别归档到 `app/build/patrol-dual/<marker>/`。该目录是本地验收证据，不纳入 Git。
- `make app.test.patrol.layout`：2026-08-03 在 iPhone 17 Pro Simulator 上通过，真实账号 A 登录并进入账号 B 私聊，验证长 composer、发送按钮设备边界和焦点优先返回；`xcresult` 为本地 `app/build/ios_results_1785747584703.xcresult`。
- 横竖屏尺寸自动化发现并修复 `flutter_screenutil` 的手机横屏放大问题：横屏时不再启用会把逻辑高度强制抬到 700 的 `splitScreenMode`，动态旋转测试通过。
- `make app.test.patrol.permission`：2026-08-03 在 iPhone 17 Pro Simulator 上通过。宿主真实撤销照片和麦克风权限后，聊天相册与录音入口均显示“前往设置”，`xcresult` 为本地 `app/build/ios_results_1785749306738.xcresult`。
- `make app.test.ios-permission-acceptance`：2026-08-04 使用独立原生 XCTest 通过照片和麦克风首次拒绝与设置恢复。照片恢复后 PHPicker 可打开并取消；麦克风设置开关从 `0` 恢复为 `1`，App 无需重登即可重新进入同一聊天的录音面板。真实录音采集与音质不在 Simulator PASS 范围内。
- 权限状态已统一为可测试的 `PermissionService`，覆盖 granted/limited/denied/permanentlyDenied/restricted，并接入聊天附件、语音、资料头像、群头像、聊天背景、举报凭证和本地通知请求。
- 附件状态机不再用无限 `sending` 和定时重试表示失败：签名、上传或发送失败会落为可点击的 `failed`，App 重启后把遗留 `sending` 降为 `failed` 并恢复手动重试队列；图片、文件、语音恢复重试及本地源文件丢失均有单测。语音首次发送失败时保留本地录音，避免重试入口失效。
- `api_contract_flow_test.dart` 已加入小型 PDF 的完整合同链路：签名、S3-compatible PUT、commit、发送附件 parts、账号 B 拉取可见和强制下载字节一致。2026-08-04 通过 `make app.test.integration.device.contract` 在 iPhone 17 Pro Simulator 与 Compose API/S3-compatible mock 上取得真实运行时 PASS。
- `image_attachment_test.dart` 已在双 iOS Simulator 通过，marker 为 `1785773518-91298-11190`。A 点击真实“相册”入口后，由测试进程返回固定 PNG；图片解析、签名、S3-compatible PUT、commit、正式 `messages/` key、消息广播以及 B 下载落盘均通过。Patrol 4.5 无法稳定操作独立系统进程中的 iOS 26 PHPicker，因此系统选择器交互仍为人工 PENDING，不将本结果泛化为文件或语音附件通过。
- `network_recovery_test.dart` 已在双 iOS Simulator 通过，最终 marker 为 `1785775688-87809-18168`。A 经可控 TCP 代理连接 API/WebSocket，测试真实销毁现有连接并拒绝重连；B 保持直连并在隔离窗口发送消息，恢复代理后 A 自动重新认证、恢复房间订阅并仅显示一条离线消息。首次运行暴露 WebSocket 握手失败的 `HttpException` 会泄漏到 Flutter zone；`WebSocketService` 现等待 channel `ready` 后再监听和认证，使失败统一进入既有重连状态机，并异步清理失败 channel，避免阻塞后续重连。
- `make app.test.patrol.pages`：2026-08-04 在 iPhone 17 Pro Simulator 上使用真实账号通过，完成 41 个检查点。已验证新的朋友、群聊、群通知、个人资料、编辑资料、账号与安全、修改密码、注销账号、聊天、聊天背景、表情管理、隐私政策、关于和意见反馈页面可打开与返回，并滚动反馈页到“提交反馈”；`xcresult` 为本地 `app/build/ios_results_1785776662273.xcresult`。该结果不泛化为系统软键盘、安全区、大字号、Reduced Motion 或所有数据状态的视觉验收。
- `rich_attachment_test.dart` 已在双 iOS Simulator 通过，最终 marker 为 `1785778188-93063-1916`。A 点击真实“文件”入口发送固定 PDF，并通过正式 `ChatProvider.sendVoiceMessage` 发送 1200ms 有效 M4A；两类附件均完成签名、S3-compatible PUT、commit、正式 `messages/` key、WebSocket 广播和 B 强制下载字节一致，B 还按本轮服务端消息 ID 精确定位并点击 `0:01` 语音气泡，成功启动播放器。测试进程替换系统文件选择结果并绕过麦克风采集，因此不将系统文件选择器、录音质量或听感泛化为 PASS。
- `make app.test.ios-file-picker-acceptance` 已在 iPhone 17 Pro Simulator 通过。原生 XCTest 从真实聊天“文件”入口打开系统“最近项目”选择器，点击 `Cancel` 后返回原聊天页，并断言 composer、更多功能入口仍存在且无文件访问/处理失败提示。期间发现 UIScene 模式下 `file_selector_ios` 仍通过 `AppDelegate.window` 获取 presenter，原配置使其返回 `Missing root view controller.`；项目级 `SceneDelegate` 现回填有效 window。该证据只覆盖系统选择器打开与取消，PDF 选择结果后的上传链路由上述双设备 Patrol 覆盖。
- `make app.test.patrol.cross`：2026-08-04 在 iPhone 17 Pro Simulator 与 Android 15 Emulator 上通过，marker `1785778695-15873-13110`。iOS A 通过 `127.0.0.1`、Android B 通过 `10.0.2.2` 登录同一私聊，A/B 实时互发唯一消息且双方发送状态均更新为已读。
- `make app.test.patrol.cross-offline`：反向角色最终通过，marker `1785779441-49039-18587`。Android A 主动断开 WebSocket 并进入后台，iOS B 在离线窗口发送消息；Android 回前台后自动重新认证、恢复当前会话并补拉唯一消息。iOS 作为恢复端的首次跨端尝试 marker `1785778902-25693-30072` 未收到可证明的 Patrol 生命周期恢复事件，未记为 PASS；该方向已有双 iOS marker `1785753847-83687-3109` 的独立通过证据。
- 2026-08-04 在 iPhone 17 Pro Simulator 将系统字号切到 `accessibility-extra-extra-extra-large` 后，正式登录页暴露 `RenderFlex overflowed by 182 pixels`。`LoginPage` 已将欢迎文案改为可换行约束，并让登录类型区域按内容撑高；新增 3.2x 字号 Widget 回归后，设备复验不再显示 overflow。最高字号下 41 个 P0 导航/滚动检查通过，`xcresult` 为 `app/build/ios_results_1785780497220.xcresult`。
- 同一设备开启系统 `ReduceMotionEnabled=1` 并保持最高字号后，41 个 P0 导航/滚动检查再次通过，`xcresult` 为 `app/build/ios_results_1785780881788.xcresult`；验收后已恢复标准字号与 `ReduceMotionEnabled=0`。首次通知权限由 XCTest 真实点击“不允许”后，正式 App 仍正常进入登录页；设置恢复与 APNs 仍保留真机验收。外部 Simulator 旋转无法作用于 Patrol 的 XCTest 隔离前台，真实聊天页横屏截图不记 PASS。
- `device_layout_test.dart` 已扩展真实 Simulator 安全区几何门禁，读取设备 `MediaQuery.padding` 后分别断言登录标题低于状态栏、四 Tab 交互标签高于 Home Indicator、聊天 header/composer 位于上下安全边界内、设置页最后一项可滚动至底部安全区上方；2026-08-04 在 iPhone 17 Pro Simulator 通过，`xcresult` 为 `app/build/ios_results_1785781793361.xcresult`。
- Patrol 无法证明真实系统软键盘后，已改用独立原生 XCTest 驱动普通 App。2026-08-04 已验证系统键盘出现、三行 composer 与发送按钮不被遮挡、第一次返回收键盘和第二次退出聊天；证据为 `app/build/ios-device-acceptance-1785786732.xcresult`。

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

R1.1 的 Patrol 系统软键盘路径无法稳定暴露 Flutter `TextField`，因此已转为独立原生 XCTest，并完成真实键盘、遮挡和返回优先级验收。

R1.2 的 Patrol 权限 helper 不支持中文 Simulator，因此首次照片/麦克风弹窗和设置恢复已转由独立原生 XCTest 覆盖并通过。通知设置恢复、真实相机/麦克风采集与 APNs 仍保留真机 PENDING/SKIPPED。

R1.3 群聊用例复用了受控双设备编排，通过 `DUAL_TEST_TARGET` 选择 `patrol_test/group_chat_test.dart`，默认私聊入口保持不变。首次完整互发暴露 `ChatDetailPageV2` 在 `initState` 期间触发 `ChatProvider.notifyListeners()` 的 build-phase 异常；聊天室初始化移到首帧后执行后，双端创建群、发送和回复完整通过。

R1.3 联系人用例覆盖备注、删除和重新申请闭环。修复包括联系人缓存持久化备注、资料刷新不丢备注、列表返回主动刷新，以及好友申请弹窗退出动画期间提前释放输入控制器的竞态。API 同时允许已删除关系使用历史 accepted 请求记录重新发起申请。双端真实 UI 验证后，编排器新增场景化身份前缀校验，避免联系人场景被默认私聊前缀误判。

群聊已读详情原有页面与请求链已存在，本轮补齐稳定设备入口，并修复 API 只校验调用者属于路径房间、却未校验消息属于该房间的越权边界。真实联调还发现管理员任命只写 `group_admins`、未同步 `room_members.role`，导致对端收到事件后重新拉成员仍被降回普通成员；任命与移除现通过同一事务维护两张表，API 集成测试覆盖角色升降和跨房间已读查询拒绝。

群设置页现订阅当前群的成员变更和设置变更事件：角色变更后重新拉取成员并重算 owner/admin 权限，全体禁言事件直接刷新开关。其他群事件会被过滤，页面销毁时取消订阅；2 项 Widget 回归和双 iOS 真实任命场景已验证该链路。

群禁言设备验收拆为独立 `group_mute_test.dart`，避免群消息、已读详情、角色刷新和禁言状态共用一条长链。首次全体禁言操作只点击了带 Key 的整行容器，没有命中右侧 `CustomSwitch`；改为等待开关加载完成并精确点击子控件后，个人禁言、全体禁言和两次恢复发送均在双 iOS Simulator 通过。

私聊已读同步的首次真实断言发现时序竞态：接收方提交已读时，发送方可能仍持有临时消息 ID，服务端消息 ID 的 WebSocket 回执因此无法匹配并被丢弃。`MessageService` 现按房间暂存最多 128 个未匹配回执，在消息回显或发送响应完成 ID 替换时消费，并在房间消息清理时移除；双端 UI 已读状态随后通过。

App 原先只依赖 socket `onDone` 和网络变化触发重连，iOS 后台冻结连接但未及时回调时可能停留在陈旧的 `authenticated` 状态。`HomeShellPage` 现识别真实离开前台后的 `resumed`，受控重建 WebSocket 传输并保留房间订阅意图；认证后继续使用既有重订阅、会话刷新和离线补拉。主动断连同步等待旧 stream 退出并禁止迟到 `onDone` 安排竞争重连。

对应提交包括 `14855f43 test(app): 对齐 2.0 登录设备巡检` 和本次 P0 巡检扩展提交。

## 未完成项

- 默认设备上的冷启动与登录主流程；真实账号 Patrol 登录和进入私聊已通过，仍待进程级冷启动复核。
- 相机和通知权限恢复仍需真机验收；照片和麦克风的首次拒绝、永久拒绝提示与设置恢复已通过 Simulator。
- 系统 Wi-Fi/蜂窝切换仍需真机人工验收；双 iOS API/WebSocket TCP 路径真实中断与恢复，以及主动断连后的前后台重连、当前聊天和离线文本消息恢复均已通过。
- 默认设备系统返回、原生返回手势和多层路由回退；Android 两层二级路由返回已通过。
- 系统文件选择器打开与取消已通过原生 XCTest；真实麦克风采集仍需 iPhone 真机验收。PHPicker 打开与取消、图片/文件/语音附件真实上传、广播和对端下载已通过，语音接收端播放器启动也已验证。联系人、群通知、个人资料、账号安全、聊天设置、隐私、关于和反馈页面导航巡检已通过；成员移除、个人禁言/解禁、全体禁言/恢复、联系人备注/删除/重新申请，以及管理员任命后对端权限实时刷新已验证。
- 双账号登录、好友私聊双向已读、群聊已读/未读成员详情、建群、群消息双向互发、前后台重连、离线文本消息恢复和 WebSocket 实时同步已通过。

## 阻塞与恢复条件

1. 补齐通知/APNs、相机、真实麦克风采集和系统网络切换等真机设备场景。
2. 上述默认设备证据和未完成场景关闭前，不得将 U8 标记完成或开始依赖 U8 完成态的 U9。
