# Go 黑盒契约测试（重构版）

本目录用于承载后端对外 HTTP/WS 契约测试。

当前状态：
- 已覆盖：`system`、`auth`、`users`、`friends`、`rooms`、`messages`、`uploads`、`versions`、`admin`、`websocket`
- 待补齐：无（Backend Go 黑盒主域已覆盖，后续进入前端各模块测试）

测试栈会自动启动 `external-mock`（第三方依赖模拟），用于覆盖：
- OAuth/JWKS（Google/Apple）
- FCM Push
- Tencent COS / CI
- IPInfo
