# 测试工作流程指南（重构版）

> 本文档定义 RedCode IM 的统一测试分层、目录规范与执行入口。
>
> 当前策略：**先保证稳定可执行，再逐模块扩充深度**。

## 1. 测试分层

### L0：快速反馈（开发者本地）

- Backend 单元测试：`cargo test --lib`
- Frontend 单元测试：`flutter test`

目标：分钟级反馈，阻断明显回归。

### L1：PR 门禁（默认）

- Backend 集成测试（Rust）：`cargo test --tests`
- Backend 黑盒契约测试（Go）：`go test ./...`

目标：验证后端对外契约和核心链路稳定。

### L2：发版前/夜间（扩展）

- Admin E2E（Playwright）
- Frontend 集成/E2E（Flutter integration / Patrol）

目标：跨端关键用户旅程验证。

## 2. 模块测试矩阵

| 模块 | 单元测试 | 集成测试 | 端到端测试 |
|------|----------|----------|------------|
| Backend | Rust (`backend/src`) | Rust (`backend/tests`) + Go (`tests/go`) | WebSocket/关键业务链路（Go） |
| Frontend (Flutter) | `frontend/test` | `frontend/integration_test` | `frontend/patrol_test` |
| Admin (Vue) | 复用契约 + 页面级断言 | API 契约复用 Go | Playwright (`admin/playwright-tests/specs`) |
| Desktop (Vue + Tauri) | Vitest (`desktop/test`) | API/Store/Utils 集成（Vitest） | 复用 Backend Go 契约 |
| Website (Nuxt) | Vitest (`website/test`) | 下载链路逻辑集成（Vitest） | 复用 Playwright/页面手动验收 |

## 3. 统一入口

### 3.1 一键回归（推荐）

```bash
./tests/run.sh
```

该入口会：
1. 启动测试依赖（External Mock / PostgreSQL / Redis）
2. 运行 Backend Rust 单元测试
3. 运行 Backend Rust 集成测试
4. 启动 Backend 服务
5. 运行 Go 黑盒契约测试

### 3.2 模块独立执行

