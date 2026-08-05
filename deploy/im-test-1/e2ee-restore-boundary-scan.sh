#!/usr/bin/env bash
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-scan}"
run_id="${E2EE_RESTORE_RUN_ID:-}"
evidence_file="${E2EE_RESTORE_EVIDENCE_PATH:-}"
env_file="${E2EE_RESTORE_ENV_FILE:-$script_dir/.env}"
compose_file="${E2EE_RESTORE_COMPOSE_FILE:-$script_dir/docker-compose.e2ee-restore.yml}"
state_root="${E2EE_RESTORE_STATE_ROOT:-$script_dir/.e2ee-restore}"
artifact_root="${E2EE_RESTORE_ARTIFACT_ROOT:-$script_dir/.e2ee-drill}"
state_file="$state_root/$run_id/control.env"
artifact_dir="$artifact_root/$run_id"
project="e2ee-restore-${run_id//[._]/-}"
monitor_log="$artifact_dir/redis-monitor.log"
monitor_pid="$artifact_dir/redis-monitor.pid"
monitor_snapshot="$artifact_dir/redis-monitor.snapshot"
monitor_probe_channel="e2ee-restore-monitor-probe:$run_id"
command_timeout="${E2EE_RESTORE_SCAN_COMMAND_TIMEOUT:-180}"
restore_password=""
restore_redis_password=""

log() {
  printf '[e2ee-restore-scan] %s\n' "$*" >&2
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
  if wait "$command_pid"; then status=0; else status=$?; fi
  return "$status"
}

