# 后端开发与构建命令说明

本文档整理了 Rust 后端在本地开发、测试及生产构建阶段常用的命令，便于快速查阅。若无特殊说明，均在仓库根目录（`backend/`）执行。

## 1. 本地开发流程

1. **准备环境变量**
   ```bash
   cp .env.example .env
   # 按需修改数据库、Redis 等连接字符串
   ```
2. **启动依赖服务（可选）**：如果未使用外部 PostgreSQL/Redis，可直接复用仓库内的 Compose 服务。
   ```bash
   docker compose up -d postgres redis-session redis-cache
   ```
3. **（首次部署）初始化数据库结构**
   > 仅在**首次在新环境使用 RedCode IM** 且目标数据库为空库时需要执行，后续重复启动无需再次执行。
   - 确保目标数据库为空或确认可以覆盖现有结构；
   - 推荐做法：直接启动 backend，由 `Database::migrate` 自动执行 `backend/sql/base.sql` 并记录迁移；
   - 如需手工执行，也可以在项目根目录（包含 `backend/`、`backend/sql/base.sql`）下执行：
     ```bash
     # PostgreSQL 运行在 Docker 容器中
     docker exec -i postgres psql -U postgres -d redcode_im < backend/sql/base.sql
     
     # PostgreSQL 直接运行在本地
     psql -h localhost -U postgres -d redcode_im < backend/sql/base.sql
     ```
   - 该步骤会一次性创建所有业务表、管理后台相关表及初始数据，后续结构演进通过 `backend/sql/migrations/` 下的增量脚本 + `db_migrations` 表管理。
4. **运行后端**：带上调试日志可以更快定位问题。
   ```bash
   RUST_LOG=debug cargo run
   ```
   - `cargo run` 会自动执行数据库迁移并启动 HTTP 服务。
   - 默认监听 `0.0.0.0:8010`，可通过 `PORT` 环境变量覆盖。

> 提示：若需要与 Docker 中的依赖保持一致，也可以直接运行 `docker compose up backend`，仓库根目录的 Compose 会启动 PostgreSQL/Redis 及后端容器，内部同样执行 `cargo run` 并挂载本地源码。

## 2. 本地测试

修改代码后需及时回归测试：
```bash
cargo test
```
常用扩展：
- `cargo test http::`：只运行与 `http` 模块相关的测试。
- `RUST_LOG=info cargo test websocket -- --nocapture`：在测试时输出日志。

## 3. 生产环境构建

### 3.1 构建发布二进制

#### 方案 A：直接使用 `cargo build --release`
```bash
cargo build --release
```
> 生成的二进制位于 `target/release/redcode-im-backend`，架构与当前主机一致（例如 Mac mini M4 会生成 `aarch64-apple-darwin` 可执行文件）。该方案适合在同架构的 macOS/Linux 环境调试使用；若部署目标是 x86_64 Linux，需要改用方案 B 交叉编译对应架构。

#### 方案 B：使用 Docker 镜像交叉编译（推荐生成 Linux/musl 二进制）

在执行交叉编译前，请确保 PostgreSQL/Redis 服务已在宿主机监听（可通过 `docker compose up -d postgres redis-session redis-cache` 启动默认依赖）。
```bash
docker run --rm \
  --add-host=host.docker.internal:host-gateway \
  -v "$(cd .. && pwd)":/work \
  -w /work/backend \
  -e DATABASE_URL=postgresql://postgres:123456@host.docker.internal:5432/redcode_im \
  messense/rust-musl-cross:x86_64-musl \
  bash -c 'set -euo pipefail; \
           apt-get update && apt-get install -y --no-install-recommends pkg-config curl ca-certificates build-essential perl && \
           OPENSSL_VERSION=3.3.1 && \
           cd /tmp && \
           curl -fsSLO https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
           tar xf openssl-${OPENSSL_VERSION}.tar.gz && \
           cd openssl-${OPENSSL_VERSION} && \
           CC=x86_64-unknown-linux-musl-gcc ./Configure linux-x86_64 no-shared --prefix=/usr/local/musl --openssldir=/usr/local/musl --libdir=/usr/local/musl/lib && \
           make -j$(nproc) && make install_sw && \
           cd /work/backend && \
           OPENSSL_DIR=/usr/local/musl \
           OPENSSL_LIB_DIR=/usr/local/musl/lib \
           OPENSSL_INCLUDE_DIR=/usr/local/musl/include \
           PKG_CONFIG_ALLOW_CROSS=1 \
           PKG_CONFIG_PATH=/usr/local/musl/lib/pkgconfig \
           cargo build --release --target x86_64-unknown-linux-musl'
```
> 单条命令即完成 OpenSSL 编译与交叉构建（首次运行约需 3~5 分钟下载、编译 OpenSSL 3.3.1），产物位于 `target/x86_64-unknown-linux-musl/release/redcode-im-backend`，可直接部署到 Linux/x86 或打包到 Docker。`--add-host=host.docker.internal:host-gateway` 让 Linux 主机也能解析 `host.docker.internal`，以便容器访问宿主机上的 PostgreSQL。若使用自定义数据库地址，请将 `-e DATABASE_URL=...` 替换为实际连接串。
```bash
DATABASE_URL=... \
REDIS_SESSION_URL=... \
REDIS_CACHE_URL=... \
JWT_SECRET=... \
PORT=8010 \
./target/x86_64-unknown-linux-musl/release/redcode-im-backend
```

