# Frontend 多语言迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Flutter `frontend` 建立官方 `gen_l10n` 多语言基础设施，补齐高频页面与非 UI 层文案，并接入 backend `message/message_key` 兜底策略。

**Architecture:** 以 [frontend/lib/app.dart](/Users/chen/code/redcode-im/frontend/lib/app.dart) 为应用入口，新增 `flutter_localizations + intl + gen_l10n`，同时补 locale 控制与 API message 解析层。迁移顺序先基础设施、再认证与首页、再聊天与设置，验证采用 `flutter test` 与现有 widget/integration 入口。

**Tech Stack:** Flutter、Dart、gen_l10n、flutter_localizations、intl

---

### Task 1: 建立 Flutter i18n 基础设施

**Files:**
- Create: `frontend/l10n.yaml`
- Create: `frontend/lib/l10n/app_zh.arb`
- Create: `frontend/lib/l10n/app_en.arb`
- Create: `frontend/lib/core/i18n/locale_controller.dart`
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/main.dart`
- Modify: `frontend/lib/app.dart`

- [ ] **Step 1: 先写失败测试**
  - 为应用入口补测试，确认 `MaterialApp` 具备 `localizationsDelegates`、`supportedLocales` 与 locale 切换能力。
  - 在测试中先断言当前项目尚未接入 `AppLocalizations`。

- [ ] **Step 2: 接入官方多语言依赖**
  - 在 `pubspec.yaml` 中加入 `flutter_localizations` 与 `intl`。
  - 新增 `l10n.yaml` 与两份 ARB 文件，先覆盖共享动作、通用错误与应用级标题。

- [ ] **Step 3: 建立 locale 控制器并接入 `MaterialApp`**
  - 新增 `LocaleController` 负责读取/持久化语言偏好。
  - 在 `app.dart` 中接入 `locale`、`supportedLocales`、`localizationsDelegates`，不要继续依赖硬编码字符串。

- [ ] **Step 4: 运行基础测试**
  - Run: `cd frontend && flutter pub get`
  - Run: `cd frontend && flutter test test/smoke_test.dart`
  - Expected: 依赖安装成功，应用级 smoke test 通过，`AppLocalizations` 已可生成并使用。

- [ ] **Step 5: 提交基础设施改动**
  - Run: `git add frontend/pubspec.yaml frontend/l10n.yaml frontend/lib/l10n frontend/lib/core/i18n frontend/lib/main.dart frontend/lib/app.dart && git commit -m "feat(frontend): add flutter i18n foundation"`

### Task 2: 建立 API message 解析与共享文案访问层

**Files:**
- Create: `frontend/lib/core/i18n/api_message_resolver.dart`
- Modify: `frontend/lib/core/services/settings_service.dart`
- Modify: `frontend/lib/core/widgets/tip_dialog.dart`
- Modify: `frontend/lib/core/widgets/input_dialog.dart`
- Modify: `frontend/lib/core/widgets/agreement_tip_dialog.dart`
- Modify: `frontend/lib/core/widgets/agreement_content_dialog.dart`
- Modify: `frontend/test/core/settings_service_test.dart`
- Modify: `frontend/test/widgets/tip_dialog_test.dart`
- Modify: `frontend/test/widgets/input_dialog_test.dart`

- [ ] **Step 1: 先补失败测试**
  - 为 `settings_service` 和通用对话框补测试，验证它们可以从 `AppLocalizations` 获取文案，而不是依赖中文硬编码。
  - 为 API message 解析函数设计测试，验证 `message` 优先、`message_key` + `params` 本地兜底。

- [ ] **Step 2: 新增共享 message 解析层**
  - 将 API 错误解析收敛到单一 helper，供 `service/repository/widget` 复用。
  - 保证当后端 `message` 回退成 `message_key` 时，前端可用本地 ARB 再翻译一次。

- [ ] **Step 3: 替换通用组件硬编码**
  - 先迁移通用对话框、协议提示、输入框按钮等高频复用组件。
  - 新增的共享 key 同步补进 `app_zh.arb` 与 `app_en.arb`。

- [ ] **Step 4: 运行定向测试**
  - Run: `cd frontend && flutter test test/core/settings_service_test.dart test/widgets/tip_dialog_test.dart test/widgets/input_dialog_test.dart`
  - Expected: 共享文案和 message resolver 测试通过。

- [ ] **Step 5: 提交共享层改动**
  - Run: `git add frontend/lib/core/i18n frontend/lib/core/services/settings_service.dart frontend/lib/core/widgets frontend/test/core/settings_service_test.dart frontend/test/widgets && git commit -m "feat(frontend): add localized message resolver"`

### Task 3: 迁移高频页面一：启动、登录、首页、联系人

**Files:**
- Modify: `frontend/lib/features/startup/splash_page.dart`
- Modify: `frontend/lib/features/auth/login_page.dart`
- Modify: `frontend/lib/features/auth/reset_password_page.dart`
- Modify: `frontend/lib/features/auth/data/auth_repository.dart`
- Modify: `frontend/lib/features/home/home_shell_page.dart`
- Modify: `frontend/lib/features/contacts/contacts_page.dart`
- Modify: `frontend/lib/features/contacts/contact_detail_page.dart`
- Modify: `frontend/lib/features/contacts/add_friend_page.dart`
- Modify: `frontend/test/features/auth_models_test.dart`
- Modify: `frontend/test/features/friend_models_test.dart`

- [ ] **Step 1: 用 ARB 补齐认证与联系人高频 key**
  - 先列出登录、验证码、重置密码、联系人搜索、加好友、空态等 key。
  - 保持命名与 backend 错误 key 区分，UI 文案使用前端本地 key。

- [ ] **Step 2: 迁移页面与 repository 中的硬编码**
  - 页面标题、按钮、表单提示、错误信息统一改为 `AppLocalizations.of(context)!` 或集中 helper。
  - `auth_repository` 中遇到 backend message/message_key 时统一走解析层。

- [ ] **Step 3: 处理 locale 持久化与切换**
  - 若设置页已有语言偏好存储，复用之；否则在 `SettingsService` 中新增语言偏好存储。
  - 保证应用重启后仍使用上次选择的 locale。

- [ ] **Step 4: 运行页面级测试**
  - Run: `cd frontend && flutter test test/smoke_test.dart test/core/settings_service_test.dart`
  - Expected: 应用入口与高频页面相关测试通过。

- [ ] **Step 5: 提交高频页面一改动**
  - Run: `git add frontend/lib/features/startup frontend/lib/features/auth frontend/lib/features/home frontend/lib/features/contacts frontend/lib/l10n && git commit -m "feat(frontend): localize auth home and contacts flows"`

### Task 4: 迁移高频页面二：聊天、搜索、设置

**Files:**
- Modify: `frontend/lib/features/chat/chat_list_page.dart`
- Modify: `frontend/lib/features/chat/chat_detail_page.dart`
- Modify: `frontend/lib/features/chat/chat_detail_page_v2.dart`
- Modify: `frontend/lib/features/chat/message_search_page.dart`
- Modify: `frontend/lib/features/chat/create_group_page.dart`
- Modify: `frontend/lib/features/chat/group_settings_page.dart`
- Modify: `frontend/lib/features/settings/settings_page.dart`
- Modify: `frontend/lib/features/settings/account_security_page.dart`
- Modify: `frontend/lib/features/settings/about_page.dart`
- Modify: `frontend/lib/features/settings/feedback_page.dart`
- Modify: `frontend/lib/core/services/message_service.dart`
- Modify: `frontend/lib/core/services/friend_service.dart`
- Modify: `frontend/lib/core/services/room_service.dart`
- Modify: `frontend/lib/core/services/feedback_service.dart`
- Modify: `frontend/test/chat/chat_list_item_test.dart`
- Modify: `frontend/test/chat/chat_message_bubble_test.dart`
- Modify: `frontend/test/widgets/confirm_action_dialog_test.dart`

- [ ] **Step 1: 收口聊天与设置域 key**
  - 为聊天列表、消息状态、群组操作、搜索空态、设置页操作补齐 ARB key。
  - 把 service 层中的硬编码错误/提示收口到共享解析层或本地 key。

- [ ] **Step 2: 逐文件替换页面硬编码**
  - 聊天与设置相关页面改为使用 `AppLocalizations`。
  - 复用的 widgets 保持单一 key 来源，不要在多个文件复制同一文案。

- [ ] **Step 3: 增加 widget 测试覆盖**
  - 为聊天气泡、列表项、确认对话框增加 locale 场景，验证中英文切换时主文案变化正常。

- [ ] **Step 4: 运行定向 Flutter 测试**
  - Run: `cd frontend && flutter test test/chat/chat_list_item_test.dart test/chat/chat_message_bubble_test.dart test/widgets/confirm_action_dialog_test.dart`
  - Expected: 聊天与设置域组件测试通过。

- [ ] **Step 5: 提交高频页面二改动**
  - Run: `git add frontend/lib/features/chat frontend/lib/features/settings frontend/lib/core/services frontend/lib/l10n frontend/test/chat frontend/test/widgets && git commit -m "feat(frontend): localize chat and settings flows"`

### Task 5: 集成验证、文档与默认设备说明

**Files:**
- Modify: `frontend/README.md`
- Modify: `docs/reference/testing/README.md`
- Create: `docs/reports/2026-03-26-frontend-i18n-acceptance.md`

- [ ] **Step 1: 补文档中的多语言运行与测试说明**
  - 记录 `flutter gen-l10n`、`flutter test`、语言切换验证方式。
  - 若当前文档已有默认真机设备口径，保持与现有设备说明一致。

- [ ] **Step 2: 运行最终验证**
  - Run: `cd frontend && flutter test`
  - Run: `cd frontend && flutter test integration_test/smoke_test.dart`
  - Expected: 单测通过；在本地设备/模拟器环境满足时，集成 smoke 通过。

- [ ] **Step 3: 记录验收结果**
  - 在验收文档中列出已迁移页面、剩余长尾文案与语言切换结果。

- [ ] **Step 4: 提交文档与验收**
  - Run: `git add frontend/README.md docs/reference/testing/README.md docs/reports/2026-03-26-frontend-i18n-acceptance.md && git commit -m "docs(frontend): record i18n rollout acceptance"`