[[ "$run_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || die "run_id 无效"
[[ "$command_timeout" =~ ^[1-9][0-9]{0,2}$ ]] && ((command_timeout <= 900)) ||
  die "scan command timeout 必须是 1..900 的整数"
for path in "$env_file" "$compose_file" "$state_root" "$artifact_root"; do
  [[ "$path" == /* && "$path" =~ ^/[A-Za-z0-9._/-]+$ ]] || die "控制路径无效：$path"
done
[[ -f "$env_file" && -f "$compose_file" && -f "$state_file" ]] || die "restore scan 状态不完整"
for command in awk cp docker grep jq sed seq sha256sum sort tr wc; do
  command -v "$command" >/dev/null || die "缺少命令：$command"
done

set -a
# shellcheck disable=SC1090
. "$env_file"
set +a
restore_password="$(sed -n 's/^E2EE_RESTORE_PASSWORD=//p' "$state_file")"
restore_redis_password="$(sed -n 's/^E2EE_RESTORE_REDIS_PASSWORD=//p' "$state_file")"
[[ "$restore_password" =~ ^[0-9a-f]{48}$ && "$restore_redis_password" =~ ^[0-9a-f]{48}$ ]] ||
  die "restore scan 状态损坏"

compose_restore() {
  E2EE_RESTORE_PROJECT_NAME="$project" \
  E2EE_RESTORE_DATABASE=redcode_e2ee_restore \
  E2EE_RESTORE_USER=e2ee_restore \
  E2EE_RESTORE_PASSWORD="$restore_password" \
  E2EE_RESTORE_REDIS_PASSWORD="$restore_redis_password" \
  E2EE_DRILL_API_IMAGE="${E2EE_DRILL_API_IMAGE:?}" \
    run_with_timeout docker compose --env-file "$env_file" -p "$project" -f "$compose_file" "$@"
}

postgres_query() {
  compose_restore exec -T postgres-restore psql -X -qAt -v ON_ERROR_STOP=1 \
    -U e2ee_restore -d redcode_e2ee_restore -c "$1"
}

redis_container() {
  compose_restore ps -q --status running redis-restore
}

start_monitor() {
  local container pid
  mkdir -p "$artifact_dir"
  date -u +%Y-%m-%dT%H:%M:%SZ >"$artifact_dir/scan-log-since"
  container="$(redis_container)"
  [[ -n "$container" ]] || die "restore Redis 未运行"
  rm -f "$monitor_log" "$monitor_pid" "$monitor_snapshot"
  nohup docker exec -e "REDISCLI_AUTH=$restore_redis_password" "$container" \
    redis-cli --no-auth-warning MONITOR >"$monitor_log" 2>&1 </dev/null &
  pid=$!
  printf '%s\n' "$pid" >"$monitor_pid"
  sleep 1
  kill -0 "$pid" 2>/dev/null || die "restore Redis MONITOR 进程提前退出"
  grep -q '^OK$' "$monitor_log" ||
    die "restore Redis MONITOR 未就绪"
  run_with_timeout docker exec -e "REDISCLI_AUTH=$restore_redis_password" "$container" \
    redis-cli --no-auth-warning PUBLISH "$monitor_probe_channel" probe >/dev/null
  for _ in $(seq 1 50); do
    grep -aFq "$monitor_probe_channel" "$monitor_log" && break
    sleep 0.1
  done
  grep -aFq "$monitor_probe_channel" "$monitor_log" ||
    die "restore Redis MONITOR probe 未落盘"
  printf 'ready\n' >"$artifact_dir/monitor-ready"
  log "restore Redis MONITOR 已启动"
}

validate_evidence() {
  [[ "$evidence_file" == "$artifact_dir/"* && -f "$evidence_file" && ! -L "$evidence_file" ]] ||
    die "evidence 必须位于当前 run artifact 目录"
  jq -e --arg run_id "$run_id" '
    (.run_id == $run_id) and
    (.scenarios | type == "array" and length == 4) and
    ([.scenarios[].name] | sort == ["android-h5", "h5-h5", "ios-h5", "restore-continuity"]) and
    (all(.scenarios[]; (.room_id | type == "string" and length > 0))) and
    (all(.scenarios[];
      (.message_proofs | type == "array" and length > 0) and
      all(.message_proofs[];
        (.message_id | type == "string" and length > 0) and
        (.plaintext_marker | type == "string" and length > 0) and
        (.kind == "text" or .kind == "attachment") and
        (if .kind == "attachment"
         then (.object_key | type == "string" and length > 0)
         else (has("object_key") | not)
         end)))) and
    ([.scenarios[].message_proofs[]] | length == 9) and
    ([.scenarios[].message_proofs[] | select(.kind == "attachment")] | length == 1)
  ' "$evidence_file" >/dev/null || die "四场景 evidence 结构无效"
}

scan() {
  local container monitor_bytes monitor_process monitor_channels object_key attachment_marker object_file object_sha256
  local message_csv db_rows attachment_rows push_rows api_logs push_status marker_predicate
  local content_predicate encrypted_predicate metadata_predicate envelope_predicate push_predicate
  local content_expression metadata_expression push_expression
  local proof_file="$artifact_dir/message-proofs.tsv"
  local room_ids=() message_ids=() markers=() object_keys=()
  validate_evidence
  [[ "$(cat "$artifact_dir/monitor-ready" 2>/dev/null || true)" == ready ]] ||
    die "Redis MONITOR ready marker 缺失"
  jq -r '.scenarios[] as $scenario | $scenario.message_proofs[] |
    [$scenario.name, $scenario.room_id, .message_id, .plaintext_marker, .kind, (.object_key // "")] | @tsv' \
    "$evidence_file" >"$proof_file"
  while IFS=$'\t' read -r _ room_id message_id marker kind proof_object_key; do
    room_ids+=("$room_id")
    message_ids+=("$message_id")
    markers+=("$marker")
    [[ "$kind" != attachment ]] || object_keys+=("$proof_object_key")
  done <"$proof_file"
  for value in "${room_ids[@]}" "${message_ids[@]}"; do
    [[ "$value" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$ ]] ||
      die "evidence UUID 无效"
  done
  for marker in "${markers[@]}"; do
    [[ "$marker" =~ ^u[0-9]+-[A-Za-z0-9-]+$ ]] || die "plaintext marker 无效"
  done
  [[ "$(printf '%s\n' "${room_ids[@]}" | sort -u | wc -l | tr -d ' ')" == 4 ]] ||
    die "scenario room_id 必须全局唯一"
  [[ "$(printf '%s\n' "${message_ids[@]}" | sort -u | wc -l | tr -d ' ')" == "${#message_ids[@]}" ]] ||
    die "message_id 必须全局唯一"
  [[ "$(printf '%s\n' "${markers[@]}" | sort -u | wc -l | tr -d ' ')" == "${#markers[@]}" ]] ||
    die "plaintext marker 必须全局唯一"
  [[ "${#object_keys[@]}" == 1 ]] || die "必须且只能有一个 attachment object"
  object_key="${object_keys[0]}"
  attachment_marker="$(awk -F '\t' '$5 == "attachment" { print $4 }' "$proof_file")"
  [[ "$object_key" =~ ^messages/[0-9a-f-]+/[A-Za-z0-9._/-]+$ ]] || die "object key 无效"
  [[ "$attachment_marker" =~ ^u[0-9]+-attachment-[0-9a-f-]+$ ]] || die "attachment marker 无效"

  message_csv="$(printf "'%s'," "${message_ids[@]}")"; message_csv="${message_csv%,}"
  db_rows="$(postgres_query "SELECT id, room_id, content, encrypted_content IS NOT NULL
    FROM messages WHERE id IN ($message_csv) ORDER BY id")"
  [[ "$(printf '%s\n' "$db_rows" | sed '/^$/d' | wc -l | tr -d ' ')" == "${#message_ids[@]}" ]] ||
    die "restore DB 未找到全部 evidence messages"
  printf '%s\n' "$db_rows" | awk -F '|' '$3 != "[加密消息]" || $4 != "t" { exit 1 }' ||
    die "restore DB 消息不是密文占位"
  while IFS=$'\t' read -r scenario room_id message_id _ _ _; do
    printf '%s\n' "$db_rows" | awk -F '|' -v id="$message_id" -v room="$room_id" \
      '$1 == id && $2 == room { found=1 } END { exit(found ? 0 : 1) }' ||
      die "message-room proof 不匹配：$scenario/$message_id"
  done <"$proof_file"

  attachment_rows="$(postgres_query "SELECT room_id, object_key, file_size FROM
    message_attachment_commits WHERE object_key = '$object_key'")"
  [[ -n "$attachment_rows" ]] || die "restore DB 缺少 attachment commit"
  while IFS=$'\t' read -r scenario room_id message_id _ kind proof_object_key; do
    [[ "$kind" != attachment ]] || {
      printf '%s\n' "$attachment_rows" | awk -F '|' -v room="$room_id" -v object="$proof_object_key" \
        '$1 == room && $2 == object { found=1 } END { exit(found ? 0 : 1) }' ||
        die "attachment object-message-room proof 不匹配：$scenario/$message_id"
    }
  done <"$proof_file"

  marker_predicate="$(printf "position(convert_to('%s', 'UTF8') in %%s) > 0 OR " "${markers[@]}")"
  marker_predicate="${marker_predicate% OR }"
  content_expression="convert_to(COALESCE(content, ''), 'UTF8')"
  metadata_expression="convert_to(encryption_metadata::text, 'UTF8')"
  push_expression="convert_to(payload::text, 'UTF8')"
  content_predicate="${marker_predicate//%s/$content_expression}"
  encrypted_predicate="${marker_predicate//%s/encrypted_content}"
  metadata_predicate="${marker_predicate//%s/$metadata_expression}"
  envelope_predicate="${marker_predicate//%s/envelope}"
  push_predicate="${marker_predicate//%s/$push_expression}"
  [[ "$(postgres_query "SELECT COUNT(*) FROM messages WHERE ($content_predicate)")" == 0 ]] ||
    die "messages.content 命中 plaintext marker"
  [[ "$(postgres_query "SELECT COUNT(*) FROM messages WHERE encrypted_content IS NOT NULL AND
    ($encrypted_predicate)")" == 0 ]] ||
    die "messages.encrypted_content 命中 plaintext marker"
  [[ "$(postgres_query "SELECT COUNT(*) FROM messages WHERE encryption_metadata IS NOT NULL AND
    ($metadata_predicate)")" == 0 ]] ||
    die "messages.encryption_metadata 命中 plaintext marker"
  [[ "$(postgres_query "SELECT COUNT(*) FROM e2ee_control_messages WHERE ($envelope_predicate)")" == 0 ]] ||
    die "e2ee_control_messages.envelope 命中 plaintext marker"
  [[ "$(postgres_query "SELECT COUNT(*) FROM push_job_queue WHERE ($push_predicate)")" == 0 ]] ||
    die "push_job_queue.payload 命中 plaintext marker"

  push_rows="$(postgres_query "SELECT payload::text FROM push_job_queue WHERE
    $(printf "payload::text LIKE '%%%s%%' OR " "${message_ids[@]}" | sed 's/ OR $//')")"
  push_status=not-observed-live
  if [[ -n "$push_rows" ]]; then
    printf '%s' "$push_rows" | grep -Eq '【加密消息】|你收到一条加密消息' || die "Push 未使用 E2EE 占位"
    push_status=placeholder-verified
  fi

  container="$(redis_container)"
  [[ -n "$container" ]] || die "restore Redis 未运行"
  monitor_process="$(cat "$monitor_pid" 2>/dev/null || true)"
  [[ "$monitor_process" =~ ^[1-9][0-9]*$ && -f "$monitor_log" ]] ||
    die "Redis MONITOR run-scoped 状态损坏"
  monitor_bytes="$(wc -c <"$monitor_log" | tr -d ' ')"
  if ! grep -aFq "$monitor_probe_channel" "$monitor_log"; then
    monitor_channels="$(sed -nE 's/.*"(PUBLISH|SUBSCRIBE|PSUBSCRIBE)" "([^"]+)".*/\1 \2/p' \
      "$monitor_log" | sort -u)"
    log "Redis MONITOR 停止前状态：pid_alive=$(kill -0 "$monitor_process" 2>/dev/null && printf yes || printf no)，bytes=$monitor_bytes，channels=${monitor_channels:-none}"
    die "Redis MONITOR probe 在停止采集前已丢失"
  fi
  cp -- "$monitor_log" "$monitor_snapshot"
  grep -aFq "$monitor_probe_channel" "$monitor_snapshot" ||
    die "Redis MONITOR 不可变快照缺少 probe"
  kill "$monitor_process" 2>/dev/null || true
  for _ in $(seq 1 50); do
    kill -0 "$monitor_process" 2>/dev/null || break
    sleep 0.1
  done
  kill -0 "$monitor_process" 2>/dev/null && die "Redis MONITOR 进程未停止"
  monitor_channels="$(sed -nE 's/.*"(PUBLISH|SUBSCRIBE|PSUBSCRIBE)" "([^"]+)".*/\1 \2/p' \
    "$monitor_snapshot" | sort -u)"
  while IFS= read -r room_id; do
    if ! sed -nE 's/.*"PUBLISH" "([^"]+)".*/\1/p' "$monitor_snapshot" |
      grep -Fxq "room:$room_id"; then
      log "Redis MONITOR 已观测 channel：${monitor_channels:-none}"
      die "Redis MONITOR 缺少精确 PUBLISH：room:$room_id"
    fi
  done < <(printf '%s\n' "${room_ids[@]}" | sort -u)

  api_logs="$(compose_restore logs --since "$(cat "$artifact_dir/scan-log-since")" --no-color api-restore)"
  for marker in "${markers[@]}"; do
    for surface in "$db_rows" "$attachment_rows" "$push_rows" "$api_logs"; do
      printf '%s' "$surface" | grep -aFq "$marker" && die "边界面命中 plaintext marker"
    done
    grep -aFq "$marker" "$monitor_snapshot" && die "Redis MONITOR 命中 plaintext marker"
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      run_with_timeout docker exec -e "REDISCLI_AUTH=$restore_redis_password" "$container" \
        redis-cli --no-auth-warning --raw DUMP "$key" | grep -aFq "$marker" &&
        die "restore Redis key 命中 plaintext marker"
    done < <(run_with_timeout docker exec -e "REDISCLI_AUTH=$restore_redis_password" "$container" \
      redis-cli --no-auth-warning --raw --scan)
  done
  for surface in "$db_rows" "$push_rows" "$api_logs"; do
    printf '%s' "$surface" | grep -aEq '(^|[^A-Za-z0-9_])(dek|nonce|rcst|root_private_key|private_key_p8)([^A-Za-z0-9_]|$)' &&
      die "边界面命中敏感字段"
  done
  grep -aEq '(^|[^A-Za-z0-9_])(dek|nonce|rcst|root_private_key|private_key_p8)([^A-Za-z0-9_]|$)' \
    "$monitor_snapshot" && die "Redis MONITOR 命中敏感字段"

  object_file="$artifact_dir/object.bin"
  run_with_timeout docker run --rm --network im-test-1-network \
    -e "RUSTFS_ACCESS_KEY=$RUSTFS_ACCESS_KEY" -e "RUSTFS_SECRET_KEY=$RUSTFS_SECRET_KEY" \
    -e "RUSTFS_BUCKET=$RUSTFS_PRIVATE_BUCKET" -e "RUSTFS_OBJECT_KEY=$object_key" \
    --entrypoint /bin/sh minio/mc:latest -ec \
    'mc alias set rustfs http://rustfs:9000 "$RUSTFS_ACCESS_KEY" "$RUSTFS_SECRET_KEY" >/dev/null; mc cat "rustfs/$RUSTFS_BUCKET/$RUSTFS_OBJECT_KEY"' \
    >"$object_file"
  [[ -s "$object_file" ]] || die "RustFS object 为空"
  grep -aFq "$attachment_marker" "$object_file" && die "RustFS object 包含附件明文"
  object_sha256="$(sha256sum "$object_file" | awk '{print $1}')"
  rm -f "$object_file"

  jq -n --arg run_id "$run_id" --arg object_key "$object_key" \
    --arg object_sha256 "$object_sha256" --arg push "$push_status" \
    '{run_id: $run_id, db: "ciphertext-only", redis: "marker-free",
      logs: "marker-free", push: $push,
      rustfs: {object_key: $object_key, content: "ciphertext-only", sha256: $object_sha256}}'
}

case "$mode" in
  monitor-start) start_monitor ;;
  scan) scan ;;
  *) die "用法：e2ee-restore-boundary-scan.sh monitor-start|scan" ;;
esac
