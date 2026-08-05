#!/usr/bin/env bash

set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
compose_file="${E2EE_DRILL_COMPOSE_FILE:-$script_dir/docker-compose.e2ee-drill.yml}"
postgres_service="${E2EE_DRILL_POSTGRES_SERVICE:-postgres-drill}"
api_service="${E2EE_DRILL_API_SERVICE:-api-drill}"
api_base_url="${E2EE_DRILL_API_BASE_URL:-http://127.0.0.1:18010}"
mode="${1:-preflight}"
run_id="${E2EE_DRILL_RUN_ID:-g1-$(date -u +%Y%m%dT%H%M%SZ)}"
[[ "$run_id" =~ ^[a-zA-Z0-9._-]+$ ]] || {
  printf '[e2ee-g1] 失败：E2EE_DRILL_RUN_ID 只能包含字母、数字、点、下划线和连字符\n' >&2
  exit 64
}
artifact_dir="${E2EE_DRILL_ARTIFACT_DIR:-$script_dir/.e2ee-drill/$run_id}"
report_path="${E2EE_DRILL_REPORT_PATH:-$artifact_dir/report.json}"
recovery_state_path="${E2EE_DRILL_RECOVERY_STATE_PATH:-$artifact_dir/recovery-state}"
lock_dir="${E2EE_DRILL_LOCK_DIR:-${artifact_dir}.lock}"
restore_container="e2ee-g1-restore-${run_id//[^a-zA-Z0-9_.-]/-}"
restore_volume="${restore_container}-data"
restore_database="redcode_e2ee_restore"
restore_user="e2ee_restore"
restore_password=""
original_security_review_approved=""
dump_path=""
corrupt_path=""
cleanup_hard_timeout="${E2EE_DRILL_CLEANUP_HARD_TIMEOUT:-45}"
curl_connect_timeout="${E2EE_DRILL_CURL_CONNECT_TIMEOUT:-5}"
curl_max_time="${E2EE_DRILL_CURL_MAX_TIME:-15}"
for timeout_value in "$cleanup_hard_timeout" "$curl_connect_timeout" "$curl_max_time"; do
  [[ "$timeout_value" =~ ^[1-9][0-9]*$ ]] && ((timeout_value <= 300)) || {
    printf '[e2ee-g1] 失败：超时参数必须是 1..300 的整数\n' >&2
    exit 64
  }
done

usage() {
  cat <<'EOF'
用法：e2ee-backup-rollout-drill.sh [preflight|backup-restore|full|recover]

模式：
  preflight       只读检查当前部署、migration、关键表和 runtime（默认）
  backup-restore  停止 API 写入，备份并恢复到临时独立 PostgreSQL 实例
  full            完成 backup-restore 后，通过 Admin API 演练 prepare/active/recreate/rollback
  recover         按实际状态恢复 API、审批、runtime 并删除当前 run_id 的临时资源

写操作确认变量：
  E2EE_DRILL_ALLOW_API_STOP=yes   允许 backup-restore/full 短暂停止 API
  E2EE_DRILL_ALLOW_ACTIVE=yes     允许 full 临时进入 active
  E2EE_DRILL_ADMIN_TOKEN=...      full 调用 Admin gate API 的 bearer token

可选：
  E2EE_DRILL_KEEP_ARTIFACTS=yes   保留 dump；默认完成后删除 dump，仅保留 report.json
  E2EE_DRILL_REPORT_PATH=...      指定脱敏 JSON 报告路径
EOF
}

log() {
  printf '[e2ee-g1] %s\n' "$*" >&2
}

