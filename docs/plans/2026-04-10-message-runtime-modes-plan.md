# 消息运行模式与服务器存储开关计划

- status: completed
- date: 2026-04-10
- owner: codex

> 说明：第 1-8 节保留原计划与历史决策语境；当前完成事实以第 9 节和 `docs/reference/architecture/message-runtime-modes.md` 为准。

## 1. 问题定义
当前消息链路默认假设“服务端持久化消息”，`send_message` / `send_encrypted_message` 都直接写入 `messages` 与 `message_parts`。这与目标能力存在差距：
1. 管理后台需要配置“服务端是否存储聊天记录”
2. 关闭后，服务端应仅负责实时转发，不保留消息正文与附件分片记录
3. 企业审计场景下，需要明确“内容可审计（明文）/ 不可审计（端侧加密）”的运行模式边界

## 2. 现状结论
- 已有 E2EE key API 与 `messages.encrypted_content` 字段，但当前仍是“密文落库透传”，不是“服务端不存储”
- `general_settings` 已可承载全局开关，无需新增表
- 以下能力当前都依赖消息落库：
  - 房间历史消息 `/rooms/{room_id}/messages`
  - 搜索 `/messages/search`
  - 后台聊天记录 `backend/src/handlers/chat_history.rs`
  - 转发 / 引用 / 编辑 / 删除 / reaction / 已读
  - push 队列（当前只存 `message_id`，发送时再回查 DB）

## 3. 范围边界
### 本轮纳入
1. 建立“消息运行模式”设置基座（后端 + admin）
2. 对外公开当前模式给客户端读取
3. 第一阶段只切 **服务器存储开关**，不在本轮真正实现完整端到端加密协议
4. 为下一阶段行为切换预留清晰枚举与 API 契约

### 本轮不纳入
1. 真正的端到端加密客户端协议联调
2. relay-only 模式下所有历史/搜索/转发等完整降级实现
3. push 队列从 message_id 改为快照 payload 的完整改造

## 4. 关键决策
### 决策 A：拆成两个维度而不是一个布尔值
- `server_storage_mode`: `persist` / `relay_only`
- `content_audit_mode`: `plaintext` / `e2ee`

理由：
- “是否存储”与“是否可审计”不是同一维度
- 企业场景常见组合是 `persist + plaintext`
- 隐私场景可能是 `persist + e2ee` 或未来的 `relay_only + e2ee`

### 决策 B：本轮只让 `content_audit_mode` 进入配置面，不切主链路行为
理由：
- 当前客户端没有完整 E2EE 收发链路，直接切行为会导致不可用
- 先把运行模式定义固定住，避免后续接口再次返工

### 决策 C：客户端公开接口复用 `/settings/general`
理由：
- Flutter 已有 `SettingsService.fetchAppName()` / `/settings/general` 读取模式
- 复用通用设置返回，减少新增公开接口数量

## 5. 实施单元

### Unit 1：后端消息运行模式设置基座
- Files:
  - `backend/src/database/settings_store.rs`
  - `backend/src/handlers/settings.rs`
  - `backend/src/routes.rs`
- Goal:
  - 定义消息运行模式的读写常量、默认值与管理员更新接口
- Decisions:
  - 默认值为 `server_storage_mode=persist`、`content_audit_mode=plaintext`
  - 懒写入 `general_settings`，不新增 migration
- Verification:
  - 能通过 admin API 获取/更新模式
  - 非法枚举值被拒绝

### Unit 2：admin 通用设置新增“消息运行模式”页签
- Files:
  - `admin/src/api/settings.ts`
  - `admin/src/views/settings/general/index.vue`
- Goal:
  - 管理员可查看并修改消息运行模式
- Decisions:
  - 使用单独 tab，避免和应用名称/上传策略混杂
  - UI 明确提示 relay-only 的功能退化风险
- Verification:
  - 页面加载可看到当前值
  - 提交后刷新仍能保持

### Unit 3：公开通用设置扩展给客户端
- Files:
  - `backend/src/handlers/settings.rs`
  - `frontend/lib/core/services/settings_service.dart`
- Goal:
  - 客户端能拉到当前消息模式，为后续行为切换做前置条件
- Decisions:
  - `GET /settings/general` 扩展返回，不破坏已有 `app_name`
- Verification:
  - 旧字段保持兼容
  - 新字段缺失时客户端有默认回退

## 6. 下一阶段（本计划之后）
1. relay-only 模式下 `send_message` 改为“构造消息快照后直接广播，不写 messages/message_parts”
2. push 队列 job payload 改为最小快照，不再依赖 `message_id` 回查数据库
3. 房间历史 / 搜索 / 后台聊天记录 / 引用转发 / reaction / 已读功能按模式降级
4. 客户端根据模式隐藏不支持的交互

### 6.1 第二阶段代码扫描结论（2026-04-10）
已确认以下链路直接依赖消息落库，不能只改发送端：

- 发送主链路：
  - `backend/src/handlers/message.rs`
    - `send_message`
    - `send_encrypted_message`
    - `forward_message`
- 广播链路：
  - `broadcast_message_to_room` 当前可接受“内存快照”，这部分可以复用，不是主要阻塞点
- Push 链路：
  - `backend/src/services/push.rs`
  - 当前 job payload 只有 `message_id`
  - worker 会二次查询 `messages` / `message_parts`
