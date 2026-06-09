# Redis 配置指南

## 概述

当前仓库的 api 采用 **3 个逻辑 Redis 入口**，部署上可映射到 **1~3 套 Redis 实例**。
本地开发、测试与验收默认只启动 **1 套 Redis**，并把三个逻辑入口都指向同一个 Redis 实例，避免浪费本机资源。

- **Session Redis**
  - 用途：用户会话、节点心跳、跨节点在线态
  - 环境变量：`REDIS_SESSION_URL`
- **Pub/Sub Redis**
  - 用途：跨节点广播；代码里始终使用独立 client/connection
  - 环境变量：`REDIS_PUBSUB_URL`（未设置时回退 `REDIS_SESSION_URL`）
- **Cache Redis**
  - 用途：刷新令牌、短信验证码、下载 URL 缓存
  - 环境变量：`REDIS_CACHE_URL`（未设置时回退 `REDIS_SESSION_URL`）

> 当前 api 不再依赖独立的 `REDIS_URL` 主实例；代码入口见 `api/src/redis/mod.rs`。

## 当前仓库中的 Redis 运行形态

### 1. API 开发调试（默认）

使用 `api/docker/dev/docker-compose.yml`：

```bash
docker compose -f api/docker/dev/docker-compose.yml up -d api
docker compose -f api/docker/dev/docker-compose.yml logs -f api
docker compose -f api/docker/dev/docker-compose.yml down -v
```

特点：

- Compose 内部网络里只有一个 Redis 服务：`redis`
- Redis 容器内部监听 `6379`
- api 通过服务名连接：
  - `redis://:123456@redis:6379/0`
- 开发栈 **不会把 Redis 端口映射到宿主机**

### 2. 测试隔离栈

使用 `tests/docker-compose.test.yml`：

```bash
docker compose -f tests/docker-compose.test.yml up -d --wait postgres redis external-mock
docker compose -f tests/docker-compose.test.yml down -v --remove-orphans
```

测试栈里 Redis 只启动一套：

- `redis`：容器内监听 `6379`
- PostgreSQL / Redis 均不映射宿主机端口

api 对应环境变量：

```bash
REDIS_SESSION_URL=redis://:123456@redis:6379/0
REDIS_PUBSUB_URL=redis://:123456@redis:6379/0
REDIS_CACHE_URL=redis://:123456@redis:6379/0
```

### 3. 宿主机本地 Redis（可选，不是默认）

如果你需要不用 Compose、直接在宿主机跑 api，可用本地 Redis：

```bash
cd api
./start-redis.sh start
./start-redis.sh status
./start-redis.sh stop
```

该模式默认使用一套本地 Redis：

- Session / Pub/Sub / Cache：`localhost:6381`

与 `api/src/redis/mod.rs` 的默认回退值一致。

> 注意：当前仓库默认是 **Compose-first**。只有在需要宿主机直接 `cargo run` 调试时，才建议走本地 Redis。

## 环境变量约定

最小必需项：

```bash
REDIS_SESSION_URL=redis://localhost:6381
```

如果需要显式拆出逻辑入口：

```bash
REDIS_SESSION_URL=redis://localhost:6381
REDIS_PUBSUB_URL=redis://localhost:6381
REDIS_CACHE_URL=redis://localhost:6381
```

如果 Redis 开启密码，例如本仓库 Compose 默认密码 `123456`：

```bash
REDIS_SESSION_URL=redis://:123456@localhost:6381/0
REDIS_PUBSUB_URL=redis://:123456@localhost:6381/0
REDIS_CACHE_URL=redis://:123456@localhost:6381/0
```

## 代码内职责划分

`api/src/redis/mod.rs` 中的连接职责：

- `pubsub_client`：Pub/Sub 专用 client/connection；默认复用 `REDIS_SESSION_URL`，也可单独指定 `REDIS_PUBSUB_URL`
- `session_client`：Session 数据
- `cache_client`：Cache 数据；默认复用 `REDIS_SESSION_URL`，也可单独指定 `REDIS_CACHE_URL`

也就是说，当前是 **三类逻辑入口**，但不要求三套物理 Redis：

- **1 套 Redis**：session + pub/sub + cache 都复用同一实例（当前本地 Compose 默认）
- **2 套 Redis**：session/pubsub 一套，cache 一套
- **3 套 Redis**：session / pubsub / cache 各自独立

## 常见键空间

### Session Redis

```text
session:user:{user_id}
sessions:node:{node_id}
node:heartbeat:{node_id}
nodes:active
room:{room_id}
user:online:{user_id}
```

### Cache Redis

```text
auth:refresh:{token}
auth:sms:{phone}
cache:download_url:{object_key}:{provider_id}:{expires_in}
```

## 常用排查命令

### Compose 开发栈

```bash
docker compose -f api/docker/dev/docker-compose.yml ps
docker compose -f api/docker/dev/docker-compose.yml logs -f redis
```

### 宿主机本地 Redis

```bash
redis-cli -p 6381 ping

redis-cli -p 6381 info memory
```

### 清理本地 Redis

```bash
redis-cli -p 6381 flushall
```

## 故障排查

### api 启动时报 Redis 连接失败

优先检查：

1. `REDIS_SESSION_URL` 是否与当前运行形态一致；`REDIS_CACHE_URL` 是否需要显式覆盖
2. `REDIS_PUBSUB_URL` 是否显式配置；未配置时是否预期回退 `REDIS_SESSION_URL`
3. 当前是 dev Compose、tests Compose，还是宿主机本地 Redis
4. Redis 是否带密码；URL 是否包含 `:123456@`
5. api 与 Redis 是否在同一网络中

### 端口占用

宿主机本地 Redis 场景下可检查：

```bash
lsof -i :6381
```

### 为什么 dev Compose 里 Redis 端口是 6379，而代码默认回退是 6381？

因为这是两种不同运行形态：

- **Compose 内部容器网络**：Redis 容器内部监听 `6379`
- **宿主机本地直连模式**：本地 Redis 使用 `6381`

只要 `REDIS_SESSION_URL`、`REDIS_PUBSUB_URL`、`REDIS_CACHE_URL` 与当前运行形态匹配，或明确依赖回退规则即可。

## 参考文件

- `api/src/redis/mod.rs`
- `api/docker/dev/docker-compose.yml`
- `api/docker/release/docker-compose.yml`
- `tests/docker-compose.test.yml`
- `api/start-redis.sh`
