#!/usr/bin/env bash
set -euo pipefail

TARGET="${TARGET:-x86_64-unknown-linux-musl}"
PROFILE="${PROFILE:-release}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "缺少依赖命令: $1" >&2
    exit 1
  fi
}

need_cmd zig
need_cmd rustup
need_cmd cargo

if ! cargo zigbuild --help >/dev/null 2>&1; then
  echo "未检测到 cargo-zigbuild，请先执行 'cargo install cargo-zigbuild'" >&2
  exit 1
fi

# 导入 .env，便于 SQLx 在编译期读取 DATABASE_URL
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

if [ -z "${SQLX_OFFLINE:-}" ] && [ -z "${DATABASE_URL:-}" ]; then
  echo "SQLx 需要 DATABASE_URL 或 SQLX_OFFLINE=1，请先配置环境变量" >&2
  exit 1
fi

if ! rustup target list --installed | grep -q "^${TARGET}$"; then
  rustup target add "$TARGET"
fi

echo "使用 Zig 交叉编译 -> ${TARGET} (${PROFILE})"
if [ "$PROFILE" = "release" ]; then
  cargo zigbuild --release --target "$TARGET"
else
  cargo zigbuild --target "$TARGET" --profile "$PROFILE"
fi

echo "构建完成: target/${TARGET}/${PROFILE}/redcode-im-backend"