die() {
  log "失败：$*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

acquire_run_lock() {
  local owner_pid=""
  mkdir -p "$(dirname "$lock_dir")"
  if mkdir "$lock_dir" 2>/dev/null; then
    printf '%s\n' "$$" >"$lock_dir/pid"
    return
  fi
  [[ -f "$lock_dir/pid" ]] && owner_pid="$(cat "$lock_dir/pid" 2>/dev/null || true)"
  if [[ "$owner_pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$owner_pid" 2>/dev/null; then
    log "同一 run_id 的演练正在运行，pid=$owner_pid"
    return 1
  fi
  rm -f "$lock_dir/pid" || return 1
  rmdir "$lock_dir" || return 1
  mkdir "$lock_dir" || return 1
  printf '%s\n' "$$" >"$lock_dir/pid"
  log "已接管崩溃进程遗留的 run_id 锁"
}

release_run_lock() {
  rm -f "$lock_dir/pid" || return 1
  rmdir "$lock_dir" || return 1
}

run_with_timeout() {
  local seconds="$1" command_pid started_at status
  shift
  "$@" <&0 &
  command_pid=$!
  started_at=$SECONDS
  while kill -0 "$command_pid" 2>/dev/null; do
    if ((SECONDS - started_at >= seconds)); then
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

compose() {
  docker compose -f "$compose_file" "$@"
}

source_psql() {
  compose exec -T "$postgres_service" sh -ec \
    'psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<SQL
$1
SQL
}

restore_psql() {
  docker exec -i "$restore_container" \
    psql -X -qAt -v ON_ERROR_STOP=1 -h 127.0.0.1 \
      -U "$restore_user" -d "$restore_database" <<SQL
$1
SQL
}

wait_for_api_health() {
  for _ in $(seq 1 90); do
    if [[ "$(curl -fsS --connect-timeout "$curl_connect_timeout" --max-time "$curl_max_time" \
      "$api_base_url/healthz" 2>/dev/null || true)" == "ok" ]]; then
      return 0
    fi
    sleep 1
  done
  return 1
}

required_tables_sql() {
  cat <<'SQL'
WITH required(name) AS (
    VALUES
      ('e2ee_account_identities'), ('e2ee_devices'), ('e2ee_key_packages'),
      ('e2ee_room_epochs'), ('e2ee_control_messages'), ('e2ee_control_receipts'),
      ('e2ee_runtime_gate'), ('messages'), ('message_parts'),
      ('message_attachment_commits')
), missing AS (
    SELECT name FROM required
    WHERE to_regclass('public.' || name) IS NULL
)
SELECT COALESCE(string_agg(name, ',' ORDER BY name), '') FROM missing;
SQL
}

snapshot_sql() {
  cat <<'SQL'
WITH snapshot AS (
  SELECT jsonb_build_object(
    'account_identities', (SELECT COUNT(*) FROM e2ee_account_identities),
    'devices', (SELECT COUNT(*) FROM e2ee_devices),
    'active_devices', (SELECT COUNT(*) FROM e2ee_devices WHERE status = 'active'),
    'revoked_devices', (SELECT COUNT(*) FROM e2ee_devices WHERE status = 'revoked'),
    'pending_devices', (SELECT COUNT(*) FROM e2ee_devices WHERE status = 'pending_approval'),
    'key_packages', (SELECT COUNT(*) FROM e2ee_key_packages),
    'available_key_packages', (
      SELECT COUNT(*) FROM e2ee_key_packages
      WHERE consumed_at IS NULL AND expires_at > NOW()
    ),
    'room_epochs', (SELECT COUNT(*) FROM e2ee_room_epochs),
    'control_messages', (SELECT COUNT(*) FROM e2ee_control_messages),
    'control_receipts', (SELECT COUNT(*) FROM e2ee_control_receipts),
    'encrypted_messages', (
      SELECT COUNT(*) FROM messages WHERE encrypted_content IS NOT NULL
    ),
    'rcml_messages', (
      SELECT COUNT(*) FROM messages
      WHERE encrypted_content IS NOT NULL
        AND substring(encrypted_content FROM 1 FOR 4) = decode('52434d4c', 'hex')
    ),
    'message_parts', (SELECT COUNT(*) FROM message_parts),
    'attachment_commits', (SELECT COUNT(*) FROM message_attachment_commits),
    'runtime_gate', (
      SELECT jsonb_build_object(
        'state', state,
        'required_coverage_percent', required_coverage_percent,
        'key_package_low_watermark', key_package_low_watermark,
        'security_review_approved', security_review_approved
      ) FROM e2ee_runtime_gate WHERE id = 1
    ),
    'digest', md5(concat_ws('|',
      (SELECT COALESCE(string_agg(md5(concat_ws(':', id, user_id, status,
        encode(credential_fingerprint, 'hex'))), '' ORDER BY id), '') FROM e2ee_devices),
      (SELECT COALESCE(string_agg(md5(concat_ws(':', id, device_id, consumed_at IS NOT NULL,
        encode(package_ref, 'hex'), encode(key_package, 'hex'))), '' ORDER BY id), '')
        FROM e2ee_key_packages),
      (SELECT COALESCE(string_agg(md5(concat_ws(':', room_id, membership_revision,
        active_epoch, status)), '' ORDER BY room_id), '') FROM e2ee_room_epochs),
      (SELECT COALESCE(string_agg(md5(concat_ws(':', id, room_id, epoch,
        membership_revision, content_type, encode(envelope, 'hex'))), '' ORDER BY id), '')
        FROM e2ee_control_messages),
      (SELECT COALESCE(string_agg(md5(concat_ws(':', id, room_id,
        encode(encrypted_content, 'hex'), encryption_metadata::text)), '' ORDER BY id), '')
        FROM messages WHERE encrypted_content IS NOT NULL),
      (SELECT COALESCE(string_agg(md5(concat_ws(':', room_id, object_key, uploaded_by,
        file_size, confirmed_at IS NOT NULL)), '' ORDER BY room_id, object_key), '')
        FROM message_attachment_commits)
    )),
    'orphan_control_senders', (
      SELECT COUNT(*) FROM e2ee_control_messages c
      LEFT JOIN e2ee_devices d ON d.id = c.sender_device_id WHERE d.id IS NULL
    ),
    'orphan_room_epochs', (
      SELECT COUNT(*) FROM e2ee_room_epochs e
      LEFT JOIN rooms r ON r.id = e.room_id WHERE r.id IS NULL
    ),
    'orphan_attachment_rooms', (
      SELECT COUNT(*) FROM message_attachment_commits a
      LEFT JOIN rooms r ON r.id = a.room_id WHERE r.id IS NULL
    )
  ) AS value
)
SELECT value::text FROM snapshot;
SQL
}

runtime_json() {
  curl -fsS --connect-timeout "$curl_connect_timeout" --max-time "$curl_max_time" \
    "$api_base_url/settings/general" |
    jq -c '{server_storage_mode: .message_runtime.server_storage_mode,
      content_audit_mode: .message_runtime.content_audit_mode}'
}

assert_plaintext_runtime() {
  local runtime
  runtime="$(runtime_json)"
  [[ "$(jq -r '.server_storage_mode' <<<"$runtime")" == "persist" ]] ||
    die "server_storage_mode 不是 persist"
  [[ "$(jq -r '.content_audit_mode' <<<"$runtime")" == "plaintext" ]] ||
    die "content_audit_mode 不是 plaintext"
}

admin_gate_request() {
  local method="$1"
  local path="$2"
  curl -fsS -X "$method" \
    --connect-timeout "$curl_connect_timeout" \
    --max-time "$curl_max_time" \
    -H "Authorization: Bearer ${E2EE_DRILL_ADMIN_TOKEN:?}" \
    -H 'Content-Type: application/json' \
    "$api_base_url$path"
}

cleanup_source_psql() {
  run_with_timeout "$cleanup_hard_timeout" \
    docker compose -f "$compose_file" exec -T "$postgres_service" sh -ec \
      'psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<SQL
$1
SQL
}

restore_gate_approval() {
  if [[ ! -f "$recovery_state_path" ]]; then
    return 0
  fi
  original_security_review_approved="$(sed -n 's/^security_review_approved=//p' "$recovery_state_path")"
  local approved_sql
  case "$original_security_review_approved" in
    t) approved_sql=TRUE ;;
    f) approved_sql=FALSE ;;
    *)
      log "无法恢复非法 security_review_approved 值"
      return 1
      ;;
  esac
  if ! cleanup_source_psql "UPDATE e2ee_runtime_gate SET security_review_approved = ${approved_sql} WHERE id = 1;" >/dev/null; then
    return 1
  fi
  log "已恢复 security_review_approved=${original_security_review_approved}"
}

