# E2EE MLS API

> 当前接口用于 U3 联调。生产 E2EE 仍为 No-Go，U2-U9 发布门禁关闭前不得启用正式消息链。

所有接口都要求普通用户 Bearer token。二进制字段使用标准 Base64，协议版本当前只接受 `1`；请求包含未知字段时拒绝处理。

## 设备

### 注册设备

`POST /e2ee/mls/devices`

```json
{
  "device_id": "0198...",
  "device_label": "Alice iPhone",
  "root_public_key": "<base64 1..4096 bytes>",
  "root_fingerprint": "<base64 16..128 bytes>",
  "credential": "<base64 1..65536 bytes>",
  "credential_fingerprint": "<base64 16..128 bytes>",
  "approval_public_key": "<base64 Ed25519 public key, 32 bytes>",
  "protocol_version": 1
}
```

账号首台设备进入 `active`，后续设备进入 `pending_approval`。同一 `device_id` 只有全部公开材料完全一致时才允许幂等重试；根身份或设备凭据变化返回冲突，不会覆盖旧值。

`approval_public_key` 仅用于验证可信设备对新设备的批准授权，不是 MLS 私钥。对应私钥只能保存在客户端安全存储中。

### 查询与撤销

- `GET /e2ee/mls/devices`：查询当前账号全部设备，不返回凭据、根公钥或批准公钥。
- `DELETE /e2ee/mls/devices/{device_id}`：撤销当前账号设备，并将相关房间标记为需要 rekey。

撤销会把该用户参与的全部房间置为 `rekey_required`（即使设备从未加入某个房间的
MLS group，客户端仍按房间执行成员移除并以 `member not found` 跳过）。已撤销
设备不能发布/领取 KeyPackage、拉取或提交控制消息；重复撤销幂等返回当前
`revoked` 状态，不重复推进房间 rekey。待批准设备无需撤销，返回 `409` 冲突。

### 查询账号根身份

`GET /e2ee/mls/identities/{user_id}` 返回账号稳定根身份的公开材料：

```json
{
  "user_id": "0198...",
  "root_public_key": "<base64 1..4096 bytes>",
  "root_fingerprint": "<base64 16..128 bytes>",
  "protocol_version": 1,
  "created_at": "2026-08-04T12:00:00Z",
  "updated_at": "2026-08-04T12:00:00Z"
}
```

只允许查询当前账号自身或已建立好友关系的账号。无权限、目标未初始化 E2EE
或目标不存在时统一返回 `404`，避免枚举账号身份状态。客户端必须对首次读取执行
TOFU；后续指纹变化时阻断发送，不得用本响应静默覆盖本地可信记录。

### 查询对方设备列表

`GET /e2ee/mls/identities/{user_id}/devices` 返回目标账号当前 `active` 设备
的公开信息（仅本人或已建立好友关系可查，否则统一返回 `404`）：

```json
[
  {
    "id": "0198...",
    "protocol_version": 1,
    "credential_fingerprint": "<base64>"
  }
]
```

### 批准新设备

`POST /e2ee/mls/devices/{target_device_id}/approve`

```json
{
  "approver_device_id": "0198...",
  "signature": "<base64 Ed25519 signature, 64 bytes>"
}
```

签名算法为 Ed25519。签名输入是以下字段直接拼接，不使用 JSON，不包含文本 UUID，也不做 Base64：

```text
ASCII "redcode-im/e2ee/device-approval/v1\0"
|| user_id UUID raw bytes (16)
|| approver_device_id UUID raw bytes (16)
|| target_device_id UUID raw bytes (16)
|| protocol_version signed i16 big-endian (2)
|| credential_fingerprint_length unsigned u16 big-endian (2)
|| target credential_fingerprint raw bytes
```

批准者必须是当前账号的 `active` 设备，目标必须是当前账号的 `pending_approval` 设备。服务端使用批准设备注册时的 `approval_public_key` 验证签名；普通登录 token 本身不能完成批准。目标已为 `active` 时重复批准幂等返回当前状态，不误判为冲突。

## KeyPackage

### 发布

`POST /e2ee/mls/devices/{device_id}/key-packages`

```json
{
  "packages": [{
    "id": "0198...",
    "package_ref": "<base64 16..128 bytes>",
    "key_package": "<base64 1..1048576 bytes>",
    "protocol_version": 1,
    "expires_at": "2026-08-05T12:00:00Z"
  }]
}
```

单次发布 `1..100` 个，只允许当前账号的 `active` 设备发布；有效期必须晚于当前时间且不超过 30 天，协议版本必须与设备一致。重复 `package_ref` 不重复插入，响应 `inserted` 是本次实际新增数量。每账号设备每分钟最多发布 60 次，每台设备最多保留 500 个未过期、未消费 KeyPackage。

### 库存查询

`GET /e2ee/mls/devices/{device_id}/key-packages`

```json
{
  "available": 12,
  "maxAvailable": 500
}
```

返回当前账号 `active` 设备尚未消费、未过期的 KeyPackage 数量与每设备上限。客户端在
首次初始化、进入前台和受控周期检查时读取该库存，低于低水位后批量补充；未批准、已
撤销或不属于当前账号的设备返回 `403`。

### 领取

`POST /e2ee/mls/devices/{target_device_id}/key-packages/claim`

```json
{
  "room_id": "0198...",
  "consumer_device_id": "0198..."
}
```

调用 token 必须拥有该 `consumer_device_id`，调用账号与目标设备账号都必须是 `room_id` 的当前成员，且消费设备和目标设备都必须为 `active`。领取通过数据库原子更新和 `FOR UPDATE SKIP LOCKED` 完成，一个 KeyPackage 最多成功返回一次；每账号每分钟最多领取 120 次。没有可用项统一返回 `404`，不暴露其他账号的设备状态。

