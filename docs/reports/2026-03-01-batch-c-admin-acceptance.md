# 批次 C 验收报告（Admin 测试重建）

**日期**: 2026-03-01  
**范围**: Admin（Vue）关键业务链路 E2E 重建

## 1. 本批新增测试

### 1.1 Playwright 场景
- `admin/playwright-tests/specs/core-flows.spec.ts`
  - 未登录访问受保护页面 -> 重定向登录
  - 登录后进入用户管理页（带接口 mock）
  - 通用设置页加载（应用名/IP 地理开关/账号限制/上传策略）
  - 版本管理页可访问与主操作按钮可见
- 既有场景复用：`admin/playwright-tests/specs/smoke-login.spec.ts`

### 1.2 复用契约测试
- Backend admin/dashboard/version 相关 Go 契约测试（批次 B-3）继续作为 Admin API 稳定性基线。

## 2. 验证命令与结果

### 2.1 Admin E2E（真实执行）
- 启动本地 Admin: `pnpm dev --host 127.0.0.1 --port 8011`
- 执行: `ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://127.0.0.1:8011 pnpm exec playwright test --workers=1`
- 结果: `5 passed`

## 3. 可追溯更新

- 已更新矩阵: `docs/reference/testing/matrix/admin.csv`
- Admin 功能点均标记 `done`（含测试入口与复用契约说明）

## 4. 本批完成度

- 需求覆盖: 100%（按本批矩阵口径）
- 验收覆盖: 100%
- 通过率: 100%
- 可追溯: 100%
