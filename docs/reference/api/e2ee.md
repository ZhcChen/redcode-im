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

批准者必须是当前账号的 `active` 设备，目标必须是当前账号的 `pending_approval` 设备。服务端使用批准设备注册时的 `approval_public_key` 验证签名；普通登录 token 本身不能完成批准。

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

单次发布 `1..100` 个，只允许当前账号的 `active` 设备发布；有效期必须晚于当前时间且不超过 30 天，协议版本必须与设备一致。重复 `package_ref` 不重复插入，响应 `inserted` 是本次实际新增数量。

### 领取

`POST /e2ee/mls/devices/{target_device_id}/key-packages/claim`

```json
{
  "room_id": "0198...",
  "consumer_device_id": "0198..."
}
```

调用 token 必须拥有该 `consumer_device_id`，调用账号与目标设备账号都必须是 `room_id` 的当前成员，且消费设备和目标设备都必须为 `active`。领取通过数据库原子更新和 `FOR UPDATE SKIP LOCKED` 完成，一个 KeyPackage 最多成功返回一次；没有可用项统一返回 `404`，不暴露其他账号的设备状态。

## 错误边界

- `400`：Base64、长度、协议版本、有效期或请求字段不合法。
- `403`：设备未获批准、已撤销、签名失败或设备不属于当前账号。
- `404`：设备或可领取 KeyPackage 不存在；领取接口用此状态隐藏归属差异。
- `409` / 业务码 `40902`：根身份、设备材料或设备状态发生冲突。
