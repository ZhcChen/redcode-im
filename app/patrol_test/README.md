# Patrol E2E

当前目录用于承载 Patrol 专用用例，避免和 `integration_test/` 的轻量 smoke 混用。

当前已落地：
- `login_smoke_test.dart`：登录页基础可见性、注册切换、mock 登录、四 Tab、二级路由、系统返回和 Android 前后台恢复 smoke。`enterText()` 不会拉起原生软键盘，键盘遮挡仍需设备人工验收
- `harness_smoke_test.dart`：最小 Patrol harness 冒烟，优先用于验证 iOS / Android 原生测试桥是否可用
- `dual_device_chat_test.dart`：双设备真实账号登录、私聊文本实时互发和双向已读同步。只通过 `make app.test.patrol.dual` 编排运行；B 先进入会话等待，A 发送后 B 回复，双方均断言 WebSocket 实时消息可见且自己的消息更新为已读
- `group_chat_test.dart`：双设备真实账号创建群聊、群消息实时互发和管理员权限刷新。只通过 `make app.test.patrol.group` 编排运行；A 创建包含 B 的群聊并与 B 互发消息，B 停留在群设置页时，A 通过真实 UI 任命 B 为管理员，B 无需重新进页即可见“禁言管理”
- `offline_recovery_test.dart`：双设备前后台重连和离线消息恢复。只通过 `make app.test.patrol.offline` 编排运行；A 主动断开 WebSocket 并进入后台，B 在离线窗口发送消息，A 回前台后断言重新认证、当前会话恢复且消息不重复
- `device_layout_test.dart`：真实账号进入私聊后的长 composer、发送按钮边界和焦点优先返回回归。Patrol 4.3 无法通过 iOS native tree 定位 Flutter `TextField`，因此该用例不作为真实系统软键盘 PASS 证据
- `permission_flow_test.dart`：由 `simctl privacy revoke` 建立真实 iOS 永久拒绝状态，验证相册和麦克风业务入口提供“前往设置”降级 UI；不声称覆盖首次系统弹窗或设置恢复

注意：
- `test_bundle.dart` 由 Patrol CLI 运行时自动生成，已加入 `.gitignore`，不要提交。
- 本机存在 `8081 / 8082` 端口占用时，Patrol 默认端口会把 app service 请求打到宿主机其他服务上，导致 `markPatrolAppServiceReady() failed with 404`。本仓库默认改用 `19081 / 19082` 规避冲突。
- 双设备私聊和群聊共用同一编排脚本，固定使用四个不同的 test/app server 端口，并把 A/B 源码复制到两个临时工作区。Patrol 固定的 `build/ios_integ`、`.dart_tool/flutter_build` 和生成的 `test_bundle.dart` 因此不会跨角色复用。
- B 端输出经过编译参数和真实登录验证的 `DUAL_READY` 后才启动 A；完成时还会核对双方首条 `DUAL_IDENTITY` 的角色、账号、marker 和消息前缀。全新隔离构建可能超过两分钟，因此双端可见性等待窗口为 300 秒。
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

# 从仓库根目录运行；设备必须是两个不同且已 Booted 的 Simulator UUID
make app.test.patrol.dual \
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
```
