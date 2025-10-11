# 使用官方Rust镜像作为构建环境
FROM rust:1.75-alpine as builder

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apk add --no-cache \
    musl-dev \
    pkgconfig \
    openssl-dev \
    postgresql-dev

# 复制Cargo文件
COPY Cargo.toml Cargo.lock ./

# 创建虚拟源文件以缓存依赖
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# 复制源代码
COPY . .

# 构建应用
RUN cargo build --release

# 运行时镜像
FROM alpine:latest

# 安装运行时依赖
RUN apk add --no-cache \
    openssl \
    postgresql-client

# 创建应用用户
RUN addgroup -g 1000 app && \
    adduser -D -s /bin/sh -u 1000 -G app app

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/target/release/redcode-im-backend .

# 更改所有者
RUN chown -R app:app /app

# 切换到应用用户
USER app

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/healthz || exit 1

# 启动应用
CMD ["./redcode-im-backend"]