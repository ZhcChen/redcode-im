FROM rust:1.91-slim

ENV PATH="/usr/local/cargo/bin:${PATH}"

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    pkg-config \
    libssl-dev \
  && rm -rf /var/lib/apt/lists/*

# 覆盖率工具链（可选，但建议在测试容器内内置，避免每次手工安装）
RUN rustup component add llvm-tools-preview \
  && cargo install cargo-llvm-cov

WORKDIR /workspace/backend
