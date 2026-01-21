# 管理后台登录与默认管理员账号说明（2026-01-19）

## 结论
- 默认管理员账号写入 `backend/sql/base.sql`，用户名为 `admin`，密码为 `admin123`（bcrypt）。
- 管理后台登录接口：`POST /auth/admin/login`。
- 如数据库未执行 `base.sql` 或未完成迁移，可能不存在默认管理员导致登录失败。

## 默认账号来源
- `backend/sql/base.sql` 插入默认管理员：
  - username: `admin`
  - password: `admin123`
- 文档中一致的账号说明：
  - `docs/reference/api/auth.md`
  - `docs/reference/api/api-reference.md`
  - `docs/reference/testing/test-architecture.md`

## 文档不一致说明
- `docs/reference/operations/docker-deploy.md` 仍写 `admin/admin`，与 `base.sql` 不一致，疑似过期。

## 备用初始化方式（仅调试/初始化）
- 临时接口：`POST /api/admin/init-default-admin`
- 需要设置环境变量：`ALLOW_INSECURE_ADMIN_BOOTSTRAP=true`
- 成功后会创建 `admin/admin123`。

## 排查登录失败的重点
- 确认后端连接的数据库是否执行了 `base.sql` 与迁移。
- 确认 `admin/.env.development` 的 `VITE_API_BASE_URL` 指向正确后端（默认 `http://localhost:8010`）。
- 若账号存在但仍无法登录，检查 `admin_users` 表中的状态/锁定字段。

## UI 登录 401 快速定位
1. 先用命令行验证后端是否可登录（排除前端问题）：
   `POST /auth/admin/login`，账号 `admin` / `admin123`。
2. 若命令行可登录但 UI 401：
   - 检查浏览器 Network 中实际请求的 `Base URL` 是否仍指向 `http://localhost:8010`；
   - 确认没有使用生产环境构建或其他 `.env` 覆盖（例如 `.env.production`）。 
3. 若命令行也 401：
   - 检查 `admin_users` 是否存在 `admin`，状态是否为 `active`；
   - 必要时使用 `/api/admin/init-default-admin` 重新初始化（需 `ALLOW_INSECURE_ADMIN_BOOTSTRAP=true`，且库内无管理员）。
