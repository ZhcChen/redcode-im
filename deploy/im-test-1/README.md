# im-test-1 Docker Compose 部署

这套 profile 用于给 `im-test-1` 准备单机测试环境。

包含服务：

- PostgreSQL
- Redis
- RustFS（S3 兼容对象存储）
- API
- Admin

不包含：

- NATS
- external-mock

当前 API 运行时仍然使用 Redis Pub/Sub 做跨连接 fanout，所以这里先保持最小栈。

## 文件说明

- `docker-compose.yml`：单机部署 compose
- `Caddyfile`：`im-test-1.codelib.cc` / `im-test-admin-1.codelib.cc` 的反向代理配置
- `.env.example`：环境变量模板
- `load-api-image.sh`：从 GitHub Release 产物加载并重打 API Docker 镜像标签
- `load-admin-image.sh`：加载并重打 Admin Docker 镜像标签
- `load-rustfs-image.sh`：加载并重打 RustFS Docker 镜像标签
- `e2ee-backup-rollout-drill.sh`：E2EE 备份恢复、独立实例校验与灰度回滚演练
- `docker-compose.e2ee-drill.yml`：不接触主库的 E2EE 候选演练栈

## 前置条件

- Docker Engine
- Docker Compose 插件（`docker compose`）
- 已安装 Caddy
- 一个名为 `redcode-im-api-linux-x86_64.docker.tar.gz` 的正式版 API 镜像产物
- 一个本地构建并导出的 Admin Docker 镜像产物（例如 `redcode-im-admin-im-test-1.docker.tar.gz`）
- 一个本地导出的 RustFS Docker 镜像产物（例如 `rustfs-rustfs-1.0.0-beta.11.docker.tar.gz`）
- `im-test-1.codelib.cc` 已解析到该服务器公网 IP
- `im-test-admin-1.codelib.cc` 已解析到该服务器公网 IP

> 截至 2026-07-24，在 `im-test-1` 服务器上实测 `docker pull rustfs/rustfs:1.0.0-beta.11` 会开始下载，但无法稳定完成落盘，因此这里默认按离线加载 RustFS 镜像设计。

如果目标服务器是 `x86_64`，本地构建 Admin 镜像时要显式指定：

```bash
docker buildx build \
  --platform linux/amd64 \
  --build-arg VITE_API_BASE_URL=https://im-test-1.codelib.cc \
  --tag redcode-im-admin:im-test-1 \
  --load \
  -f admin/nginx/Dockerfile \
  admin
```

`VITE_API_BASE_URL` 现在是必填参数；如果漏传，Docker 构建会直接失败，避免把测试 Admin 误连到其他环境。

构建完成后，再把镜像导出成部署脚本可直接加载的归档：

```bash
docker save redcode-im-admin:im-test-1 | gzip -c > redcode-im-admin-im-test-1.docker.tar.gz
```

本地准备 RustFS 镜像时，建议固定到已验证版本：

```bash
docker pull rustfs/rustfs:1.0.0-beta.11
docker save rustfs/rustfs:1.0.0-beta.11 | gzip -c > rustfs-rustfs-1.0.0-beta.11.docker.tar.gz
```

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
   - `RUSTFS_ACCESS_KEY`
   - `RUSTFS_SECRET_KEY`
   - `JWT_SECRET`
   - `DATA_ENCRYPTION_KEY`

   另外，`RUSTFS_INTERNAL_ENDPOINT` 应保持为容器网络内的 `rustfs:9000`。
   不要把它改成 `im-test-1.codelib.cc` 这类经由 Caddy 的公网域名，否则 API 服务端生成 / 校验 S3
   签名时会把对象存储流量绕回反向代理，导致附件上传、审核和下载链路异常。

   这些值建议都用 URL-safe 随机串，避免拼接出来的 PostgreSQL / Redis 连接串失效。
   `RUSTFS_ACCESS_KEY` / `RUSTFS_SECRET_KEY` 在卷里已有数据后不要随意更换。

   如果你改了：

   - `API_PUBLIC_HOST`
   - `RUSTFS_PRIVATE_BUCKET`
   - `RUSTFS_PUBLIC_BUCKET`

   记得同步修改 `Caddyfile` 里的站点域名和 bucket 路径前缀。
   如果你还改了 compose 里给 `rustfs` / `admin` 预留的固定桥接 IP，也要同步改 `Caddyfile`。

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

