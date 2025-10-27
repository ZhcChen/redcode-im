# WebSocket接口

## WebSocket /ws — WebSocket 连接

建立WebSocket连接用于实时消息传递。支持认证、加入房间、消息推送与好友请求红点更新等事件。

- 需要认证：否
- 标识：ws-connection

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
