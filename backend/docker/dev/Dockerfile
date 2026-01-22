# 本地开发环境 Dockerfile - 多阶段构建
# Context: backend/

# ============ 构建阶段 ============
FROM rust:alpine AS builder

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
    cargo build --release 2>/dev/null || true && \
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
RUN cargo build --release

# ============ 运行阶段 ============
FROM alpine:3.21

WORKDIR /app

# 安装运行时依赖
RUN apk add --no-cache \
    ca-certificates \
    openssl \
    libpq \
    tzdata \
    curl

# 从构建阶段复制二进制
COPY --from=builder /app/target/release/redcode-im-backend ./redcode-im-backend

# 创建非 root 用户
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app && \
    chown -R app:app /app

USER app

EXPOSE 8010

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8010/healthz || exit 1

CMD ["./redcode-im-backend"]
