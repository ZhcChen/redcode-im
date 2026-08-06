#!/usr/bin/env bash
set -euo pipefail
umask 077

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
remote="${H5_RELEASE_REMOTE:-im-test-1}"
run_id="${H5_SECURE_STATE_RUN_ID:-h5audit$(date -u +%Y%m%d%H%M%S)}"
remote_deploy="${H5_SECURE_STATE_REMOTE_DEPLOY:-/tmp/redcode-h5-secure-state-audit-$run_id}"
remote_env="${H5_SECURE_STATE_REMOTE_ENV:-/srv/redcode-im/deploy/im-test-1/.env}"
api_image="${E2EE_DRILL_API_IMAGE:-}"
candidate_api="https://im-test-admin-1.codelib.cc/h5-candidate-api"
candidate_ws="wss://im-test-admin-1.codelib.cc/h5-candidate-api/ws"
candidate_base="/h5-candidate/"
control="$remote_deploy/e2ee-restore-control.sh"
cleanup_started=0
remote_dir_created=0
child_pid=""
source_schema_before=""
source_gate_before=""

log() {
  printf '[h5-secure-state-audit] %s\n' "$*" >&2
}

die() {
  log "失败：$*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

remote_control() {
  ssh "$remote" "E2EE_RESTORE_RUN_ID='$run_id' \
E2EE_DRILL_API_IMAGE='$api_image' \
E2EE_RESTORE_ENV_FILE='$remote_env' \
E2EE_RESTORE_COMPOSE_FILE='$remote_deploy/docker-compose.e2ee-restore.yml' \
E2EE_RESTORE_SOURCE_COMPOSE_FILE='/srv/redcode-im/deploy/im-test-1/docker-compose.yml' \
E2EE_RESTORE_SNAPSHOT_FILE='$remote_deploy/e2ee-restore-snapshot.sql' \
E2EE_RESTORE_STATE_ROOT='$remote_deploy/state' \
'$control' '$1'"
}

source_schema_digest() {
  ssh "$remote" "set -a; . '$remote_env'; set +a; \
docker compose --env-file '$remote_env' -f /srv/redcode-im/deploy/im-test-1/docker-compose.yml \
exec -T postgres pg_dump -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" --schema-only --no-owner --no-privileges" |
    shasum -a 256 | awk '{print $1}'
}

source_gate_table() {
  ssh "$remote" "set -a; . '$remote_env'; set +a; \
docker compose --env-file '$remote_env' -f /srv/redcode-im/deploy/im-test-1/docker-compose.yml \
exec -T postgres psql -X -qAt -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" \
-c \"SELECT COALESCE(to_regclass('public.e2ee_runtime_gate')::text, 'absent')\""
}

cleanup() {
  local exit_code="${1:-$?}" cleanup_ok=0 attempt
  trap - EXIT INT TERM
  if [[ "$child_pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$child_pid" 2>/dev/null; then
    kill -TERM "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
  child_pid=""
  if [[ "$cleanup_started" == 1 ]]; then
    for attempt in 1 2 3; do
      if remote_control cleanup >/dev/null 2>&1; then
        cleanup_ok=1
        break
      fi
      sleep 1
    done
    if [[ "$cleanup_ok" == 0 ]]; then
      log "远端 cleanup 失败，保留 $remote_deploy 供幂等恢复"
      exit_code=1
    elif ssh "$remote" "! curl --connect-timeout 1 --max-time 2 -fsS http://127.0.0.1:18010/healthz >/dev/null 2>&1"; then
      :
    else
      log "远端 18010 在 cleanup 后仍可访问"
      exit_code=1
    fi
  fi
  if [[ "$remote_dir_created" == 1 && ( "$cleanup_started" == 0 || "$cleanup_ok" == 1 ) ]]; then
    ssh "$remote" "rm -rf '$remote_deploy'" >/dev/null 2>&1 || exit_code=1
  fi
  exit "$exit_code"
}

for command in awk bun jq make scp shasum ssh; do require_command "$command"; done
[[ "$remote" =~ ^([A-Za-z0-9._][A-Za-z0-9._-]*@)?[A-Za-z0-9._][A-Za-z0-9._-]*$ ]] ||
  die "H5_RELEASE_REMOTE 不安全"
[[ "$run_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || die "run id 不安全"
[[ -n "$api_image" && "$api_image" =~ ^[A-Za-z0-9._:/-]+$ ]] ||
  die "必须提供安全的 E2EE_DRILL_API_IMAGE"
[[ "$remote_deploy" == /* && "$remote_deploy" =~ ^/[A-Za-z0-9._/-]+$ ]] ||
  die "H5_SECURE_STATE_REMOTE_DEPLOY 不安全"
[[ "$remote_env" == /* && "$remote_env" =~ ^/[A-Za-z0-9._/-]+$ ]] ||
  die "H5_SECURE_STATE_REMOTE_ENV 不安全"

jq -e --arg api "$candidate_api" --arg ws "$candidate_ws" --arg base "$candidate_base" '
  .endpoints.api_base_url == $api and .endpoints.ws_url == $ws and .base_path == $base
' "$root_dir/h5-app/dist/release-manifest.json" >/dev/null ||
  die "release candidate 未绑定隔离审计同源端点"

source_schema_before="$(source_schema_digest)"
source_gate_before="$(source_gate_table)"
[[ "$source_schema_before" =~ ^[a-f0-9]{64}$ && "$source_gate_before" == absent ]] ||
  die "旧主 schema/审批表基线不符合冻结合同"

trap 'cleanup $?' EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM
ssh "$remote" "test ! -e '$remote_deploy' && install -d -m 0700 '$remote_deploy'"
remote_dir_created=1
scp -q \
  "$root_dir/deploy/im-test-1/docker-compose.e2ee-restore.yml" \
  "$root_dir/deploy/im-test-1/e2ee-restore-control.sh" \
  "$root_dir/deploy/im-test-1/e2ee-restore-snapshot.sql" \
  "$remote:$remote_deploy/"
ssh "$remote" "chmod 0700 '$control'"
cleanup_started=1
ssh "$remote" "E2EE_RESTORE_ALLOW_EMPTY_PREPARE=yes \
E2EE_RESTORE_RUN_ID='$run_id' \
E2EE_DRILL_API_IMAGE='$api_image' \
E2EE_RESTORE_ENV_FILE='$remote_env' \
E2EE_RESTORE_COMPOSE_FILE='$remote_deploy/docker-compose.e2ee-restore.yml' \
E2EE_RESTORE_SOURCE_COMPOSE_FILE='/srv/redcode-im/deploy/im-test-1/docker-compose.yml' \
E2EE_RESTORE_SNAPSHOT_FILE='$remote_deploy/e2ee-restore-snapshot.sql' \
E2EE_RESTORE_STATE_ROOT='$remote_deploy/state' \
'$control' prepare-empty" >/dev/null
remote_control verify >/dev/null

H5_RELEASE_CANDIDATE_URL="https://im-test-admin-1.codelib.cc/h5-candidate/" \
  "$root_dir/scripts/h5-release-candidate-window.sh" &
child_pid=$!
if wait "$child_pid"; then
  child_status=0
else
  child_status=$?
fi
child_pid=""
[[ "$child_status" == 0 ]] || exit "$child_status"
remote_control verify >/dev/null
source_schema_after="$(source_schema_digest)"
source_gate_after="$(source_gate_table)"
[[ "$source_schema_after" == "$source_schema_before" && "$source_gate_after" == "$source_gate_before" ]] ||
  die "旧主 schema 或审批表在审计窗口发生变化"
log "production secure state Chrome 审计通过"
