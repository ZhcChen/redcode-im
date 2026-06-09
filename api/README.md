# RedCode IM API（Rust）

> 后端服务基于 **Axum + SQLx + Redis**，提供 REST API 与 WebSocket 能力。
>
> 文档统一入口请优先查看：`docs/index.md`（仓库根目录下的 `docs/`）。

---

## 目录

- [快速开始（本地运行）](#快速开始本地运行)
- [使用 Docker Compose](#使用-docker-compose)
- [环境变量](#环境变量)
- [数据库迁移](#数据库迁移)
- [运行测试](#运行测试)
- [代码入口](#代码入口)

---

## 快速开始（本地运行）

### 1) 准备依赖

- Docker
- Docker Compose 插件（使用 `docker compose` 命令）
- 如需宿主机本地调试：Rust（建议使用仓库约定版本）

### 2) 配置环境

在 `api/` 目录下复制示例配置：

```bash
cp .env.example .env
```

按需修改 `.env` 中的 `DATABASE_URL`、`REDIS_SESSION_URL`、`REDIS_PUBSUB_URL`、`REDIS_CACHE_URL`、`JWT_SECRET` 等配置。

### 3) 启动服务

```bash
docker compose -f docker/dev/docker-compose.yml up -d api
```

默认端口为 `8010`，健康检查：`GET /healthz`

查看日志：

```bash
docker compose -f docker/dev/docker-compose.yml logs -f api
```

如需宿主机本地进程调试（非默认方式）：

```bash
# dev Compose 的 PostgreSQL / Redis 不映射宿主机端口；
# 宿主机 cargo run 需使用本机可访问的 PostgreSQL / Redis。
./start-redis.sh start
DATABASE_URL=postgresql://postgres:123456@localhost:5432/redcode_im \
REDIS_SESSION_URL=redis://localhost:6381 \
REDIS_PUBSUB_URL=redis://localhost:6381 \
REDIS_CACHE_URL=redis://localhost:6381 \
RUST_LOG=debug cargo run
```

---

## 使用 Docker Compose

在 `api/` 目录下执行以下命令。开发调试默认使用 dev Compose：

```bash
docker compose -f docker/dev/docker-compose.yml up -d api
```

本地 release 构建验证使用 release Compose：

```bash
docker compose -f docker/release/docker-compose.yml up -d --build api
```

---

## 环境变量

示例配置见：`api/.env.example`。

常用项：

- `PORT`：服务端口（默认 `8010`）
- `DATABASE_URL`：PostgreSQL 连接串
- `REDIS_SESSION_URL`：Session Redis
- `REDIS_PUBSUB_URL`：Pub/Sub Redis（可选；默认回退 `REDIS_SESSION_URL`）
- `REDIS_CACHE_URL`：Cache Redis（可选；默认回退 `REDIS_SESSION_URL`）
- `JWT_SECRET`：JWT 密钥
- `RUST_LOG`：日志级别

测试可选项（若设置则优先使用）：

- `DATABASE_URL_TEST`：数据库测试连接串

---

## 数据库迁移

服务启动时会自动执行 `Database::migrate`，按顺序执行 `api/src/database/mod.rs` 中声明的迁移脚本。

数据库迁移与基线说明请查看：`api/sql/README.md`。

---

## 运行测试

api Rust 单元 + 集成（集成自动拉起 `tests/docker-compose.test.yml` 的 pg/redis）：

```bash
make api.test             # 单元 + 集成
make api.test.unit        # 仅单元（cargo test --lib）
make api.test.integration # 仅集成（axum oneshot 进程内）
make api.test.deps.down   # 停掉集成依赖栈
```

集成测试用 `axum` `oneshot` 进程内打 Router，对单一临时测试库运行（每测试 `CREATE/DROP DATABASE`，`--test-threads=1`）；详见 `docs/reference/testing/README.md`。

---

## 代码入口

- 路由入口：`api/src/routes.rs`
- 服务启动：`api/src/main.rs`
- 业务处理：`api/src/handlers/`
- 数据库访问：`api/src/database/`
- WebSocket：`api/src/websocket/`

更多文档：

- `docs/reference/api/`
- `docs/reference/guides/`
- `docs/reference/operations/`
