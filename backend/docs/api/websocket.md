# WebSocket接口

## WebSocket /ws — WebSocket 连接

建立WebSocket连接用于实时消息传递。支持认证、加入房间、消息推送与好友请求红点更新等事件。

- 需要认证：否
- 标识：ws-connection
> 说明：当前实现中，连接建立后仍需发送一次 `auth` 事件完成绑定（收到 `authed` 推送才算认证完成）；可参考 `docs/reference/testing/websocket-test.md` 的可执行步骤。

### 请求体
无

### 响应
#### HTTP 101
WebSocket连接建立成功
示例：
```json
{
  "connection": "WebSocket upgraded",
  "behavior": "事件驱动 - 认证/加入/消息推送/心跳"
}
```
