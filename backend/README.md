# RedCode IM Backend（Rust）

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

在 `backend/` 目录下复制示例配置：

```bash
cp .env.example .env
```

按需修改 `.env` 中的 `DATABASE_URL`、`REDIS_SESSION_URL`、`REDIS_PUBSUB_URL`、`REDIS_CACHE_URL`、`JWT_SECRET` 等配置。

### 3) 启动服务

```bash
docker compose -f docker/dev/docker-compose.yml up -d backend
```

默认端口为 `8010`，健康检查：`GET /healthz`

查看日志：

```bash
docker compose -f docker/dev/docker-compose.yml logs -f backend
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

在 `backend/` 目录下执行以下命令。开发调试默认使用 dev Compose：

```bash
docker compose -f docker/dev/docker-compose.yml up -d backend
```

本地 release 构建验证使用 release Compose：

```bash
docker compose -f docker/release/docker-compose.yml up -d --build backend
```

---

## 环境变量

示例配置见：`backend/.env.example`。

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

服务启动时会自动执行 `Database::migrate`，按顺序执行 `backend/src/database/mod.rs` 中声明的迁移脚本。

数据库迁移与基线说明请查看：`backend/sql/README.md`。

---

## 运行测试

运行统一回归（推荐，从仓库根目录执行）：

```bash
make tests.run
```

仅运行 backend 模块测试：

```bash
make backend.test
make backend.test.smoke
```

如果需要直接调用底层 contract 入口：

```bash
./tests/run.sh
./tests/run.sh go
```

运行数据库集成测试（需要 PostgreSQL 可用，并配置 `DATABASE_URL_TEST` 或 `DATABASE_URL`）：

```bash
docker compose -f ../tests/docker-compose.yml run --rm rust-tests \
  cargo test --test database_store_tests -- --test-threads=1
```

---

## 代码入口

- 路由入口：`backend/src/routes.rs`
- 服务启动：`backend/src/main.rs`
- 业务处理：`backend/src/handlers/`
- 数据库访问：`backend/src/database/`
- WebSocket：`backend/src/websocket/`

更多文档：

- `docs/reference/api/`
- `docs/reference/guides/`
- `docs/reference/operations/`
