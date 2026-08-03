# Flutter iOS 设备人工验收清单

本文档只记录 Patrol / integration 无法可靠证明的系统交互，不用自动化 mock 结果替代真实设备证据。

## 2026-08-03 iOS Simulator 布局验收

- 设备：iPhone 17 Pro Simulator，iOS 26.4，`EE1B44A0-0924-49D8-8CE7-E15FE2555AC9`
- API：`http://127.0.0.1:8010`
- 账号：使用 `/tmp/redcode-dual-env` 中的 A/B 测试账号

| 场景 | 操作 | 通过标准 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| 真实系统软键盘 | 真实登录后进入 A/B 私聊，点击 composer | iOS 软键盘可见，不能使用 Patrol `enterText()` 代替 | PASS | 独立原生 XCTest 通过普通 App 的 accessibility tree 点击 Flutter `TextField`，断言真实 `XCUIElementTypeKeyboard` 出现；`app/build/ios-device-acceptance-*.xcresult` |
| 键盘遮挡 | 输入至少三行长文本 | composer、发送按钮和当前输入行完整位于键盘上方 | PASS | 原生 XCTest 输入三行文本，断言 composer 与“发送”语义按钮底边均不越过键盘上缘，且发送按钮保持在屏幕横向边界内 |
| 返回优先级 | 键盘打开时点击聊天页返回键，再次点击 | 第一次只收键盘并保留聊天页，第二次退出聊天页 | PASS | 原生 XCTest 第一次点击“返回”后等待键盘消失并断言 composer 仍存在，第二次点击后等待 composer 消失 |
| 顶部/底部安全区 | 分别检查登录页、四 Tab、聊天页和长设置页 | 状态栏不遮挡标题，Home Indicator 不遮挡底栏或最后一项 | PASS | `device_layout_test.dart` 在真实 iPhone 17 Pro Simulator padding 下验证登录标题、底部 Tab 标签、聊天 header/composer 与设置页末项几何边界，`app/build/ios_results_1785781793361.xcresult` |
| 横屏策略 | 聊天页旋转到横屏并恢复竖屏 | 页面不溢出，`.h/.sp` 不异常放大，恢复后状态保留 | PASS | `device_layout_test.dart` 通过真实 iOS platform channel 驱动 Simulator 横屏并恢复竖屏，断言宽高方向、安全区、标题、composer、发送按钮与输入草稿；`app/build/ios_results_1785783462845.xcresult` |
| 大字号与长文本 | 系统文字调至最大，再巡检四 Tab、聊天和设置页 | 文案不重叠、不截断关键命令，列表可滚动至最后一项 | PASS | Simulator `content_size=accessibility-extra-extra-extra-large`；首次设备截图发现登录页横向溢出 182px，修复欢迎文案换行和登录类型区域自适应高度后复验无 overflow；最高字号下 41 个 P0 导航/滚动检查通过，`app/build/ios_results_1785780497220.xcresult` |
| Reduced Motion | 打开“减弱动态效果”后重复导航和面板操作 | 功能状态不丢失，无依赖动画才能完成的操作 | PASS | Simulator `ReduceMotionEnabled=1` 与最高字号组合下 41 个 P0 导航/滚动检查通过，`app/build/ios_results_1785780881788.xcresult`；验收后已恢复 `ReduceMotionEnabled=0` 和标准字号 |

## 2026-08-03 iOS 权限验收

