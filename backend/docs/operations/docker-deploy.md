# Docker 部署指南

## 📁 Docker Compose 配置说明

本项目提供了两个 Docker Compose 配置文件：

### 1. 开发环境 - `docker-compose.yml`
- 包含所有端口映射，便于开发调试
- 挂载源码目录，支持热重载
- 包含 Redis 管理工具
- 使用简单密码（123456）

### 2. 生产环境 - `docker-compose.prod.yml`
- 无端口暴露（仅后端服务）
- 使用预构建镜像
- 资源限制和日志管理
- 环境变量配置

## 🚀 使用方法

### 开发环境
```bash
# 启动所有服务
docker-compose up -d

# 包含 Redis 管理工具
docker-compose --profile tools up -d

# 查看日志
docker-compose logs -f backend

# 停止服务
docker-compose down
```

### 生产环境
```bash
# 使用生产配置启动
docker-compose -f docker-compose.prod.yml up -d

# 查看状态
docker-compose -f docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker-compose.prod.yml logs -f backend
```

## 🔧 方案一：.env 文件配置

### 1. 确保 .env 文件存在
```bash
backend/
├── .env          # 环境变量配置文件
├── docker-compose.yml
└── src/
```

### 2. .env 文件内容示例
```env
# 数据库配置
DATABASE_URL=postgresql://postgres:123456@postgres:5432/redcode_im

# Redis 配置（Docker 内部网络）
REDIS_SESSION_URL=redis://:123456@redis-session:6381
REDIS_STREAM_URL=redis://:123456@redis-streams:6382
REDIS_CACHE_URL=redis://:123456@redis-cache:6383

# 服务器配置
PORT=8080

# JWT 配置
JWT_SECRET=N6zrM6bXvcumQkWWaj+2XttFhKUBCgHUcOlyZBtWWUM=

# 日志级别
RUST_LOG=info
```

### 3. 关键配置说明

#### 开发环境
```yaml
volumes:
  - ./.env:/app/.env:ro  # 挂载 .env 文件到容器
```

#### 生产环境
```yaml
# .env 文件内容通过环境变量传递
environment:
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
  REDIS_SESSION_PASSWORD: ${REDIS_SESSION_PASSWORD}
```

## 🌐 网络配置

### 内部网络
- **网络名称**: `redcode_backend_network`
- **子网**: `172.21.0.0/16`
- **类型**: bridge

### 服务通信
- **后端 → PostgreSQL**: `postgres:5432`
- **后端 → Redis-Session**: `redis-session:6381`
- **后端 → Redis-Streams**: `redis-streams:6382`
- **后端 → Redis-Cache**: `redis-cache:6383`

## 📊 端口映射

### 开发环境
- **后端**: `8080:8080`
- **PostgreSQL**: `5432:5432`
- **Redis-Session**: `6381:6381`
- **Redis-Streams**: `6382:6382`
- **Redis-Cache**: `6383:6383`
- **Redis Commander**: `8081:8081` (可选)

### 生产环境
- **后端**: `8080:8080` (可配置反向代理)

## 🗂️ 数据持久化

### PostgreSQL
```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
```

### Redis Session
```yaml
volumes:
  - redis_session_data:/data
```

### 数据卷位置
```bash
# 查看数据卷
docker volume ls | grep redcode

# 数据卷路径
/var/lib/docker/volumes/redcode_postgres_data
/var/lib/docker/volumes/redcode_redis_session_data
```

## 🔍 健康检查

所有服务都配置了健康检查：

### PostgreSQL
```bash
pg_isready -U postgres
```

### Redis
```bash
redis-cli -p 6381 -a 123456 ping
```

### 后端
```bash
curl -f http://localhost:8080/healthz
```

## 🛠️ 管理工具

### Redis Commander (开发环境)
```bash
# 启动管理工具
docker-compose --profile tools up -d

# 访问地址
http://localhost:8081
用户名: admin
密码: admin
```

### 日志查看
```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f backend
docker-compose logs -f postgres
```

## 🔄 更新部署

### 开发环境
```bash
# 重新构建并启动
docker-compose up -d --build
```

### 生产环境
```bash
# 拉取最新镜像
docker-compose -f docker-compose.prod.yml pull

# 重启服务
docker-compose -f docker-compose.prod.yml up -d
```

## 🚨 故障排查

### 1. 检查服务状态
```bash
docker-compose ps
```

### 2. 查看日志
```bash
docker-compose logs backend
```

### 3. 进入容器调试
```bash
docker-compose exec backend sh
```

### 4. 测试连接
```bash
# 测试 Redis 连接
docker-compose exec redis-session redis-cli -p 6381 -a 123456 ping

# 测试数据库连接
docker-compose exec postgres psql -U postgres -d redcode_im -c "SELECT 1;"
```

## 🔐 安全建议

1. **生产环境**：使用强密码替换默认密码
2. **网络隔离**：仅暴露必要端口
3. **日志管理**：配置日志轮转
4. **资源限制**：设置 CPU 和内存限制
5. **定期备份**：备份 PostgreSQL 数据和 Redis AOF 文件