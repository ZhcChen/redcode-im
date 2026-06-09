# Docker 部署指南

本文档基于仓库当前实际文件结构整理 Docker Compose 用法。仓库内统一使用 `docker compose` 命令。

## Compose 文件一览

- API 开发调试：`api/docker/dev/docker-compose.yml`
- API 发布构建验证：`api/docker/release/docker-compose.yml`
- 测试隔离栈：`tests/docker-compose.test.yml`
- Website 部署：`website/docker/docker-compose.yml`
- Admin Nginx 部署：`admin/nginx/docker-compose.yml`

## API 开发调试（dev）

在仓库根目录执行：

```bash
# 启动开发栈（会同时拉起 PostgreSQL / Redis / api）
docker compose -f api/docker/dev/docker-compose.yml up -d api

# 查看日志
docker compose -f api/docker/dev/docker-compose.yml logs -f api

# 重启 api
docker compose -f api/docker/dev/docker-compose.yml restart api

# 停止并清理
docker compose -f api/docker/dev/docker-compose.yml down -v
```

说明：
- 仅 api 暴露宿主机端口 `8010`
- PostgreSQL / Redis 仅在容器网络内使用，不映射宿主机端口
- api 容器内执行 `cargo run --bin redcode-im-api`

## API 发布构建验证（release）

在仓库根目录执行：

```bash
# 构建并启动 release 验证栈
docker compose -f api/docker/release/docker-compose.yml up -d --build api

# 查看日志
docker compose -f api/docker/release/docker-compose.yml logs -f api

# 查看状态
docker compose -f api/docker/release/docker-compose.yml ps

# 停止并清理
docker compose -f api/docker/release/docker-compose.yml down -v
```

说明：
- release 栈用于验证镜像内构建与二进制运行结果
- api 仍映射 `8010:8010`
- PostgreSQL / Redis 不映射宿主机端口

## 测试隔离栈

推荐入口：

```bash
make api.test
```

如需手动控制：

```bash
docker compose -f tests/docker-compose.test.yml up -d --wait postgres redis external-mock
docker compose -f tests/docker-compose.test.yml down -v --remove-orphans
```

说明：
- 测试栈不要复用 dev / release 栈
- 测试栈只启动一个 Redis；api 的 session / pubsub / cache 三个逻辑入口都指向该 Redis
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
# 查看 api dev 栈日志
docker compose -f api/docker/dev/docker-compose.yml logs -f api

# 查看 api release 栈状态
docker compose -f api/docker/release/docker-compose.yml ps

# 进入测试栈 api 容器
docker compose -f tests/docker-compose.test.yml exec api sh
```

## 注意事项

- `docker compose` 为统一命令，不再使用 `docker-compose`
- 若端口 `8010` 被占用，必须先释放占用进程，再启动对应栈
- 数据库迁移由 api 启动时自动执行，不在 PostgreSQL 容器挂载 init SQL
