# Admin E2E（重构版）

目录：

- `specs/smoke-login.spec.ts`：登录主链路 smoke
- `specs/core-flows.spec.ts`：核心功能链路
- `specs/route-smoke.spec.ts`：全路由可达 + 关键交互 + 4xx/5xx 异常冒烟
- `support/`：路由清单、统一 mock、运行上下文

## 运行方式

1) 启动 Admin（另一个终端）：

```bash
cd admin
pnpm dev
```

2) 运行全量 E2E：

```bash
cd admin
ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 pnpm test:e2e
```

3) 仅运行全路由冒烟（默认 profile）：

```bash
cd admin
ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 ADMIN_ROUTE_PROFILE=default pnpm test:e2e:routes
```

4) 运行 data-cleanup profile（需以 `VITE_ENABLE_DATA_CLEANUP=true` 启动 dev）：

```bash
cd admin
ADMIN_E2E_ENABLED=true ADMIN_BASE_URL=http://localhost:8011 ADMIN_ROUTE_PROFILE=data-cleanup pnpm test:e2e:routes
```

## 验收口径（route-smoke）

- 每条路由必须满足：
  - 可达（URL 命中目标路由）
  - 页面锚点可见（核心标题/关键文案）
  - 至少完成一个关键交互
- 异常场景（宽松口径）：
  - 对主接口注入 4xx、5xx 各一次
  - 页面不崩溃（`#app` 可见）
  - 可继续交互或刷新恢复