8. 把本地导出的 Admin 镜像归档上传到服务器。

9. 加载 Admin 镜像：

   ```bash
   ./load-admin-image.sh /path/to/redcode-im-admin-im-test-1.docker.tar.gz
   ```

   如果你想在服务器上改成本地自定义标签：

   ```bash
   ADMIN_IMAGE_TARGET=redcode-im-admin:test-20260724 ./load-admin-image.sh /path/to/redcode-im-admin-im-test-1.docker.tar.gz
   ```

   如果用了自定义标签，记得把 `.env` 里的 `ADMIN_IMAGE` 一并改成同一个值。

10. 把本地导出的 RustFS 镜像归档上传到服务器。

11. 加载 RustFS 镜像：

   ```bash
   ./load-rustfs-image.sh /path/to/rustfs-rustfs-1.0.0-beta.11.docker.tar.gz
   ```

   如果你想在服务器上改成本地自定义标签：

   ```bash
   RUSTFS_IMAGE_TARGET=rustfs/rustfs:im-test-1 ./load-rustfs-image.sh /path/to/rustfs-rustfs-1.0.0-beta.11.docker.tar.gz
   ```

   如果用了自定义标签，记得把 `.env` 里的 `RUSTFS_IMAGE` 一并改成同一个值。

12. 启动整套服务：

   ```bash
   docker compose up -d
   ```

13. 验证：

   ```bash
    docker compose ps
    docker compose logs -f api
    docker compose logs -f admin
    docker compose logs -f rustfs
    curl http://127.0.0.1:8010/healthz
    curl https://im-test-1.codelib.cc/healthz
    curl -I https://im-test-admin-1.codelib.cc
    curl -I https://im-test-1.codelib.cc/redcode-im-private
   ```

## 升级

1. 下载新的正式版 API 镜像产物，或重新构建并导出新的 Admin / RustFS 镜像产物。
2. 对照新的 `.env.example` 检查 `.env` 是否缺少新增变量；如果你的老环境文件里还没有 `API_PUBLIC_HOST`、`RUSTFS_*` 或 `ADMIN_IMAGE`，请先补齐。
3. 先做一次配置体检：

   ```bash
   docker compose --env-file .env config >/tmp/im-test-1-compose.check
   ```

4. 用 `./load-api-image.sh ...` / `./load-admin-image.sh ...` / `./load-rustfs-image.sh ...` 加载并覆盖本地标签。
5. 按需重建对应容器：

   ```bash
   docker compose up -d --force-recreate api
   docker compose up -d --force-recreate admin
   ```

   如果这次还改了 `RUSTFS_*` 或 RustFS 镜像版本，再额外执行：

   ```bash
   docker compose up -d --force-recreate rustfs
   docker compose up -d rustfs-init
   ```

6. 再次检查 `healthz`、Admin 首页和日志。

## 回滚

1. 保留上一个 API / Admin / RustFS 镜像产物。
2. 用 `./load-api-image.sh ...` / `./load-admin-image.sh ...` / `./load-rustfs-image.sh ...` 重新加载旧版本。
3. 重建对应容器：

   ```bash
   docker compose up -d --force-recreate api
   docker compose up -d --force-recreate admin
   ```

## E2EE 备份恢复与灰度演练

正式演练优先使用独立候选栈，而不是直接升级或清空现有测试主库。候选栈使用独立
PostgreSQL/Redis volume 和本机 `127.0.0.1:18010` API 端口，只复用现有 RustFS
容器网络：

