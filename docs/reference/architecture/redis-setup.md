# Redis 多实例配置指南

## 概述

当前仓库的 backend 采用 **两套 Redis**：

- **Session Redis**
  - 用途：用户会话、节点心跳、Pub/Sub
  - 环境变量：`REDIS_SESSION_URL`
- **Cache Redis**
  - 用途：用户/房间等高频缓存
  - 环境变量：`REDIS_CACHE_URL`

> 当前 backend 不再依赖独立的 `REDIS_URL` 主实例；代码入口见 `backend/src/redis/mod.rs`。

## 当前仓库中的 Redis 运行形态

### 1. Backend 开发调试（默认）

使用 `backend/docker/dev/docker-compose.yml`：

```bash
docker compose -f backend/docker/dev/docker-compose.yml up -d backend
docker compose -f backend/docker/dev/docker-compose.yml logs -f backend
docker compose -f backend/docker/dev/docker-compose.yml down -v
```

特点：

- Compose 内部网络里有两个 Redis 服务：`redis-session`、`redis-cache`
- 两个容器内部都监听 `6379`
- backend 通过服务名连接：
  - `redis://:123456@redis-session:6379/0`
  - `redis://:123456@redis-cache:6379/0`
- 开发栈 **不会把 Redis 端口映射到宿主机**

### 2. 测试隔离栈

使用 `tests/docker-compose.yml`：

```bash
docker compose -f tests/docker-compose.yml up -d --build external-mock postgres redis-session redis-cache backend
docker compose -f tests/docker-compose.yml run --rm go-tests
docker compose -f tests/docker-compose.yml down -v --remove-orphans
```

测试栈里 Redis 明确拆成：

- `redis-session`：容器内监听 `6381`
- `redis-cache`：容器内监听 `6383`

backend 对应环境变量：

```bash
REDIS_SESSION_URL=redis://:123456@redis-session:6381/0
REDIS_CACHE_URL=redis://:123456@redis-cache:6383/0
```

### 3. 宿主机本地 Redis（可选，不是默认）

如果你需要不用 Compose、直接在宿主机跑 backend，可用本地 Redis：

```bash
cd backend
./start-redis.sh start
./start-redis.sh status
./start-redis.sh stop
```

该模式默认使用：

- Session Redis：`localhost:6381`
- Cache Redis：`localhost:6383`

与 `backend/src/redis/mod.rs` 的默认回退值一致。

> 注意：当前仓库默认是 **Compose-first**。只有在需要宿主机直接 `cargo run` 调试时，才建议走本地 Redis。

## 环境变量约定

最小必需项：

```bash
REDIS_SESSION_URL=redis://localhost:6381
REDIS_CACHE_URL=redis://localhost:6383
```

如果 Redis 开启密码，例如本仓库 Compose 默认密码 `123456`：

```bash
REDIS_SESSION_URL=redis://:123456@localhost:6381/0
REDIS_CACHE_URL=redis://:123456@localhost:6383/0
```

## 代码内职责划分

`backend/src/redis/mod.rs` 中的连接职责：

- `pubsub_client`：复用 **Session Redis**
- `session_client`：Session 数据
- `cache_client`：Cache 数据

也就是说，当前并不是三套 Redis，而是：

- **1 套 Session Redis**（会话 + Pub/Sub）
- **1 套 Cache Redis**（缓存）

## 常见键空间

### Session Redis

```text
session:{user_id}
node_sessions:{node_id}
node_heartbeat:{node_id}
active_nodes
```

### Cache Redis

```text
cache:user:{user_id}
cache:room:{room_id}
cache:room_members:{id}
user_online:{user_id}
```

## 常用排查命令

### Compose 开发栈

```bash
docker compose -f backend/docker/dev/docker-compose.yml ps
docker compose -f backend/docker/dev/docker-compose.yml logs -f redis-session
docker compose -f backend/docker/dev/docker-compose.yml logs -f redis-cache
```

### 宿主机本地 Redis

```bash
redis-cli -p 6381 ping
redis-cli -p 6383 ping

redis-cli -p 6381 info memory
redis-cli -p 6383 info memory
```

### 清理缓存 Redis

```bash
redis-cli -p 6383 flushall
```

## 故障排查

### backend 启动时报 Redis 连接失败

优先检查：

1. `REDIS_SESSION_URL` / `REDIS_CACHE_URL` 是否与当前运行形态一致
2. 当前是 dev Compose、tests Compose，还是宿主机本地 Redis
3. Redis 是否带密码；URL 是否包含 `:123456@`
4. backend 与 Redis 是否在同一网络中

### 端口占用

宿主机本地 Redis 场景下可检查：

```bash
lsof -i :6381
lsof -i :6383
```

### 为什么 dev Compose 里 Redis 端口是 6379，而代码默认回退是 6381/6383？

因为这是两种不同运行形态：

- **Compose 内部容器网络**：每个 Redis 容器内部都可监听 `6379`
- **宿主机本地直连模式**：为了区分两套 Redis，使用 `6381/6383`

只要 `REDIS_SESSION_URL` / `REDIS_CACHE_URL` 配对正确即可。

## 参考文件

- `backend/src/redis/mod.rs`
- `backend/docker/dev/docker-compose.yml`
- `backend/docker/release/docker-compose.yml`
- `tests/docker-compose.yml`
- `backend/start-redis.sh`
