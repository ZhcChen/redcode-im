#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-verify}"
run_id="${E2EE_RESTORE_RUN_ID:-}"
api_image="${E2EE_RESTORE_API_IMAGE:-}"
env_file="${E2EE_RESTORE_ENV_FILE:-$script_dir/.env}"
drill_compose="${E2EE_RESTORE_DRILL_COMPOSE_FILE:-$script_dir/docker-compose.e2ee-drill.yml}"
restore_control="${E2EE_RESTORE_CONTROL_PATH:-$script_dir/e2ee-restore-control.sh}"
backup_control="${E2EE_RESTORE_BACKUP_CONTROL_PATH:-$script_dir/e2ee-backup-rollout-drill.sh}"
snapshot_file="${E2EE_RESTORE_SNAPSHOT_FILE:-$script_dir/e2ee-restore-snapshot.sql}"
artifact_root="${E2EE_RESTORE_ARTIFACT_ROOT:-$script_dir/.e2ee-drill}"
artifact_dir="$artifact_root/$run_id"
dump_path="$artifact_dir/database.dump"
owner_dir="$artifact_root/.restore-window-owner"
owner_file="$owner_dir/run-id"
command_timeout="${E2EE_RESTORE_WINDOW_COMMAND_TIMEOUT:-600}"

log() {
  printf '[e2ee-restore-window] %s\n' "$*" >&2
}

die() {
  log "失败：$*"
  exit 1
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
  log "E2EE_RESTORE_RUN_ID 无效"
  exit 64
}
[[ "$api_image" =~ ^[A-Za-z0-9][A-Za-z0-9._/@:-]{0,127}$ ]] || {
  log "E2EE_RESTORE_API_IMAGE 无效"
  exit 64
}
[[ "$command_timeout" =~ ^[1-9][0-9]{0,2}$ ]] && ((command_timeout <= 900)) ||
  die "E2EE_RESTORE_WINDOW_COMMAND_TIMEOUT 必须是 1..900 的整数"
