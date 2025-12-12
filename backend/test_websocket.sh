#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v node >/dev/null 2>&1; then
  echo "需要 node 执行 WebSocket 测试（未找到 node）"
  exit 1
fi

# 依赖：backend/package.json 已声明 ws/axios
node "$SCRIPT_DIR/test_websocket.js" "$@"

