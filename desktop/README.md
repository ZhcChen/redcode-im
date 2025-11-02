# Redcode Desktop 客户端

面向 `backend` Rust API 与 Flutter 客户端共用的数据模型，基于 Vue 3 + Vite + Tauri 的桌面端实现。

## 启动与开发

```bash
pnpm install
pnpm dev
```

Tauri 调试：

```bash
pnpm tauri dev
```

## 构建与测试

```bash
pnpm build
uv run python -m pytest  # 预留测试入口
```

## 目录结构

- `src/api/`：对接后端 REST API 的轻量封装。
- `src/store/`：Vuex 状态，统一管理会话、联系人、消息。
- `src/views/`：`Login` 登录页与 `AppShell` 交互主界面。
- `src/components/Toast.vue`：全局轻提示。

## 环境变量

- `VITE_API_BASE_URL`：HTTP API 根路径，默认 `http://127.0.0.1:8010`。
- `VITE_WS_URL`：WebSocket 地址，默认 `<BASE_URL>` 对应的 `/ws`。

## TODO

- 接入 WebSocket 推送能力，实时更新消息与好友状态。
- 丰富联系人管理（搜索、申请），补充聊天高级功能。
- 落地 `uv run python -m pytest` 的端到端自动化测试。