rollback_runtime() {
  if assert_plaintext_runtime >/dev/null 2>&1; then
    return
  fi
  [[ -n "${E2EE_DRILL_ADMIN_TOKEN:-}" ]] || return 1
  admin_gate_request POST '/api/admin/settings/message-runtime/e2ee/rollback' >/dev/null || return 1
  assert_plaintext_runtime
}

api_service_running() {
  local container_id
  container_id="$(run_with_timeout "$cleanup_hard_timeout" \
    docker compose -f "$compose_file" ps -q --status running "$api_service")" || return 2
  [[ -n "$container_id" ]]
}

restore_container_exists() {
  run_with_timeout "$cleanup_hard_timeout" \
    docker container inspect "$restore_container" >/dev/null 2>&1
}

restore_volume_exists() {
  run_with_timeout "$cleanup_hard_timeout" \
    docker volume inspect "$restore_volume" >/dev/null 2>&1
}

ensure_api_running() {
  if ! api_service_running; then
    run_with_timeout "$cleanup_hard_timeout" \
      docker compose -f "$compose_file" start "$api_service" >/dev/null || return 1
  fi
  wait_for_api_health
}

remove_restore_resources() {
  local failed=0 probe_status
  if restore_container_exists; then
    run_with_timeout "$cleanup_hard_timeout" docker rm -f "$restore_container" >/dev/null || failed=1
  else
    probe_status=$?
    [[ "$probe_status" == "1" ]] || failed=1
  fi
  if restore_volume_exists; then
    run_with_timeout "$cleanup_hard_timeout" docker volume rm "$restore_volume" >/dev/null || failed=1
  else
    probe_status=$?
    [[ "$probe_status" == "1" ]] || failed=1
  fi
  [[ "$failed" == "0" ]]
}

