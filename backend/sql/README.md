# 数据库迁移说明

## 数据库初始化

### base.sql
数据库 **v1 基线（baseline）** 初始化脚本，用于在空库上创建第一版表结构与基础数据。

> 说明：
> - `base.sql` 不再追求“始终等于当前最新结构”；最新结构由 `base.sql` + `backend/sql/migrations/` 下的增量脚本共同组成。
> - 推荐通过启动 backend 执行 `Database::migrate` 完成初始化与增量迁移；手工执行仅用于排障或特殊场景。

**执行方式（新项目首次部署必须执行一次）：**

✅ 推荐方式：启动 backend（会自动按顺序执行 `base.sql` + `MIGRATIONS` 中声明的增量脚本，并在 `db_migrations` 中记录）

⚠️ 手工方式（通常只在排障或特殊场景下使用）：

1) 执行 `base.sql`

如果 PostgreSQL 在 Docker 容器中运行：
```bash
docker exec -i postgres psql -U postgres -d redcode_im < sql/base.sql
```

如果 PostgreSQL 直接安装在本地：
```bash
psql -h localhost -U postgres -d redcode_im < sql/base.sql
```

2) 按 `backend/src/database/mod.rs` 的 `MIGRATIONS` 顺序依次执行 `backend/sql/migrations/*.sql`

> 说明：
> - 线上已有环境已视为执行过初始基线，不需要也不允许重复执行 `base.sql`；
> - 在全新环境（数据库为空库，无任何业务表）下，可以通过启动 backend，让 `Database::migrate` 自动执行 `base.sql` + 增量迁移并记录；
> - 之后的结构演进全部通过 `backend/sql/migrations/` 下的增量脚本 + 迁移记录表 `db_migrations` 管理，`Database::migrate` 会在启动时自动按顺序执行未记录的脚本。

## 数据库迁移规则

开发过程中，如果有 SQL 结构或者数据更新，请遵循以下规则：

1. **增量迁移脚本**：
   - 所有数据库结构变更或数据更新必须使用增量 SQL 脚本；
   - 脚本文件命名格式：`YYYYMMDDHHMMSS_描述性名称.sql`（例如：`20251112120000_add_user_room_pins.sql`）；
   - 脚本文件放置在 `backend/sql/migrations/` 目录下。

2. **迁移脚本内容**：
   - 每个脚本应该是幂等的，使用 `IF NOT EXISTS` 等条件判断
   - 包含必要的注释说明变更内容和原因
   - 避免使用特定数据库的方言，保持 SQL 标准兼容性

3. **迁移执行顺序**：
- 迁移脚本的执行顺序由 backend 代码中写死的常量数组 `MIGRATIONS` 控制（`backend/src/database/mod.rs`）；
- 每个迁移脚本执行成功后都会在 `db_migrations` 表中记录一条执行记录（字段 `name` 对应脚本文件名）。

4. **测试与验证**：
   - 每个迁移脚本应在测试环境充分测试
   - 提供验证步骤确保迁移成功
   - 考虑回滚方案以防迁移失败

5. **文档更新**：
   - 重大数据库变更需要更新相关文档
   - 在 README.md 中记录重要的数据库结构变更

## 迁移脚本示例

以下是一个迁移脚本的示例：

```sql
-- 20251112_add_user_room_pins.sql
-- 添加用户房间置顶功能和好友备注功能

-- 创建用户房间置顶表
CREATE TABLE IF NOT EXISTS user_room_pins (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    room_id INTEGER NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, room_id)
);

-- 创建好友备注表
CREATE TABLE IF NOT EXISTS user_friend_remarks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    remark TEXT NOT NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, friend_id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_user_room_pins_user_id ON user_room_pins(user_id);
CREATE INDEX IF NOT EXISTS idx_user_room_pins_room_id ON user_room_pins(room_id);
CREATE INDEX IF NOT EXISTS idx_user_friend_remarks_user_id ON user_friend_remarks(user_id);
CREATE INDEX IF NOT EXISTS idx_user_friend_remarks_friend_id ON user_friend_remarks(friend_id);
```

## 验证迁移

执行迁移后，可以使用以下命令验证变更：

```bash
# 检查表结构
docker exec -i postgres psql -U postgres -d redcode_im -c "\d 表名"

# 检查视图定义
docker exec -i postgres psql -U postgres -d redcode_im -c "\d+ 视图名"

# 检查索引
docker exec -i postgres psql -U postgres -d redcode_im -c "\di"
```
