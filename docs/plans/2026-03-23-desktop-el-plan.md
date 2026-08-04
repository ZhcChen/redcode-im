---
status: superseded
superseded_by: docs/plans/2026-08-02-001-feat-im-2-0-formal-development-plan.md
---

# Desktop-EL 移植 Implementation Plan

> **For agentic workers:** REQUIRED WORKFLOW: Use `ce:work` to execute this plan task-by-task. If scope or architecture assumptions change, refresh the requirements with `ce:brainstorm` and update the implementation path with `ce:plan`. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新建 `desktop-el` 模块，基于现有 `desktop` Vue UI 迁移出 Electron 桌面端，并将全部业务核心下沉到 Go core，通过 stdio 与 Electron Main 通信。

**Architecture:** `desktop-el` 固定为三层结构：Renderer 复用现有 Vue UI，Electron Main/Preload 只保留桌面宿主与桥接职责，Go core 承接全部业务核心。Renderer 不再直接调用 HTTP/WebSocket/Tauri；业务状态以 Go core 为真源，Electron Main 通过 `stdin/stdout` 的 NDJSON RPC 转发请求与事件，不开放本地 HTTP 端口。

**Tech Stack:** Electron、Bun、Vue 3、Vite、TypeScript、Go 1.25、Electron IPC、NDJSON over stdio、SQLite（pure-Go 驱动，避免 CGO 打包复杂度）

---

### Task 1: 建立 `desktop-el` 模块骨架与统一命令

**Files:**
- Create: `desktop-el/package.json`
- Create: `desktop-el/tsconfig.json`
- Create: `desktop-el/tsconfig.node.json`
- Create: `desktop-el/vite.config.ts`
- Create: `desktop-el/electron/main/index.ts`
- Create: `desktop-el/electron/preload/index.ts`
- Create: `desktop-el/renderer/index.html`
- Create: `desktop-el/renderer/src/main.ts`
- Create: `desktop-el/renderer/src/App.vue`
- Create: `desktop-el/go-core/go.mod`
- Create: `desktop-el/go-core/cmd/desktop-el-core/main.go`
- Create: `desktop-el/README.md`
- Modify: `Makefile`
- Modify: `README.md`

- [ ] **Step 1: 创建目录骨架**
创建 `desktop-el/electron`、`desktop-el/renderer`、`desktop-el/go-core` 三层目录，并补基础入口文件。

- [ ] **Step 2: 配置脚本与开发命令**
在 `desktop-el/package.json` 中补齐 `dev`、`dev:renderer`、`dev:electron`、`dev:core`、`build`、`type-check`、`lint` 等脚本；`README.md` 与根 `Makefile` 增加 `desktop-el-up/down/logs` 入口。

- [ ] **Step 3: 初始化 Go module**
在 `desktop-el/go-core/go.mod` 中声明 `desktop-el-core` 模块，固定 Go 1.25，确保后续所有核心测试默认通过 `go test` 执行。

- [ ] **Step 4: 验证骨架可解析**
Run:
```bash
cd desktop-el && bun install
cd desktop-el && bun run type-check
cd desktop-el/go-core && go test ./...
make help
```
Expected: `bun` 依赖安装成功，TypeScript 配置可通过，Go module 空测试通过，根命令出现 `desktop-el-*` 目标。

### Task 2: 固化 stdio RPC 协议与 Electron-Go 桥接契约

**Files:**
- Create: `desktop-el/docs/rpc-contract.md`
- Create: `desktop-el/electron/main/rpc.ts`
- Create: `desktop-el/electron/main/go-core.ts`
- Create: `desktop-el/electron/preload/api.ts`
- Create: `desktop-el/electron/preload/types.ts`
- Create: `desktop-el/go-core/internal/rpc/message.go`
- Create: `desktop-el/go-core/internal/rpc/codec.go`
- Create: `desktop-el/go-core/internal/rpc/server.go`
- Create: `desktop-el/go-core/internal/rpc/errors.go`
- Create: `desktop-el/go-core/internal/rpc/codec_test.go`

- [ ] **Step 1: 定义消息协议**
在 `rpc-contract.md` 中明确 `request/response/event` 三类消息格式、错误码、事件命名、超时/取消语义，以及 `stderr` 只打印日志、不承载协议消息的约束。

- [ ] **Step 2: 实现 Go 侧编解码与单元测试**
实现 NDJSON 编解码、请求路由、请求 ID 关联和错误封送；使用 Go 测试覆盖半包、非法 JSON、未知方法、超时取消等核心场景。

- [ ] **Step 3: 实现 Electron 侧桥接类型**
在 `rpc.ts` 与 `preload/types.ts` 中生成与 Go 对齐的类型定义和请求调度器，确保 Renderer 只看到受控 API，不直接接触 Node `child_process`。

