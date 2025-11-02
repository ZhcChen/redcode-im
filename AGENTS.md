# 仓库指引

## 项目结构与模块组织
本仓库包含三套应用：Rust API 位于 `backend/backend/src`，Flutter 客户端位于 `frontend/lib`，Vue 3 管理端位于 `admin/src`。SQLx 迁移脚本存放在 `backend/migrations`，命令行集成脚本集中在 `backend/test_*.sh`。Flutter 资源放在 `frontend/assets`，测试位于 `frontend/test`，Vue 配置辅助脚本位于 `admin/config`。基础设施文件（如 `docker-compose*.yml`、`services.sh`、`docker-start.sh`）统一放在仓库根目录。

## 构建、测试与开发命令
- `cd backend && docker-compose up -d` 可启动 PostgreSQL 17 和运行在 6381/6382/6383 端口的三套 Redis 实例。
- `cd backend && cargo run` 启动 API（默认监听 8010），并在 8011 端口提供静态文档；打包前请运行 `cargo build --release`。
- `cd frontend && flutter run` 或 `./run_flutter.sh` 在执行过 `flutter pub get` 后启动客户端；`flutter test` 用于运行组件测试。
- `cd admin && pnpm install && pnpm dev` 本地启动管理端，`pnpm build` 生成优化后的构建产物；若需做一次全链路冒烟，可执行 `./test_all.sh`。

## 代码风格与命名规范
Rust 模块遵循 `cargo fmt --all` 与 `cargo clippy --all-targets -- -D warnings`，模块名使用 `snake_case`，类型名使用 `PascalCase`。Flutter 代码需跑 `dart format .` 与 `dart analyze`，文件命名保持 `snake_case.dart`，组件使用 `PascalCase`。Vue 代码采用两个空格缩进，脚本标识符使用 `camelCase`，组件文件名保持 `PascalCase.vue`；所有格式化与 lint 通过 lint-staged 与 Prettier 自动执行。

## 测试规范
- 在调用集成脚本（如 `backend/test_flow.sh`、`backend/test_friend_api.sh`）前先运行 `cargo test`。
- Flutter 的组件测试与 golden 测试放在 `frontend/test/<feature>_test.dart` 下，网络请求请复用现有的 mock 服务。
- 管理端依赖 `pnpm type:check`（以及开启时的 `pnpm lint`），出现 UI 回归时请补充模拟器截图或日志。

## Commit 与 Pull Request 规范
遵循由 commitlint 强制的 Conventional Commits 格式，例如 `feat(frontend-chat): enable reactions` 或 `fix(backend-auth): trim token scope`。保持单次提交聚焦、与 main 分支保持 rebase，并在推送前确保格式化与单元测试通过。Pull Request 需描述变更、关联相关 issue、列出验证步骤（若执行过 `./test_all.sh` 需写明），UI 变更需附带截图。

**重要规则：每次代码改动完成后，必须立即执行 Git 提交并推送到远端仓库，确保远端历史及时同步。不允许在本地累积多次未提交的改动。**

## 配置与安全提示
复制 `backend/.env.example` 为 `backend/.env`，定期轮换 JWT 密钥，将凭据存放在共享保险库；禁止提交生成的 `.env` 文件。部署到 staging 或生产时优先使用 `backend/docker-compose.prod.yml`，并为不同环境覆写 Redis 密码。开发完毕后运行 `cd backend && docker-compose down` 释放端口，避免遗留旧的 Redis 数据。

## 数据库约定
- 自 2025-10-20 起，数据库中的业务状态字段统一使用整数类型，禁止新增或扩展 PostgreSQL 枚举；对应取值及含义需在代码端集中维护（使用枚举或常量并写明注释）。
- 值域由业务代码约束，数据库层无需额外 `CHECK` 约束；请确保代码常量与文档保持同步，所有入口在写入前都需校验值是否合法。
- 若要变更结构或基础数据，需在 `backend/sql` 目录新增按时间戳命名的 SQL 文件（`YYYYMMDDHHMMSS_desc.sql`），禁止直接修改既有快照。

---

# Desktop 模块后续任务（2025-11-02）

## 近期优先事项
1. **消息体验增强**
   - 支持多媒体/文件消息上传与展示（待确认后端文件服务接口）。
   - 补齐消息撤回、转发、引用展示、置顶列表、搜索等高级功能。
   - 处理 WebSocket `message_read`/`message_update`/`pin_update`，保持未读数实时同步。
   - 桌面通知、托盘角标、声音提示开关。

2. **房间与群组管理**
   - 群设置面板：公告、禁言、群头像、免打扰、退出/解散。
   - 成员管理：列表、角色标签、邀请/踢人等操作。
   - 群聊创建流程与房间详情附属视图（群文件、图片墙等）。

3. **WebSocket 深化**
   - 完成未处理的推送事件，补充 UI 状态提示（连接中/已断开/重连中）。
   - 将 WebSocket 新消息与系统通知、Dock/任务栏角标打通。
   - 整理事件协议文档，写入 `docs`，便于前后端协作。

4. **测试与发布流水线**
   - 编写 `uv run python -m pytest` API/E2E 测试（登录、好友申请、消息往返）。
   - 在 CI 中执行 `pnpm --dir desktop build` 与自动化测试。
   - 准备桌面端冒烟测试 checklist，补充打包流程、环境变量说明。

## 中长期任务
- 联系人增强：备注、标签、拉黑、分组及历史申请管理。
- 社交模块取舍：账户/红包、朋友圈、AI、音乐等需产品确认是否重建或正式下线。
- UI 与体验：主题/深浅色模式、字体字号、国际化、离线场景提示。
- 安全与风控：上传白名单、内容过滤、异常登录告警。
- 可访问性与性能：键盘导航、ARIA、虚拟列表、大消息量优化。
- 产品文档：补齐桌面端使用手册、变更记录，与后端/Flutter 平台信息同步。

> 详细拆解与子任务请参见 `docs/desktop_remaining_work.md`，所有新增功能优先对齐后端能力与产品需求。