assert_cleanup_state() {
  local failed=0 expected_approval current_approval probe_status
  if ! api_service_running || ! wait_for_api_health; then
    log "API 未恢复到运行且健康状态"
    failed=1
  fi
  if restore_container_exists; then
    log "临时恢复容器仍然存在：$restore_container"
    failed=1
  else
    probe_status=$?
    if [[ "$probe_status" != "1" ]]; then
      log "无法确认临时恢复容器状态"
      failed=1
    fi
  fi
  if restore_volume_exists; then
    log "临时恢复 volume 仍然存在：$restore_volume"
    failed=1
  else
    probe_status=$?
    if [[ "$probe_status" != "1" ]]; then
      log "无法确认临时恢复 volume 状态"
      failed=1
    fi
  fi
  if ! assert_plaintext_runtime; then
    log "runtime 未恢复为 persist/plaintext"
    failed=1
  fi
  if [[ -f "$recovery_state_path" ]]; then
    expected_approval="$(sed -n 's/^security_review_approved=//p' "$recovery_state_path")"
    current_approval="$(cleanup_source_psql "SELECT security_review_approved FROM e2ee_runtime_gate WHERE id = 1;" 2>/dev/null)" || current_approval=""
    if [[ -z "$expected_approval" || "$current_approval" != "$expected_approval" ]]; then
      log "security_review_approved 未恢复到原值"
      failed=1
    fi
  fi
  [[ "$failed" == "0" ]]
}

