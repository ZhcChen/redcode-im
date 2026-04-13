# 数据备份与恢复指南

本文档描述 RedCode IM 系统的数据备份策略和恢复流程。

---

## 目录

- [备份概述](#备份概述)
- [PostgreSQL 备份](#postgresql-备份)
- [Redis 备份](#redis-备份)
- [文件存储备份](#文件存储备份)
- [自动化备份脚本](#自动化备份脚本)
- [恢复流程](#恢复流程)
- [灾难恢复](#灾难恢复)

---

## 备份概述

### 需要备份的数据

| 数据类型 | 存储位置 | 重要性 | 备份频率 |
|---------|---------|--------|---------|
| 用户数据 | PostgreSQL | 关键 | 每日 |
| 消息记录 | PostgreSQL | 关键 | 每日 |
| 会话状态 | Redis | 重要 | 每小时 |
| 媒体文件 | Backblaze B2 / S3 兼容对象存储 | 重要 | 实时同步 |
| 配置文件 | 文件系统 | 重要 | 每次变更 |

### 备份存储位置

```
/backup/
├── postgresql/
│   ├── daily/
│   │   └── redcode_im_2026-01-13.sql.gz
│   └── weekly/
│       └── redcode_im_week_02.sql.gz
├── redis/
│   ├── dump.rdb
│   └── appendonly.aof
└── config/
    └── config_backup_2026-01-13.tar.gz
```

---

## PostgreSQL 备份

### 全量备份

```bash
#!/bin/bash
# 全量备份脚本

DATE=$(date +%Y-%m-%d)
BACKUP_DIR="/backup/postgresql/daily"
DATABASE_URL="postgresql://user:pass@localhost:5432/redcode_im"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 执行备份
pg_dump $DATABASE_URL \
  --format=custom \
  --compress=9 \
  --file="$BACKUP_DIR/redcode_im_$DATE.dump"

# 同时创建 SQL 格式备份（便于查看）
pg_dump $DATABASE_URL \
  --format=plain \
  | gzip > "$BACKUP_DIR/redcode_im_$DATE.sql.gz"

# 清理 30 天前的备份
find $BACKUP_DIR -name "*.dump" -mtime +30 -delete
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: redcode_im_$DATE"
```

### 增量备份（使用 WAL）

```bash
# 配置 PostgreSQL WAL 归档
# postgresql.conf
archive_mode = on
archive_command = 'cp %p /backup/postgresql/wal/%f'
wal_level = replica

# 创建 WAL 归档目录
mkdir -p /backup/postgresql/wal
chown postgres:postgres /backup/postgresql/wal
```

### 逻辑备份（特定表）

```bash
# 只备份消息表
pg_dump $DATABASE_URL \
  --table=messages \
  --table=message_reads \
  --format=custom \
  --file="messages_backup.dump"

# 只备份用户数据
pg_dump $DATABASE_URL \
  --table=users \
  --table=friendships \
  --table=friend_requests \
  --format=custom \
  --file="users_backup.dump"
```

### 验证备份

```bash
# 检查备份文件完整性
pg_restore --list redcode_im_2026-01-13.dump

# 测试恢复到临时数据库
createdb redcode_im_test
pg_restore --dbname=redcode_im_test redcode_im_2026-01-13.dump
dropdb redcode_im_test
```

---

## Redis 备份

### RDB 快照备份

```bash
# 手动触发 RDB 备份
redis-cli BGSAVE

# 等待备份完成
while [ $(redis-cli LASTSAVE) == $LASTSAVE ]; do
  sleep 1
done

# 复制 RDB 文件
cp /var/lib/redis/dump.rdb /backup/redis/dump_$(date +%Y%m%d_%H%M%S).rdb
```

### AOF 备份

```bash
# 确保 AOF 已启用
# redis.conf
appendonly yes
appendfilename "appendonly.aof"
appendfsync everysec

# 备份 AOF 文件
redis-cli BGREWRITEAOF
cp /var/lib/redis/appendonly.aof /backup/redis/
```

### Redis 备份脚本

```bash
#!/bin/bash
# Redis 备份脚本

BACKUP_DIR="/backup/redis"
DATE=$(date +%Y-%m-%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 触发 BGSAVE
redis-cli BGSAVE

# 等待完成
sleep 5

# 复制文件
cp /var/lib/redis/dump.rdb "$BACKUP_DIR/dump_$DATE.rdb"

# 如果启用了 AOF
if [ -f /var/lib/redis/appendonly.aof ]; then
  cp /var/lib/redis/appendonly.aof "$BACKUP_DIR/appendonly_$DATE.aof"
fi

# 清理 7 天前的备份
find $BACKUP_DIR -name "*.rdb" -mtime +7 -delete
find $BACKUP_DIR -name "*.aof" -mtime +7 -delete

echo "Redis backup completed: $DATE"
```

---

## 文件存储备份

### Backblaze B2 跨区域备份

```bash
# 使用 rclone 同步到备份 Bucket
brew install rclone

# 配置 rclone B2 remote
rclone config create b2 b2 account <keyId> key <applicationKey>

# 同步文件
rclone sync b2:redcode-im-bucket b2:redcode-backup-bucket --progress --transfers 10
```

### 本地备份

```bash
#!/bin/bash
# 从 B2 下载到本地

BACKUP_DIR="/backup/b2"
DATE=$(date +%Y-%m-%d)

mkdir -p "$BACKUP_DIR/$DATE"

# 下载所有文件（使用 rclone）
rclone sync b2:redcode-im-bucket "$BACKUP_DIR/$DATE" \
  --progress \
  --transfers 10

# 清理 30 天前的备份
find $BACKUP_DIR -type d -mtime +30 -exec rm -rf {} +
```

---

## 自动化备份脚本

### 完整备份脚本

```bash
#!/bin/bash
# /opt/scripts/backup.sh
# RedCode IM 完整备份脚本

set -e

# 配置
BACKUP_ROOT="/backup"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
LOG_FILE="/var/log/backup/backup_$DATE.log"

# 加载环境变量
source /etc/redcode/backup.env

# 日志函数
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# 创建目录
mkdir -p $BACKUP_ROOT/{postgresql,redis,config}/daily
mkdir -p /var/log/backup

log "=== 开始备份 ==="

# 1. PostgreSQL 备份
log "开始 PostgreSQL 备份..."
pg_dump $DATABASE_URL \
  --format=custom \
  --compress=9 \
  --file="$BACKUP_ROOT/postgresql/daily/redcode_im_$DATE.dump" 2>> $LOG_FILE
log "PostgreSQL 备份完成"

# 2. Redis 备份
log "开始 Redis 备份..."
redis-cli -a $REDIS_PASSWORD BGSAVE
sleep 5
cp /var/lib/redis/dump.rdb "$BACKUP_ROOT/redis/daily/dump_$DATE.rdb"
log "Redis 备份完成"

# 3. 配置文件备份
log "开始配置文件备份..."
tar -czf "$BACKUP_ROOT/config/daily/config_$DATE.tar.gz" \
  /etc/redcode/ \
  /opt/redcode/config/ 2>> $LOG_FILE
log "配置文件备份完成"

# 4. 清理旧备份
log "清理旧备份..."
find $BACKUP_ROOT/postgresql/daily -name "*.dump" -mtime +30 -delete
find $BACKUP_ROOT/redis/daily -name "*.rdb" -mtime +7 -delete
find $BACKUP_ROOT/config/daily -name "*.tar.gz" -mtime +30 -delete

# 5. 上传到远程存储（可选）
if [ -n "$BACKUP_REMOTE_PATH" ]; then
  log "上传到远程存储..."
  rclone copy $BACKUP_ROOT $BACKUP_REMOTE_PATH --progress 2>> $LOG_FILE
  log "远程上传完成"
fi

# 6. 发送通知
BACKUP_SIZE=$(du -sh $BACKUP_ROOT | cut -f1)
log "=== 备份完成 ==="
log "备份大小: $BACKUP_SIZE"

# 发送成功通知（可选）
# curl -X POST "https://hooks.slack.com/..." -d "{\"text\":\"备份完成: $DATE\"}"

exit 0
```

### Crontab 配置

```bash
# 编辑 crontab
crontab -e

# 每日凌晨 3 点执行全量备份
0 3 * * * /opt/scripts/backup.sh >> /var/log/backup/cron.log 2>&1

# 每小时执行 Redis 备份
0 * * * * /opt/scripts/redis_backup.sh >> /var/log/backup/redis_cron.log 2>&1

# 每周日凌晨 4 点执行周备份
0 4 * * 0 /opt/scripts/weekly_backup.sh >> /var/log/backup/weekly_cron.log 2>&1
```

### 备份监控

```bash
#!/bin/bash
# 检查备份状态

BACKUP_DIR="/backup/postgresql/daily"
TODAY=$(date +%Y-%m-%d)

# 检查今天的备份是否存在
if [ ! -f "$BACKUP_DIR/redcode_im_$TODAY.dump" ]; then
  echo "ERROR: 今日备份不存在!"
  # 发送告警
  exit 1
fi

# 检查备份文件大小
SIZE=$(stat -f%z "$BACKUP_DIR/redcode_im_$TODAY.dump" 2>/dev/null || stat -c%s "$BACKUP_DIR/redcode_im_$TODAY.dump")
if [ $SIZE -lt 1000000 ]; then  # 小于 1MB
  echo "WARNING: 备份文件过小，可能有问题"
  exit 1
fi

echo "备份检查通过: $TODAY, 大小: $(numfmt --to=iec $SIZE)"
```

---

## 恢复流程

### PostgreSQL 恢复

#### 完整恢复

```bash
# 停止后端服务
systemctl stop redcode-backend

# 删除现有数据库
dropdb redcode_im

# 创建新数据库
createdb redcode_im

# 恢复数据
pg_restore --dbname=redcode_im \
  --verbose \
  --clean \
  /backup/postgresql/daily/redcode_im_2026-01-13.dump

# 重启服务
systemctl start redcode-backend
```

#### 部分恢复（特定表）

```bash
# 只恢复消息表
pg_restore --dbname=redcode_im \
  --table=messages \
  --data-only \
  /backup/postgresql/daily/redcode_im_2026-01-13.dump
```

#### 时间点恢复（PITR）

```bash
# 1. 停止 PostgreSQL
systemctl stop postgresql

# 2. 清理数据目录
rm -rf /var/lib/postgresql/15/main/*

# 3. 恢复基础备份
pg_restore -D /var/lib/postgresql/15/main /backup/postgresql/base_backup.tar

# 4. 创建恢复配置
cat > /var/lib/postgresql/15/main/recovery.signal << EOF
EOF

cat >> /var/lib/postgresql/15/main/postgresql.conf << EOF
restore_command = 'cp /backup/postgresql/wal/%f %p'
recovery_target_time = '2026-01-13 10:00:00'
EOF

# 5. 启动 PostgreSQL
systemctl start postgresql
```

### Redis 恢复

```bash
# 停止 Redis
systemctl stop redis

# 恢复 RDB 文件
cp /backup/redis/daily/dump_2026-01-13.rdb /var/lib/redis/dump.rdb
chown redis:redis /var/lib/redis/dump.rdb

# 启动 Redis
systemctl start redis

# 验证恢复
redis-cli DBSIZE
```

### 文件存储恢复

```bash
# 从本地备份恢复到 B2
rclone sync /backup/b2/2026-01-13 b2:redcode-im-bucket \
  --progress \
  --transfers 10

# 或从备份 Bucket 恢复
rclone sync b2:redcode-backup-bucket/2026-01-13 b2:redcode-im-bucket --progress --transfers 10
```

---

## 灾难恢复

### 恢复优先级

1. **P0 - 立即恢复**: PostgreSQL 数据库
2. **P1 - 1小时内**: Redis 缓存
3. **P2 - 4小时内**: 文件存储
4. **P3 - 24小时内**: 历史日志

### 灾难恢复流程

```bash
#!/bin/bash
# 灾难恢复脚本

echo "=== 开始灾难恢复 ==="

# 1. 恢复 PostgreSQL
echo "恢复数据库..."
LATEST_PG_BACKUP=$(ls -t /backup/postgresql/daily/*.dump | head -1)
dropdb redcode_im --if-exists
createdb redcode_im
pg_restore --dbname=redcode_im $LATEST_PG_BACKUP

# 2. 恢复 Redis
echo "恢复 Redis..."
systemctl stop redis
LATEST_REDIS_BACKUP=$(ls -t /backup/redis/daily/*.rdb | head -1)
cp $LATEST_REDIS_BACKUP /var/lib/redis/dump.rdb
chown redis:redis /var/lib/redis/dump.rdb
systemctl start redis

# 3. 验证服务
echo "验证服务..."
sleep 5
curl -s http://localhost:8010/healthz

echo "=== 灾难恢复完成 ==="
```

### 恢复验证清单

- [ ] 数据库连接正常
- [ ] Redis 连接正常
- [ ] API 健康检查通过
- [ ] 用户可以登录
- [ ] WebSocket 连接正常
- [ ] 消息收发正常
- [ ] 文件上传下载正常

---

## 备份最佳实践

### 安全建议

1. **加密备份文件**
```bash
# 使用 GPG 加密
gpg --symmetric --cipher-algo AES256 backup.dump
```

2. **异地存储**
- 至少保留一份备份在不同地理位置
- 使用云存储的跨区域复制功能

3. **访问控制**
```bash
chmod 600 /backup/**/*
chown root:root /backup -R
```

### 测试恢复

- 每月至少进行一次恢复演练
- 在测试环境验证备份可用性
- 记录恢复时间（RTO）

---

**文档最后更新**: 2026-01-13
