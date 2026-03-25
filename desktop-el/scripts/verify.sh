#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "[desktop-el] go test ./..."
(
  cd "${PROJECT_DIR}/go-core"
  go test ./...
)

echo "[desktop-el] bun test"
(
  cd "${PROJECT_DIR}"
  bun test
)

echo "[desktop-el] bun run build"
(
  cd "${PROJECT_DIR}"
  bun run build
)