- 房间消息历史：
  - `backend/src/database/message_store.rs`
  - `backend/src/handlers/message.rs` 的 `/rooms/{room_id}/messages`
- 搜索：
  - `backend/src/handlers/message_search.rs`
- 后台聊天记录：
  - `backend/src/handlers/chat_history.rs`
- 聊天摘要 / 未读：
  - `backend/src/database/room_store.rs::list_chat_summaries`
  - `backend/src/handlers/message_read.rs`

### 6.2 第二阶段建议拆分

#### Unit 4：抽出公共消息运行模式服务
- Files:
  - `backend/src/services/message_runtime.rs`
  - `backend/src/handlers/settings.rs`
  - `backend/src/services/mod.rs`
- Goal:
  - 把 `persist / relay_only` 与 `plaintext / e2ee` 的读取、校验、更新抽成公共能力
- Why:
  - 后续发送链路、push、读侧降级都要共用，不能继续把逻辑锁死在 settings handler 里

#### Unit 5：实现 relay-only 的最小发送闭环
- Files:
  - `backend/src/handlers/message.rs`
  - `backend/src/services/push.rs`
  - `backend/src/database/user_store.rs`（如需补发件人资料读取）
- Goal:
  - `send_message` / `send_encrypted_message` 在 `relay_only` 下不写 `messages` / `message_parts`
  - 改为构造消息快照后：
    - 直接广播到 WebSocket
    - push 入队使用最小快照 payload
- Scope note:
  - 最小可行版本建议先禁止 `quoted_message_id`
  - `forward_message` 暂不支持 relay-only，直接返回模式不支持错误

#### Unit 6：读侧与变更侧降级
- Files:
  - `backend/src/handlers/message.rs`
  - `backend/src/handlers/message_search.rs`
  - `backend/src/handlers/chat_history.rs`
  - `backend/src/handlers/message_read.rs`
  - `backend/src/database/room_store.rs`
- Goal:
  - 在 `relay_only` 下明确行为，而不是继续假装支持
- 建议口径:
  - 房间历史消息：返回空列表
  - 搜索：返回空结果
  - 后台聊天记录：返回空结果
  - 转发 / 编辑 / 删除 / reaction / pin / read：返回“当前消息运行模式不支持该操作”
  - 聊天摘要：`last_message = null`，`unread_count = 0`

### 6.3 第二阶段的产品边界
- `relay_only + plaintext`：
  - 服务端可看见消息内容，但不保留消息记录
- `relay_only + e2ee`：
  - 服务端只做密文转发，且不落库
- 由于当前客户端没有“纯实时无历史”的完整降级体验，后端切换前必须同步补客户端 UI 降级

## 7. 风险
1. 配置已存在但行为未切换，容易让人误以为功能已完全生效
2. relay-only 真正落地后，会影响较多既有接口契约
3. push / unread / search 三条链路最容易遗漏
4. 房间摘要 `last_message / unread_count` 目前同样依赖落库，若不处理，聊天列表会出现“模式已切换但列表仍假定可追溯”的错位

## 8. 验证策略
- Backend:
  - `cargo test` 新增 settings handler / store 测试
- Admin:
  - `npm run type:check`
  - 新增或扩展 Playwright admin settings 用例
- Manual:
  - admin 修改设置后，公开 `/settings/general` 返回值同步变化

## 9. 收口结果（2026-07-23）

本计划已按 Flutter 首版服务端能力完成收口：

- `persist` 为默认完整持久化模式：消息写入 PostgreSQL，并通过 Redis Pub/Sub 实时广播。
- `relay_only` 为仅实时转发模式：发送成功时返回运行时消息快照，通过 Redis Pub/Sub 广播，但不写 `messages` / `message_parts`，也不写 message 类型离线 Push 队列。
- 读侧与变更侧按模式降级：
  - 房间历史消息返回空列表。
  - 消息搜索、搜索建议、热门关键词返回空结果。
  - 后台聊天记录不返回服务端历史。
  - 聊天摘要不展示服务端最后一条消息，未读数与已读游标归零。
  - 引用、转发、编辑、删除、清空聊天记录、置顶、reaction、已读回执返回 `relay_only` 不支持。
- Push 队列已使用 `PushMessageSnapshot` 支撑 `persist` 消息离线通知；`relay_only` 不生成该队列任务，避免把消息正文或预览短期落库。
- `relay_only` 附件发送要求 key 属于当前房间前缀并已完成上传提交；下载依赖 Redis TTL grant，生成的对象存储下载 URL 不超过 grant 剩余 TTL。
- Flutter 已读取公开 `message_runtime`，并在 `relay_only` 下跳过服务端历史、隐藏不支持动作、提示仅本地缓存。
- Admin “消息运行模式”页已更新为正式能力说明，不再提示“尚未切完整主链路”。
- 正式参考文档见 `docs/reference/architecture/message-runtime-modes.md`。

主回归入口：

```bash
make api.test
```

关键 API 合同可用以下 Compose 内定向用例补充验证：

```bash
docker compose -f tests/docker-compose.test.yml run --rm rust-tests cargo test --test admin_integration message_runtime_settings_can_be_updated_and_read_publicly
docker compose -f tests/docker-compose.test.yml run --rm rust-tests cargo test --test websocket_integration relay_only_message_broadcasts_without_server_persistence
```
