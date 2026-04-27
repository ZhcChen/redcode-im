# Redis 安全配置指南

## 🔐 密码认证配置

本项目已为 Redis 启用密码认证，提高安全性。当前 backend 保留 session / pubsub / cache 三类逻辑入口；本地开发、测试与验收默认只启动一套 Redis，三个逻辑入口共用同一个实例。

### 密码设置

- **本地单 Redis** (默认端口 6381): `REDIS_PASSWORD`
- 如生产环境拆分多套 Redis，可按实例分别配置独立密码。

### 环境变量配置

#### 开发环境
在 `.env` 文件中设置：
```bash
REDIS_PASSWORD=redis_password_2024
REDIS_SESSION_URL=redis://:redis_password_2024@localhost:6381/0
REDIS_PUBSUB_URL=redis://:redis_password_2024@localhost:6381/0
REDIS_CACHE_URL=redis://:redis_password_2024@localhost:6381/0
```

#### 生产环境
请使用强密码，建议使用以下命令生成：
```bash
openssl rand -base64 32
```

### Docker Compose 配置

Redis 已配置密码认证：

```yaml
command: |
  redis-server
  --port 6379
  --requirepass ${REDIS_PASSWORD:-redis_password}
  # ... 其他配置
```

### 连接 URL 格式

带密码的 Redis 连接 URL 格式：
```
redis://:密码@主机:端口
```

例如：
```bash
REDIS_SESSION_URL=redis://:redis_password@localhost:6381/0
REDIS_PUBSUB_URL=redis://:redis_password@localhost:6381/0
REDIS_CACHE_URL=redis://:redis_password@localhost:6381/0
```

## 🛡️ 安全最佳实践

### 1. 使用强密码
- 至少 16 位字符
- 包含大小写字母、数字和特殊字符
- 定期更换密码

### 2. 网络安全
- Redis 实例运行在内部 Docker 网络
- 仅在必要时暴露端口到宿主机
- 生产环境建议关闭端口映射

### 3. 访问控制
- 本地开发、测试与验收使用单 Redis，减少资源占用
- 生产环境如需强隔离，可拆分 Redis 实例并按需分配权限
- 监控异常访问

### 4. 数据保护
- 敏感数据加密存储
- 定期备份重要数据
- 设置合适的内存策略

## 🔧 管理命令

### 连接带密码的 Redis
```bash
# 使用 redis-cli 连接
redis-cli -p 6381 -a redis_password

# 或者使用环境变量
redis-cli -p 6381 -a $REDIS_PASSWORD
```

### 测试连接
```bash
# 在 Docker 容器中测试（本地 Compose 内部端口为 6379，默认密码 123456）
docker exec redcode-dev-redis redis-cli -p 6379 -a 123456 ping
```

### 修改密码
```bash
# 在 Redis CLI 中执行
CONFIG SET requirepass new_password
CONFIG REWRITE
```

## 📋 安全检查清单

- [ ] Redis 已设置密码
- [ ] 使用强密码（生产环境）
- [ ] 环境变量正确配置
- [ ] 健康检查使用密码认证
- [ ] 连接测试通过
- [ ] 网络访问控制配置
- [ ] 日志监控异常访问

## 🚨 注意事项

1. **密码管理**：不要在代码中硬编码密码
2. **环境隔离**：不同环境使用不同密码
3. **密钥轮换**：定期更换 Redis 密码
4. **访问日志**：监控 Redis 访问日志
5. **备份加密**：备份文件也要加密保护

## 🔍 故障排查

### 连接失败
1. 检查密码是否正确
2. 验证环境变量配置
3. 确认 Redis 服务状态
4. 查看容器日志

### 权限错误
1. 检查用户权限配置
2. 验证 Redis 命令权限
3. 确认认证流程

### 性能问题
1. 监控内存使用
2. 检查连接数限制
3. 优化配置参数
