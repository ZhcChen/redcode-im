# Patrol E2E

当前目录用于承载 Patrol 专用用例，避免和 `integration_test/` 的轻量 smoke 混用。

当前已落地：
- `login_smoke_test.dart`：登录页基础可见性、注册切换、mock 登录、四 Tab、二级路由、系统返回和 Android 前后台恢复 smoke。`enterText()` 不会拉起原生软键盘，键盘遮挡仍需设备人工验收
- `harness_smoke_test.dart`：最小 Patrol harness 冒烟，优先用于验证 iOS / Android 原生测试桥是否可用
- `dual_device_chat_test.dart`：双设备真实账号登录和私聊文本实时互发。两个 Patrol 进程通过 `DUAL_ROLE=a/b` 分工，B 先进入会话等待，A 发送后 B 回复，双方均断言 WebSocket 实时消息可见

注意：
- `test_bundle.dart` 由 Patrol CLI 运行时自动生成，已加入 `.gitignore`，不要提交。
- 本机存在 `8081 / 8082` 端口占用时，Patrol 默认端口会把 app service 请求打到宿主机其他服务上，导致 `markPatrolAppServiceReady() failed with 404`。本仓库默认改用 `19081 / 19082` 规避冲突。
- 双设备进程必须使用不同的 test/app server 端口。B 端先完成构建并进入消息等待，再启动 A 端；用例使用 120 秒可见性超时覆盖第二台设备构建和导航时间。
- 用例启动时会把 `user_agreed_to_terms` 明确设为 `true`，避免 Simulator 历史偏好状态影响登录结果。

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
```