cleanup() {
  local exit_code="${1:-$?}"
  local cleanup_failed=0
  trap - EXIT
  trap '' INT TERM
  if ! ensure_api_running; then
    log "API 恢复启动失败"
    cleanup_failed=1
  fi
  if ! rollback_runtime; then
    log "runtime API 回滚失败"
    cleanup_failed=1
  fi
  if ! restore_gate_approval; then
    log "security_review_approved 恢复失败"
    cleanup_failed=1
  fi
  if ! remove_restore_resources; then
    log "临时恢复容器或 volume 删除失败"
    cleanup_failed=1
  fi
  if [[ "${E2EE_DRILL_KEEP_ARTIFACTS:-}" != "yes" ]]; then
    [[ -z "$dump_path" ]] || rm -f "$dump_path"
    [[ -z "$corrupt_path" ]] || rm -f "$corrupt_path"
  fi
  if ! assert_cleanup_state; then
    cleanup_failed=1
  fi
  if [[ "$cleanup_failed" == "0" ]]; then
    rm -f "$recovery_state_path"
    log "恢复终验通过：API、审批、runtime 与临时资源均已复原"
  elif [[ "$exit_code" == "0" ]]; then
    exit_code=1
  fi
  if ! release_run_lock; then
    log "run_id 锁释放失败：$lock_dir"
    [[ "$exit_code" != "0" ]] || exit_code=1
  fi
  if [[ "$exit_code" != "0" ]]; then
    log "演练中断，退出码=$exit_code"
  fi
  exit "$exit_code"
}

preflight() {
  require_command docker
  require_command curl
  require_command jq
  require_command sha256sum
  [[ -f "$compose_file" ]] || die "找不到 Compose 文件：$compose_file"
  compose config >/dev/null
  local running_services health
  running_services="$(compose ps --status running "$postgres_service" "$api_service")"
  grep -q "$postgres_service" <<<"$running_services" || die "$postgres_service 未运行"
  grep -q "$api_service" <<<"$running_services" || die "$api_service 未运行"
  health="$(curl -fsS --connect-timeout "$curl_connect_timeout" --max-time "$curl_max_time" \
    "$api_base_url/healthz")"
  [[ "$health" == "ok" ]] || die "API healthz 未就绪"
  assert_plaintext_runtime

  local missing_tables
  missing_tables="$(source_psql "$(required_tables_sql)")"
  [[ -z "$missing_tables" ]] || die "部署版本过旧，缺少表：$missing_tables"

  local migration_version
  migration_version="$(source_psql "SELECT COALESCE(MAX(name) FILTER (WHERE name ~ '^[0-9]'), '') FROM db_migrations;")"
  [[ "$migration_version" == "20260805201000_message_attachment_commit_leases.sql" ]] ||
    die "migration 版本过旧或清单异常：$migration_version"

  local snapshot
  snapshot="$(source_psql "$(snapshot_sql)")"
  [[ "$(jq -r '.orphan_control_senders + .orphan_room_epochs + .orphan_attachment_rooms' <<<"$snapshot")" == "0" ]] ||
    die "源库存在 E2EE 引用完整性异常"
  [[ "$(jq -r '.encrypted_messages' <<<"$snapshot")" == "$(jq -r '.rcml_messages' <<<"$snapshot")" ]] ||
    die "存在非 RCML encrypted_content"

  local api_image_id
  api_image_id="$(docker inspect "$(compose ps -q "$api_service")" --format '{{.Image}}')"
  jq -n \
    --arg run_id "$run_id" \
    --arg mode "$mode" \
    --arg migration_version "$migration_version" \
    --arg api_image_id "$api_image_id" \
    --argjson runtime "$(runtime_json)" \
    --argjson source_snapshot "$snapshot" \
    '{run_id: $run_id, mode: $mode, migration_version: $migration_version,
      api_image_id: $api_image_id, runtime_before: $runtime,
      source_snapshot: $source_snapshot}'
}

