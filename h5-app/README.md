# h5-app

`h5-app` 是 Flutter `app/` 的 H5 Web 版本，目标是复用移动端视觉语言，并作为当前 backend + frontend 联调的优先验收入口。

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
make api.up
make api.wait
make h5-app.install
make h5-app.up
make h5-app.wait
make h5-app.logs
```

默认端口：

- H5 dev server：`http://127.0.0.1:8016`
- API：`http://127.0.0.1:8010`

本地联调依赖由 Docker Compose 创建；对象存储、Push 和 IPInfo 使用 `external-mock`，不访问线上服务。

## 测试

```bash
make h5-app.check
make h5-app.test.unit
```

真实后端 smoke：

```bash
make api.up
make api.wait
make h5-app.test.live
```

浏览器 E2E smoke：

```bash
make api.up
make api.wait
make h5-app.test.e2e
```

`make h5-app.test.live` 当前覆盖：

- 普通账号密码注册、登录和 `/auth/me`
- service 层认证、资料更新、settings、好友搜索、建群、文本消息发送、已读和聊天列表
- H5/iOS-compatible HTTP 合同互通
- 富媒体 mock 对象存储直传、commit、发送和下载 URL 读取

发布或联调前推荐顺序：

```bash
make h5-app.check
make h5-app.test.unit
make api.up
make api.wait
make h5-app.test.live
make h5-app.test.e2e
```

`make h5-app.test.e2e` 使用 Playwright + Chrome channel，启动或复用 `http://127.0.0.1:8016`，覆盖：

- UI 普通账号注册后进入聊天 tab
- 创建/进入群聊、发送消息、刷新页面后恢复消息
- 群设置页置顶关键路径
- 搜索用户、发送好友申请、接受后联系人状态可见

## 当前范围

- 普通账号密码登录
- 普通账号注册后自动登录
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
- 设置与内容页：
  - 设置 tab 连接个人资料、账号安全、隐私协议、用户协议、关于和反馈页面
  - 个人资料支持昵称更新并同步 localStorage session；账号安全支持修改密码
  - 隐私协议/用户协议复用后端公开 settings 文档，反馈提交走 `/feedbacks`
- 媒体缓存：
  - `BlobCache` 用 Cache API + localStorage metadata 保存头像、附件、表情资源，测试环境降级为内存 Blob
  - 用户头像、群头像、消息附件和表情图片统一用 `objectKey -> objectUrl`，不依赖手机本机路径
  - 消息 `parts` 会映射为 H5 `attachments`，HTTP 历史消息和 WebSocket 实时消息都能渲染附件预览

后续继续补齐：

- 本地消息搜索页面：关键词、room 过滤、结果跳转
- 头像上传浏览器能力：用户头像、群头像、失败回退和缓存刷新
- 浏览器存储增强：wa-sqlite OPFS worker、IndexedDB fallback、FTS5 能力探测、Cache API 配额清理
