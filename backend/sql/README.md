# 数据库迁移说明

## 当前状态

- `backend/sql/base.sql` 已在 **2026-04-09** 重置为当前完整基线，覆盖当前 schema、视图、函数与基础 seed 数据。
- `backend/sql/migrations/` 现在只用于存放 **这次基线之后** 的新增迁移。
- 重置前的 18 个历史迁移已归档到 `backend/sql/migrations_legacy_20260409/`，仅作审计与回溯用途，不再参与默认启动链路。

## 初始化方式

### 推荐：启动 backend

启动 backend 时会执行 `Database::migrate`：

- 空库：创建 `db_migrations`，执行 `base.sql`，再按 `MIGRATIONS` 补齐后续增量迁移。
- 已有 `db_migrations`：只执行尚未记录的脚本，并校验当前 manifest 的 checksum。
- 非空库但缺少 `db_migrations`：默认直接报错，避免把半初始化库误认成已完成基线。

> 当前 active migration 链为：
>
> 1. `backend/sql/base.sql`
> 2. `backend/sql/migrations/20260410093000_remove_default_admin_seed.sql`
> 3. `backend/sql/migrations/20260413153000_add_object_storage_configs.sql`
>
> 因此“当前完整 schema”不是只执行 `base.sql`，而是执行完整链路后的结果。

### 手工执行（排障场景）

如果确实需要手工初始化空库：

```bash
# PostgreSQL 在 Docker 容器中
docker exec -i postgres psql -v ON_ERROR_STOP=1 -U postgres -d redcode_im < backend/sql/base.sql

# PostgreSQL 在宿主机
psql -v ON_ERROR_STOP=1 -h localhost -U postgres -d redcode_im < backend/sql/base.sql
```

然后再按 `backend/src/database/mod.rs` 的 `MIGRATIONS` 顺序补执行后续 active migration。

> 注意：当前首个超级管理员不是依赖 `base.sql` 中的静态默认账号，而是依赖运行时 bootstrap 初始化流程。
> 手工只执行 `base.sql` 不代表已经完成当前正式初始化链路。

## 迁移规则

1. 所有新的结构或 seed 变更，统一写入 `backend/sql/migrations/`。
2. 文件命名格式：`YYYYMMDDHHMMSS_desc.sql`。
3. 必须同步更新 `backend/src/database/mod.rs` 的 `MIGRATIONS` 数组。
4. 已提交的历史迁移文件禁止修改；如需调整，新增一份后续迁移。
5. migration 应尽量幂等：优先使用 `IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS` 等写法。

## 迁移记录表

`db_migrations` 由 backend 自动维护，当前字段包括：

- `name`：迁移文件名
- `checksum`：当前文件内容的 SHA-256 指纹
- `applied_at`：执行时间

已记录 migration 在启动时会校验 checksum；如果文件被人改过，backend 会直接拒绝继续启动。

## 兼容开关

若你明确知道某个**非空库**已经是当前完整 schema，只是缺少 `db_migrations` 表，可临时设置：

```bash
ALLOW_INSECURE_MIGRATION_BASELINE_ADOPT=true
```

此模式仍会先校验关键表 / 视图 / 字段是否齐全；校验失败时不会 adopt。

默认情况下，不建议使用这个开关。对于本地旧环境，更推荐直接重建数据库或执行 `docker compose ... down -v`。
