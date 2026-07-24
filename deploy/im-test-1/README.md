# im-test-1 Docker Compose 部署

这套 profile 用于给 `im-test-1` 准备单机测试环境。

包含服务：

- PostgreSQL
- Redis
- API

不包含：

- NATS
- external-mock
- reverse proxy

当前 API 运行时仍然使用 Redis Pub/Sub 做跨连接 fanout，所以这里先保持最小栈。

## 文件说明

- `docker-compose.yml`：单机部署 compose
- `Caddyfile`：`im-test-1.codelib.cc` 的反向代理配置
- `.env.example`：环境变量模板
- `load-api-image.sh`：从 GitHub Release 产物加载并重打 API Docker 镜像标签

## 前置条件

- Docker Engine
- Docker Compose 插件（`docker compose`）
- 已安装 Caddy
- 一个名为 `redcode-im-api-linux-x86_64.docker.tar.gz` 的正式版 API 镜像产物
- `im-test-1.codelib.cc` 已解析到该服务器公网 IP

## 首次部署

1. 把这套部署目录放到服务器上，或者直接在服务器上拉取仓库。
2. 进入目录：

   ```bash
   cd deploy/im-test-1
   ```

3. 生成环境文件：

   ```bash
   cp .env.example .env
   ```

4. 修改 `.env`。

   首次启动前至少要改这些值：

   - `POSTGRES_PASSWORD`
   - `REDIS_PASSWORD`
   - `JWT_SECRET`
   - `DATA_ENCRYPTION_KEY`

   这些值建议都用 URL-safe 随机串，避免拼接出来的 PostgreSQL / Redis 连接串失效。

5. 从目标正式版 Release 下载 API Docker 镜像产物。

6. 加载并重打镜像标签：

   ```bash
   ./load-api-image.sh /path/to/redcode-im-api-linux-x86_64.docker.tar.gz
   ```

   如果你想在服务器上改成本地自定义标签：

   ```bash
   API_IMAGE_TARGET=redcode-im-api:test-20260724 ./load-api-image.sh /path/to/redcode-im-api-linux-x86_64.docker.tar.gz
   ```

   如果用了自定义标签，记得把 `.env` 里的 `API_IMAGE` 一并改成同一个值。

7. 安装 Caddy 站点配置：

   ```bash
   cp Caddyfile /etc/caddy/Caddyfile
   caddy validate --config /etc/caddy/Caddyfile
   systemctl restart caddy
   ```

8. 启动整套服务：

   ```bash
   docker compose up -d
   ```

9. 验证：

   ```bash
    docker compose ps
    docker compose logs -f api
    curl http://127.0.0.1:8010/healthz
    curl https://im-test-1.codelib.cc/healthz
   ```

## 升级

1. 下载新的正式版镜像产物。
2. 用 `./load-api-image.sh ...` 加载并覆盖本地标签。
3. 仅重建 API 容器：

   ```bash
   docker compose up -d --force-recreate api
   ```

4. 再次检查 `healthz` 和日志。

## 回滚

1. 保留上一个正式版镜像产物。
2. 用 `./load-api-image.sh ...` 重新加载旧版本。
3. 重建 API 容器：

   ```bash
   docker compose up -d --force-recreate api
   ```

## 说明

- PostgreSQL 和 Redis 都只在容器网络内使用，不暴露宿主机端口。
- API 暴露为 `${API_BIND_IP}:${API_PORT}`，容器内端口固定是 `8010`。
- 当前推荐由 Caddy 对外承接 `80/443`，再反代到 `127.0.0.1:8010`。
- 数据库迁移仍然由 API 启动时自动执行。
- Push provider、对象存储等能力不在这套基础 profile 里；后面测试范围真的需要时再补。
