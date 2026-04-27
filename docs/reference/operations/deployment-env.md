# 生产环境配置指南

## 🚀 环境变量配置方案

### 代码加载逻辑
代码中使用了 `dotenvy::dotenv().ok()` 来加载 `.env` 文件，这意味着：
- 优先读取环境变量
- 如果环境变量不存在，尝试从 `.env` 文件读取
- 如果 `.env` 文件不存在，使用默认值或报错

## 📁 不同部署场景的配置位置

### 1. 本地开发（Compose-first）
```
backend/
├── .env                         ✅ 开发环境配置
└── docker/dev/docker-compose.yml
```
**运行方式**: `docker compose -f docker/dev/docker-compose.yml up -d backend`

### 2. 本地 release 构建验证
```
backend/
├── .env                             ✅ release 验证环境变量
└── docker/release/docker-compose.yml
```
**运行方式**: `docker compose -f docker/release/docker-compose.yml up -d backend`

### 3. 二进制部署
```
/opt/redcode-im/
├── redcode-im    ✅ 编译后的二进制文件
├── .env          ✅ 生产环境配置文件
└── config/       # 可选：配置文件目录
```

### 4. 系统服务部署 (systemd)
```
/etc/systemd/system/redcode-im.service
├── Environment=DATABASE_URL=postgresql://...
├── Environment=REDIS_SESSION_URL=redis://...
├── Environment=REDIS_PUBSUB_URL=redis://...
├── Environment=REDIS_CACHE_URL=redis://...
└── Environment=JWT_SECRET=...
```

## 🔧 推荐的生产环境配置方式

### 方案一：系统环境变量 (推荐)
```bash
# 设置系统环境变量
export DATABASE_URL="postgresql://user:pass@host:5432/db"
export REDIS_SESSION_URL="redis://:password@host:6381"
export REDIS_PUBSUB_URL="redis://:password@host:6381"
export REDIS_CACHE_URL="redis://:password@host:6381"
export JWT_SECRET="your-jwt-secret"
export PORT=8080
export RUST_LOG=info

# 启动服务
./redcode-im
```

### 方案二：.env 文件
```bash
# 将 .env 文件放在二进制文件同目录
/opt/redcode-im/
├── redcode-im
└── .env

# 启动时自动加载同目录下的 .env
./redcode-im
```

### 方案三：Docker 部署
```bash
# 使用环境变量文件
docker run -d \
  --name redcode-im \
  --env-file /path/to/.env \
  -p 8080:8080 \
  redcode-im:latest
```

## 📋 配置文件优先级

1. **系统环境变量** (最高优先级)
2. **当前目录 .env 文件**
3. **父目录 .env 文件** (向上查找)
4. **代码中的默认值** (最低优先级)

## 🛡️ 生产环境安全建议

### 1. 不要使用 .env 文件
```bash
# 直接设置环境变量，避免敏感信息存储在文件中
export DATABASE_URL="postgresql://..."
export JWT_SECRET="..."
```

### 2. 使用密钥管理服务
```bash
# AWS Parameter Store / Secrets Manager
# HashiCorp Vault
# Kubernetes Secrets
```

### 3. 文件权限控制
```bash
# 如果必须使用 .env 文件，设置严格权限
chmod 600 .env
chown app:app .env
```

## 🚀 部署检查清单

- [ ] 所有密码都是强密码
- [ ] JWT_SECRET 是随机生成的
- [ ] 数据库连接使用生产环境地址
- [ ] Redis 连接使用生产环境地址
- [ ] 环境变量已正确设置
- [ ] 文件权限已正确配置
- [ ] 防火墙规则已设置
- [ ] 日志级别适合生产环境

## 🔄 环境变量热重载

当前实现不支持热重载，修改环境变量需要重启服务：

```bash
# 重启服务
systemctl restart redcode-im
# 或
cd backend && docker compose -f docker/dev/docker-compose.yml restart backend
```
