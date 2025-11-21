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
3. **运行后端**：带上调试日志可以更快定位问题。
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
> macOS 开发机需先安装 musl 交叉编译器，并手动构建一次 Linux 版 OpenSSL，示例：
> ```bash
> brew tap messense/macos-cross-toolchains
> brew install x86_64-unknown-linux-musl
> rustup target add x86_64-unknown-linux-musl
> 
> # 构建 Linux/musl 版 OpenSSL 并安装到 ~/.musl-openssl
> TMPDIR="$(mktemp -d)"
> curl -L https://www.openssl.org/source/openssl-3.3.1.tar.gz -o "$TMPDIR/openssl.tar.gz"
> tar -xf "$TMPDIR/openssl.tar.gz" -C "$TMPDIR"
> cd "$TMPDIR/openssl-3.3.1"
> CC="x86_64-unknown-linux-musl-gcc" \
>   ./Configure linux-x86_64 no-shared --prefix="$HOME/.musl-openssl" --openssldir="$HOME/.musl-openssl"
> make -j"$(sysctl -n hw.ncpu)"
> make install
> ```
> 构建时可在命令前临时注入 OpenSSL/编译器变量，避免污染全局环境：
> ```bash
> OPENSSL_DIR="$HOME/.musl-openssl" \
> OPENSSL_LIB_DIR="$OPENSSL_DIR/lib" \
> OPENSSL_INCLUDE_DIR="$OPENSSL_DIR/include" \
> PKG_CONFIG_ALLOW_CROSS=1 \
> PKG_CONFIG_PATH="$OPENSSL_LIB_DIR/pkgconfig" \
> CC_x86_64_unknown_linux_musl=x86_64-unknown-linux-musl-gcc \
> cargo build --release --target x86_64-unknown-linux-musl
> ```
输出会生成在 `target/x86_64-unknown-linux-musl/release/redcode-im-backend`，部署时只需携带该二进制以及 `.env`/环境变量即可：
```bash
DATABASE_URL=... \
REDIS_SESSION_URL=... \
REDIS_CACHE_URL=... \
JWT_SECRET=... \
PORT=8010 \
./target/x86_64-unknown-linux-musl/release/redcode-im-backend
```

### 3.2 以 Docker 方式构建
1. **准备发布产物**：
   ```bash
   OPENSSL_DIR="$HOME/.musl-openssl" \
   OPENSSL_LIB_DIR="$OPENSSL_DIR/lib" \
   OPENSSL_INCLUDE_DIR="$OPENSSL_DIR/include" \
   PKG_CONFIG_ALLOW_CROSS=1 \
   PKG_CONFIG_PATH="$OPENSSL_LIB_DIR/pkgconfig" \
   CC_x86_64_unknown_linux_musl=x86_64-unknown-linux-musl-gcc \
   cargo build --release --target x86_64-unknown-linux-musl
   cp target/x86_64-unknown-linux-musl/release/redcode-im-backend docker/
   cp .env docker/        # 若不希望把敏感信息打包进镜像，可复制精简版 .env
   ```
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
