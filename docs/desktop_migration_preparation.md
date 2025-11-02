# Desktop 迁移准备清单

## 1. 代码与依赖盘点
- **现有实现**：`bear-chat-tauri` 基于 Vue 3 + Vite + Vuex，桌面壳为 Tauri 2（Rust 端位于 `src-tauri`）。存在 `_build` 本地产物目录，应在迁移时忽略。
- **前端依赖**：`@tauri-apps/api`、`@tauri-apps/plugin-opener`、`vue@^3.5`、`vue-router@^4.5`、`vuex@^4.1`，开发依赖包含 `vite@^6`、`vue-tsc`、`typescript@~5.6` 等。锁文件同时存在 `bun.lock` 与 `package-lock.json`，后续需统一包管理器（建议 `pnpm` 与仓库保持一致）。
- **Tauri 端依赖**：`tauri`、`tauri-plugin-*`、`tokio`、`serde`，配置位于 `src-tauri/Cargo.toml` 与 `tauri.conf.json`。
- **资源结构**：静态资源 `public/`、业务组件与页面在 `src/`，API 封装集中于 `src/api`，状态管理位于 `src/store`。
- **目标目录**：当前 `desktop/` 为空，可直接落地迁移文件，无需保留原实现回滚路径。

## 2. 迁移策略
- **文件同步**：使用 `rsync`/脚本从 `bear-chat-tauri` 迁移至 `desktop`，排除 `.git`、`_build`、`node_modules`、锁文件（待统一后再生成）。
- **依赖管理**：统一采用 `pnpm`，迁移后补充 `pnpm-workspace.yaml`/`package.json` 适配，生成新的锁文件并移除历史锁。
- **配置调整**：更新 API 基础配置，改为读取新后端 `API_BASE_URL` 与 `WS_URL`，对接仓库现有 `.env`/配置体系。
- **状态管理**：复用既有 Vuex 结构，但清理所有旧 API 相关状态，改为调用新接口返回结构。
- **脚本与 CI**：为桌面端补充 `package.json` 脚本（`dev`/`build`/`lint`/`test`），并接入仓库统一测试命令。
- **测试方案**：以 `uv run python -m pytest` 作为统一入口，编写基于 Playwright/Tauri CLI 的端到端脚本，覆盖登录、好友、消息三大流程。

## 3. 接口对接概览
- **核心映射**：详见 `docs/desktop_api_mapping.md`，涵盖认证、用户、好友、房间/消息、文件等模块。
- **需删除功能**：旧实现包含账户流水、红包转账、朋友圈、AI 聊天、音乐等独立服务，新后端未提供；迁移后直接移除相关界面/状态。
- **待确认差异**：
  - 旧接口以 POST + 路径参数形式传递（如 `imUserFriend/*`），新后端采用 RESTful 路由，需要彻底重写数据层。
  - 旧版依赖 Bear 自建鉴权/Token 逻辑，新后端统一使用 Bearer Token，需调整鉴权拦截器。
  - 文件上传/多媒体能力需对接后端存储方案，目前仅提供头像上传接口（`POST /users/me/avatar`），大文件共享需评估是否暂缓。

## 4. 需删除或重写的模块
- **账户流水**：`src/views/account/`、`src/api/account.ts`，直接移除。
- **红包与转账**：`src/views/group/redPacket*`、`src/api/group.ts` 中红包/转账相关方法，暂不迁移。
- **朋友圈**：`src/views/friend-circle/`、`src/api/friendCircle.ts`，整体下线。
- **音乐中心**：`src/views/music/`、`src/api/music.ts`，暂不迁移。
- **AI 助手**：`src/views/ai-chat/`、`src/api/chatgpt.ts`，暂不迁移。
- **文件中心旧逻辑**：`src/views/file-center/`、`src/api/file.ts`，待后端提供统一文件服务后重新规划。
- **交易密码/余额**：`src/views/user/trade-password.*`、`src/api/user.ts` 中交易及余额操作，移除。

## 5. 任务清单（阶段一）
- [x] 梳理 `bear-chat-tauri` API → `backend` 映射（输出 `docs/desktop_api_mapping.md`）。
- [x] 列出需删除/重写的模块与页面（旧账户、红包、朋友圈、AI、音乐等）。
- [x] 明确统一包管理器、构建脚本与测试命令并形成迁移步骤草案。
- [x] 整理初始风险列表并与后续阶段挂钩。

## 6. 初始风险
- **功能缺口**：后端暂无账户流水、红包、朋友圈等服务，相关桌面页面需要下线或等待后端补齐。
- **鉴权差异**：旧版存在 Token 登录、第三方登录、交易密码等逻辑，新后端暂不支持，需要在 UI 层关闭入口并更新提示。
- **实时能力**：旧版可能依赖第三方 IM 网关；新端需接入仓库既有 WebSocket 服务（参照 Flutter `WebSocketService` 实现）。
- **文件系统权限**：Desktop 端需评估 Tauri 插件（如 `fs`/`shell`）使用范围，与当前安全策略对齐。
- **测试空白**：原项目未附带自动化测试，需要在迁移过程同步补充 `uv run python -m pytest` 相关脚本或端到端测试。

## 7. 下一步
1. 完成 API 映射文档及模块差异列表。
2. 制定目录迁移脚本与依赖统一方案。
3. 更新 `docs/desktop_migration_plan.md` 进度并进入阶段二。