for path in "$env_file" "$drill_compose" "$restore_control" "$backup_control" "$snapshot_file" "$artifact_root"; do
  [[ "$path" == /* && "$path" =~ ^/[A-Za-z0-9._/-]+$ ]] || die "控制路径必须是安全绝对路径：$path"
done
[[ -f "$env_file" && -f "$drill_compose" && -x "$restore_control" && -x "$backup_control" &&
   -f "$snapshot_file" ]] ||
  die "远端部署文件不完整"
mkdir -p "$artifact_root"

set -a
# shellcheck disable=SC1091
. "$env_file"
set +a
export E2EE_DRILL_API_IMAGE="$api_image"

candidate_compose() {
  run_with_timeout docker compose --env-file "$env_file" -f "$drill_compose" "$@"
}

current_owner() {
  [[ -f "$owner_file" ]] && cat "$owner_file" || true
}

acquire_owner() {
  local owner
  if mkdir "$owner_dir" 2>/dev/null; then
    printf '%s\n' "$run_id" >"$owner_file"
    return
  fi
  owner="$(current_owner)"
  [[ "$owner" == "$run_id" ]] || die "candidate window 已由其他 run_id 占用：${owner:-unknown}"
}

require_owner() {
  [[ "$(current_owner)" == "$run_id" ]] || die "当前 run_id 不持有 candidate window"
}

candidate_psql() {
  candidate_compose exec -T postgres-drill \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<SQL
$1
SQL
}

candidate_snapshot() {
  local value
  value="$(candidate_psql "$(cat "$snapshot_file")")"
  jq -e '.digest | type == "string" and length == 32' <<<"$value" >/dev/null ||
    die "candidate snapshot 输出无效"
  jq -S . <<<"$value"
}

wait_candidate_health() {
  local attempt
  for attempt in $(seq 1 120); do
    if [[ "$(curl --connect-timeout 2 --max-time 5 -fsS http://127.0.0.1:18010/healthz 2>/dev/null || true)" == ok ]]; then
      return
    fi
    sleep 1
  done
  return 1
}

candidate_runtime() {
  curl --connect-timeout 5 --max-time 15 -fsS http://127.0.0.1:18010/settings/general
}

candidate_set_runtime() {
  local audit="$1" gate_state="$2" approval="$3"
  candidate_psql "
    INSERT INTO general_settings (key, value, description, updated_at, updated_by)
    VALUES
      ('message_server_storage_mode', 'persist', '消息服务器存储模式', NOW(), NULL),
      ('message_content_audit_mode', '$audit', '消息内容审计模式', NOW(), NULL)
    ON CONFLICT (key) DO UPDATE SET
      value = EXCLUDED.value,
      description = EXCLUDED.description,
      updated_at = NOW(),
      updated_by = NULL;
    UPDATE e2ee_runtime_gate SET state = '$gate_state', security_review_approved = $approval,
      updated_at = NOW(), updated_by = NULL WHERE id = 1;
  " >/dev/null
}

recreate_candidate_api() {
  candidate_compose up -d --force-recreate api-drill >/dev/null
  wait_candidate_health || die "candidate API recreate 后未就绪"
}

restore_command() {
  E2EE_RESTORE_RUN_ID="$run_id" E2EE_DRILL_API_IMAGE="$api_image" \
  E2EE_RESTORE_SNAPSHOT_FILE="$snapshot_file" \
    run_with_timeout "$restore_control" "$@"
}

cleanup() {
  local exit_code="${1:-0}" containers monitor_process volumes owner
  owner="$(current_owner)"
  restore_command cleanup >/dev/null || exit_code=1
  if [[ -z "$owner" || "$owner" == "$run_id" ]]; then
    candidate_compose down --volumes --remove-orphans >/dev/null || exit_code=1
    containers="$(run_with_timeout docker ps -aq --filter label=com.docker.compose.project=im-test-1-e2ee-drill)"
    volumes="$(run_with_timeout docker volume ls -q --filter label=com.docker.compose.project=im-test-1-e2ee-drill)"
    if [[ -n "$containers" || -n "$volumes" ]]; then
      log "candidate project 仍有 container/volume 残留"
      exit_code=1
    elif [[ "$owner" == "$run_id" ]]; then
      rm -f "$owner_file"
      rmdir "$owner_dir" 2>/dev/null || exit_code=1
    fi
  else
    log "拒绝清理其他 run_id 持有的 candidate window：$owner"
    exit_code=1
  fi
  monitor_process="$(cat "$artifact_dir/redis-monitor.pid" 2>/dev/null || true)"
  if [[ "$monitor_process" =~ ^[1-9][0-9]*$ ]] && kill -0 "$monitor_process" 2>/dev/null; then
    if ps -p "$monitor_process" -o args= 2>/dev/null | grep -Eq 'docker exec .*redis-cli .*MONITOR'; then
      kill "$monitor_process" 2>/dev/null || true
      for _ in $(seq 1 50); do
        kill -0 "$monitor_process" 2>/dev/null || break
        sleep 0.1
      done
      kill -0 "$monitor_process" 2>/dev/null && exit_code=1
    else
      log "拒绝终止身份不匹配的 MONITOR pid：$monitor_process"
      exit_code=1
    fi
  fi
  rm -rf -- "$artifact_dir"
  log "candidate 与 restore project 已清理"
  return "$exit_code"
}

candidate_prepare() {
  [[ "${E2EE_RESTORE_ALLOW_CANDIDATE:-}" == yes ]] ||
    die "candidate-prepare 需要 E2EE_RESTORE_ALLOW_CANDIDATE=yes"
  acquire_owner
  trap 'cleanup $?' EXIT
  trap 'cleanup 130' INT
  trap 'cleanup 143' TERM
  restore_command cleanup >/dev/null
  candidate_compose down --volumes --remove-orphans >/dev/null
  candidate_compose config >/dev/null
  candidate_compose up -d postgres-drill redis-drill api-drill >/dev/null
  wait_candidate_health || die "candidate API 未就绪"
  candidate_set_runtime e2ee active TRUE
  recreate_candidate_api
  jq -e '.message_runtime.server_storage_mode == "persist" and
    .message_runtime.content_audit_mode == "e2ee"' <<<"$(candidate_runtime)" >/dev/null ||
    die "candidate runtime 未进入 persist/e2ee"
  trap - EXIT INT TERM
  jq -n --arg run_id "$run_id" --arg image "$api_image" \
    '{run_id: $run_id, source: "isolated-candidate", api_image: $image,
      api_url: "http://127.0.0.1:18010", runtime: "persist/e2ee", ready: true}'
}

switch_to_restore() {
  local candidate_snapshot_json restore_identity restore_snapshot_json
  [[ "${E2EE_RESTORE_ALLOW_SWITCH:-}" == yes ]] || die "switch 需要 E2EE_RESTORE_ALLOW_SWITCH=yes"
  require_owner
  trap 'cleanup $?' EXIT
  trap 'cleanup 130' INT
  trap 'cleanup 143' TERM
  candidate_set_runtime plaintext plaintext FALSE
  recreate_candidate_api
  jq -e '.message_runtime.server_storage_mode == "persist" and
    .message_runtime.content_audit_mode == "plaintext"' <<<"$(candidate_runtime)" >/dev/null ||
    die "candidate runtime 未恢复 plaintext"
  candidate_snapshot_json="$(candidate_snapshot)"
  E2EE_DRILL_RUN_ID="$run_id" \
  E2EE_DRILL_ARTIFACT_DIR="$artifact_dir" \
  E2EE_DRILL_REPORT_PATH="$artifact_dir/report.json" \
  E2EE_DRILL_COMPOSE_FILE="$drill_compose" \
  E2EE_DRILL_ALLOW_API_STOP=yes \
  E2EE_DRILL_KEEP_ARTIFACTS=yes \
    run_with_timeout "$backup_control" backup-restore >/dev/null
  [[ -s "$dump_path" ]] || die "candidate dump 未生成"
  candidate_compose stop api-drill >/dev/null
  restore_identity="$(E2EE_RESTORE_ALLOW_PREPARE=yes E2EE_RESTORE_DUMP_PATH="$dump_path" \
    restore_command prepare)"
  restore_snapshot_json="$(restore_command snapshot)"
  [[ "$(jq -S . <<<"$candidate_snapshot_json")" == "$(jq -S . <<<"$restore_snapshot_json")" ]] ||
    die "candidate 与 restore snapshot 不一致"
  trap - EXIT INT TERM
  jq -n --argjson identity "$restore_identity" \
    --argjson candidate_snapshot "$candidate_snapshot_json" \
    --argjson restore_snapshot "$restore_snapshot_json" \
    '{identity: $identity, candidate_snapshot: $candidate_snapshot,
      restore_snapshot: $restore_snapshot, snapshots_match: true}'
}

case "$mode" in
  candidate-prepare) candidate_prepare ;;
  switch) switch_to_restore ;;
  verify)
    require_owner
    restore_command verify
    ;;
  snapshot)
    require_owner
    restore_command snapshot
    ;;
  cleanup) cleanup ;;
  *)
    log "用法：e2ee-restore-window-control.sh candidate-prepare|switch|verify|snapshot|cleanup"
    exit 64
    ;;
esac
