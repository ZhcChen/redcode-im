# 升级与迁移指南

本文档描述 RedCode IM 系统的版本升级流程和数据迁移方法。

---

## 目录

- [升级前准备](#升级前准备)
- [后端升级](#后端升级)
- [数据库迁移](#数据库迁移)
- [客户端升级](#客户端升级)
- [回滚流程](#回滚流程)
- [版本兼容性](#版本兼容性)

---

## 升级前准备

### 检查清单

- [ ] 阅读版本发布说明（Release Notes）
- [ ] 检查版本兼容性要求
- [ ] 备份所有数据（参考 [备份指南](backup-restore.md)）
- [ ] 通知用户维护窗口
- [ ] 准备回滚方案
- [ ] 在测试环境验证升级流程

### 环境要求检查

```bash
# 检查系统资源
free -h
df -h

# 检查依赖版本
rustc --version
psql --version
redis-cli --version

# 检查当前版本
curl http://localhost:8010/ | jq .version
```

### 备份验证

```bash
# 确保备份可用
ls -la /backup/postgresql/daily/
ls -la /backup/redis/daily/

# 验证备份完整性
pg_restore --list /backup/postgresql/daily/latest.dump
```

---

## 后端升级

### 标准升级流程

#### 1. 停止服务

```bash
# 优雅停止（等待请求处理完成）
systemctl stop redcode-backend

# 或发送 SIGTERM
kill -15 $(pgrep -f redcode-backend)
```

#### 2. 备份当前版本

```bash
# 备份二进制文件
cp /opt/redcode/backend/redcode-backend \
   /opt/redcode/backup/redcode-backend.$(date +%Y%m%d)

# 备份配置文件
cp -r /etc/redcode /etc/redcode.backup.$(date +%Y%m%d)
```

#### 3. 部署新版本

```bash
# 下载新版本
wget https://releases.example.com/redcode-backend-v1.2.0-linux-x86_64.tar.gz

# 解压
tar -xzf redcode-backend-v1.2.0-linux-x86_64.tar.gz

# 替换二进制文件
mv redcode-backend /opt/redcode/backend/

# 设置权限
chmod +x /opt/redcode/backend/redcode-backend
```

#### 4. 数据库迁移

```bash
# 运行迁移
cd /opt/redcode/backend
sqlx migrate run

# 验证迁移
sqlx migrate info
```

#### 5. 启动服务

```bash
# 启动服务
systemctl start redcode-backend

# 检查状态
systemctl status redcode-backend

# 查看日志
journalctl -u redcode-backend -f
```

#### 6. 验证升级

```bash
# 健康检查
curl http://localhost:8010/healthz

# 版本确认
curl http://localhost:8010/ | jq .version

# API 测试
curl http://localhost:8010/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
```

### Docker 升级

```bash
# 拉取新镜像
docker pull redcode/backend:v1.2.0

# 停止旧容器
docker stop redcode-backend

# 运行数据库迁移
docker run --rm \
  -e DATABASE_URL=$DATABASE_URL \
  redcode/backend:v1.2.0 \
  sqlx migrate run

# 启动新容器
docker run -d \
  --name redcode-backend \
  -e DATABASE_URL=$DATABASE_URL \
  -e REDIS_URL=$REDIS_URL \
  -p 8010:8010 \
  redcode/backend:v1.2.0

# 清理旧镜像
docker image prune -f
```

### Docker Compose 升级

```yaml
# docker-compose.yml
version: '3.8'
services:
  backend:
    image: redcode/backend:v1.2.0  # 更新版本
    # ... 其他配置
```

```bash
# 升级
docker-compose pull
docker-compose up -d

# 查看日志
docker-compose logs -f backend
```

---

## 数据库迁移

### 迁移流程

#### 1. 查看待执行的迁移

```bash
sqlx migrate info
```

输出示例：
```
20240101000000/applied initial schema
20240201000000/applied add message reactions
20240301000000/pending add hot updates table  # 待执行
```

#### 2. 执行迁移

```bash
# 运行所有待执行的迁移
sqlx migrate run

# 或指定数据库 URL
DATABASE_URL="postgresql://..." sqlx migrate run
```

#### 3. 验证迁移

```bash
# 检查迁移状态
sqlx migrate info

# 验证表结构
psql $DATABASE_URL -c "\dt"
psql $DATABASE_URL -c "\d+ messages"
```

### 手动迁移

如果自动迁移失败，可以手动执行：

```bash
# 查看迁移 SQL
cat backend/migrations/20240301000000_add_hot_updates.sql

# 手动执行
psql $DATABASE_URL -f backend/migrations/20240301000000_add_hot_updates.sql

# 标记迁移完成
psql $DATABASE_URL -c "INSERT INTO _sqlx_migrations (version, description, installed_on, success, checksum) VALUES (20240301000000, 'add_hot_updates', NOW(), true, E'\\x...');"
```

### 迁移回滚

```bash
# 查看回滚 SQL（如果有）
cat backend/migrations/20240301000000_add_hot_updates.down.sql

# 执行回滚
sqlx migrate revert

# 或手动回滚
psql $DATABASE_URL -f backend/migrations/20240301000000_add_hot_updates.down.sql
```

### 大表迁移注意事项

对于大表（如 messages），需要特别处理：

```sql
-- 使用 CONCURRENTLY 添加索引（不锁表）
CREATE INDEX CONCURRENTLY idx_messages_new ON messages(new_column);

-- 批量更新数据
UPDATE messages SET new_column = default_value
WHERE id IN (
  SELECT id FROM messages
  WHERE new_column IS NULL
  LIMIT 10000
);

-- 重复执行直到所有数据更新完成
```

---

## 客户端升级

### 移动端 (Flutter)

#### 强制更新

```json
// 版本配置
{
  "platform": "android",
  "version": "1.2.0",
  "build_number": 120,
  "mandatory": true,
  "release_notes": "重要安全更新，请立即升级"
}
```

#### 热更新

```bash
# 创建热更新包
cd mobile
flutter build bundle

# 上传热更新
curl -X POST http://localhost:8010/api/admin/hot-updates \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -F "platform=android" \
  -F "patch_version=1.2.0-patch1" \
  -F "file=@build/app.bundle"
```

### 桌面端 (Tauri)

```bash
# 构建新版本
cd desktop
npm run tauri build

# 上传到存储
rclone copy src-tauri/target/release/bundle cos:redcode-releases/desktop/
```

### 管理后台 (Vue)

```bash
# 构建生产版本
cd admin
npm run build

# 部署到服务器
rsync -avz dist/ user@server:/var/www/admin/
```

---

## 回滚流程

### 后端回滚

```bash
#!/bin/bash
# rollback.sh - 后端回滚脚本

echo "开始回滚..."

# 1. 停止当前服务
systemctl stop redcode-backend

# 2. 恢复二进制文件
BACKUP_VERSION=$1
cp /opt/redcode/backup/redcode-backend.$BACKUP_VERSION \
   /opt/redcode/backend/redcode-backend

# 3. 恢复配置文件
cp -r /etc/redcode.backup.$BACKUP_VERSION/* /etc/redcode/

# 4. 回滚数据库迁移（如需要）
sqlx migrate revert

# 5. 启动服务
systemctl start redcode-backend

# 6. 验证
sleep 5
curl http://localhost:8010/healthz

echo "回滚完成"
```

### 数据库回滚

```bash
# 如果迁移失败需要回滚
sqlx migrate revert

# 如果需要完全恢复
systemctl stop redcode-backend
dropdb redcode_im
createdb redcode_im
pg_restore --dbname=redcode_im /backup/postgresql/daily/latest.dump
systemctl start redcode-backend
```

### Docker 回滚

```bash
# 停止新版本
docker stop redcode-backend
docker rm redcode-backend

# 启动旧版本
docker run -d \
  --name redcode-backend \
  redcode/backend:v1.1.0  # 旧版本

# 或使用 docker-compose
docker-compose down
git checkout v1.1.0 -- docker-compose.yml
docker-compose up -d
```

---

## 版本兼容性

### API 版本兼容性矩阵

| 后端版本 | 移动端最低版本 | 桌面端最低版本 | 管理后台版本 |
|---------|--------------|--------------|------------|
| v1.0.x | v1.0.0 | v1.0.0 | v1.0.x |
| v1.1.x | v1.0.0 | v1.0.0 | v1.1.x |
| v1.2.x | v1.1.0 | v1.1.0 | v1.2.x |

### 数据库版本要求

| 后端版本 | PostgreSQL | Redis |
|---------|-----------|-------|
| v1.0.x | >= 14 | >= 6.0 |
| v1.1.x | >= 14 | >= 6.0 |
| v1.2.x | >= 15 | >= 7.0 |

### 破坏性变更处理

当遇到破坏性 API 变更时：

1. **添加版本头**
```bash
curl -H "X-API-Version: 2" http://localhost:8010/api/...
```

2. **使用兼容层**
```rust
// 在代码中处理版本兼容
if api_version < 2 {
    // 旧版本逻辑
} else {
    // 新版本逻辑
}
```

3. **弃用通知**
```json
{
  "data": {...},
  "warnings": ["该接口将在 v2.0 中移除，请使用新接口 /api/v2/..."]
}
```

---

## 升级最佳实践

### 蓝绿部署

```bash
# 部署新版本到蓝色环境
docker run -d --name backend-blue \
  -p 8011:8010 \
  redcode/backend:v1.2.0

# 测试蓝色环境
curl http://localhost:8011/healthz

# 切换流量（通过负载均衡器）
# 更新 nginx upstream 配置

# 确认无问题后移除旧版本
docker stop backend-green
docker rm backend-green
```

### 灰度发布

```bash
# 配置部分流量到新版本
# nginx.conf
upstream backend {
    server backend-v1.1.0:8010 weight=9;
    server backend-v1.2.0:8010 weight=1;
}
```

### 维护窗口通知

```bash
# 提前通知用户
curl -X POST http://localhost:8010/api/admin/announcements \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{
    "title": "系统升级通知",
    "content": "系统将于 2026-01-14 02:00-04:00 进行升级维护",
    "level": "warning"
  }'
```

---

**文档最后更新**: 2026-01-13
