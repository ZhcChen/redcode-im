# Go 黑盒契约测试（重构版）

本目录用于承载后端对外 HTTP/WS 契约测试。

当前状态：
- 已覆盖：`system`、`auth`、`users`、`friends`
- 待补齐：`rooms`、`messages`、`uploads`、`admin`、`websocket`

测试栈会自动启动 `external-mock`（第三方依赖模拟），用于覆盖：
- OAuth/JWKS（Google/Apple）
- FCM Push
- Tencent COS / CI
- IPInfo
