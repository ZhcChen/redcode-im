# 增量迁移目录

2026-06-09 已完成一次**整合重置**：历史增量迁移已折叠进 `api/sql/base.sql`（schema 等价已验证），旧归档目录已移除。

当前基线：

- `api/sql/base.sql`（单一基线，`api/src/database/mod.rs` 的 `MIGRATIONS` 数组唯一条目）

后续新增数据库结构 / seed 变更，从本目录追加增量：

- 文件命名：`YYYYMMDDHHMMSS_desc.sql`
- 同步在 `api/src/database/mod.rs` 的 `MIGRATIONS` 数组追加条目
- migration 尽量幂等（`IF NOT EXISTS` 等）
- **不要修改已提交的迁移文件（含 `base.sql`）**——由 `make migration.guard` 自动强制（只允许新增，拒绝修改/重命名/删除）

校验入口：

- `api/scripts/verify-base-sql.sh`：基线一致性
- `api/tests/database_migration_smoke.rs`：迁移链运行时校验
- `make migration.guard`：additive-only 守护