run_backup_restore() {
  [[ "${E2EE_DRILL_ALLOW_API_STOP:-}" == "yes" ]] ||
    die "backup-restore/full 需要 E2EE_DRILL_ALLOW_API_STOP=yes"
  mkdir -p "$artifact_dir"
  dump_path="$artifact_dir/database.dump"
  corrupt_path="$artifact_dir/database-corrupt.dump"
  local started_at finished_at duration_seconds backup_sha source_snapshot restored_snapshot

  compose stop "$api_service" >/dev/null
  started_at="$(date +%s)"
  source_snapshot="$(source_psql "$(snapshot_sql)")"
  compose exec -T "$postgres_service" sh -ec \
    'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -Z 5' >"$dump_path"
  compose exec -T "$postgres_service" sh -ec \
    'pg_restore -l >/dev/null' <"$dump_path"

  head -c 1024 "$dump_path" >"$corrupt_path"
  if compose exec -T "$postgres_service" sh -ec \
    'pg_restore -l >/dev/null 2>&1' <"$corrupt_path"; then
    die "损坏备份未被 pg_restore 拒绝"
  fi
  rm -f "$corrupt_path"
  log "备份归档可读且损坏归档已被拒绝"

  restore_password="$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')"
  docker volume create "$restore_volume" >/dev/null
  docker run -d --name "$restore_container" \
    --network none \
    -e "POSTGRES_DB=$restore_database" \
    -e "POSTGRES_USER=$restore_user" \
    -e "POSTGRES_PASSWORD=$restore_password" \
    -v "$restore_volume:/var/lib/postgresql/data" \
    postgres:17-alpine >/dev/null || die "临时恢复容器启动失败"
  log "临时恢复容器已启动"
  for _ in $(seq 1 60); do
    if docker exec "$restore_container" pg_isready -h 127.0.0.1 \
      -U "$restore_user" -d "$restore_database" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  docker exec "$restore_container" pg_isready -h 127.0.0.1 \
    -U "$restore_user" -d "$restore_database" >/dev/null ||
    die "临时恢复 PostgreSQL 未就绪"
  log "临时恢复 PostgreSQL 已就绪"
  docker exec -i "$restore_container" pg_restore \
    -h 127.0.0.1 -U "$restore_user" -d "$restore_database" \
    --no-owner --no-privileges <"$dump_path" || die "pg_restore 恢复失败"
  log "数据库归档已恢复到临时实例"
  restored_snapshot="$(restore_psql "$(snapshot_sql)")"
  [[ "$(jq -S . <<<"$source_snapshot")" == "$(jq -S . <<<"$restored_snapshot")" ]] ||
    die "恢复实例与源库快照不一致"
  log "独立恢复快照与源库一致"

  finished_at="$(date +%s)"
  duration_seconds="$((finished_at - started_at))"
  backup_sha="$(sha256sum "$dump_path" | awk '{print $1}')"

  remove_restore_resources || die "临时恢复容器或 volume 删除失败"
  log "临时恢复容器与 volume 已删除"
  ensure_api_running || die "API 恢复启动后 healthz 未就绪"
  assert_plaintext_runtime
  log "API 已恢复且 runtime 为 persist/plaintext"

  backup_report="$(jq -n \
    --arg backup_sha256 "$backup_sha" \
    --argjson duration_seconds "$duration_seconds" \
    --argjson source_snapshot "$source_snapshot" \
    --argjson restored_snapshot "$restored_snapshot" \
    '{backup_sha256: $backup_sha256, duration_seconds: $duration_seconds,
      archive_readable: true, corrupt_archive_rejected: true,
      independent_restore_instance: true, snapshots_match: true,
      source_snapshot: $source_snapshot, restored_snapshot: $restored_snapshot}')"
  log "备份恢复报告已生成"

  if [[ "${E2EE_DRILL_KEEP_ARTIFACTS:-}" != "yes" ]]; then
    rm -f "$dump_path"
  fi
}

