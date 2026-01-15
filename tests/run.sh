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

# 当前环境缺少 buildx 时，Compose 的 Bake 构建会失败；这里强制使用内部构建器。
export COMPOSE_BAKE=false

if command -v colima >/dev/null 2>&1; then
  # colima list: PROFILE STATUS ARCH CPUS MEMORY DISK RUNTIME ADDRESS
  mem="$(colima list 2>/dev/null | awk 'NR==2 {print $5}')"
  if [[ "${mem}" =~ ^[0-9]+GiB$ ]]; then
    mem_gib="${mem%GiB}"
    if [[ "${mem_gib}" -lt 6 ]]; then
      echo "[tests] 检测到 colima MEMORY=${mem}，Rust 编译通常会 OOM（建议 >= 6GiB）" >&2
      echo "[tests] 参考：colima stop && colima start --cpu 4 --memory 8" >&2
      exit 1
    fi
  fi
fi

# 每次运行默认使用独立的 project name，避免与其他项目/历史残留栈冲突。
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

wait_for_backend() {
  local tries=90
  while [[ "${tries}" -gt 0 ]]; do
    if docker-compose -f "${COMPOSE_FILE}" exec -T backend curl -fsS http://localhost:8010/healthz >/dev/null 2>&1; then
      return 0
    fi
    tries=$((tries - 1))
    sleep 2
  done

  echo "[tests] Backend 健康检查超时，输出最近日志：" >&2
  docker-compose -f "${COMPOSE_FILE}" logs --tail=200 backend >&2 || true
  return 1
}

echo "[tests] 启动测试依赖（PG/Redis）..." >&2
docker-compose -f "${COMPOSE_FILE}" up -d --build postgres redis-session redis-cache >/dev/null

echo "[tests] 运行 Rust 单元测试（cargo test --lib）..." >&2
# 注意：backend 容器使用 cargo run，会触发编译；如果与其他 cargo 进程并发共享同一 registry volume，
# 会出现 “failed to unpack package ... .cargo-ok File exists” 的竞争问题。
# 因此这里先跑完 Rust 单测，再启动 backend（顺序化 cargo 进程）。
docker-compose -f "${COMPOSE_FILE}" run --rm rust-tests

echo "[tests] 启动 Backend（用于 Go 黑盒/契约测试）..." >&2
docker-compose -f "${COMPOSE_FILE}" up -d backend >/dev/null
wait_for_backend

echo "[tests] 运行 Go 契约/集成测试（go test ./...）..." >&2
docker-compose -f "${COMPOSE_FILE}" run --rm go-tests

echo "[tests] ✅ 完成" >&2
