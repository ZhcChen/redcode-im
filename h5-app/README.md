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

后续可继续补聊天详情、联系人管理、设置页完整功能和 WebSocket 实时链路。
