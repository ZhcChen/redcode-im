# 当前增量迁移目录

2026-04-09 已完成一次 SQL 基线重置：此前的增量迁移已归档到 `backend/sql/migrations_legacy_20260409/`。

当前 active migration 链：

1. `backend/sql/base.sql`
2. `backend/sql/migrations/20260410093000_remove_default_admin_seed.sql`
3. `backend/sql/migrations/20260413153000_add_object_storage_configs.sql`

其中 `20260410093000_remove_default_admin_seed.sql` 用于把默认管理员 seed 切换为“运行时 bootstrap 初始化首个超级管理员”的新流程。
其中 `20260413153000_add_object_storage_configs.sql` 用于引入对象存储运行时配置版本表，承接 B2-only runtime config 工作流。

后续若有新的数据库结构或 seed 变更，请继续从本目录追加，并保持顺序：

- 文件命名：`YYYYMMDDHHMMSS_desc.sql`
- 同步在 `backend/src/database/mod.rs` 的 `MIGRATIONS` 数组追加条目
- 不要修改已提交的历史迁移文件

说明：

- `backend/sql/migrations_legacy_20260409/` 仅保留审计与回溯价值，不参与默认执行入口。
- `backend/scripts/verify-base-sql.sh` 与 `backend/tests/database_migration_smoke.rs` 是当前迁移链的一致性校验入口。
