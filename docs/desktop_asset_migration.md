# 桌面端资产迁移记录（阶段二）

## 已完成事项
- `bear-chat-tauri` 全量资源迁移至 `desktop/`，并删除原目录，确保仓库仅保留新结构。
- 清理遗留脚本与无用组件，`desktop/src/components` 仅保留全局 `Toast` 组件，避免旧 Vuex 依赖。
- 重写 API 访问层：
  - `src/api/http.ts` 统一适配 REST 接口与 Bearer Token 鉴权。
  - `system`/`user`/`friend`/`rooms`/`message` 模块与后端 `auth`、`friends`、`rooms`、`messages` 路由对齐。
- 构建全新 Vuex Store（`src/store/index.ts`），统一管理会话、会话列表、消息、好友关系与用户搜索结果。
- 重置前端路由与页面：
  - `AppShell.vue` 作为主壳层，集成会话、联系人、好友申请面板与消息窗。
  - `Login.vue` 简化为用户名+密码登录流，重用 store 登录动作。
  - `App.vue` 精简为路由渲染容器。
- 联系人面板新增用户搜索、好友申请入口与待处理申请响应能力。
- 接入 WebSocket：自动鉴权、房间订阅与事件处理（消息、好友申请、房间创建），同步刷新聊天与联系人数据。
- 更新 `package.json` 脚本（`test`/`test:ci` 使用 `uv run python`）与 `.gitignore`，统一包管理策略。
- `docs/desktop_migration_plan.md` 标记 M1 进入执行阶段，阶段二交付项同步更新。

## 进行中事项
- 细化桌面端构建 & CI（Tauri 构建脚本、打包流程待补充）。
- 依据后端数据模型优化界面展示与字段映射（例如消息预览、未读数归零策略）。
- 补充好友搜索/申请入口、房间创建流程等增量能力。

## 待办与风险
- **WebSocket 实时能力**：当前版本尚未接入，后续需要复用 `backend` 的推送协议或采用轮询策略。
- **文件/多媒体上传**：仅实现头像上传占位，聊天文件共享需待后端统一文件服务上线。
- **端到端测试**：需新增基于 `uv run python -m pytest` 的 API/E2E 脚本，覆盖登录、好友、消息流程。
- **UI 调整**：旧设计稿未沿用，需要与设计/产品确认新版桌面交互是否满足体验要求。

## 下一步建议
1. 对接后端 WebSocket 或通过轮询实现实时消息更新；同时补充已读/未读同步逻辑。
2. 扩展联系人模块，支持搜索、发送好友申请及本地校验。
3. 编写 Python 自动化测试（请求模拟 + Tauri UI 流程），并纳入 CI。
4. 梳理 Tauri 构建/发布脚本，形成可重复的打包流程。