run_rollout() {
  [[ "${E2EE_DRILL_ALLOW_ACTIVE:-}" == "yes" ]] ||
    die "full 需要 E2EE_DRILL_ALLOW_ACTIVE=yes"
  [[ -n "${E2EE_DRILL_ADMIN_TOKEN:-}" ]] || die "full 需要 E2EE_DRILL_ADMIN_TOKEN"

  original_security_review_approved="$(source_psql "SELECT security_review_approved FROM e2ee_runtime_gate WHERE id = 1;")"
  [[ "$original_security_review_approved" == "t" || "$original_security_review_approved" == "f" ]] ||
    die "无法读取 security_review_approved"
  mkdir -p "$(dirname "$recovery_state_path")"
  printf 'security_review_approved=%s\n' "$original_security_review_approved" >"${recovery_state_path}.tmp"
  mv "${recovery_state_path}.tmp" "$recovery_state_path"
  source_psql "UPDATE e2ee_runtime_gate SET security_review_approved = TRUE WHERE id = 1;" >/dev/null

  local prepare active after_recreate rollback started_at finished_at
  started_at="$(date +%s)"
  prepare="$(admin_gate_request POST '/api/admin/settings/message-runtime/e2ee/prepare')"
  [[ "$(jq -r '.state' <<<"$prepare")" == "prepare" ]] || die "prepare 未进入 prepare"
  [[ "$(jq -r '.readiness.ready' <<<"$prepare")" == "true" ]] ||
    die "readiness 未通过：$(jq -c '.readiness.blocking_reasons' <<<"$prepare")"

  active="$(admin_gate_request POST '/api/admin/settings/message-runtime/e2ee/active')"
  [[ "$(jq -r '.state' <<<"$active")" == "active" ]] || die "active 未进入 active"
  [[ "$(jq -r '.content_audit_mode' <<<"$active")" == "e2ee" ]] || die "active 未切换 e2ee"

  compose up -d --force-recreate "$api_service" >/dev/null
  wait_for_api_health || die "API recreate 后 healthz 未就绪"
  after_recreate="$(admin_gate_request GET '/api/admin/settings/message-runtime/e2ee/gate')"
  [[ "$(jq -r '.state' <<<"$after_recreate")" == "active" ]] ||
    die "API recreate 后 gate 未保持 active"
  [[ "$(jq -r '.content_audit_mode' <<<"$after_recreate")" == "e2ee" ]] ||
    die "API recreate 后 audit mode 未保持 e2ee"

  rollback="$(admin_gate_request POST '/api/admin/settings/message-runtime/e2ee/rollback')"
  [[ "$(jq -r '.state' <<<"$rollback")" == "plaintext" ]] || die "rollback 未恢复 plaintext"
  [[ "$(jq -r '.content_audit_mode' <<<"$rollback")" == "plaintext" ]] ||
    die "rollback 未恢复 plaintext audit mode"
  assert_plaintext_runtime
  restore_gate_approval
  finished_at="$(date +%s)"

  rollout_report="$(jq -n \
    --argjson duration_seconds "$((finished_at - started_at))" \
    --argjson readiness "$(jq '.readiness' <<<"$prepare")" \
    '{duration_seconds: $duration_seconds, prepare: true, active: true,
      api_recreate_while_active: true, rollback: true,
      runtime_restored: "persist/plaintext", readiness: $readiness}')"
}

case "$mode" in
  -h|--help|help)
    usage
    exit 0
    ;;
  preflight|backup-restore|full|recover) ;;
  *)
    usage >&2
    exit 64
    ;;
esac

acquire_run_lock || exit 73
trap 'cleanup $?' EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

if [[ "$mode" == "recover" ]]; then
  cleanup 0
fi

mkdir -p "$(dirname "$report_path")"
preflight_report="$(preflight)"
backup_report='null'
rollout_report='null'
if [[ "$mode" == "backup-restore" || "$mode" == "full" ]]; then
  run_backup_restore
fi
if [[ "$mode" == "full" ]]; then
  run_rollout
fi

jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson preflight "$preflight_report" \
  --argjson backup_restore "$backup_report" \
  --argjson rollout "$rollout_report" \
  '{generated_at: $generated_at, preflight: $preflight,
    backup_restore: $backup_restore, rollout: $rollout}' >"$report_path"

log "演练完成，脱敏报告：$report_path"
if [[ "$mode" == "preflight" ]]; then
  trap - EXIT INT TERM
  release_run_lock || exit 1
  exit 0
fi
cleanup 0