- [ ] **Step 4: 运行协议验证**
Run:
```bash
cd desktop-el/go-core && go test ./internal/rpc/...
cd desktop-el && bun run type-check
```
Expected: RPC 单元测试通过，Electron/Preload 类型检查通过。

### Task 3: 实现 Electron 宿主层与 Go core 进程监管

**Files:**
- Create: `desktop-el/electron/main/app.ts`
- Create: `desktop-el/electron/main/window.ts`
- Create: `desktop-el/electron/main/tray.ts`
- Create: `desktop-el/electron/main/dialog.ts`
- Create: `desktop-el/electron/main/notification.ts`
- Create: `desktop-el/electron/main/lifecycle.ts`
- Create: `desktop-el/electron/main/shell-api.ts`
- Modify: `desktop-el/electron/main/index.ts`
- Modify: `desktop-el/electron/preload/api.ts`

- [ ] **Step 1: 建立 Electron Main 生命周期**
实现应用初始化、单实例控制、主窗口创建、托盘、关闭最小化策略和退出流程。

- [ ] **Step 2: 加入 Go core 进程守护**
在 `go-core.ts` / `lifecycle.ts` 中完成 `spawn`、ready 握手、异常退出重启、关闭时清理、日志转发等宿主逻辑。

- [ ] **Step 3: 暴露壳层 API**
通过 preload 暴露 `window`、`dialog`、`notification`、`app` 等宿主 API；明确哪些调用留在 Electron，哪些转发到 Go core。

- [ ] **Step 4: 运行最小桌面烟测**
Run:
```bash
cd desktop-el && bun run dev
```
Expected: Electron 主窗口成功启动，Main 日志出现 `go core ready`，应用退出时无僵尸 Go 进程。

### Task 4: 实现 Go core 启动容器、配置加载与 bootstrap 快照

**Files:**
- Create: `desktop-el/go-core/internal/app/app.go`
- Create: `desktop-el/go-core/internal/app/app_test.go`
- Create: `desktop-el/go-core/internal/config/config.go`
- Create: `desktop-el/go-core/internal/bootstrap/service.go`
- Create: `desktop-el/go-core/internal/bootstrap/service_test.go`
- Create: `desktop-el/go-core/internal/eventbus/bus.go`
- Create: `desktop-el/go-core/internal/eventbus/bus_test.go`
- Create: `desktop-el/go-core/internal/state/snapshot.go`
- Modify: `desktop-el/go-core/cmd/desktop-el-core/main.go`

- [ ] **Step 1: 建立核心容器**
实现配置加载、日志初始化、服务注册、事件总线与 RPC server 启动顺序，确保 Go core 具备可扩展的模块装配入口。

- [ ] **Step 2: 输出 bootstrap 快照**
定义初始快照结构（账号、配置、最近会话、连接状态、功能开关），在 Renderer 启动时一次性下发，用于替代当前前端侧的分散初始化逻辑。

- [ ] **Step 3: 为事件与快照补 Go 测试**
覆盖事件订阅、事件广播、快照组装、空状态启动等关键路径，保证后续业务迁移时状态入口稳定。

- [ ] **Step 4: 验证 Go core 启动链**
Run:
```bash
cd desktop-el/go-core && go test ./internal/app/... ./internal/bootstrap/... ./internal/eventbus/...
cd desktop-el && bun run dev
```
Expected: Go 测试通过，Electron 启动后 Renderer 能收到 bootstrap 快照。

### Task 5: 将认证、HTTP、WebSocket 传输层整体下沉到 Go core

**Files:**
- Create: `desktop-el/go-core/internal/httpclient/client.go`
- Create: `desktop-el/go-core/internal/httpclient/client_test.go`
- Create: `desktop-el/go-core/internal/auth/service.go`
- Create: `desktop-el/go-core/internal/auth/service_test.go`
- Create: `desktop-el/go-core/internal/session/service.go`
- Create: `desktop-el/go-core/internal/session/service_test.go`
- Create: `desktop-el/go-core/internal/ws/client.go`
- Create: `desktop-el/go-core/internal/ws/client_test.go`
- Create: `desktop-el/go-core/internal/ws/dispatcher.go`
- Create: `desktop-el/renderer/src/api/http.ts`
- Create: `desktop-el/renderer/src/api/config.ts`
- Create: `desktop-el/renderer/src/api/user.ts`
- Create: `desktop-el/renderer/src/api/system.ts`
- Create: `desktop-el/renderer/src/api/version.ts`
- Create: `desktop-el/renderer/src/api/websocket.ts`

- [ ] **Step 1: 实现 Go 侧认证与传输模块**
将登录、刷新 token、登出、HTTP client、WebSocket 连接/重连/事件分发全部移到 Go core，前端不再直接创建网络客户端。

