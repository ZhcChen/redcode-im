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

usage() {
  cat <<'USAGE'
用法：
  ./tests/run.sh [mode]

说明：
  tests/ 目录只负责 backend contract 测试栈：
  - Rust backend 单元 / 集成测试
  - Go 黑盒契约测试
  - external-mock / postgres / redis 测试依赖

模式：
  all               默认。运行 rust-lib + rust-integration + go-contract
  rust              运行 rust-lib + rust-integration
  rust-lib          仅运行 cargo test --lib
  rust-integration  仅运行 cargo test --tests -- --test-threads=1
  go                仅运行 go test ./... -v -p 1（自动拉起 backend 与依赖）
  help              显示帮助

环境变量：
  KEEP_STACK=1      保留测试栈，不自动 down
  BACKEND_HEALTH_TIMEOUT=420
                   backend 健康检查超时时间（秒）
USAGE
}

MODE="${1:-all}"
shift || true

case "${MODE}" in
  help|-h|--help)
    if [[ $# -ne 0 ]]; then
      echo "[tests] mode=help 不接受额外参数" >&2
      usage
      exit 1
    fi
    usage
    exit 0
    ;;
  all|rust|rust-lib|rust-integration|go)
    ;;
  *)
    echo "[tests] 未知 mode: ${MODE}" >&2
    usage
    exit 1
    ;;
esac

require_cmd docker

if ! docker compose version >/dev/null 2>&1; then
  echo "[tests] 缺少 Docker Compose 插件，请使用支持 docker compose 的 Docker 版本" >&2
  exit 1
fi

dc() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

export COMPOSE_BAKE=false

if [[ -z "${COMPOSE_PROJECT_NAME:-}" ]]; then
  export COMPOSE_PROJECT_NAME="redcode_im_tests_$(date +%s)"
fi

KEEP_STACK="${KEEP_STACK:-0}"
BACKEND_HEALTH_TIMEOUT="${BACKEND_HEALTH_TIMEOUT:-420}"

cleanup() {
  if [[ "${KEEP_STACK}" == "1" ]]; then
    echo "[tests] KEEP_STACK=1，跳过 docker compose down" >&2
    return
  fi
  dc down -v --remove-orphans >/dev/null 2>&1 || true
}

trap cleanup EXIT

start_deps() {
  echo "[tests] project=${COMPOSE_PROJECT_NAME}" >&2
  echo "[tests] 启动 backend contract 依赖（external-mock / postgres / redis）..." >&2
  dc up -d --build external-mock postgres redis-session redis-cache >/dev/null
}

run_rust_lib() {
  echo "[tests] 运行 backend Rust 单元测试（cargo test --lib）..." >&2
  dc run --rm rust-tests cargo test --lib
}

run_rust_integration() {
  echo "[tests] 运行 backend Rust 集成测试（cargo test --tests）..." >&2
  dc run --rm rust-tests cargo test --tests -- --test-threads=1
}

wait_backend() {
  local deadline=$((SECONDS + BACKEND_HEALTH_TIMEOUT))
  while (( SECONDS < deadline )); do
    local container_id=""
    local health_status=""

    container_id="$(dc ps -q backend 2>/dev/null || true)"
    if [[ -n "${container_id}" ]]; then
      health_status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${container_id}" 2>/dev/null || true)"
    fi

    if [[ "${health_status}" == "healthy" ]]; then
      return 0
    fi

    sleep 1
  done

  echo "[tests] backend 健康检查超时（>${BACKEND_HEALTH_TIMEOUT}s）" >&2
  dc logs --tail=200 backend >&2 || true
  exit 1
}

start_backend() {
  echo "[tests] 启动 backend（供 Go 黑盒契约测试）..." >&2
  dc up -d backend >/dev/null
  wait_backend
}

run_go_contract() {
  echo "[tests] 运行 Go 黑盒契约测试（go test ./... -v -p 1）..." >&2
  dc run --rm go-tests
}

case "${MODE}" in
  all)
    if [[ $# -ne 0 ]]; then
      echo "[tests] mode=all 不接受额外参数" >&2
      usage
      exit 1
    fi
    start_deps
    run_rust_lib
    run_rust_integration
    start_backend
    run_go_contract
    ;;
  rust)
    if [[ $# -ne 0 ]]; then
      echo "[tests] mode=rust 不接受额外参数" >&2
      usage
      exit 1
    fi
    start_deps
    run_rust_lib
    run_rust_integration
    ;;
  rust-lib)
    if [[ $# -ne 0 ]]; then
      echo "[tests] mode=rust-lib 暂不接受额外参数" >&2
      usage
      exit 1
    fi
    start_deps
    run_rust_lib
    ;;
  rust-integration)
    if [[ $# -ne 0 ]]; then
      echo "[tests] mode=rust-integration 暂不接受额外参数" >&2
      usage
      exit 1
    fi
    start_deps
    run_rust_integration
    ;;
  go)
    if [[ $# -ne 0 ]]; then
      echo "[tests] mode=go 暂不接受额外参数" >&2
      usage
      exit 1
    fi
    start_deps
    start_backend
    run_go_contract
    ;;
esac

echo "[tests] ✅ 完成 (${MODE})" >&2
