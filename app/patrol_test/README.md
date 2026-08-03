# Patrol E2E

当前目录用于承载 Patrol 专用用例，避免和 `integration_test/` 的轻量 smoke 混用。

当前已落地：
- `login_smoke_test.dart`：登录页基础可见性、注册切换、mock 登录、四 Tab、二级路由、系统返回和 Android 前后台恢复 smoke。`enterText()` 不会拉起原生软键盘，键盘遮挡仍需设备人工验收
- `harness_smoke_test.dart`：最小 Patrol harness 冒烟，优先用于验证 iOS / Android 原生测试桥是否可用
- `dual_device_chat_test.dart`：双设备真实账号登录、私聊文本实时互发和双向已读同步。只通过 `make app.test.patrol.dual` 编排运行；B 先进入会话等待，A 发送后 B 回复，双方均断言 WebSocket 实时消息可见且自己的消息更新为已读
- `group_chat_test.dart`：双设备真实账号创建群聊、群消息实时互发、已读详情和管理员权限刷新。只通过 `make app.test.patrol.group` 编排运行；A 查看自己消息的已读/未读成员，B 停留在群设置页时，A 通过真实 UI 任命 B 为管理员，B 无需重新进页即可见“禁言管理”
- `group_mute_test.dart`：双设备真实群聊个人禁言/解禁、全体禁言/恢复及输入区状态同步。只通过 `make app.test.patrol.group-mute` 编排运行；A 管理禁言，B 必须实时出现对应提示，并在两次恢复后分别发送确认消息
- `group_member_removal_test.dart`：双设备真实群成员移除闭环。只通过 `make app.test.patrol.group-member-removal` 编排运行；A 从群设置移除 B，B 必须实时退出群详情并看到移除提示
- `image_attachment_test.dart`：双设备图片附件真实链路。只通过 `make app.test.patrol.image-attachment` 编排运行；A 点击真实“相册”入口，测试进程提供固定 PNG 选择结果，图片解析、签名、S3-compatible PUT、commit、消息发送、B 端 WebSocket 接收和下载均走真实链路
- `rich_attachment_test.dart`：双设备文件与语音附件真实链路。只通过 `make app.test.patrol.rich-attachment` 编排运行；A 点击真实“文件”入口发送固定 PDF，并通过正式 `sendVoiceMessage` 发送有效 M4A，B 端分别下载、校验字节并点击语音气泡启动播放器
- `network_recovery_test.dart`：双设备 API/WebSocket 网络路径中断与恢复。只通过 `make app.test.patrol.network` 编排运行；A 经可控 TCP 代理连接，B 保持直连，代理切断 A 的现有连接并拒绝重连后由 B 发送离线消息，恢复转发后 A 必须自动重新认证、补拉消息且不重复
- `contact_lifecycle_test.dart`：双设备真实联系人生命周期。只通过 `make app.test.patrol.contact` 编排运行；A 修改 B 的备注并验证列表优先展示，删除 B 后重新搜索和发送申请，B 接受后双方联系人关系恢复
- `offline_recovery_test.dart`：双设备前后台重连和离线消息恢复。只通过 `make app.test.patrol.offline` 编排运行；A 主动断开 WebSocket 并进入后台，B 在离线窗口发送消息，A 回前台后断言重新认证、当前会话恢复且消息不重复
- `device_layout_test.dart`：真实账号进入私聊后的长 composer、发送按钮边界和焦点优先返回回归。Patrol 4.3 无法通过 iOS native tree 定位 Flutter `TextField`，因此该用例不作为真实系统软键盘 PASS 证据
- `permission_flow_test.dart`：由 `simctl privacy revoke` 建立真实 iOS 永久拒绝状态，验证相册和麦克风业务入口提供“前往设置”降级 UI；不声称覆盖首次系统弹窗或设置恢复
- `page_navigation_test.dart`：真实账号巡检联系人、群聊、群通知、个人资料、账号安全、聊天设置、隐私政策、关于和反馈等 P0 页面，验证页面可打开、可返回，并滚动反馈页到提交按钮；不作为系统键盘、安全区或可访问性视觉验收证据

