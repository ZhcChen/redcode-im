# 当前增量迁移目录

2026-04-09 已完成一次 SQL 基线重置：此前的增量迁移已归档到 `backend/sql/migrations_legacy_20260409/`。

后续若有新的数据库结构或 seed 变更，请从本目录重新追加：

- 文件命名：`YYYYMMDDHHMMSS_desc.sql`
- 同步在 `backend/src/database/mod.rs` 的 `MIGRATIONS` 数组追加条目
- 不要修改已提交的历史迁移文件
