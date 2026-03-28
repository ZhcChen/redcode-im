# Admin 多语言验收报告（2026-03-26）

## 1. 验收目标

本轮验收目标是收口 `admin` 模块已有 `vue-i18n` 基础上的多语言改造，统一页面文案与 API 错误提示策略，并将 `admin/src/views` 范围内的中文硬编码清理到可追踪、可验证状态。

## 2. 覆盖范围

### 2.1 基础设施

- 统一接入 `resolveApiMessage` / `resolveHttpErrorMessage`
- 补齐公共错误文案与共享 locale 入口
- 将路由英文表面断言固化到 `admin/playwright-tests/specs/i18n-routes.spec.ts`

### 2.2 已完成的页面/路由覆盖

- 仪表盘：`dashboard-workplace`、`dashboard-monitor`
- 运维管理：`operations-system-log`、`operations-push-log`、`operations-storage-provider`、`operations-cos-test`、`operations-ipinfo-token`、`operations-api-metrics`、`operations-file-upload-audit`、`operations-data-cleanup`
- 系统设置：`settings-captcha`、`settings-privacy-policy`、`settings-user-agreement`、`settings-general`、`settings-push`、`settings-emoji-pack`、`settings-user-profile`
- 用户管理：`user-management-list`、`user-management-feedback`、`user-management-reports`、`user-management-chat-history`、`user-management-room-history`、`user-management-user-history`
- 版本管理：`versions-frontend`、`versions-desktop`、`versions-hot-updates`、`versions-hot-update-events`
- 共享壳层与登录页：登录品牌、导航、消息盒子、面包屑、公共页壳

### 2.3 视图层扫描结果

执行以下命令后，`admin/src/views` 范围内中文残留已清零：

```bash
rg -l "[一-龥]" admin/src/views --glob '!**/locale/**' | sort
```

结果：空输出。

说明：

- 本轮同时清理了旧注释、调试日志和 mock 文本中的中文残留，避免后续扫描被噪音干扰。
- 页面级 locale 继续采用“模块内独立 locale 文件 + 根入口合并”策略，未将长尾 key 继续堆入全局 settings locale。

## 3. 验证记录

### 3.1 类型检查

```bash
cd admin && npm run type:check
```

结果：通过。

### 3.2 Admin 英文表面回归

```bash
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  npx playwright test playwright-tests/specs/i18n-routes.spec.ts --workers=1
```

本轮重点复核的批次包括：

- `settings-user-profile|settings-emoji-pack|versions-frontend|versions-desktop|versions-hot-updates|versions-hot-update-events`
- `dashboard-workplace|dashboard-monitor|versions-frontend|versions-desktop|versions-hot-updates|versions-hot-update-events`

结果：通过。

### 3.3 Admin 中文路由烟测

```bash
cd admin && ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 \
  npx playwright test playwright-tests/specs/route-smoke.spec.ts --workers=1
```

本轮重点复核的批次包括：

- `settings-user-profile|settings-emoji-pack|versions-frontend|versions-desktop|versions-hot-updates|versions-hot-update-events`
- `dashboard-workplace|dashboard-monitor|versions-frontend|versions-desktop|versions-hot-updates|versions-hot-update-events`

结果：通过。

## 4. 交付结论

- `admin` 现有主路由与共享壳层已经具备中英文切换能力。
- 页面请求失败时，优先使用后端返回的 `message`，其次使用本地 `message_key` 命中，最后再回退本地兜底文案。
- `admin/src/views` 视图层中文硬编码扫描结果为 0，当前可作为后续 backend / frontend / desktop 多语言扩展的对齐基线。

## 5. 经验记录

- 本地 Admin 开发与回归统一使用单实例 `http://localhost:8011`，避免多开 Vite 进程导致测试命中错误实例。
- 若 Playwright 看到页面空白或找不到锚点，优先检查 Vite ESLint overlay；这类问题会直接遮挡真实页面而不是产生类型错误。