## 错误边界

- `400`：Base64、长度、协议版本、有效期或请求字段不合法。
- `403`：设备未获批准、已撤销、签名失败或设备不属于当前账号。
- `404`：设备或可领取 KeyPackage 不存在；领取接口用此状态隐藏归属差异。
- `409` / 业务码 `40902`：根身份、设备材料或设备状态发生冲突。

## 房间 Epoch

`GET /rooms/{room_id}/e2ee/epoch` 返回：

```json
{
  "room_id": "0198...",
  "membership_revision": 3,
  "active_epoch": 1,
  "status": "rekey_required",
  "updated_at": "2026-08-04T16:00:00Z"
}
```

`membership_revision` 由数据库根据 `room_members` 的活跃成员集合变化自动推进。新增、恢复、退出或移除成员会推进 revision；角色、通知设置和已读状态变化不会推进。房间处于 `active` 时发生成员变化，状态立即转为 `rekey_required`。

## 控制消息

### 提交 Commit 或 Welcome

`POST /rooms/{room_id}/e2ee/control-messages`

```json
{
  "id": "0198...",
  "epoch": 2,
  "membership_revision": 3,
  "sender_device_id": "0198...",
  "recipient_device_id": null,
  "content_type": "commit",
  "envelope": "<base64 RCML v1 envelope>",
  "idempotency_key": "0198..."
}
```

- `commit` 必须广播，`recipient_device_id` 为 `null`；epoch 必须严格等于当前 `active_epoch + 1`。提交成功后服务端原子推进 active epoch，并为当前房间所有其他 active 设备创建 receipt。
- `welcome` 必须指定当前房间的 active 接收设备；epoch 必须等于当前 active epoch。
- `membership_revision` 必须等于服务端当前值。成员变化与 Commit 并发时，旧 revision 请求返回冲突，客户端必须刷新状态并重新生成 Commit。
- envelope 必须是对应 kind 的 RCML v1，最大 payload 为 16 MiB。服务端只校验外层合同，不解密 MLS 内容。
- 同一房间的 `idempotency_key` 或全局 `id` 只能绑定完全相同的消息。完全相同的重试返回原 sequence；内容漂移返回冲突。

### 分页拉取

`GET /rooms/{room_id}/e2ee/control-messages?device_id={device_id}&after_sequence=0&limit=50`

- `limit` 范围为 `1..100`，按 `sequence_no` 升序返回。
- token 必须拥有该 active 设备，账号必须仍是房间当前成员。
- 只返回提交时为该设备生成 receipt 的广播 Commit 或定向 Welcome。
- 成功返回即原子记录 `delivered_at`；重复拉取不重复创建 receipt。

### 确认消费

`POST /rooms/{room_id}/e2ee/control-messages/{message_id}/consume`

```json
{
  "device_id": "0198..."
}
```

消息必须先成功投递，且 token 仍拥有该 active 设备、账号仍是当前房间成员。成功后幂等写入 `consumed_at`；撤销设备或退出房间后不能继续拉取或确认控制消息。

## Application 消息发送

`POST /rooms/{room_id}/messages/encrypted`

```json
{
  "encrypted_content": "<base64 RCML v1 application envelope>",
  "encryption_metadata": {
    "protocol": "mls",
    "version": 1,
    "epoch": 2,
    "sender_device_id": "0198...",
    "content_type": "application",
    "control_message_id": "0198..."
  },
  "idempotency_key": "0198..."
}
```

- `sender_device_id` 必须是调用账号的 active 设备。
- 房间状态必须为 `active`，消息 epoch 必须等于当前 active epoch。
- `control_message_id` 必须引用当前 room、epoch 和 membership revision 的 Commit。
- 房间处于 `preparing` 或 `rekey_required`、设备待批准/已撤销、epoch 过期或 Commit 引用不匹配时返回冲突或禁止，不会降级发送明文。
- `persist` 模式在同一数据库事务中完成上述裁决与消息插入。相同幂等键和完全相同内容的重试返回原消息，不重复持久化、广播或 Push；内容漂移返回冲突。
- `relay_only` 模式使用 Redis 保留 10 分钟幂等占位；重复键返回冲突且不会再次广播，不保存消息历史。

## 遗留 Key Bundle 链路（旧客户端兼容）

以下为 2.0 之前的 Signal 风格 Key Bundle 链路，仅用于旧客户端兼容；新客户端
统一走上方 MLS 设备/KeyPackage 链路。

### 上传 Key Bundle

`POST /e2ee/keys/bundle`

```json
{
  "device_id": "device-id",
  "identity_key": "<base64 32 bytes>",
  "signed_pre_key": {
    "key_id": 1,
    "public_key": "<base64 32 bytes>",
    "signature": "<base64>"
  },
  "one_time_pre_keys": [
    { "key_id": 101, "public_key": "<base64 32 bytes>" }
  ]
}
```

响应：

```json
{
  "success": true,
  "message": "Key bundle 上传成功",
  "device_id": "device-id",
  "one_time_pre_keys_saved": 1
}
```

### 获取目标 Key Bundle

`GET /e2ee/users/{user_id}/key-bundles` 返回目标账号各设备的
Identity Key、Signed Pre-Key，并原子取用一个 One-Time Pre-Key
（`one_time_pre_key` 可能为 `null`，`one_time_pre_key_remaining` 为剩余数量）；
目标未初始化 E2EE 时返回 `404`。