```bash
# Backend
cd backend && cargo test --lib
# 仅执行成本/生命周期清理配置边界单测
cd backend && cargo test file_upload_cleanup_config --lib
cd backend && cargo test log_writer_config --lib
cd backend && cargo test push_db_queue_cleanup_config --lib
cd backend && cargo test --tests -- --test-threads=1

# Go 契约
cd tests/go && go test ./... -v
# 仅执行管理端清理接口契约（系统日志/Push 日志）
cd tests/go && go test ./backend/admin -run TestAdminLogCleanupContract_OKAndValidationError -v
# 仅执行 Wave A（readyz/改密/未读计数）回归
cd tests/go && go test ./backend/system -run 'Test(Healthz_OK|Readyz_OK)$' -v
cd tests/go && go test ./backend/users -run TestChangePassword_WrongOldThenSuccess -v
cd tests/go && go test ./backend/messages -run TestUnreadCounts_MultiMessageReadUntil_OK -v
# 仅执行 Wave B（消息搜索/系统设置）回归
cd tests/go && go test ./backend/messages -run TestMessageSearch_MembershipIsolationAndValidation_OK -v
cd tests/go && go test ./backend/admin -run 'TestAdminSettings_(UserAccountLimitAndUploadPolicy_OK|NonAdminShouldBeForbidden)$' -v
# 仅执行 Wave C（短信登录/头像上传）回归
cd tests/go && go test ./backend/auth -run TestSMSLogin_WithCaptchaSetting_OK -v
# 头像上传依赖 external-mock 与 http 签名链路，建议使用隔离栈执行
cd tests && COMPOSE_PROJECT_NAME=redcode_im_tests_local docker-compose -f docker-compose.yml run --rm go-tests
# 仅执行 Wave D（分片上传/审核链路/Push）回归
cd tests/go && go test ./backend/uploads -run 'Test(MessageAttachmentMultipartUploadAndDownload_OK|FileUploadAuditTaskLifecycle_WithViolationMock)$' -v
cd tests/go && go test ./backend/push -run TestPushDeviceRegisterSendAndUnregister_OK -v
# 若本机 backend 未配置 OAuth/COS mock，使用隔离测试栈执行完整 Go 套件
cd tests && COMPOSE_PROJECT_NAME=redcode_im_tests_local docker-compose -f docker-compose.yml up -d external-mock postgres redis-session redis-cache backend
cd tests && COMPOSE_PROJECT_NAME=redcode_im_tests_local docker-compose -f docker-compose.yml run --rm go-tests
cd tests && COMPOSE_PROJECT_NAME=redcode_im_tests_local docker-compose -f docker-compose.yml down -v --remove-orphans

# Frontend
cd frontend && flutter test
# 仅执行核心服务单测（会话存储/配置回退/设置服务/版本契约）
cd frontend && flutter test test/core/token_storage_test.dart test/core/app_config_service_test.dart test/core/settings_service_test.dart test/core/version_service_test.dart
# 聊天与弹窗关键 UI/模型回归（会话项/气泡/消息模型/确认弹窗）
cd frontend && flutter test \
  test/chat/chat_list_item_test.dart \
  test/chat/chat_message_bubble_test.dart \
  test/chat/chat_input_widget_test.dart \
  test/chat/chat_message_model_test.dart \
  test/chat/chat_conversation_test.dart \
  test/chat/chat_provider_test.dart \
  test/chat/voice_message_widget_test.dart \
  test/chat/message_reader_test.dart \
  test/chat/reaction_picker_test.dart \
  test/chat/message_model_test.dart \
  test/widgets/confirm_action_dialog_test.dart \
  test/widgets/tip_dialog_test.dart
# 上传策略与反馈服务回归（配置解析、缓存回退、错误映射）
cd frontend && flutter test test/core/upload_policy_service_test.dart test/core/feedback_service_test.dart
# 核心工具/基础组件回归（文件哈希、角标组件、表情模型）
cd frontend && flutter test test/core/file_hash_test.dart test/core/chat_cache_test.dart test/core/environment_config_test.dart test/widgets/app_badge_test.dart test/features/emoji_pack_models_test.dart
# 表单与交互基础组件回归（开关/输入框/输入弹窗/底部选择器）
cd frontend && flutter test test/widgets/custom_switch_test.dart test/widgets/styled_text_field_test.dart test/widgets/input_dialog_test.dart test/widgets/bottom_picker_test.dart
# macOS 端内集成 smoke（无真机时可用）
cd frontend && flutter test integration_test/smoke_test.dart -d macos
# 先设置本机局域网 IP（确保与真机在同一网段，自动识别默认网卡）
LAN_IFACE=$(route -n get default | awk '/interface:/{print $2}')
LAN_IP=$(ipconfig getifaddr ${LAN_IFACE})
# 默认 smoke（推荐，真机：Pixel 8 Pro）
cd frontend && flutter test integration_test/smoke_test.dart -d 3A091FDJG001DN \
  --dart-define=API_BASE_URL=http://${LAN_IP}:8010 \
  --dart-define=WS_URL=ws://${LAN_IP}:8010/ws
# 发布前真机联调（包含 network_connectivity_test）
cd frontend && flutter test integration_test -d 3A091FDJG001DN \
  --dart-define=API_BASE_URL=http://${LAN_IP}:8010 \
  --dart-define=WS_URL=ws://${LAN_IP}:8010/ws \
  --dart-define=ENABLE_REAL_NETWORK_INTEGRATION=true

# Admin E2E
# 保持单个 Admin dev server 实例，默认使用 8011
cd admin && npm run dev -- --host 0.0.0.0 --port 8011
# 再执行真实联调 E2E
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 npx playwright test --workers=1
# Admin 鉴权韧性（登录失败/续签成功/失效回登录）
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  npx playwright test playwright-tests/specs/auth-resilience.spec.ts --workers=1
# 仅执行 Admin 全路由冒烟（default 可达集合）
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  ADMIN_ROUTE_PROFILE=default npx playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1
# 执行 data-cleanup 可达集合（需 dev 以 VITE_ENABLE_DATA_CLEANUP=true 启动）
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  ADMIN_ROUTE_PROFILE=data-cleanup npx playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1
# Admin 英文表面多语言回归
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  npx playwright test playwright-tests/specs/i18n-routes.spec.ts --workers=1
# 针对多语言改造页面执行定向回归
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  npx playwright test playwright-tests/specs/i18n-routes.spec.ts \
    --grep "settings-user-profile|settings-emoji-pack|versions-frontend|versions-desktop|versions-hot-updates|versions-hot-update-events" \
    --workers=1
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  npx playwright test playwright-tests/specs/route-smoke.spec.ts \
    --grep "dashboard-workplace|dashboard-monitor|versions-frontend|versions-desktop|versions-hot-updates|versions-hot-update-events" \
    --workers=1
# 若页面被 Vite ESLint overlay 遮挡，优先修复对应文件
cd admin && ./node_modules/.bin/eslint --fix src/views/version-management/hot-update.vue

# Desktop
cd desktop && bun run test
# 定向执行新增高价值链路
cd desktop && bun run test -- test/store/accounts.actions.test.ts test/utils/cache.test.ts test/api/message.transform-and-send.test.ts

# Website
cd website && bun run test
# Website 下载边界与回退逻辑
cd website && bun run test -- test/download-utils.test.ts
```

## 4. 目录规范

```
backend/tests/                  # Rust 集成测试
tests/go/                       # Go 黑盒契约测试
tests/mocks/external/           # 外部依赖模拟 + Go 测试
frontend/test/                  # Flutter 单元测试
frontend/integration_test/      # Flutter 集成测试
frontend/patrol_test/           # Flutter E2E（Patrol）
admin/playwright-tests/specs/   # Admin E2E（Playwright）
docs/reference/testing/matrix/  # 功能-测试-验收追踪矩阵
```

矩阵文件：
- `docs/reference/testing/matrix/backend.csv`
- `docs/reference/testing/matrix/admin.csv`
- `docs/reference/testing/matrix/frontend.csv`
- `docs/reference/testing/matrix/desktop.csv`
- `docs/reference/testing/matrix/website.csv`

## 5. 本次重构决策

- 已移除测试可视化 Dashboard 模块，测试执行不再依赖额外可视化服务。
- 已清理旧测试与旧覆盖率统计脚本，改为“单入口 + 分层执行”的基础架构。
- 已引入第三方依赖本地模拟（External Mock），用于在无公网/无云资源场景下回归 OAuth、Push、COS/CI、IP 地理位置链路。

---

**最后更新**: 2026-03-28