注意：
- `test_bundle.dart` 由 Patrol CLI 运行时自动生成，已加入 `.gitignore`，不要提交。
- 本机存在 `8081 / 8082` 端口占用时，Patrol 默认端口会把 app service 请求打到宿主机其他服务上，导致 `markPatrolAppServiceReady() failed with 404`。本仓库默认改用 `19081 / 19082` 规避冲突。
- 双设备私聊和群聊共用同一编排脚本，固定使用四个不同的 test/app server 端口，并把 A/B 源码复制到两个临时工作区。Patrol 固定的 `build/ios_integ`、`.dart_tool/flutter_build` 和生成的 `test_bundle.dart` 因此不会跨角色复用。
- 编排脚本也接受已连接的 Android Emulator，并在 `run.env` 记录 A/B 平台。跨端私聊固定使用 iOS A (`127.0.0.1`) 与 Android B (`10.0.2.2`)；跨端离线恢复反转角色，让 Android A 执行后台恢复、iOS B 在离线窗口发送。
- B 端输出经过编译参数和真实登录验证的 `DUAL_READY` 后才启动 A；完成时还会核对双方首条 `DUAL_IDENTITY` 的角色、账号、marker 和消息前缀。全新隔离构建可能超过两分钟，因此双端可见性等待窗口为 300 秒。
- 群聊、群禁言和成员移除用例分别要求 A/B 输出 `DUAL_GROUP_COMPLETE`、`DUAL_GROUP_MUTE_COMPLETE`和 `DUAL_GROUP_MEMBER_REMOVAL_COMPLETE`。当业务断言已经完成但 B 端 XCTest 收尾不退出时，编排器据此受控结束残留进程；没有双方完成标记时仍判失败。
- 图片附件用例要求 A/B 输出 `DUAL_IMAGE_ATTACHMENT_COMPLETE`。Patrol 4.5 无法跨进程稳定驱动 iOS 26 PHPicker，因此该用例替换测试进程中的 picker 返回值，不把系统 PHPicker 交互记为自动化 PASS；系统选择器仍按人工清单验收。
- 文件与语音附件用例要求 A/B 输出 `DUAL_RICH_ATTACHMENT_COMPLETE`。固定 PDF 由测试进程替换 file selector 返回值，固定静音 M4A 跳过真实麦克风采集；系统文件选择器、真实录音质量和听感仍按人工清单验收。
- 网络恢复用例要求 A/B 输出 `DUAL_NETWORK_RECOVERY_COMPLETE`。它证明 App 的 API/WebSocket TCP 路径真实中断与恢复，不等同于 Simulator 系统 Wi-Fi、蜂窝或 Network Link Conditioner UI 验收。
- 用例启动时会把 `user_agreed_to_terms` 明确设为 `true`，避免 Simulator 历史偏好状态影响登录结果。
- 任一端失败或超时会终止另一端。双方日志、marker 和 `xcresult` 归档到 `app/build/patrol-dual/<marker>/`，临时工程在退出时删除。

建议命令：

```bash
cd app
patrol test -t patrol_test/harness_smoke_test.dart \
  -d <simulator-uuid> \
  --test-server-port 19081 \
  --app-server-port 19082

patrol test -t patrol_test/login_smoke_test.dart \
  -d <simulator-uuid> \
  --test-server-port 19081 \
  --app-server-port 19082 \
  --dart-define USE_MOCK_DATA=true \
  --dart-define API_BASE_URL=http://127.0.0.1:1 \
  --dart-define WS_URL=ws://127.0.0.1:1/ws

# 从仓库根目录运行；双设备入口必须使用两个不同且已 Booted 的 Simulator UUID
make app.test.patrol.dual \
  PATROL_DUAL_DEVICE_A=<simulator-a-uuid> \
  PATROL_DUAL_DEVICE_B=<simulator-b-uuid> \
  PATROL_DUAL_ACCOUNT_A=<account-a> \
  PATROL_DUAL_ACCOUNT_B=<account-b> \
  PATROL_DUAL_PASSWORD=<password>

make app.test.patrol.rich-attachment \
  PATROL_DUAL_DEVICE_A=<simulator-a-uuid> \
  PATROL_DUAL_DEVICE_B=<simulator-b-uuid> \
  PATROL_DUAL_ACCOUNT_A=<account-a> \
  PATROL_DUAL_ACCOUNT_B=<account-b> \
  PATROL_DUAL_PASSWORD=<password>

make app.test.patrol.cross \
  PATROL_CROSS_IOS_DEVICE=<ios-simulator-uuid> \
  PATROL_CROSS_ANDROID_DEVICE=<android-emulator-id> \
  PATROL_CROSS_IOS_ACCOUNT=<ios-account> \
  PATROL_CROSS_ANDROID_ACCOUNT=<android-account> \
  PATROL_CROSS_PASSWORD=<password>

make app.test.patrol.cross-offline \
  PATROL_CROSS_IOS_DEVICE=<ios-simulator-uuid> \
  PATROL_CROSS_ANDROID_DEVICE=<android-emulator-id> \
  PATROL_CROSS_IOS_ACCOUNT=<ios-account> \
  PATROL_CROSS_ANDROID_ACCOUNT=<android-account> \
  PATROL_CROSS_PASSWORD=<password>

make app.test.patrol.contact \
  PATROL_DUAL_DEVICE_A=<simulator-a-uuid> \
  PATROL_DUAL_DEVICE_B=<simulator-b-uuid> \
  PATROL_DUAL_ACCOUNT_A=<account-a> \
  PATROL_DUAL_ACCOUNT_B=<account-b> \
  PATROL_DUAL_PASSWORD=<password>

make app.test.patrol.group-mute \
  PATROL_DUAL_DEVICE_A=<simulator-a-uuid> \
  PATROL_DUAL_DEVICE_B=<simulator-b-uuid> \
  PATROL_DUAL_ACCOUNT_A=<account-a> \
  PATROL_DUAL_ACCOUNT_B=<account-b> \
  PATROL_DUAL_PASSWORD=<password>

make app.test.patrol.group-member-removal \
  PATROL_DUAL_DEVICE_A=<simulator-a-uuid> \
  PATROL_DUAL_DEVICE_B=<simulator-b-uuid> \
  PATROL_DUAL_ACCOUNT_A=<account-a> \
  PATROL_DUAL_ACCOUNT_B=<account-b> \
  PATROL_DUAL_PASSWORD=<password>

make app.test.patrol.permission \
  PATROL_PERMISSION_DEVICE=<simulator-uuid> \
  PATROL_PERMISSION_ACCOUNT=<account> \
  PATROL_PERMISSION_PEER_ACCOUNT=<peer-account> \
  PATROL_PERMISSION_PASSWORD=<password>

make app.test.patrol.pages \
  PATROL_PAGE_DEVICE=<simulator-uuid> \
  PATROL_PAGE_ACCOUNT=<account> \
  PATROL_PAGE_PASSWORD=<password>
```
