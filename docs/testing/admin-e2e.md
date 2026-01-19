# Admin（Vue）E2E 测试（Playwright）

> 本文档用于规范 admin 模块的 Playwright E2E 测试目录、运行方式与数据依赖。

## 目录与入口

- **配置文件**：`admin/playwright.config.ts`
- **标准化用例目录**：`admin/playwright-tests/specs/`
- **历史脚本目录**：`admin/playwright-tests/*.js`（仅保留参考/排障，不作为标准用例）
- **输出目录**：`admin/test-results/`、`admin/playwright-report/`

## 运行前置条件

1. 后端服务已启动：`http://localhost:8010`
2. 管理后台前端已启动：`http://localhost:8011`
3. 管理员账号可用（默认 `admin/admin123`）

> 若数据库未初始化导致管理员账号不存在，可启用一次性初始化接口（仅本地调试）：
>
> ```bash
> # backend/.env
> ALLOW_INSECURE_ADMIN_BOOTSTRAP=true
>
> # 初始化默认管理员
> curl -sS -X POST "http://localhost:8010/api/admin/init-default-admin"
> ```

## 环境变量

- `ADMIN_BASE_URL`：管理后台地址（默认 `http://localhost:8011`）
- `ADMIN_USERNAME`：管理员账号（默认 `admin`）
- `ADMIN_PASSWORD`：管理员密码（默认 `admin123`）
- `ADMIN_E2E_ENABLED=true`：开启 E2E 执行（默认关闭，避免环境未就绪误失败）

## 运行方式

```bash
cd admin
pnpm install
pnpm test:e2e
```

常用命令：

```bash
pnpm test:e2e:ui       # 交互式运行
pnpm test:e2e:report   # 查看报告
```

## 用例组织约定

- 单文件单场景：`login.spec.ts`、`chat-history.spec.ts` 等
- 每个用例应最小化依赖：可用 `ADMIN_E2E_ENABLED` 控制是否执行
- 与后端契约相关的逻辑，仍优先由 `tests/go/` 覆盖，E2E 只验证关键用户旅程

## 最小用例清单（建议）

1. 登录成功（管理后台可进入仪表盘）
2. 进入用户列表页并加载数据
3. 进入聊天记录查询页并正确展示筛选结果
4. 存储配置页可读写（依赖 COS 配置）

## 备注

- admin 的 E2E 测试属于前端生态例外，采用 Playwright（TypeScript），不影响 Go 作为跨端契约测试的主线。
