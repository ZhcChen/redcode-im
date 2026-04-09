# SQL 开发规范

本文档约定数据库结构变更的维护方式，确保开发、测试与部署环境的结构一致。

## 当前基线策略

- `backend/sql/base.sql` 是 **当前完整基线**，可直接初始化空库。
- `backend/sql/migrations/` 只存放 **当前基线之后** 的新增迁移。
- 2026-04-09 之前的历史迁移已归档到 `backend/sql/migrations_legacy_20260409/`，不再参与默认迁移链路。

## 基本原则

1. **空库初始化优先走 backend**：推荐直接启动 backend，由 `Database::migrate` 自动执行 `base.sql` 与未完成增量迁移。
2. **增量脚本记录后续变化**：每次结构调整时，在 `backend/sql/migrations/` 新增一份 SQL 文件，并同步更新 `backend/src/database/mod.rs` 的 `MIGRATIONS` 数组。
3. **脚本尽量幂等**：优先使用 `CREATE TABLE IF NOT EXISTS`、`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`、`CREATE INDEX IF NOT EXISTS` 等写法。
4. **禁止修改历史迁移**：已提交的迁移文件不可直接改写；需要修正时，继续追加新迁移。
5. **保持文档同步**：涉及初始化方式、运维流程或 schema 规则变化时，同步更新 `backend/sql/README.md` 与相关运维文档。

## 增量脚本要求

- **目录**：`backend/sql/migrations/`
- **命名规范**：`YYYYMMDDHHMMSS_<简要描述>.sql`
- **内容范围**：只包含本次新增或修改的 DDL / seed 调整，不写回滚逻辑
- **提交策略**：与代码改动同一次提交，确保应用代码和数据库结构同步发布

## 更新流程

1. 在 `backend/sql/migrations/` 新增增量脚本。
2. 在 `backend/src/database/mod.rs` 的 `MIGRATIONS` 数组追加条目。
3. 为新增结构补测试；至少确保空库初始化链路或相关 smoke test 覆盖该变化。
4. 更新相关文档与需求/计划文档。

## 迁移记录与校验

backend 会把已执行脚本记录到 `db_migrations`，并保存当前文件 checksum。

- 若 migration 已执行且 checksum 一致：跳过。
- 若 migration 已执行但 checksum 不一致：直接报错，禁止继续启动。
- 若数据库非空但缺少 `db_migrations`：默认拒绝自动 adopt；仅在显式设置 `ALLOW_INSECURE_MIGRATION_BASELINE_ADOPT=true` 时，才会做结构校验后补记基线。

## 示例

```sql
-- backend/sql/migrations/20260410120000_add_example_column.sql
ALTER TABLE messages
    ADD COLUMN IF NOT EXISTS example_flag BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_messages_example_flag
    ON messages(example_flag);
```
