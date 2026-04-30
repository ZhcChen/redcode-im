# Docker 部署指南

本文档基于仓库当前实际文件结构整理 Docker Compose 用法。仓库内统一使用 `docker compose` 命令。

## Compose 文件一览

- Backend 开发调试：`backend/docker/dev/docker-compose.yml`
- Backend 发布构建验证：`backend/docker/release/docker-compose.yml`
- 测试隔离栈：`tests/docker-compose.yml`
- Website 部署：`website/docker/docker-compose.yml`
- Admin Nginx 部署：`admin/nginx/docker-compose.yml`

## Backend 开发调试（dev）

在仓库根目录执行：

```bash
# 启动开发栈（会同时拉起 PostgreSQL / Redis / backend）
docker compose -f backend/docker/dev/docker-compose.yml up -d backend

# 查看日志
docker compose -f backend/docker/dev/docker-compose.yml logs -f backend

# 重启 backend
docker compose -f backend/docker/dev/docker-compose.yml restart backend

# 停止并清理
docker compose -f backend/docker/dev/docker-compose.yml down -v
```

说明：
- 仅 backend 暴露宿主机端口 `8010`
- PostgreSQL / Redis 仅在容器网络内使用，不映射宿主机端口
- backend 容器内执行 `cargo run --bin redcode-im-backend`

## Backend 发布构建验证（release）

在仓库根目录执行：

```bash
# 构建并启动 release 验证栈
docker compose -f backend/docker/release/docker-compose.yml up -d --build backend

# 查看日志
docker compose -f backend/docker/release/docker-compose.yml logs -f backend

# 查看状态
docker compose -f backend/docker/release/docker-compose.yml ps

# 停止并清理
docker compose -f backend/docker/release/docker-compose.yml down -v
```

说明：
- release 栈用于验证镜像内构建与二进制运行结果
- backend 仍映射 `8010:8010`
- PostgreSQL / Redis 不映射宿主机端口

## 测试隔离栈

推荐入口：

```bash
./tests/run.sh
```

如需手动控制：

```bash
docker compose -f tests/docker-compose.yml up -d --build external-mock postgres redis backend
docker compose -f tests/docker-compose.yml run --rm go-tests
docker compose -f tests/docker-compose.yml down -v --remove-orphans
```

说明：
- 测试栈不要复用 dev / release 栈
- 测试栈只启动一个 Redis；backend 的 session / pubsub / cache 三个逻辑入口都指向该 Redis
- 测试栈包含 `external-mock`，用于模拟 B2/S3 兼容对象存储 / FCM / IPInfo 等外部依赖

## Website 与 Admin 独立 Compose

Website：

```bash
docker compose -f website/docker/docker-compose.yml up -d --build
docker compose -f website/docker/docker-compose.yml logs -f website
```

Admin Nginx：

```bash
docker compose -f admin/nginx/docker-compose.yml up -d
docker compose -f admin/nginx/docker-compose.yml logs -f
```

## 常用排查命令

```bash
# 查看 backend dev 栈日志
docker compose -f backend/docker/dev/docker-compose.yml logs -f backend

# 查看 backend release 栈状态
docker compose -f backend/docker/release/docker-compose.yml ps

# 进入测试栈 backend 容器
docker compose -f tests/docker-compose.yml exec backend sh
```

## 注意事项

- `docker compose` 为统一命令，不再使用 `docker-compose`
- 若端口 `8010` 被占用，必须先释放占用进程，再启动对应栈
- 数据库迁移由 backend 启动时自动执行，不在 PostgreSQL 容器挂载 init SQL