| 场景 | 操作 | 通过标准 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| 相册永久拒绝 | `simctl privacy revoke photos` 后在私聊点击“相册” | 不启动 picker，显示“需要相册权限”和“前往设置” | PASS | `make app.test.patrol.permission`，`app/build/ios_results_1785749306738.xcresult` |
| 麦克风永久拒绝 | `simctl privacy revoke microphone` 后长按录音 | 不启动 recorder，显示“需要麦克风权限”和“前往设置” | PASS | 同一 Patrol 运行通过 |
| 首次相册拒绝 | `simctl privacy reset` 后触发相册入口并拒绝系统弹窗 | App 不死锁，返回相册设置引导 | PASS | 独立原生 XCTest 点击真实系统“不允许”，随后断言“需要相册权限”和“前往设置”；`app/build/ios-photo-permission-acceptance-*.xcresult` |
| 从设置恢复相册权限 | 在设置中改为“完全访问”，再回 App 重试 | 无需重登即可继续 picker 流程 | PASS | XCTest 经 `Settings -> App -> Chatly -> 照片` 恢复权限，返回原聊天页后 PHPicker 正常出现并可取消；`app/build/ios-photo-permission-acceptance-*.xcresult` |
| 首次麦克风拒绝与恢复 | `simctl privacy reset microphone` 后触发录音、拒绝，再从设置恢复 | App 不死锁，恢复后无需重登即可重新进入录音流程 | PASS | 原生 XCTest 真实点击系统“不允许”，验证设置引导，将 Chatly 的麦克风开关从 `0` 恢复为 `1`，返回已登录 App 后重新进入同一聊天和录音面板；`app/build/ios-microphone-permission-acceptance-*.xcresult` |
| 通知拒绝与恢复 | 首次拒绝通知，再从系统设置恢复 | App 可继续使用；恢复后可注册 token 并接收提醒 | PENDING | 2026-08-04 已由 XCTest 真实点击首次系统“不允许”，拒绝后正式 App 正常进入登录页；设置恢复、APNs token 和前后台通知仍待 iPhone 真机验收 |
| 相机权限 | 在支持相机的设备上拒绝、永久拒绝并恢复 | 拒绝不死锁，永久拒绝有设置入口，恢复后无需重登 | SKIPPED | iOS Simulator 无真实相机能力，转 iPhone 真机验收 |
| 真实采集质量 | 拍照、录制 1-60 秒语音并发送 | 图片方向/清晰度正常，音频可播放且时长正确 | SKIPPED | 必须 iPhone 真机验证 |

## 2026-08-04 iOS 附件系统交互验收

| 场景 | 操作 | 通过标准 | 状态 | 证据 |
| --- | --- | --- | --- | --- |
| 系统图片选择器 | 私聊点击“相册”，打开 PHPicker 后取消 | PHPicker 正常出现，取消选择不产生失败消息 | PASS | 原生 XCTest 从系统设置恢复照片权限后返回原聊天页，断言 PHPicker 出现并点击取消；图片选择后的上传与发送由双设备 Patrol 覆盖 |
| 系统文件选择器 | 私聊点击“文件”，打开系统文件选择器后取消 | 系统选择器正常出现；取消后返回原聊天页且不产生失败消息 | PASS | 原生 XCTest 真实打开 iOS `UIDocumentPickerViewController`，断言“最近项目”出现并点击系统 `Cancel`，返回后 composer 与更多功能入口仍可用；`app/build/ios-file-picker-acceptance-*.xcresult`。PDF 选择结果后的上传、广播和下载由双设备 Patrol 覆盖 |
| 真实语音采集与播放 | 长按录音 1-60 秒并发送，由另一台设备播放 | 时长正确、声音可辨、播放可暂停，文件无截断或损坏 | SKIPPED | 双 iOS 自动化已证明 M4A 上传、广播、下载和播放器启动；采集质量与听感必须使用 iPhone 真机验证 |

## Patrol 兼容性结论

`device_layout_test.dart` 保留真实账号登录、长 composer、设备尺寸和焦点优先返回回归，但不声称覆盖真实系统软键盘。真实键盘证据由 `RunnerUITests.m` 中独立的 `RedCodeDeviceAcceptanceTests` 提供，其链路为：

1. 原生点击 Flutter composer，而不是 `PatrolTester.enterText()`。
2. iOS native UI tree 能查询到 `IOSElementType.keyboard`。
3. XCTest 比较 composer、发送按钮与系统键盘的实际 frame，确认控件位于键盘上方。
4. 首次系统返回只收键盘，第二次才退出聊天页。

权限弹窗仍存在 Patrol 边界：当前 CLI 的自动权限 helper 不支持中文系统语言。照片和麦克风首次拒绝、设置恢复已改由独立原生 XCTest 覆盖；`permission_flow_test.dart` 继续证明宿主设置的真实永久拒绝状态与 App 降级 UI。Simulator 无法提供可验收的真实麦克风采集与音质，相关结果不记为 PASS。
