#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/tests/docker-compose.yml"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[tests] 缺少命令: $1" >&2
    exit 1
  fi
}

require_cmd docker-compose

export COMPOSE_BAKE=false

if [[ -z "${COMPOSE_PROJECT_NAME:-}" ]]; then
  export COMPOSE_PROJECT_NAME="redcode_im_tests_$(date +%s)"
fi

KEEP_STACK="${KEEP_STACK:-0}"

cleanup() {
  if [[ "${KEEP_STACK}" == "1" ]]; then
    echo "[tests] KEEP_STACK=1，跳过 docker-compose down" >&2
    return
  fi
  docker-compose -f "${COMPOSE_FILE}" down -v --remove-orphans >/dev/null 2>&1 || true
}

trap cleanup EXIT

echo "[tests] project=${COMPOSE_PROJECT_NAME}" >&2

echo "[tests] 启动测试依赖（External Mock / PostgreSQL / Redis）..." >&2
docker-compose -f "${COMPOSE_FILE}" up -d --build external-mock postgres redis-session redis-cache >/dev/null

echo "[tests] 运行 Rust 单元测试（cargo test --lib）..." >&2
docker-compose -f "${COMPOSE_FILE}" run --rm rust-tests cargo test --lib

echo "[tests] 运行 Rust 集成测试（cargo test --tests）..." >&2
docker-compose -f "${COMPOSE_FILE}" run --rm rust-tests cargo test --tests -- --test-threads=1

echo "[tests] 启动 Backend（供 Go 黑盒测试）..." >&2
docker-compose -f "${COMPOSE_FILE}" up -d backend >/dev/null

for i in {1..120}; do
  if docker-compose -f "${COMPOSE_FILE}" exec -T backend curl -fsS http://localhost:8010/healthz >/dev/null 2>&1; then
    break
  fi
  if [[ $i -eq 120 ]]; then
    echo "[tests] Backend 健康检查超时" >&2
    docker-compose -f "${COMPOSE_FILE}" logs --tail=200 backend >&2 || true
    exit 1
  fi
  sleep 1
done

echo "[tests] 运行 Go 黑盒契约测试（go test ./...）..." >&2
docker-compose -f "${COMPOSE_FILE}" run --rm go-tests

echo "[tests] ✅ 完成" >&2