- [ ] **Step 2: 在 Renderer 保留同名 API 包装层**
新建 `renderer/src/api/*` 适配器，尽量保持旧 `desktop/src/api/*` 的导出形状，内部改为调用 preload 暴露的桌面 API，降低 UI 层改动面。

- [ ] **Step 3: 用 Go 测试覆盖传输关键路径**
覆盖 token 刷新、鉴权失败、重连退避、登录态失效广播、配置拉取和版本检查等链路。

- [ ] **Step 4: 对接本地 dev backend 做联调**
Run:
```bash
docker compose -f backend/docker/dev/docker-compose.yml up -d backend
cd desktop-el/go-core && go test ./internal/httpclient/... ./internal/auth/... ./internal/session/... ./internal/ws/...
cd desktop-el && bun run dev
```
Expected: Go 侧传输测试通过，桌面端可完成最小登录与连接 smoke。

### Task 6: 将联系人、群组、消息、搜索、文件与缓存业务整体下沉到 Go core

**Files:**
- Create: `desktop-el/go-core/internal/storage/sqlite/db.go`
- Create: `desktop-el/go-core/internal/storage/sqlite/db_test.go`
- Create: `desktop-el/go-core/internal/cache/service.go`
- Create: `desktop-el/go-core/internal/cache/service_test.go`
- Create: `desktop-el/go-core/internal/chat/service.go`
- Create: `desktop-el/go-core/internal/chat/service_test.go`
- Create: `desktop-el/go-core/internal/contacts/service.go`
- Create: `desktop-el/go-core/internal/contacts/service_test.go`
- Create: `desktop-el/go-core/internal/groups/service.go`
- Create: `desktop-el/go-core/internal/groups/service_test.go`
- Create: `desktop-el/go-core/internal/search/service.go`
- Create: `desktop-el/go-core/internal/search/service_test.go`
- Create: `desktop-el/go-core/internal/transfer/service.go`
- Create: `desktop-el/go-core/internal/transfer/service_test.go`
- Create: `desktop-el/renderer/src/api/friend.ts`
- Create: `desktop-el/renderer/src/api/group.ts`
- Create: `desktop-el/renderer/src/api/message.ts`
- Create: `desktop-el/renderer/src/api/message-search.ts`
- Create: `desktop-el/renderer/src/api/search.ts`
- Create: `desktop-el/renderer/src/api/file.ts`
- Create: `desktop-el/renderer/src/api/settings.ts`
- Create: `desktop-el/renderer/src/api/report.ts`
- Create: `desktop-el/renderer/src/api/notification.ts`
- Create: `desktop-el/renderer/src/api/emoji-item.ts`
- Create: `desktop-el/renderer/src/api/emoji-pack.ts`

- [ ] **Step 1: 建立本地持久化与缓存抽象**
使用 pure-Go SQLite 驱动实现本地存储入口，承接会话缓存、消息索引、下载记录和配置缓存，避免 CGO 打包复杂度。

- [ ] **Step 2: 实现领域服务与事件模型**
将联系人、群组、消息、搜索、文件传输、通知配置等能力全部转成 Go core 服务，通过 RPC 方法和事件对外暴露。

- [ ] **Step 3: 衔接 Renderer API 兼容层**
在 `renderer/src/api/*` 中逐个替换旧 HTTP/Tauri 逻辑，保持页面层调用方式基本不变，只把底层实现换成 `window.desktop.*`。

- [ ] **Step 4: 运行核心业务测试**
Run:
```bash
cd desktop-el/go-core && go test ./internal/storage/... ./internal/cache/... ./internal/chat/... ./internal/contacts/... ./internal/groups/... ./internal/search/... ./internal/transfer/...
```
Expected: 领域层与持久化层 Go 测试全部通过。

### Task 7: 迁移 Renderer UI，并替换 Tauri 专属适配层

**Files:**
- Create: `desktop-el/renderer/src/views/**`
- Create: `desktop-el/renderer/src/components/**`
- Create: `desktop-el/renderer/src/router/**`
- Create: `desktop-el/renderer/src/store/**`
- Create: `desktop-el/renderer/src/assets/**`
- Create: `desktop-el/renderer/src/styles/**`
- Create: `desktop-el/renderer/src/utils/tauri.ts`
- Create: `desktop-el/renderer/src/utils/window.ts`
- Create: `desktop-el/renderer/src/utils/cache.ts`
- Create: `desktop-el/renderer/src/utils/download-settings.ts`
- Create: `desktop-el/renderer/src/utils/accountMigration.ts`
- Create: `desktop-el/renderer/src/utils/nativeVoiceRecorder.ts`
- Create: `desktop-el/renderer/src/utils/voiceRecorder.ts`
- Modify: `desktop-el/renderer/src/main.ts`
- Modify: `desktop-el/renderer/src/App.vue`
- Modify: `desktop-el/renderer/src/store/index.ts`

