# 本地 release Dockerfile - 多阶段构建
# Context: api/

# ============ 构建阶段 ============
FROM rust:1.94.0-alpine3.21@sha256:2ff5a7235f7b13b05b8a23c3c92737ad7adea11bf68ab5116b0e52991410c721 AS builder

WORKDIR /app

# 安装构建依赖
RUN apk add --no-cache \
    musl-dev \
    pkgconfig \
    openssl-dev \
    openssl-libs-static \
    postgresql-dev \
    protobuf-dev

# 复制 Cargo 文件以缓存依赖
COPY Cargo.toml Cargo.lock ./

# 创建虚拟 src 以预编译依赖
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release --locked 2>/dev/null || true && \
    rm -rf src

# 复制构建所需文件
COPY build.rs ./
COPY .sqlx ./.sqlx
COPY proto ./proto
COPY sql ./sql
COPY src ./src

# 设置 SQLx 离线模式
ENV SQLX_OFFLINE=true

# 构建
RUN cargo build --release --locked

# ============ 运行阶段 ============
FROM alpine:3.21@sha256:48b0309ca019d89d40f670aa1bc06e426dc0931948452e8491e3d65087abc07d

WORKDIR /app

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    openssl \
    libpq \
    tzdata \
    curl

# 从构建阶段复制二进制
COPY --from=builder /app/target/release/redcode-im-api ./redcode-im-api

# 创建非 root 用户
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app && \
    chown -R app:app /app

USER app

EXPOSE 8010

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8010/healthz || exit 1

CMD ["./redcode-im-api"]
