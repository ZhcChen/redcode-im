# 黑名单接口

黑名单用于阻止特定用户与自己交互。拉黑是**服务端生效**的公共语义：被拉黑
后，双向任一方向的私聊、发消息与好友申请都会被拦截，与客户端实现无关。

- 版本：API 2.0.0
- 认证：以下接口均需要 `Authorization: Bearer <token>`

## 核心语义

- 拉黑是单向关系：A 拉黑 B，A 的列表中出现 B。
- 拦截采用**双向判断**：A 拉黑 B，或 B 拉黑 A，均视为存在阻断关系。
- 拉黑**不影响**已存在的历史消息读取。
- 不能拉黑自己（HTTP 400，code 42201）。

## 1. 获取拉黑列表

- **方法**：`GET`
- **路径**：`/users/blocked`
- **认证**：是

查询参数：

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `limit` | int | 50 | 每页数量，服务端限制 1-100 |
| `offset` | int | 0 | 偏移量 |

响应（按拉黑时间倒序）：

```json
{
  "items": [
    {
      "userId": "550e8400-e29b-41d4-a716-446655440000",
      "username": "spammer",
      "nickname": "Spammer",
      "avatarUrl": null,
      "signature": "个性签名",
      "blockedAt": "2026-08-04T10:00:00Z"
    }
  ],
  "total": 1
}
```

## 2. 拉黑用户

- **方法**：`POST`
- **路径**：`/users/blocked`
- **认证**：是

请求体：

```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440000"
}
```

响应：

```json
{ "success": true }
```

- 幂等：重复拉黑同一用户返回成功，不重复插入。
- 拉黑自己返回 HTTP 400（code 42201）。

## 3. 取消拉黑

- **方法**：`DELETE`
- **路径**：`/users/blocked/{user_id}`
- **认证**：是

响应：

```json
{ "success": true }
```

- 不存在该拉黑关系时返回 `404`。

## 4. 拦截行为

存在双向阻断关系时，以下操作返回 `403 Forbidden`：

- 创建私聊：`POST /friends/{friend_user_id}/chat`
- 发送消息：`POST /rooms/{room_id}/messages`
- 发起好友申请：`POST /friends/requests`

取消拉黑后，上述操作恢复可用（无需重建好友关系）。