#### 方案 C：使用 Zig + cargo-zigbuild（macOS 直接产出 Linux/musl 二进制）

Zig 自带完整的 musl toolchain，可在本机无需 Docker 的情况下交叉编译。准备步骤：
1. 安装 Zig（例如 `brew install zig`）
2. 安装 `cargo-zigbuild`：`cargo install cargo-zigbuild --locked`
3. 准备 SQLx 所需的数据库：保持 `DATABASE_URL` 可访问，或提前执行 `cargo sqlx prepare` 并设置 `SQLX_OFFLINE=1`

完成依赖后执行脚本：
```bash
# 可改为 aarch64-unknown-linux-musl / dev 等组合
TARGET=x86_64-unknown-linux-musl \
PROFILE=release \
scripts/build-linux-zig.sh
```
> 脚本会自动导入 `.env`、校验 `zig`/`cargo-zigbuild` 是否就绪，并执行 `cargo zigbuild --target $TARGET --release`。构建产物位于 `target/$TARGET/$PROFILE/redcode-im-backend`。

相较方案 B，该方案无需重复编译 OpenSSL，也可以通过 `TARGET`/`PROFILE` 环境变量一次产出多种架构。若希望与服务器一致，保持默认的 `x86_64-unknown-linux-musl` 即可。

### 3.2 以 Docker 方式构建
1. **准备发布产物**（推荐使用方案 B 的 Docker 命令）：
   ```bash
   docker run --rm \
     --add-host=host.docker.internal:host-gateway \
     -v "$(cd .. && pwd)":/work \
     -w /work/backend \
     -e DATABASE_URL=postgresql://postgres:123456@host.docker.internal:5432/redcode_im \
     messense/rust-musl-cross:x86_64-musl \
     bash -c 'set -euo pipefail; \
              apt-get update && apt-get install -y --no-install-recommends pkg-config curl ca-certificates build-essential perl && \
              OPENSSL_VERSION=3.3.1 && \
              cd /tmp && \
              curl -fsSLO https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
              tar xf openssl-${OPENSSL_VERSION}.tar.gz && \
              cd openssl-${OPENSSL_VERSION} && \
             CC=x86_64-unknown-linux-musl-gcc ./Configure linux-x86_64 no-shared --prefix=/usr/local/musl --openssldir=/usr/local/musl --libdir=/usr/local/musl/lib && \
             make -j$(nproc) && make install_sw && \
             cd /work/backend && \
             OPENSSL_DIR=/usr/local/musl \
             OPENSSL_LIB_DIR=/usr/local/musl/lib \
             OPENSSL_INCLUDE_DIR=/usr/local/musl/include \
             PKG_CONFIG_ALLOW_CROSS=1 \
             PKG_CONFIG_PATH=/usr/local/musl/lib/pkgconfig \
             cargo build --release --target x86_64-unknown-linux-musl'
   cp target/x86_64-unknown-linux-musl/release/redcode-im-backend docker/
   cp .env docker/
   ```
   > 若仅在本机调试，可直接使用方案 A 生成的 `target/release/redcode-im-backend`，但部署到 Linux/x86 时需使用方案 B。
2. **构建精简运行镜像**：`docker/Dockerfile` 仅复制上述二进制与 `.env`，不包含数据库或其他依赖。
   ```bash
   docker build -f docker/Dockerfile -t redcode-im/backend:latest docker
   ```
   > 运行 `docker compose -f docker/docker-compose.yaml build` 也会调用同一 Dockerfile。
3. **运行后端容器**：`docker/docker-compose.yaml` 只管理单个 backend 服务，适合在已有数据库/Redis 的环境中直接部署二进制。
   ```bash
   docker compose -f docker/docker-compose.yaml up -d
   # 停止服务
   docker compose -f docker/docker-compose.yaml down
   ```
   > 运行前请在 `docker/` 目录下准备 `log/` 文件夹，Compose 会将容器内 `/app/log` 映射到本地便于排查。
4. **多服务生产编排**：若需要一并管理 PostgreSQL/Redis，可继续复用根目录下的 `docker-compose.prod.yml`。
5. **更新镜像**：覆盖 `docker/` 目录中的二进制与 `.env`，重新执行第 2~3 步即可。

## 4. 运维排查常用命令

- 查看运行日志：`tail -f log/app.log`
- 健康探针：`curl -f http://localhost:8010/healthz`
- 重启 systemd 服务：`sudo systemctl restart redcode-im`

如需更多部署细节，参见《[生产环境配置指南](./deployment-env.md)》与《Docker 部署指南》。
