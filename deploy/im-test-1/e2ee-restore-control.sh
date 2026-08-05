#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="${E2EE_RESTORE_COMPOSE_FILE:-$script_dir/docker-compose.e2ee-restore.yml}"
source_compose_file="${E2EE_RESTORE_SOURCE_COMPOSE_FILE:-$script_dir/docker-compose.yml}"
env_file="${E2EE_RESTORE_ENV_FILE:-$script_dir/.env}"
snapshot_file="${E2EE_RESTORE_SNAPSHOT_FILE:-$script_dir/e2ee-restore-snapshot.sql}"
mode="${1:-verify}"
run_id="${E2EE_RESTORE_RUN_ID:-}"
state_root="${E2EE_RESTORE_STATE_ROOT:-$script_dir/.e2ee-restore}"
api_port="${E2EE_RESTORE_API_PORT:-18010}"
api_url="http://127.0.0.1:$api_port"
command_timeout="${E2EE_RESTORE_COMMAND_TIMEOUT:-180}"

log() {
  printf '[e2ee-restore] %s\n' "$*" >&2
}

die() {
  log "失败：$*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

run_with_timeout() {
  local command_pid started_at status
  "$@" <&0 &
  command_pid=$!
  started_at=$SECONDS
  while kill -0 "$command_pid" 2>/dev/null; do
    if ((SECONDS - started_at >= command_timeout)); then
      kill -TERM "$command_pid" 2>/dev/null || true
      sleep 1
      kill -KILL "$command_pid" 2>/dev/null || true
      wait "$command_pid" 2>/dev/null || true
      return 124
    fi
    sleep 0.05
  done
  if wait "$command_pid"; then
    status=0
  else
    status=$?
  fi
  return "$status"
}

[[ "$run_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || {
  log "E2EE_RESTORE_RUN_ID 必须是 1..64 位安全标识"
  exit 64
}
[[ "$api_port" =~ ^[1-9][0-9]{0,4}$ ]] && ((api_port <= 65535)) || {
  log "E2EE_RESTORE_API_PORT 无效"
  exit 64
}
[[ "$command_timeout" =~ ^[1-9][0-9]{0,2}$ ]] && ((command_timeout <= 900)) || {
  log "E2EE_RESTORE_COMMAND_TIMEOUT 必须是 1..900 的整数"
  exit 64
}
[[ "$state_root" == /* && "$state_root" =~ ^/[A-Za-z0-9._/-]+$ ]] || {
  log "E2EE_RESTORE_STATE_ROOT 必须是安全绝对路径"
  exit 64
}
[[ -f "$compose_file" && -f "$source_compose_file" && -f "$env_file" && -f "$snapshot_file" ]] ||
  die "缺少 restore/source Compose、snapshot SQL 或部署 .env"

state_dir="$state_root/$run_id"
state_file="$state_dir/control.env"
project="e2ee-restore-${run_id//[._]/-}"
marker="redcode-e2ee-restore:$run_id"
restore_database="redcode_e2ee_restore"
restore_user="e2ee_restore"
restore_password=""
restore_redis_password=""

load_deploy_env() {
  set -a
  # shellcheck disable=SC1090
  . "$env_file"
  set +a
}

read_state_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "$state_file"
}

load_state() {
  [[ -f "$state_file" ]] || die "恢复状态不存在：$state_file"
  restore_password="$(read_state_value E2EE_RESTORE_PASSWORD)"
  restore_redis_password="$(read_state_value E2EE_RESTORE_REDIS_PASSWORD)"
  [[ "$restore_password" =~ ^[0-9a-f]{48}$ && "$restore_redis_password" =~ ^[0-9a-f]{48}$ ]] ||
    die "恢复状态格式损坏"
}

compose_restore() {
  E2EE_RESTORE_PROJECT_NAME="$project" \
  E2EE_RESTORE_DATABASE="$restore_database" \
  E2EE_RESTORE_USER="$restore_user" \
  E2EE_RESTORE_PASSWORD="$restore_password" \
  E2EE_RESTORE_REDIS_PASSWORD="$restore_redis_password" \
  E2EE_RESTORE_API_PORT="$api_port" \
    run_with_timeout docker compose --env-file "$env_file" -p "$project" -f "$compose_file" "$@"
}

compose_source() {
  run_with_timeout docker compose --env-file "$env_file" -f "$source_compose_file" "$@"
}

restore_psql() {
  compose_restore exec -T postgres-restore \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$restore_user" -d "$restore_database" <<SQL
$1
SQL
}

snapshot() {
  local value
  value="$(restore_psql "$(cat "$snapshot_file")")"
  jq -e '.digest | type == "string" and length == 32' <<<"$value" >/dev/null ||
    die "restore snapshot 输出无效"
  jq -S . <<<"$value"
}

restore_postgres_ready() {
  compose_restore exec -T postgres-restore \
    pg_isready -U "$restore_user" -d "$restore_database" >/dev/null 2>&1
}

wait_for_restore_postgres() {
  local attempt
  for attempt in $(seq 1 90); do
    restore_postgres_ready && return
    sleep 1
  done
  return 1
}

wait_for_health() {
  local attempt
  for attempt in $(seq 1 90); do
    if [[ "$(curl --connect-timeout 2 --max-time 5 -fsS "$api_url/healthz" 2>/dev/null || true)" == ok ]]; then
      return
    fi
    sleep 1
  done
  return 1
}

verify() {
  local service container_id api_env database_marker runtime api_source_ip
  local source_pg_connections source_redis_connections
  for service in postgres-restore redis-restore api-restore; do
    container_id="$(compose_restore ps -q --status running "$service")"
    [[ -n "$container_id" ]] || die "$service 未运行"
    [[ "$(run_with_timeout docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$container_id")" == "$project" ]] ||
      die "$service 不属于预期 Compose project"
  done

  container_id="$(compose_restore ps -q api-restore)"
  api_env="$(run_with_timeout docker inspect -f '{{json .Config.Env}}' "$container_id")"
  jq -e '
    any(.[]; startswith("DATABASE_URL=") and contains("@postgres-restore:5432/redcode_e2ee_restore")) and
    any(.[]; startswith("REDIS_SESSION_URL=") and contains("@redis-restore:6379/0")) and
    any(.[]; startswith("REDIS_PUBSUB_URL=") and contains("@redis-restore:6379/0")) and
    any(.[]; startswith("REDIS_CACHE_URL=") and contains("@redis-restore:6379/0")) and
    (all(.[] | select(startswith("DATABASE_URL=")); contains("@postgres:5432/") | not))
  ' <<<"$api_env" >/dev/null || die "restore API 的 DB/Redis 身份不符合隔离合同"

  api_source_ip="$(run_with_timeout docker inspect -f \
    '{{with index .NetworkSettings.Networks "im-test-1-network"}}{{.IPAddress}}{{end}}' "$container_id")"
  [[ "$api_source_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "无法读取 restore API 共享网络 IP"
  source_pg_connections="$(compose_source exec -T postgres psql -X -qAt -v ON_ERROR_STOP=1 \
    -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c \
    "SELECT COUNT(*) FROM pg_stat_activity WHERE client_addr = inet '$api_source_ip';")"
  [[ "$source_pg_connections" == "0" ]] || die "restore API 连接到了源 PostgreSQL"
  source_redis_connections="$(compose_source exec -T redis redis-cli -a "$REDIS_PASSWORD" \
    --no-auth-warning CLIENT LIST | awk -v prefix="addr=$api_source_ip:" \
    'index($0, prefix) { count += 1 } END { print count + 0 }')"
  [[ "$source_redis_connections" == "0" ]] || die "restore API 连接到了源 Redis"

  database_marker="$(restore_psql "SELECT shobj_description(oid, 'pg_database') FROM pg_database WHERE datname = current_database();")"
  [[ "$database_marker" == "$marker" ]] || die "恢复数据库 marker 不匹配"
  runtime="$(curl --connect-timeout 5 --max-time 15 -fsS "$api_url/settings/general")"
  jq -e '.message_runtime.server_storage_mode == "persist" and .message_runtime.content_audit_mode == "e2ee"' \
    <<<"$runtime" >/dev/null || die "restore API runtime 不是 persist/e2ee"

  jq -n \
    --arg run_id "$run_id" \
    --arg project "$project" \
    --arg marker "$marker" \
    --arg api_container_id "$container_id" \
    --arg api_url "$api_url" \
    '{run_id: $run_id, project: $project, database_marker: $marker,
      api_container_id: $api_container_id, api_url: $api_url,
      database_host: "postgres-restore", redis_host: "redis-restore",
      source_postgres_connections: 0, source_redis_connections: 0,
      runtime: "persist/e2ee", verified: true}'
}

cleanup() {
  local exit_code="${1:-0}" containers volumes state_valid=1
  trap - EXIT INT TERM
  if [[ -f "$state_file" ]]; then
    load_deploy_env
    restore_password="$(read_state_value E2EE_RESTORE_PASSWORD)"
    restore_redis_password="$(read_state_value E2EE_RESTORE_REDIS_PASSWORD)"
    if [[ ! "$restore_password" =~ ^[0-9a-f]{48}$ || ! "$restore_redis_password" =~ ^[0-9a-f]{48}$ ]]; then
      log "恢复状态格式损坏，将强制清理 Compose project"
      restore_password=invalid-cleanup-placeholder
      restore_redis_password=invalid-cleanup-placeholder
      state_valid=0
      exit_code=1
    fi
    if [[ "$state_valid" == "1" ]] && restore_postgres_ready && ! restore_psql "
        UPDATE general_settings SET value = 'plaintext', updated_at = NOW(), updated_by = NULL
        WHERE key = 'message_content_audit_mode';
        UPDATE e2ee_runtime_gate SET state = 'plaintext', security_review_approved = FALSE,
          updated_at = NOW(), updated_by = NULL WHERE id = 1;
      " >/dev/null; then
      log "restore runtime 回滚失败"
      exit_code=1
    fi
  else
    restore_password=missing-state-cleanup-placeholder
    restore_redis_password=missing-state-cleanup-placeholder
  fi
  compose_restore down --volumes --remove-orphans >/dev/null || exit_code=1
  containers="$(run_with_timeout docker ps -aq --filter "label=com.docker.compose.project=$project")" || {
    log "无法探测 restore container 残留"
    containers=probe-failed
  }
  volumes="$(run_with_timeout docker volume ls -q --filter "label=com.docker.compose.project=$project")" || {
    log "无法探测 restore volume 残留"
    volumes=probe-failed
  }
  if [[ -n "$containers" || -n "$volumes" ]]; then
    log "restore project 仍有 container/volume 残留"
    exit_code=1
  else
    rm -f "$state_file"
    rmdir "$state_dir" 2>/dev/null || true
    log "restore project 已清理"
  fi
  exit "$exit_code"
}

prepare() {
  local dump_path="${E2EE_RESTORE_DUMP_PATH:-}"
  [[ "${E2EE_RESTORE_ALLOW_PREPARE:-}" == yes ]] || die "prepare 需要 E2EE_RESTORE_ALLOW_PREPARE=yes"
  [[ "$dump_path" == /* && -f "$dump_path" && ! -L "$dump_path" ]] || die "E2EE_RESTORE_DUMP_PATH 必须是现有普通文件的绝对路径"
  [[ ! -e "$state_dir" ]] || die "同一 run_id 已存在恢复状态，请先 cleanup"
  mkdir -p "$state_dir"
  restore_password="$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
  restore_redis_password="$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
  printf 'E2EE_RESTORE_PASSWORD=%s\nE2EE_RESTORE_REDIS_PASSWORD=%s\n' \
    "$restore_password" "$restore_redis_password" >"$state_file"

  trap 'cleanup $?' EXIT
  trap 'cleanup 130' INT
  trap 'cleanup 143' TERM
  compose_restore config >/dev/null
  compose_restore up -d postgres-restore redis-restore >/dev/null
  wait_for_restore_postgres || die "restore PostgreSQL 未就绪"
  compose_restore exec -T postgres-restore pg_restore \
    -U "$restore_user" -d "$restore_database" --no-owner --no-privileges <"$dump_path"
  restore_psql "
    COMMENT ON DATABASE $restore_database IS '$marker';
    UPDATE general_settings SET value = 'persist', updated_at = NOW(), updated_by = NULL
      WHERE key = 'message_server_storage_mode';
    UPDATE general_settings SET value = 'e2ee', updated_at = NOW(), updated_by = NULL
      WHERE key = 'message_content_audit_mode';
    UPDATE e2ee_runtime_gate SET state = 'active', security_review_approved = TRUE,
      updated_at = NOW(), updated_by = NULL WHERE id = 1;
  " >/dev/null
  compose_restore up -d api-restore >/dev/null
  wait_for_health || die "restore API healthz 未就绪"
  verify
  trap - EXIT INT TERM
}

for command in curl docker jq od sed sleep; do require_command "$command"; done
load_deploy_env

case "$mode" in
  prepare) prepare ;;
  verify)
    load_state
    verify
    ;;
  snapshot)
    load_state
    snapshot
    ;;
  rollback)
    load_state
    restore_psql "
      UPDATE general_settings SET value = 'plaintext', updated_at = NOW(), updated_by = NULL
      WHERE key = 'message_content_audit_mode';
      UPDATE e2ee_runtime_gate SET state = 'plaintext', security_review_approved = FALSE,
        updated_at = NOW(), updated_by = NULL WHERE id = 1;
    " >/dev/null
    log "restore runtime 已回滚为 persist/plaintext"
    ;;
  cleanup) cleanup 0 ;;
  *)
    log "用法：e2ee-restore-control.sh prepare|verify|snapshot|rollback|cleanup"
    exit 64
    ;;
esac