```bash
E2EE_DRILL_API_IMAGE='redcode-im-api:<commit>' \
  docker compose --env-file .env -f docker-compose.e2ee-drill.yml up -d --wait
```

运行驱动时指定候选服务名：

```bash
export E2EE_DRILL_COMPOSE_FILE="$PWD/docker-compose.e2ee-drill.yml"
export E2EE_DRILL_POSTGRES_SERVICE=postgres-drill
export E2EE_DRILL_API_SERVICE=api-drill
export E2EE_DRILL_API_BASE_URL=http://127.0.0.1:18010
```

先执行只读 preflight；部署版本过旧、关键表缺失、runtime 非
`persist/plaintext` 或数据引用异常时会 fail closed：

```bash
./e2ee-backup-rollout-drill.sh preflight
```

备份恢复会短暂停止 API 写入，将 custom-format dump 恢复到临时独立
PostgreSQL 17 容器，比较源库/恢复库的计数、密文摘要、门禁和引用完整性，并验证
损坏归档会被拒绝：

```bash
E2EE_DRILL_ALLOW_API_STOP=yes \
  ./e2ee-backup-rollout-drill.sh backup-restore
```

完整演练还会通过 Admin API 执行 `prepare -> active`，在 active 状态重建 API
容器，再执行 `rollback`。该模式必须同时提供临时 Admin token 和两项显式确认：

```bash
E2EE_DRILL_ALLOW_API_STOP=yes \
E2EE_DRILL_ALLOW_ACTIVE=yes \
E2EE_DRILL_ADMIN_TOKEN='<temporary-token>' \
  ./e2ee-backup-rollout-drill.sh full
```

脚本默认删除数据库 dump 和临时恢复卷，只保留 `.e2ee-drill/<run-id>/report.json`；
报告不包含 token、密码、私钥、DEK、nonce 或消息正文。只有在受控环境需要人工
复核归档时才设置 `E2EE_DRILL_KEEP_ARTIFACTS=yes`。无论成功、失败或收到信号，
脚本都会尝试恢复 runtime、门禁审批值、API 和临时容器。

演练证据导出后销毁候选栈及其独立数据卷：

```bash
E2EE_DRILL_API_IMAGE='redcode-im-api:<commit>' \
  docker compose --env-file .env -f docker-compose.e2ee-drill.yml down -v
```

## 说明

- PostgreSQL 和 Redis 都只在容器网络内使用，不暴露宿主机端口。
- RustFS 也只在容器网络内使用，不映射宿主机端口。
- API 暴露为 `${API_BIND_IP}:${API_PORT}`，容器内端口固定是 `8010`。
- Admin 不映射宿主机端口，由宿主机 Caddy 直接反代到容器桥接网段固定 IP。
- API 服务端访问 RustFS 时固定走 `${RUSTFS_INTERNAL_ENDPOINT}`（默认 `rustfs:9000`）；
  仅返回给客户端的 presigned URL 会被改写成 `https://${API_PUBLIC_HOST}`。
- 当前推荐由宿主机 Caddy 对外承接 `80/443`：
  - `im-test-1.codelib.cc` -> `127.0.0.1:8010`（API）
  - `im-test-1.codelib.cc/{bucket}/...` -> `172.29.240.12:9000`（RustFS）
  - `im-test-admin-1.codelib.cc` -> `172.29.240.13:80`（Admin）
- 数据库迁移仍然由 API 启动时自动执行。
- RustFS bucket 会由 `rustfs-init` 一次性初始化；如果两个 bucket 同名，则只会创建一次。
- 目前管理端“对象存储配置探测 / authorize_account”逻辑仍然面向 Backblaze B2。测试环境已直接走 S3 兼容读写链路，因此不要用该探测结果判断 RustFS 是否可用。
