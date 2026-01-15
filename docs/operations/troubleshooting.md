# 故障排查手册

本文档提供 RedCode IM 系统常见问题的排查方法和解决方案。

---

## 目录

- [后端服务问题](#后端服务问题)
- [数据库问题](#数据库问题)
- [Redis 问题](#redis-问题)
- [WebSocket 问题](#websocket-问题)
- [文件存储问题](#文件存储问题)
- [推送通知问题](#推送通知问题)
- [客户端问题](#客户端问题)
- [性能问题](#性能问题)

---

## 后端服务问题

### 服务无法启动

**症状**：后端服务启动失败，进程立即退出

**排查步骤**：

1. **检查日志输出**
```bash
# 查看启动日志
RUST_LOG=debug cargo run

# 或查看 Docker 日志
docker logs redcode-backend
```

2. **检查环境变量**
```bash
# 确认必需的环境变量已设置
echo $DATABASE_URL
echo $REDIS_URL
echo $JWT_SECRET
```

3. **检查端口占用**
```bash
# 检查 8010 端口是否被占用
lsof -i :8010
# 或
netstat -tlnp | grep 8010
```

**常见原因**：
- 数据库连接失败
- 缺少必需的环境变量
- 端口已被占用
- 配置文件格式错误

**解决方案**：
```bash
# 释放端口
kill -9 $(lsof -t -i:8010)

# 检查数据库连接
psql $DATABASE_URL -c "SELECT 1"

# 检查 Redis 连接
redis-cli -u $REDIS_URL ping
```

---

### API 返回 500 错误

**症状**：API 请求返回 Internal Server Error

**排查步骤**：

1. **查看详细错误日志**
```bash
RUST_LOG=debug,tower_http=trace cargo run
```

2. **检查请求参数**
```bash
# 使用 curl 测试
curl -v -X POST http://localhost:8010/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'
```

3. **检查数据库状态**
```sql
-- 检查数据库连接数
SELECT count(*) FROM pg_stat_activity;

-- 检查是否有锁等待
SELECT * FROM pg_locks WHERE NOT granted;
```

**常见原因**：
- 数据库连接池耗尽
- 内存不足
- 代码 bug（查看 panic 信息）

---

### 认证失败 (401 Unauthorized)

**症状**：请求返回 401 错误

**排查步骤**：

1. **验证 Token 格式**
```bash
# 确保 Header 格式正确
curl -H "Authorization: Bearer <token>" ...

# 不是
curl -H "Authorization: <token>" ...
```

2. **检查 Token 是否过期**
```bash
# 解码 JWT Token（使用 jwt.io 或命令行工具）
echo "<token>" | cut -d'.' -f2 | base64 -d | jq .
```

3. **验证 JWT_SECRET 一致性**
```bash
# 确保生成 Token 和验证 Token 使用相同的 secret
echo $JWT_SECRET
```

**解决方案**：
- 刷新 Token：调用 `/auth/refresh` 接口
- 重新登录获取新 Token

---

## 数据库问题

### 连接超时

**症状**：`connection timed out` 或 `too many connections`

**排查步骤**：

1. **检查连接数**
```sql
-- 查看当前连接数
SELECT count(*) FROM pg_stat_activity;

-- 查看连接详情
SELECT pid, usename, application_name, client_addr, state, query_start
FROM pg_stat_activity
WHERE datname = 'redcode_im';
```

2. **检查连接池配置**
```bash
# 确认环境变量
echo $DATABASE_MAX_CONNECTIONS  # 默认 10
```

**解决方案**：
```sql
-- 终止空闲连接
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'redcode_im'
  AND state = 'idle'
  AND query_start < now() - interval '10 minutes';
```

```bash
# 增加最大连接数（配置文件）
# postgresql.conf
max_connections = 200
```

---

### 迁移失败

**症状**：数据库迁移报错

**排查步骤**：

1. **检查迁移状态**
```bash
sqlx migrate info
```

2. **查看迁移历史**
```sql
SELECT * FROM _sqlx_migrations ORDER BY installed_on DESC;
```

**解决方案**：
```bash
# 回滚上一次迁移
sqlx migrate revert

# 强制标记迁移完成（谨慎使用）
sqlx migrate run --ignore-missing
```

---

### 查询性能慢

**症状**：API 响应时间长

**排查步骤**：

1. **开启慢查询日志**
```sql
-- PostgreSQL
ALTER SYSTEM SET log_min_duration_statement = 1000;  -- 1秒
SELECT pg_reload_conf();
```

2. **分析查询计划**
```sql
EXPLAIN ANALYZE SELECT * FROM messages WHERE room_id = 'xxx';
```

3. **检查索引使用情况**
```sql
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

**解决方案**：
```sql
-- 添加缺失的索引
CREATE INDEX CONCURRENTLY idx_messages_room_id ON messages(room_id);

-- 更新统计信息
ANALYZE messages;
```

---

## Redis 问题

### 连接失败

**症状**：`Connection refused` 或 `NOAUTH`

**排查步骤**：

1. **检查 Redis 服务状态**
```bash
redis-cli ping
# 应返回 PONG
```

2. **检查认证**
```bash
redis-cli -a <password> ping
```

3. **检查网络连接**
```bash
telnet <redis-host> 6379
```

**解决方案**：
```bash
# 重启 Redis
systemctl restart redis

# 检查配置文件
cat /etc/redis/redis.conf | grep -E "^(bind|requirepass)"
```

---

### 内存不足

**症状**：`OOM command not allowed` 或写入失败

**排查步骤**：

1. **检查内存使用**
```bash
redis-cli info memory
```

2. **查看 key 分布**
```bash
redis-cli --bigkeys
```

**解决方案**：
```bash
# 设置内存上限和淘汰策略
redis-cli CONFIG SET maxmemory 2gb
redis-cli CONFIG SET maxmemory-policy allkeys-lru

# 手动清理过期 key
redis-cli --scan --pattern "session:*" | xargs redis-cli DEL
```

---

## WebSocket 问题

### 连接建立失败

**症状**：WebSocket 无法连接

**排查步骤**：

1. **检查连接地址**
```javascript
// 正确格式
ws://localhost:8010/ws?token=<jwt-token>

// 生产环境使用 wss
wss://api.example.com/ws?token=<jwt-token>
```

2. **检查 Token 有效性**
```bash
# Token 必须有效且未过期
curl -H "Authorization: Bearer <token>" http://localhost:8010/auth/me
```

3. **检查 Nginx 配置（如有代理）**
```nginx
location /ws {
    proxy_pass http://backend;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 86400;
}
```

---

### 消息不推送

**症状**：发送消息后对方收不到

**排查步骤**：

1. **确认已加入房间**
```json
// 客户端需要发送 join 事件
{"type": "join", "room_id": "xxx"}

// 应收到 joined 响应
{"type": "joined", "room_id": "xxx"}
```

2. **检查 Redis Pub/Sub**
```bash
redis-cli PUBSUB CHANNELS "room:*"
```

3. **检查连接状态**
```bash
# 查看活跃连接数
redis-cli HLEN ws:connections
```

---

### 频繁断开

**症状**：WebSocket 连接不稳定

**排查步骤**：

1. **检查心跳机制**
```javascript
// 客户端应定期发送 ping
setInterval(() => {
  ws.send(JSON.stringify({ type: "ping" }));
}, 30000);
```

2. **检查代理超时设置**
```nginx
proxy_read_timeout 86400;
proxy_send_timeout 86400;
```

---

## 文件存储问题

### 上传失败

**症状**：文件上传返回错误

**排查步骤**：

1. **检查存储配置**
```bash
# 确认 COS 配置
echo $COS_SECRET_ID
echo $COS_SECRET_KEY
echo $COS_BUCKET
echo $COS_REGION
```

2. **检查文件大小限制**
```bash
# 查看上传策略
curl -H "Authorization: Bearer <token>" \
  http://localhost:8010/system/upload-policy
```

3. **测试存储连接**
```bash
# 使用管理后台测试接口
curl -X POST http://localhost:8010/api/admin/storage-providers/test/upload
```

**常见错误**：
- `SignatureDoesNotMatch`: 密钥配置错误
- `AccessDenied`: 权限不足
- `EntityTooLarge`: 文件超过大小限制

---

### 下载链接失效

**症状**：文件下载返回 403 或 404

**原因**：签名 URL 已过期

**解决方案**：
```bash
# 重新获取下载链接
curl -H "Authorization: Bearer <token>" \
  "http://localhost:8010/rooms/<room_id>/messages/attachments/download?key=<file_key>"
```

---

## 推送通知问题

### 推送不到达

**症状**：消息发送后设备未收到通知

**排查步骤**：

1. **检查设备注册**
```sql
SELECT * FROM push_devices WHERE user_id = 'xxx';
```

2. **检查推送日志**
```bash
# 管理后台查看推送日志
curl -H "Authorization: Bearer <admin-token>" \
  http://localhost:8010/api/admin/push/logs
```

3. **验证推送配置**
```bash
# 发送测试推送
curl -X POST http://localhost:8010/api/admin/settings/push/test \
  -H "Authorization: Bearer <admin-token>" \
  -d '{"device_token": "xxx", "title": "Test", "body": "Test message"}'
```

**常见原因**：
- Device Token 已失效
- 推送证书/密钥过期
- 用户关闭了通知权限

---

## 客户端问题

### 移动端闪退

**排查步骤**：

1. **查看崩溃日志**
```bash
# Android
adb logcat | grep -E "(FATAL|crash)"

# iOS
# 使用 Xcode -> Devices -> View Device Logs
```

2. **检查网络请求**
```bash
# 使用 Charles/Proxyman 抓包分析
```

---

### 桌面端白屏

**排查步骤**：

1. **打开开发者工具**
```bash
# 按 F12 或 Cmd+Option+I 查看控制台错误
```

2. **检查本地存储**
```javascript
// 清除缓存数据
localStorage.clear();
```

---

## 性能问题

### CPU 使用率高

**排查步骤**：

1. **查看进程状态**
```bash
top -p $(pgrep -f redcode)
```

2. **分析火焰图**
```bash
# 使用 perf 采样
perf record -g -p <pid> sleep 30
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg
```

---

### 内存持续增长

**排查步骤**：

1. **监控内存使用**
```bash
watch -n 5 'ps aux | grep redcode'
```

2. **检查连接泄漏**
```sql
SELECT count(*) FROM pg_stat_activity WHERE state = 'idle';
```

3. **检查 Redis 内存**
```bash
redis-cli info memory | grep used_memory_human
```

---

## 日志收集

### 收集诊断信息

当需要向开发团队报告问题时，请收集以下信息：

```bash
#!/bin/bash
# 创建诊断报告

echo "=== System Info ===" > diagnosis.txt
uname -a >> diagnosis.txt

echo "=== Backend Version ===" >> diagnosis.txt
curl -s http://localhost:8010/ >> diagnosis.txt

echo "=== Database Status ===" >> diagnosis.txt
psql $DATABASE_URL -c "SELECT version();" >> diagnosis.txt

echo "=== Redis Status ===" >> diagnosis.txt
redis-cli info >> diagnosis.txt

echo "=== Recent Logs ===" >> diagnosis.txt
tail -n 100 /var/log/redcode/backend.log >> diagnosis.txt

echo "Diagnosis report saved to diagnosis.txt"
```

---

## 常用命令速查

```bash
# 重启服务
systemctl restart redcode-backend

# 查看日志
journalctl -u redcode-backend -f

# 检查服务状态
systemctl status redcode-backend

# 数据库备份
pg_dump $DATABASE_URL > backup.sql

# Redis 备份
redis-cli BGSAVE

# 清理日志
find /var/log/redcode -name "*.log" -mtime +7 -delete
```

---

**文档最后更新**: 2026-01-13
