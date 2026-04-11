# Admin E2E（重构版）

目录：

- `specs/smoke-login.spec.ts`：登录主链路 smoke
- `specs/core-flows.spec.ts`：核心功能链路
- `specs/auth-resilience.spec.ts`：登录失败/续签成功/续签失败鉴权韧性
- `specs/route-smoke.spec.ts`：全路由可达 + 关键交互 + 4xx/5xx 异常冒烟
- `specs/live-backend-smoke.spec.ts`：真实 backend 联调 smoke（不走 mock）
- `support/`：路由清单、统一 mock、运行上下文

## 运行方式

1) 启动 Admin（另一个终端）：

```bash
cd admin
bun run dev
```

> 默认不启用前端本地 mock。若要手工验证旧 mock 页面，显式加 `VITE_ENABLE_DEV_MOCKS=true`。

2) 运行全量 E2E：

```bash
cd admin
ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 bun run test:e2e
```

2.1) 仅运行鉴权韧性用例：

```bash
cd admin
ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 bunx playwright test playwright-tests/specs/auth-resilience.spec.ts --workers=1
```

3) 仅运行全路由冒烟（默认 profile）：

```bash
cd admin
ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 bun run test:e2e:routes
```

4) 运行 data-cleanup profile（需以 `VITE_ENABLE_DATA_CLEANUP=true` 启动 dev）：

```bash
cd admin
ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 ADMIN_ROUTE_PROFILE=data-cleanup bun run test:e2e:routes
```

5) 运行真实 backend 联调 smoke：

前置条件：

- backend 已启动：`http://127.0.0.1:8010`
- admin dev 已启动：`http://localhost:8011`
- 固定测试账号：`admin / BhgNKtC1RbOBj1sCVKmt9Rwx`

> 注意：当前 admin dev 需走 `http://localhost:8011`，不要用 `http://127.0.0.1:8011`。
> 若 live 环境尚未初始化首个管理员，联调用例会自动通过 bootstrap 建立上述固定账号。

```bash
cd admin
ADMIN_BASE_URL=http://localhost:8011 bun run test:e2e:live
```

6) 运行 data-cleanup 条件路由的真实 smoke（需以 `VITE_ENABLE_DATA_CLEANUP=true` 启动 admin dev）：

```bash
cd admin
ADMIN_BASE_URL=http://localhost:8011 bun run test:e2e:live:data-cleanup
```

6.1) 仅运行真实 backend 的 RBAC 管理回归：

```bash
cd admin
ADMIN_BASE_URL=http://localhost:8011 bun run test:e2e:live:rbac
```

覆盖页面：

- `/dashboard/workplace`
- `/dashboard/monitor`
- `/system/admin-users`
- `/system/roles`
- `/system/permissions`
- `/settings/general`
- `/settings/push`
- `/settings/captcha`
- `/settings/privacy-policy`
- `/settings/user-agreement`
- `/settings/emoji-pack`
- `/settings/user-profile`
- `/operations/storage-provider`
- `/operations/api-metrics`
- `/operations/file-upload-audit`
- `/operations/ipinfo-token`
- `/operations/cos-test`
- `/operations/system-log`
- `/operations/push-log`
- `/user-management/list`
- `/user-management/feedback`
- `/user-management/reports`
- `/user-management/chat-history`
- `/user-management/chat-history/room/:roomId`
- `/user-management/chat-history/user/:userId`
- `/versions/frontend`
- `/versions/desktop`
- `/versions/hot-updates`
- `/versions/hot-update-events`

说明：

- live smoke 会自动写入最小聊天夹具数据，用于覆盖聊天记录详情页动态路由。
- data-cleanup live smoke 只验证页面可达、危险操作防护与确认弹窗，不会真正提交清理请求。

验收口径：

- 真实登录成功
- 目标页面对应真实 API 返回 2xx
- 页面关键锚点可见
- 无 console error / pageerror

## 验收口径（route-smoke）

- 每条路由必须满足：
  - 可达（URL 命中目标路由）
  - 页面锚点可见（核心标题/关键文案）
  - 至少完成一个关键交互
- 异常场景（宽松口径）：
  - 对主接口注入 4xx、5xx 各一次
  - 页面不崩溃（`#app` 可见）
  - 可继续交互或刷新恢复
