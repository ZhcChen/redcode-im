# 登录设备管理接口

记录账号的登录设备，支持查看与撤销。撤销设备后，该设备的 access token、
refresh token 全部失效，并断开其 WebSocket 会话。

- 版本：API 2.0.0
- 认证：以下接口均需要 `Authorization: Bearer <token>`

## 设备登记

在登录/注册/短信登录/刷新请求体中可选携带以下字段（见 `auth.md`）：

| 字段 | 类型 | 说明 |
|---|---|---|
| `device_id` | string (UUID) | 客户端生成的稳定设备标识；不传则由服务端生成 |
| `device_name` | string | 设备名称，如 `iPhone 17 Pro`、`MacBook` |
| `platform` | string | 平台，如 `ios`、`android`、`macos`、`windows`、`web` |

登录响应中的 `deviceId` 即本次登记（或使用）的设备 ID，后续 JWT Claims 会携带
该设备标识用于识别「当前设备」。

## 1. 获取设备列表

- **方法**：`GET`
- **路径**：`/auth/devices`
- **认证**：是

响应（数组）：

```json
[
  {
    "deviceId": "11111111-1111-1111-1111-111111111111",
    "deviceName": "iPhone 17 Pro",
    "platform": "ios",
    "lastSeenAt": "2026-08-04T10:00:00Z",
    "createdAt": "2026-08-04T09:00:00Z",
    "revokedAt": null,
    "isCurrent": true
  },
  {
    "deviceId": "22222222-2222-2222-2222-222222222222",
    "deviceName": "MacBook",
    "platform": "macos",
    "lastSeenAt": "2026-08-04T08:00:00Z",
    "createdAt": "2026-08-04T08:00:00Z",
    "revokedAt": null,
    "isCurrent": false
  }
]
```

- `isCurrent`：是否为发起本次请求的设备。
- `revokedAt`：非空表示设备已被撤销。

## 2. 撤销设备

- **方法**：`POST`
- **路径**：`/auth/devices/{device_id}/revoke`
- **认证**：是

响应：

```json
{ "success": true }
```

撤销后的效果：

- 该设备的 refresh token 批量失效（按 `auth:refresh:by-device:{device_id}`
  索引清理），`POST /auth/refresh` 返回 401/404。
- 该设备的 WebSocket 连接被服务端断开。
- 设备不存在或已撤销返回 `404`。

## 3. 注销账号的关联清理

`DELETE /users/me` 注销账号时，服务端会一并撤销该账号全部登录设备、停用全部
Push 设备并删除会话，已删除用户的资料不可再查询、无法再登录。
