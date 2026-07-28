# 消息运行模式

RedCode IM 支持通过 Admin 后台配置服务端是否持久化聊天消息。该配置影响 API、WebSocket、Flutter 客户端和管理后台聊天记录能力。

## 模式

| 模式 | 服务端行为 | 适用场景 |
| --- | --- | --- |
| `persist` | 消息写入 PostgreSQL，再通过 Redis Pub/Sub 实时广播，并可进入离线 Push 队列。 | 企业运营、合规审计、换设备恢复历史、完整 IM 功能。 |
| `relay_only` | 消息只构造运行时快照并通过 Redis Pub/Sub 实时广播，不写 `messages` / `message_parts`，不写离线 Push 消息快照。 | 演示、低成本部署、临时聊天、偏隐私场景。 |

默认值：

```text
server_storage_mode=persist
content_audit_mode=plaintext
```

`content_audit_mode` 目前用于声明运行目标：

- `plaintext`：服务端可处理明文内容。
- `e2ee`：目标为端侧加密；当前不代表完整 E2EE 协议已经切换。

## relay_only 功能边界

`relay_only` 不是“低成本但功能完全一致”的模式。它会主动降级依赖服务端消息记录的功能：

- 房间历史消息：返回空列表。
- 消息搜索、搜索建议、热门关键词：返回空结果。
- Admin 聊天记录：返回空结果或不展示最后一条消息。
- 聊天摘要：不使用服务端最后一条消息，未读数归零。
- 引用、转发、编辑、删除、清空聊天记录、置顶、reaction、已读回执：返回 HTTP 400 ErrorResponse，`code=42201`，`message` 包含 `relay_only`。
- 离线 Push：不生成 message 类型的 `push_job_queue` 任务，避免把消息正文或预览作为短期队列 payload 落库。
- 附件下载：发送附件消息时写入 Redis TTL 临时授权，接收方仍需是房间成员才能换取下载 URL；附件 `object_key` 必须属于当前房间前缀 `messages/{room_id}/`，并且必须已经走上传提交链路形成 completed 上传记录。TTL 内即使后台切回 `persist`，该临时授权仍可用于换取下载 URL；生成的下载 URL 有效期不会超过 Redis grant 剩余 TTL。Redis 授权过期或丢失后，服务端不再能恢复该附件消息的下载授权。

客户端仍可把自己收到或发送过的消息保存到本地 SQLite，用于本机历史展示；换设备或清除本地数据后，服务端无法恢复 `relay_only` 模式下的消息正文。群成员关系、群目录收藏和会话归档属于独立的房间元数据，不受消息存储模式影响；具体边界见 `docs/reference/architecture/conversation-state-lifecycle.md`。

注意：`relay_only` 不删除此前 `persist` 模式已经写入的历史消息，只是在当前模式下隐藏依赖服务端消息记录的读取能力；切回 `persist` 后旧历史仍按数据库现状可见。附件上传仍走对象存储与必要审核元数据链路，消息正文/parts 本身不会写入服务端历史；relay-only 附件只在 Redis 临时授权 TTL 内可下载。

## 实时广播链路

```text
客户端发送消息
 -> API 校验房间成员与发送权限
 -> persist: 写 PostgreSQL
 -> relay_only: 构造运行时消息快照
 -> relay_only: 为附件 object_key 写入 Redis TTL 下载授权（如有附件）
 -> Redis Pub/Sub 发布到房间频道
 -> 各 API 节点的 PubSubHub 投递给本节点 WebSocket 连接
 -> relay_only: 不写离线 Push 队列
```

`relay_only` 对 Redis Pub/Sub 是强依赖：发布失败时发送接口返回 HTTP 503 ErrorResponse（`code=50302`），不会向客户端报告 `sent`。

当前实现仍保留两个后续优化点：

- 附件 grant 逐个写 Redis；如上传策略允许大量附件/缩略图，后续可改为 Redis pipeline 并补压测。
- `relay_only` 不持久化服务端消息状态，`/chats` 不会因新消息自动持久化上浮；如产品要求 relay-only 活跃排序，需要引入轻量 `last_activity` 元数据或 Redis sorted set。

## 配置入口

- Admin 页面：`系统设置 -> 消息运行模式`
- Admin API：`GET/PUT /api/admin/settings/message-runtime`
- 客户端公开设置：`GET /settings/general` 的 `message_runtime`

## 验证入口

主回归入口：

```bash
make api.test
```

关键 API 合同可用以下 Compose 内定向用例补充验证：

```bash
docker compose -f tests/docker-compose.test.yml run --rm rust-tests cargo test --test admin_integration message_runtime_settings_can_be_updated_and_read_publicly
docker compose -f tests/docker-compose.test.yml run --rm rust-tests cargo test --test websocket_integration relay_only_message_broadcasts_without_server_persistence
```
