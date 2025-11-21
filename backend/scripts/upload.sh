#!/usr/bin/env bash
set -euo pipefail

DEFAULT_BIN="target/x86_64-unknown-linux-musl/release/redcode-im-backend"
TARGET_DIR="/home/ubuntu/backend"
HOSTS=("xin-im-prod-0" "xin-im-prod-1")

BIN_PATH="${1:-$DEFAULT_BIN}"

if [ ! -f "$BIN_PATH" ]; then
  echo "未找到二进制文件: $BIN_PATH" >&2
  echo "请先执行 cross build --release --target x86_64-unknown-linux-musl 或指定完整路径" >&2
  exit 1
fi

for host in "${HOSTS[@]}"; do
  echo "正在上传 $BIN_PATH -> $host:$TARGET_DIR"
  scp "$BIN_PATH" "$host:$TARGET_DIR"
  echo "已完成上传至 $host"
  echo "------------------------------"
  sleep 1
fi

echo "全部主机上传完成"