- [ ] **Step 1: 复制现有 UI 目录树**
优先整体搬迁当前 `desktop/src/views`、`components`、`router`、`store`、`assets`、`styles`，保持界面结构和视觉输出不变。

- [ ] **Step 2: 重写 Tauri 兼容层**
把原先依赖 `@tauri-apps/*`、Rust command、Tauri window/file/notification 的工具模块改写为 Electron preload API 封装；`utils/tauri.ts` 保留兼容入口，但内部完全转向 Electron/Go。

- [ ] **Step 3: 让前端 store 改为消费快照与事件**
初始化从 bootstrap snapshot 读取状态，后续通过事件流增量更新，把业务真源切换为 Go core，前端 store 只保留展示态。

- [ ] **Step 4: 运行渲染层验证**
Run:
```bash
cd desktop-el && bun run type-check
cd desktop-el && bun run dev
```
Expected: UI 能正常渲染主要页面，Renderer 无 Tauri 依赖报错，登录后会话/消息列表能通过桥接层更新。

### Task 8: 接入桌面宿主能力、打包脚本与根命令

**Files:**
- Create: `desktop-el/electron-builder.yml`
- Create: `desktop-el/scripts/build-macos.sh`
- Create: `desktop-el/scripts/build-windows.sh`
- Create: `desktop-el/scripts/build-linux.sh`
- Create: `desktop-el/scripts/dev.sh`
- Modify: `desktop-el/README.md`
- Modify: `Makefile`

- [ ] **Step 1: 固化打包方案**
使用 `electron-builder` 统一生成安装包，将 Go core 二进制纳入 Electron 构建产物，保证 dev/build/release 路径一致。

- [ ] **Step 2: 补平台脚本与根级入口**
新增 `desktop-el` 的开发、构建、日志与停止脚本，并接入根 `Makefile`，使其与 `api/admin/website` 一样可以统一管理。

- [ ] **Step 3: 验证开发与构建命令**
Run:
```bash
cd desktop-el && bun run build
make help
```
Expected: Renderer/Main/Preload/Go core 均能被打包，根命令能列出 `desktop-el-*` 目标。

### Task 9: 更新文档、测试矩阵与迁移说明

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/reference/testing/README.md`
- Create: `docs/reference/testing/matrix/desktop-el.csv`
- Modify: `docs/reference/architecture/version-linkage-plan.md`
- Create: `docs/reports/2026-03-23-desktop-el-migration-report.md`

- [ ] **Step 1: 更新模块说明**
在根文档中明确 `desktop` 仍为旧 Tauri 客户端，`desktop-el` 为新 Electron + Go core 客户端，迁移期允许双模块并存。

- [ ] **Step 2: 补测试矩阵与验收口径**
新增 `desktop-el` 的 Go core 测试、Renderer type-check、桌面 smoke、构建验证命令，形成独立矩阵文件和验收报告模板。

- [ ] **Step 3: 写迁移说明**
记录哪些 UI 为直接迁移，哪些 Tauri/Rust 能力已被 Electron/Go 替换，哪些剩余差异仍需补齐。

- [ ] **Step 4: 运行文档前最终验证**
Run:
```bash
cd desktop-el/go-core && go test ./...
cd desktop-el && bun run type-check
cd desktop-el && bun run build
```
Expected: Go core 全量测试通过，Renderer 类型检查通过，桌面构建成功。

### Task 10: 分阶段提交与最终收口

**Files:**
- Modify: `desktop-el/**`
- Modify: `Makefile`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `docs/reference/testing/README.md`
- Create: `docs/reference/testing/matrix/desktop-el.csv`
- Create: `docs/reports/2026-03-23-desktop-el-migration-report.md`

- [ ] **Step 1: 每个任务结束后做一次变更检查**
Run:
```bash
git status --short
```
Expected: 仅包含本任务相关文件，避免把旧 `desktop` 的无关改动混入提交。

- [ ] **Step 2: 按阶段提交**
建议拆分为至少 4 个 Conventional Commits：
```bash
git commit -m "feat(desktop-el): scaffold electron and go core workspace"
git commit -m "feat(desktop-el): add stdio rpc bridge and process host"
git commit -m "feat(desktop-el): migrate go core business modules"
git commit -m "docs(desktop-el): add migration and testing documentation"
```

- [ ] **Step 3: 最终推送**
Run:
```bash
git push
```
Expected: 所有阶段提交已推送，`desktop-el` 模块具备继续迭代与验收的基础。
