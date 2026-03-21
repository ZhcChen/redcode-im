# Admin 鉴权韧性测试设计

**日期**: 2026-03-05
**范围**: `admin/playwright-tests`

## 1. 目标

在现有“全路由可达 + 异常恢复”基础上，补齐登录与鉴权刷新链路的高风险分支：

1. 登录失败时不应污染本地 token，页面停留在登录态。
2. access token 过期但 refresh token 有效时，应自动续签并恢复业务页面。
3. access token 与 refresh token 同时失效时，应清理本地状态并回登录页。

## 2. 测试策略

- 类型：Playwright E2E（mock 后端接口）
- 文件：新增 `auth-resilience.spec.ts`
- 关键 mock 点：
  - `/auth/admin/login`
  - `/auth/admin/me`
  - `/auth/admin/refresh`
  - 页面首屏依赖接口（如 `/api/admin/users`）

## 3. 验收标准

1. 三个分支均有独立测试用例。
2. 用例稳定通过（`--workers=1`）。
3. 纳入 `admin` 测试矩阵并更新回归报告。
