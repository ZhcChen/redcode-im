#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROTO_DIR="$ROOT_DIR/api/proto"
PROTO_FILE="$PROTO_DIR/ws.proto"
OUT_DIR="$ROOT_DIR/frontend/lib/proto"

if ! command -v protoc >/dev/null 2>&1; then
  echo "protoc not found; please install protoc first"
  exit 1
fi

if ! command -v protoc-gen-dart >/dev/null 2>&1; then
  echo "protoc-gen-dart not found; run: dart pub global activate protoc_plugin"
  exit 1
fi

mkdir -p "$OUT_DIR"

protoc \
  --plugin=protoc-gen-dart="$(command -v protoc-gen-dart)" \
  --dart_out="$OUT_DIR" \
  -I "$PROTO_DIR" \
  "$PROTO_FILE"

echo "Generated Dart protos into: $OUT_DIR"
