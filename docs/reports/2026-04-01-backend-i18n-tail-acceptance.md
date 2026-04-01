# 2026-04-01 Backend i18n Tail Acceptance

## 本轮范围

本轮收口聚焦 Backend 剩余多语言长尾，覆盖以下提交：

1. `b36594ec` `feat(backend): localize upload emoji report push and e2ee tails`
2. `ccc7c2a8` `feat(backend): localize version room and message read tails`
3. `d8d9d9ff` `feat(backend): localize storage audit and cos tails`
4. `f9a655f9` `feat(backend): localize feedback policy and chat history tails`
5. `feat(backend): localize user avatar and settings tails`
6. `feat(backend): normalize auth friend and message success tails`
7. `feat(backend): localize cleanup storage provider tails`

## 新增 / 补齐内容

### 1. catalog

新增：
- `backend/i18n/{zh-CN,en-US}/feedback.json`
- `backend/i18n/{zh-CN,en-US}/upload_policy.json`
- `backend/i18n/{zh-CN,en-US}/settings.json`

补齐：
- `backend/i18n/{zh-CN,en-US}/room.json`
- `backend/i18n/{zh-CN,en-US}/upload.json`
- `backend/i18n/{zh-CN,en-US}/common.json`
- `backend/i18n/{zh-CN,en-US}/admin.json`
- `backend/i18n/{zh-CN,en-US}/user.json`

### 2. handler / service / storage

已完成本轮尾项：
- `backend/src/services/file_upload_audit.rs`
- `backend/src/storage/cos.rs`
- `backend/src/handlers/chat_history.rs`
- `backend/src/handlers/feedback.rs`
- `backend/src/handlers/upload_policy.rs`
- `backend/src/handlers/activity_logs.rs`
- `backend/src/handlers/user.rs`
- `backend/src/handlers/settings.rs`
- `backend/src/handlers/auth.rs`
- `backend/src/handlers/friend.rs`
- `backend/src/handlers/message.rs`
- `backend/src/services/file_upload_cleanup.rs`

落地策略：
- 错误路径统一改为 `message_key + message_params`
- `claims.sub` 解析失败统一复用 `auth.token_subject_invalid`
- 非关键 success message 尽量收敛为 `"ok"`

### 3. Go locale contract

新增/补强：
- `tests/go/backend/system/locale_contract_test.go`
- `tests/go/backend/versions/version_latest_download_test.go`
- `tests/go/backend/rooms/room_lifecycle_test.go`
- `tests/go/backend/messages/unread_counts_test.go`

覆盖点：
- 英文错误响应
- 非支持语言回退中文
- `message_key/message/message_params/details` 协议稳定性

## 验证结果

### Rust

```bash
cd backend && cargo test i18n --lib -- --test-threads=1
cd backend && cargo test storage::cos --lib -- --test-threads=1
cd backend && cargo test handlers::feedback --lib -- --test-threads=1
cd backend && cargo test handlers::upload_policy --lib -- --test-threads=1
cd backend && cargo test handlers::chat_history --lib -- --test-threads=1
cd backend && cargo test handlers::activity_logs --lib -- --test-threads=1
cd backend && cargo test handlers::user --lib -- --test-threads=1
cd backend && cargo test handlers::settings --lib -- --test-threads=1
cd backend && cargo test handlers::auth --lib -- --test-threads=1
cd backend && cargo test handlers::friend --lib -- --test-threads=1
cd backend && cargo test handlers::message --lib -- --test-threads=1
cd backend && cargo test services::file_upload_cleanup --lib -- --test-threads=1
```

结果：通过。

### Go（隔离栈）

```bash
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml up -d external-mock postgres redis-session redis-cache backend
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml run --rm go-tests \
  go test ./backend/system ./backend/versions ./backend/rooms ./backend/messages -v
cd tests && COMPOSE_PROJECT_NAME=redcode_im_i18n_tail docker compose -f docker-compose.yml down -v --remove-orphans
```

结果：通过。

## 已知剩余项

1. `file_upload_audit` 中写入数据库的 `last_error` / `rejected_reason` 仍保留原始中文原因，本轮未做持久化文本国际化。
2. Go 黑盒当前没有稳定的“缺失翻译 key”外部入口，因此该规则仍由 Rust 单测 `i18n_missing_key_fallback_to_message_key` 兜底。
3. `settings.rs` 中隐私协议 / 用户协议的 fallback 文案仍为固定内容，本轮只收口校验错误与用户可感知的短尾响应。
4. `auth.rs` / `friend.rs` / `message.rs` 本轮将多处 success message 统一收敛为 `"ok"`，优先保证协议稳定而非继续扩展 success 文案 catalog。
5. 仓库内仍存在部分非本轮范围的中文 success message / 历史错误字符串，不能据此宣称“全仓库 100% i18n 完成”。
