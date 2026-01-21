# SQL 开发规范

本文档约定数据库结构变更的维护方式，确保开发、测试与部署环境的结构一致。

## 基本原则

1. **基础脚本作为 v1 基线**：`backend/sql/base.sql` 作为数据库初始化的基线脚本（v1 baseline），用于在空库上创建第一版表结构与基础数据；后续结构演进全部通过增量脚本完成。
2. **增量脚本记录变更**：每次结构调整时，需要新增一份增量脚本到 `backend/sql/migrations/`，由后端在启动时通过迁移记录表自动执行。
3. **脚本幂等**：无论基础脚本还是增量脚本，尽量使用 `CREATE TABLE IF NOT EXISTS`、`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`、`CREATE INDEX IF NOT EXISTS` 等写法，保证重复执行不会出错。

## 增量脚本要求

- **存放位置**：`backend/sql/migrations/` 目录（若不存在请先创建）。
- **命名规范**：`YYYYMMDDHHMMSS_<简要描述>.sql`，例如 `20251112120000_add_user_room_pins.sql`。
- **内容范围**：仅包含本次新增或修改的 DDL/初始化数据，禁止回滚逻辑。
- **提交策略**：与代码改动同一次提交推送，确保代码与数据库结构同步。

## 更新流程

1. 在 `backend/sql/migrations/` 新增一份增量脚本文件，记录本次结构或基础数据变更。
2. 在 `backend/src/database/mod.rs` 的 `MIGRATIONS` 常量数组中追加对应脚本条目，写死执行顺序。
4. 更新本规范（必要时）或在相关需求文档中标记变更。
5. 通知运维或执行迁移的同事增量脚本文件名（通常只需重启 backend 即可应用未执行的脚本）。

## 示例

```sql
-- backend/sql/migrations/20251112_add_user_room_pins.sql
CREATE TABLE IF NOT EXISTS user_room_pins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, room_id)
);

CREATE INDEX IF NOT EXISTS idx_user_room_pins_user_id ON user_room_pins(user_id);
CREATE INDEX IF NOT EXISTS idx_user_room_pins_room_id ON user_room_pins(room_id);
CREATE INDEX IF NOT EXISTS idx_user_room_pins_pinned_at ON user_room_pins(pinned_at);
```

执行顺序说明：由 `MIGRATIONS` 数组控制，后端会在启动时按照该数组顺序，查询 `db_migrations` 表并仅执行尚未记录的脚本。
