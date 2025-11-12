# SQL 开发规范

本文档约定数据库结构变更的维护方式，确保开发、测试与部署环境的结构一致。

## 基本原则

1. **全量脚本保持最新**：`backend/sql/all.sql` 必须始终包含当前系统所需的全部表结构、索引以及基础数据。此脚本用于初始化全新数据库实例。
2. **增量脚本记录变更**：每次结构调整时，除了更新全量脚本，还需要新增一份增量脚本，以便在已有环境中执行迁移。
3. **脚本幂等**：无论全量还是增量脚本，尽量使用 `CREATE TABLE IF NOT EXISTS`、`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`、`CREATE INDEX IF NOT EXISTS` 等写法，保证重复执行不会出错。

## 增量脚本要求

- **存放位置**：`backend/sql/migrations/` 目录（若不存在请先创建）。
- **命名规范**：`YYYYMMDD_<简要描述>.sql`，例如 `20251112_add_user_room_pins.sql`。
- **内容范围**：仅包含本次新增或修改的 DDL/初始化数据，禁止回滚逻辑。
- **提交策略**：与代码改动同一次提交推送，确保代码与数据库结构同步。

## 更新流程

1. 在 `backend/sql/all.sql` 中合并新的表结构或数据调整。
2. 复制相同的变更到新的增量脚本文件。
3. 更新本规范（必要时）或在相关需求文档中标记变更。
4. 通知运维或执行迁移的同事增量脚本文件名。

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

执行顺序建议：先运行最新增量脚本，再根据需要执行历史脚本或全量脚本进行初始化。
