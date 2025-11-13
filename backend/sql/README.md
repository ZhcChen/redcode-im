# 数据库迁移说明

## 迁移脚本

### add_room_avatar_object_key.sql
添加 `avatar_object_key` 字段到 rooms 表，用于存储群头像的对象存储键。

**执行方式：**

如果 PostgreSQL 在 Docker 容器中运行：
```bash
docker exec -i postgres psql -U postgres -d redcode_im -c "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS avatar_object_key TEXT;"
```

如果 PostgreSQL 直接安装在本地：
```bash
psql -h localhost -U postgres -d redcode_im -c "ALTER TABLE rooms ADD COLUMN IF NOT EXISTS avatar_object_key TEXT;"
```

或者直接执行 SQL 文件：
```bash
docker exec -i postgres psql -U postgres -d redcode_im < sql/add_room_avatar_object_key.sql
```

**验证迁移：**
```bash
docker exec -i postgres psql -U postgres -d redcode_im -c "\d rooms"
```

应该能看到 `avatar_object_key` 字段。
