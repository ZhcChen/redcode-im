---
date: 2026-04-09
topic: sql-baseline-reset
status: active
---

# SQL 基线重置与迁移体系加固计划

## Problem Frame
当前 `backend/sql/base.sql` 已落后于真实 schema，空库初始化依赖 `base.sql + backend/sql/migrations/*.sql` 才能得到当前结构；同时 `backend/src/database/mod.rs` 对“非空库但缺少迁移记录表”的兼容逻辑过于宽松，容易把半初始化库误判为已完成基线。

项目尚未上线，当前正是把数据库基线、迁移清单与文档一次收口的窗口。

## Decision
- 以 **当前真实 schema** 重建 `backend/sql/base.sql`，把现有 18 个增量迁移吸收进新基线。
- 将现有 `backend/sql/migrations/*.sql` 迁移到归档目录，默认迁移链只保留 `base.sql`；后续新变更再从空目录重新累积。
- 收紧 `Database::migrate`：默认拒绝自动 adopt 非空且无 `db_migrations` 的数据库，只保留显式兼容开关。
- 为 `db_migrations` 补充 checksum 兼容能力，并增加 manifest/空库初始化测试，避免基线再次漂移时毫无预警。

## Scope Boundaries
- 本轮不做业务表结构新增，只做基线整合与迁移框架加固。
- 本轮不保留“任意旧库自动升级到当前”的强兼容承诺；针对本地旧环境，允许通过重建数据库解决。
- 本轮不引入第三方迁移框架，继续沿用项目当前的内置 SQL runner。

## Implementation Units

### Unit 1: 重建当前基线
- Goal: 生成覆盖当前真实 schema 与基础 seed 的 `backend/sql/base.sql`。
- Files:
  - `backend/sql/base.sql`
  - `backend/sql/migrations/*.sql`（只读输入，后续归档）
- Patterns to follow:
  - `backend/sql/base.sql` 现有结构与 seed 风格
  - `backend/sql/migrations/*.sql` 中已落地的 DDL/注释
- Approach:
  - 在空库按现有链路执行 `base.sql + 18 个 migration`。
  - 从最终数据库导出新的 baseline，保留函数 / 视图 / 注释 / 初始数据。
  - 清理 `db_migrations` 等运行态痕迹，输出为可直接初始化空库的单文件脚本。
- Test scenarios:
  - 空库执行新 `base.sql` 后应包含 `file_upload_records`、`reports`、`push_*`、`user_oauth_accounts`、`e2ee_*`、`group_detail_view` 等当前对象。
  - 默认管理员、角色、权限等基础 seed 仍存在。
- Verification:
  - 通过空库 smoke test 验证新 `base.sql` 可独立完成初始化。

### Unit 2: 归档旧增量迁移并收紧 manifest
- Goal: 让默认迁移链只代表“基线之后的新增变更”。
- Files:
  - `backend/sql/migrations/`
  - `backend/sql/migrations_legacy_20260409/`
  - `backend/src/database/mod.rs`
- Patterns to follow:
  - `backend/sql/migrations_legacy_20260409/` 的归档方式
- Approach:
  - 把当前 18 个 migration 移到新的 legacy 目录。
  - 保留空的 `backend/sql/migrations/` 作为后续新增变更入口。
  - 更新 `MIGRATIONS`，只包含新的 `base.sql` 与未来增量迁移。
- Test scenarios:
  - migration manifest 与目录内容保持一致。
  - 归档后空库初始化不再依赖 legacy 目录。
- Verification:
  - unit test 验证 manifest/file-system 一致性。

### Unit 3: 加固迁移 runner
- Goal: 提高 `Database::migrate` 的安全性与可诊断性。
- Files:
  - `backend/src/database/mod.rs`
- Patterns to follow:
  - 现有 advisory lock / 事务执行逻辑
- Approach:
  - `db_migrations` 增加 checksum 兼容列；对已记录的当前 migration 做 checksum 校验/回填。
  - 默认拒绝“非空库 + 无迁移记录表”自动 adopt；仅在显式环境变量开启时允许，并做最低限度结构校验。
  - 抽出 manifest helper，减少未来新增 migration 时漏挂风险。
- Test scenarios:
  - 空库可正常 migrate。
  - 非空库无 `db_migrations` 时默认报错。
  - 已记录 migration checksum 与文件不匹配时报错。
- Verification:
  - Rust unit/integration tests 通过。

### Unit 4: 文档与运维说明清理
- Goal: 让文档与真实迁移机制一致。
- Files:
  - `backend/sql/README.md`
  - `docs/reference/guides/sql-development.md`
  - `docs/reference/operations/dev-and-build.md`
  - `docs/reference/operations/upgrade-migration.md`
  - `docs/reference/operations/troubleshooting.md`
  - `backend/README.md`
- Approach:
  - 删除旧 `sqlx migrate` / `_sqlx_migrations` 描述。
  - 明确“当前基线 + 后续增量迁移 + 本地旧库建议重建”的规则。
- Verification:
  - 文档中不再出现旧迁移命令与旧目录路径。

## Success Criteria
- 新空库只执行 `base.sql` 即可得到当前 schema 与初始数据。
- 默认迁移 runner 不再静默 adopt 半初始化数据库。
- `db_migrations` 具备当前 manifest 的 checksum 校验能力。
- 测试能覆盖 manifest 一致性与空库初始化链路。
- 文档全部指向当前内置迁移机制。

## Risks
- 现有本地数据库如果停留在旧 schema，切到新基线后不会再自动补齐；需要重建数据库/volume。
- `pg_dump` 导出的 baseline 若带入运行态对象或噪音语句，需要二次清理。
- 当前仓库已有大量未提交改动，实施时必须限定在 SQL/迁移相关文件。
