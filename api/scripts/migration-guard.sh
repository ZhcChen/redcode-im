#!/usr/bin/env bash
# additive-only 迁移守护（对标 qfy-sc worker/internal/migrationguard，纯 shell 实现）
#
# 规则：迁移文件 `api/sql/base.sql` 与 `api/sql/migrations/*.sql` 只允许**新增**，
# 禁止修改 / 重命名 / 删除已提交文件。如需调整结构或数据，请新增一份增量迁移。
#
# 基准 ref：
# - 可用 MIGRATION_GUARD_BASE 显式覆盖（CI 建议设为 origin/main，做 PR 全量检查）；
# - 本地 feature 分支默认对比本地 default branch，避免把分支创建前已存在的本地提交误判为本轮改动；
# - 在 default branch 上默认对比 origin/<default>。
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

CURRENT_BRANCH="$(git branch --show-current)"
DEFAULT_BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
if [ -z "$DEFAULT_BRANCH" ]; then
    if git rev-parse --verify --quiet main >/dev/null 2>&1; then
        DEFAULT_BRANCH="main"
    else
        DEFAULT_BRANCH="master"
    fi
fi

if [ -n "${MIGRATION_GUARD_BASE:-}" ]; then
    BASE="$MIGRATION_GUARD_BASE"
elif [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ] && git rev-parse --verify --quiet "$DEFAULT_BRANCH" >/dev/null 2>&1; then
    BASE="$DEFAULT_BRANCH"
else
    BASE="origin/$DEFAULT_BRANCH"
fi
PATHS=("api/sql/base.sql" "api/sql/migrations")

# 基准 ref 不存在时回退：default branch → HEAD
if ! git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
    if git rev-parse --verify --quiet "$DEFAULT_BRANCH" >/dev/null 2>&1; then
        BASE="$DEFAULT_BRANCH"
    else
        BASE="HEAD"
    fi
fi

violations=""
while IFS=$'\t' read -r status p1 p2; do
    [ -z "$status" ] && continue
    case "$status" in
        M*) violations="${violations}\n   - 修改: ${p1}" ;;
        D*) violations="${violations}\n   - 删除: ${p1}" ;;
        R*) violations="${violations}\n   - 重命名: ${p1} -> ${p2}" ;;
        C*) violations="${violations}\n   - 复制: ${p1} -> ${p2}" ;;
        # A（新增）及未跟踪新文件 = 允许
    esac
done < <(git diff --name-status "$BASE" -- "${PATHS[@]}" 2>/dev/null || true)

if [ -n "$violations" ]; then
    echo "❌ 迁移守护失败：迁移文件只允许新增，禁止修改/重命名/删除（基准 ${BASE}）"
    printf '%b\n' "$violations"
    echo "   如需调整结构或数据，请新增一份 api/sql/migrations/YYYYMMDDHHMMSS_desc.sql。"
    exit 1
fi

echo "✅ 迁移守护通过（基准 ${BASE}）：未修改/重命名/删除已提交迁移。"
