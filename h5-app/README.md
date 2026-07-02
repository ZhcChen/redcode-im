# h5-app

`h5-app` 是 Flutter `app/` 的 H5 Web 版本，目标是复用移动端视觉语言并优先作为后续前端联调验收入口。

## 技术栈

- Vue 3
- Vite 8
- Vue Router 4
- Pinia 3
- TypeScript
- Vitest
- wa-sqlite（SQLite WASM，本地消息/搜索缓存底座）

说明：当前 `vue-router@5` npm latest 是新一代插件形态，依赖 Pinia Colada，不适合本项目普通 SPA 路由；本模块使用 Vue Router 4 稳定线。

## 本地开发

```bash
make h5-app.install
make h5-app.up
make h5-app.logs
```

默认端口：`8016`。

## 测试

```bash
make h5-app.check
make h5-app.test.unit
```

真实后端邮箱注册/登录 smoke：

```bash
make api.up
make api.wait
make h5-app.test.live
```

## 当前范围

- 邮箱登录
- 邮箱注册后自动登录
- 登录后 App Shell（三栏：聊天、联系人、设置）
- Flutter 移动端视觉 token 的 H5 复刻基线
- 本地存储底座：
  - `MessageStorage` 对齐 Flutter `MessageStorage` 的 room 消息缓存语义，单房间保留最近 200 条
  - `MessageSearchStorage` 预留 SQLite FTS5 搜索语义
  - 测试环境使用内存 adapter，浏览器环境使用 wa-sqlite + IndexedDB VFS
- API/service parity 底座：
  - `authService` / `friendService` / `roomService` / `messageService` / `settingsService`
  - 请求路径与 payload 优先对齐 Flutter `app/lib/core/services/` 和 `api/src/routes.rs`
- 聊天列表与 WebSocket 主链路：
  - `chat` Pinia store 优先读取本地 SQLite 会话摘要，再后台刷新 `/chats`
  - H5 使用后端 JSON WebSocket 协议，登录后自动认证并订阅当前会话房间
  - WebSocket `message` / `room_updated` / `message_read` 等事件会更新会话列表、未读数和本地消息缓存
- 聊天详情与文本发送：
  - `/chats/:roomId` 支持本地缓存优先、后台拉取历史消息和 WebSocket 消息合并
  - 文本发送支持本地 pending、失败重发、引用消息、服务端回包替换和本地缓存写入
  - 已读同步、消息删除、消息置顶/取消置顶会走 Flutter 等价后端端点并同步本地状态
  - wa-sqlite 浏览器运行时缓存异常会降级为静默忽略，不阻断 HTTP/WS 主链路
- 联系人与群聊：
  - 联系人 tab 支持本地联系人缓存、好友请求 badge、搜索用户和发送好友申请
  - 可处理 incoming 好友请求、打开私聊、选择联系人创建群聊
  - `/groups/:roomId/settings` 覆盖成员、改名、免打扰、置顶、退出/解散群聊基础流程

后续可继续补设置页完整功能、媒体缓存和本地消息搜索页面。
