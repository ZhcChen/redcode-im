# 本地开发环境 Dockerfile - 源码运行
# Context: api/

FROM rust:alpine

WORKDIR /app

# 安装构建与运行依赖（开发模式需要编译）
RUN apk add --no-cache \
    build-base \
    musl-dev \
    pkgconfig \
    openssl-dev \
    openssl-libs-static \
    postgresql-dev \
    protobuf-dev \
    tzdata \
    curl \
    git \
    rustfmt

# rust:alpine 的 cargo-fmt 默认指向 rustup；Alpine rustfmt 包提供 /usr/bin/cargo-fmt。
RUN ln -sf /usr/bin/cargo-fmt /usr/local/cargo/bin/cargo-fmt

# 默认将编译产物放在容器卷里，避免污染宿主机
ENV CARGO_TARGET_DIR=/app/target
