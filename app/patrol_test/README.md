# Patrol E2E

当前目录用于承载 Patrol 专用用例，避免和 `integration_test/` 的轻量 smoke 混用。

当前已落地：
- `login_smoke_test.dart`：登录页基础可见性、注册切换、mock 登录导航 smoke
- `harness_smoke_test.dart`：最小 Patrol harness 冒烟，优先用于验证 iOS / Android 原生测试桥是否可用

注意：
- `test_bundle.dart` 由 Patrol CLI 运行时自动生成，已加入 `.gitignore`，不要提交。
- 本机存在 `8081 / 8082` 端口占用时，Patrol 默认端口会把 app service 请求打到宿主机其他服务上，导致 `markPatrolAppServiceReady() failed with 404`。本仓库默认改用 `19081 / 19082` 规避冲突。

建议命令：

```bash
cd frontend
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
