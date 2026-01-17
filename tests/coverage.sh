#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/tests/docker-compose.yml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[coverage] 缺少命令: $1" >&2
    exit 1
  fi
}

require_cmd docker-compose

# 当前环境缺少 buildx 时，Compose 的 Bake 构建会失败；这里强制使用内部构建器。
export COMPOSE_BAKE=false

if [[ -z "${COMPOSE_PROJECT_NAME:-}" ]]; then
  export COMPOSE_PROJECT_NAME="redcode_im_cov_$(date +%s)"
fi

KEEP_STACK="${KEEP_STACK:-0}"
FORMAT="${FORMAT:-html}" # html | lcov | all
CLEAN="${CLEAN:-1}"      # 1=先清理 llvm-cov 产物，避免 "mismatched data" 警告

cleanup() {
  if [[ "${KEEP_STACK}" == "1" ]]; then
    echo "[coverage] KEEP_STACK=1，跳过 docker-compose down" >&2
    return
  fi
  docker-compose -f "${COMPOSE_FILE}" down -v --remove-orphans >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "[coverage] project=${COMPOSE_PROJECT_NAME}" >&2

echo "[coverage] 启动测试依赖（PG/Redis）..." >&2
docker-compose -f "${COMPOSE_FILE}" up -d --build postgres redis-session redis-cache >/dev/null

echo "[coverage] 生成 Backend（Rust）覆盖率：FORMAT=${FORMAT}" >&2

if [[ "${CLEAN}" == "1" ]]; then
  echo "[coverage] 清理旧的 llvm-cov 产物（避免 profraw 与二进制不匹配）..." >&2
  docker-compose -f "${COMPOSE_FILE}" run --rm rust-tests \
    cargo llvm-cov clean --workspace
fi

case "${FORMAT}" in
  html)
    docker-compose -f "${COMPOSE_FILE}" run --rm rust-tests \
      cargo llvm-cov --lib --tests --html --output-dir coverage
    echo "[coverage] 输出: backend/coverage/html/index.html" >&2
    ;;
  lcov)
    docker-compose -f "${COMPOSE_FILE}" run --rm rust-tests \
      cargo llvm-cov --lib --tests --lcov --output-path coverage/lcov.info
    echo "[coverage] 输出: backend/coverage/lcov.info" >&2
    ;;
  all)
    docker-compose -f "${COMPOSE_FILE}" run --rm rust-tests \
      cargo llvm-cov --lib --tests --html --output-dir coverage
    docker-compose -f "${COMPOSE_FILE}" run --rm rust-tests \
      cargo llvm-cov --lib --tests --lcov --output-path coverage/lcov.info
    echo "[coverage] 输出: backend/coverage/html/index.html" >&2
    echo "[coverage] 输出: backend/coverage/lcov.info" >&2
    ;;
  *)
    echo "[coverage] 不支持的 FORMAT=${FORMAT}（可选: html | lcov | all）" >&2
    exit 1
    ;;
esac

echo "[coverage] ✅ 完成" >&2
