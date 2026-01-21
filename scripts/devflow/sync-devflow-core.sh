#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVFLOW_CORE_DIR_DEFAULT="/Users/chen/code/devflow-core"

DEVFLOW_CORE_DIR="${DEVFLOW_CORE_DIR:-$DEVFLOW_CORE_DIR_DEFAULT}"
DELETE_FLAG=""
DRY_RUN_FLAG=""

usage() {
  cat <<'USAGE'
Usage:
  scripts/devflow/sync-devflow-core.sh [--core /path/to/devflow-core] [--delete] [--dry-run]

Options:
  --core     指定 devflow-core 路径（默认 /Users/chen/code/devflow-core）
  --delete   同步时删除目标中多余文件（谨慎使用）
  --dry-run  仅打印将要变更的文件

环境变量:
  DEVFLOW_CORE_DIR  devflow-core 路径（优先级高于默认值）
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --core)
      DEVFLOW_CORE_DIR="$2"
      shift 2
      ;;
    --delete)
      DELETE_FLAG="--delete"
      shift
      ;;
    --dry-run)
      DRY_RUN_FLAG="--dry-run"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "未知参数: $1" >&2
      usage
      exit 2
      ;;
  esac
 done

if [[ ! -d "$DEVFLOW_CORE_DIR" ]]; then
  echo "devflow-core 不存在: $DEVFLOW_CORE_DIR" >&2
  exit 1
fi

DOCS_SRC="$DEVFLOW_CORE_DIR/docs"
SKILLS_SRC="$DEVFLOW_CORE_DIR/skills"

if [[ ! -d "$DOCS_SRC" || ! -d "$SKILLS_SRC" ]]; then
  echo "devflow-core 目录结构异常: $DEVFLOW_CORE_DIR" >&2
  exit 1
fi

sync_docs_dir() {
  local name="$1"
  local src="$DOCS_SRC/$name/"
  local dst="$ROOT_DIR/docs/$name/"
  mkdir -p "$dst"
  rsync -a $DELETE_FLAG $DRY_RUN_FLAG \
    --exclude '*.env' \
    --exclude 'PRD-*.md' \
    --exclude 'SPEC-*.md' \
    --exclude 'DEV-*.md' \
    --exclude 'REVIEW-*.md' \
    --exclude 'TEST-*.md' \
    "$src" "$dst"
}

sync_docs_dir workflow
sync_docs_dir templates
sync_docs_dir conventions
sync_docs_dir requirements
sync_docs_dir development
sync_docs_dir reviews
sync_docs_dir tests
sync_docs_dir backlog
sync_docs_dir specs

mkdir -p "$ROOT_DIR/skills"
rsync -a $DELETE_FLAG $DRY_RUN_FLAG \
  --exclude '.env' \
  "$SKILLS_SRC/" "$ROOT_DIR/skills/"

echo "devflow-core 同步完成: $DEVFLOW_CORE_DIR"
