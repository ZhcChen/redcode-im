# Patrol E2E

当前目录用于承载 Patrol 专用用例，避免和 `integration_test/` 的轻量 smoke 混用。

当前已落地：
- `login_smoke_test.dart`：登录页基础可见性、注册切换、mock 登录、四 Tab、二级路由、系统返回和 Android 前后台恢复 smoke。`enterText()` 不会拉起原生软键盘，键盘遮挡仍需设备人工验收
- `harness_smoke_test.dart`：最小 Patrol harness 冒烟，优先用于验证 iOS / Android 原生测试桥是否可用
- `dual_device_chat_test.dart`：双设备真实账号登录和私聊文本实时互发。只通过 `make app.test.patrol.dual` 编排运行；B 先进入会话等待，A 发送后 B 回复，双方均断言 WebSocket 实时消息可见

注意：
- `test_bundle.dart` 由 Patrol CLI 运行时自动生成，已加入 `.gitignore`，不要提交。
- 本机存在 `8081 / 8082` 端口占用时，Patrol 默认端口会把 app service 请求打到宿主机其他服务上，导致 `markPatrolAppServiceReady() failed with 404`。本仓库默认改用 `19081 / 19082` 规避冲突。
- 双设备编排固定使用四个不同的 test/app server 端口，并把 A/B 源码复制到两个临时工作区。Patrol 固定的 `build/ios_integ`、`.dart_tool/flutter_build` 和生成的 `test_bundle.dart` 因此不会跨角色复用。
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
```
