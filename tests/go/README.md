# Go 黑盒契约测试（重构版）

本目录用于承载后端对外 HTTP/WS 契约测试。

当前状态：
- 已覆盖：`system`、`auth`、`users`、`friends`、`rooms`、`messages`、`uploads`、`versions`、`admin`、`websocket`
- 已新增：`system/locale_contract_test.go`，并补齐 `versions` / `rooms` / `messages` 的 locale 断言
- 当前重点：稳定维护黑盒协议，优先验证 `message_key + message + message_params` 不回退

测试栈会自动启动 `external-mock`（第三方依赖模拟），用于覆盖：
- OAuth/JWKS（Google/Apple）
- FCM Push
- Tencent COS / CI
- IPInfo

## 常用命令

```bash
# 宿主环境 backend 已确认跑在当前分支时
cd tests/go && go test ./... -v

# 推荐：用隔离栈执行 locale contract，避免误打到宿主 8010 的旧 backend
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml up -d external-mock postgres redis-session redis-cache backend
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml run --rm go-tests \
  go test ./backend/system ./backend/versions ./backend/rooms ./backend/messages -v
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml down -v --remove-orphans
```

## 说明

- `system/locale_contract_test.go` 当前覆盖：
  - `Accept-Language: en-US` 返回英文 `message`
  - 不支持语言回退 `zh-CN`
- “缺失翻译回退 message_key” 当前由 Rust 单元测试 `backend/src/i18n/tests.rs::i18n_missing_key_fallback_to_message_key` 兜底；现有黑盒路由中没有稳定暴露“缺失翻译 key”的外部入口。
