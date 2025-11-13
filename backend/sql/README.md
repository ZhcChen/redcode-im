# 数据库迁移说明

## 数据库初始化

### all.sql
完整的数据库初始化脚本，包含所有表结构、索引、视图、触发器和初始数据。

**执行方式：**

如果 PostgreSQL 在 Docker 容器中运行：
```bash
docker exec -i postgres psql -U postgres -d redcode_im < sql/all.sql
```

如果 PostgreSQL 直接安装在本地：
```bash
psql -h localhost -U postgres -d redcode_im < sql/all.sql
```

## 数据库迁移规则

开发过程中，如果有 SQL 结构或者数据更新，请遵循以下规则：

1. **增量迁移脚本**：
   - 所有数据库结构变更或数据更新必须使用增量 SQL 脚本
   - 脚本文件命名格式：`YYYYMMDD_描述性名称.sql`（例如：20251112_add_user_room_pins.sql）
   - 脚本文件放置在 `migrations/` 目录下

2. **迁移脚本内容**：
   - 每个脚本应该是幂等的，使用 `IF NOT EXISTS` 等条件判断
   - 包含必要的注释说明变更内容和原因
   - 避免使用特定数据库的方言，保持 SQL 标准兼容性

3. **迁移执行顺序**：
   - 迁移脚本按照文件名中的日期顺序执行
   - 每个迁移脚本执行后应记录到数据库迁移历史表中

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