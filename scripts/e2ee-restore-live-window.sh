#!/usr/bin/env bash
# 在隔离 candidate 与 restore API 之间切换，并保持 H5 协议状态连续。
set -euo pipefail
umask 077

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
remote="${E2EE_RESTORE_LIVE_REMOTE:-im-test-1}"
remote_dir="${E2EE_RESTORE_LIVE_REMOTE_DIR:-/root/redcode-im/deploy/im-test-1}"
run_id="${E2EE_RESTORE_LIVE_RUN_ID:-restore-$(date -u +%Y%m%dT%H%M%SZ)}"
api_image="${E2EE_RESTORE_LIVE_API_IMAGE:-}"
source_runtime_url="${E2EE_RESTORE_LIVE_SOURCE_RUNTIME_URL:-https://im-test-1.codelib.cc/settings/general}"
output_dir="${E2EE_RESTORE_LIVE_OUTPUT_DIR:-$root_dir/.artifacts/e2ee-restore-live/$run_id}"
make_command="${MAKE:-make}"
window_control="$remote_dir/e2ee-restore-window-control.sh"
ready_path="$output_dir/ready.json"
done_path="$output_dir/switched"
recovery_path="$output_dir/recovery.json"
live_evidence_path="$output_dir/live.json"
h5_log_path="$output_dir/h5.log"
tunnel_pid=""
h5_pid=""
cleanup_started=0

log() {
  printf '[e2ee-restore-live] %s\n' "$*" >&2
}

die() {
  log "失败：$*"
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

[[ "$run_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || die "run_id 无效"
[[ "$api_image" =~ ^[A-Za-z0-9][A-Za-z0-9._/@:-]{0,127}$ ]] || die "API image 无效"
[[ "$remote" =~ ^([A-Za-z0-9._][A-Za-z0-9._-]*@)?[A-Za-z0-9._][A-Za-z0-9._-]*$ ]] ||
  die "remote 无效"
for path in "$remote_dir" "$output_dir"; do
  [[ "$path" == /* && "$path" =~ ^/[A-Za-z0-9._/-]+$ ]] || die "路径必须是安全绝对路径：$path"
done
[[ "$source_runtime_url" == https://* ]] || die "旧主 runtime URL 必须使用 HTTPS"

for command in curl jq lsof scp ssh "$make_command"; do require_command "$command"; done

mkdir -p "$output_dir"
rm -f "$ready_path" "$done_path" "$recovery_path" "$live_evidence_path" "$h5_log_path"

remote_control() {
  local operation="$1" allow=""
  case "$operation" in
    candidate-prepare) allow="E2EE_RESTORE_ALLOW_CANDIDATE=yes" ;;
    switch) allow="E2EE_RESTORE_ALLOW_SWITCH=yes" ;;
    verify|cleanup) ;;
    *) die "未知远端操作：$operation" ;;
  esac
  ssh -o BatchMode=yes -o ConnectTimeout=10 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
    "$remote" \
    "E2EE_RESTORE_RUN_ID='$run_id' E2EE_RESTORE_API_IMAGE='$api_image' $allow '$window_control' '$operation'"
}

assert_source_plaintext() {
  local runtime
  runtime="$(curl --connect-timeout 5 --max-time 15 -fsS "$source_runtime_url")" || return 1
  jq -e '.message_runtime.server_storage_mode == "persist" and
    .message_runtime.content_audit_mode == "plaintext"' <<<"$runtime" >/dev/null
}

finish() {
  local exit_code="${1:-$?}" cleanup_failed=0
  [[ "$cleanup_started" == 0 ]] || exit "$exit_code"
  cleanup_started=1
  trap - EXIT INT TERM
  if [[ -n "$h5_pid" ]] && kill -0 "$h5_pid" 2>/dev/null; then
    kill "$h5_pid" 2>/dev/null || true
    wait "$h5_pid" 2>/dev/null || true
  fi
  if [[ -n "$tunnel_pid" ]]; then
    kill "$tunnel_pid" 2>/dev/null || true
    wait "$tunnel_pid" 2>/dev/null || true
  fi
  remote_control cleanup >/dev/null 2>&1 || cleanup_failed=1
  assert_source_plaintext || cleanup_failed=1
  if [[ "$cleanup_failed" != 0 ]]; then
    log "远端资源或旧主 runtime 清理终验失败"
    exit_code=1
  else
    log "candidate、restore、SSH tunnel 已清理，旧主保持 persist/plaintext"
  fi
  exit "$exit_code"
}
trap 'finish $?' EXIT
trap 'finish 130' INT
trap 'finish 143' TERM

deploy_files=(
  "$root_dir/deploy/im-test-1/docker-compose.e2ee-drill.yml"
  "$root_dir/deploy/im-test-1/docker-compose.e2ee-restore.yml"
  "$root_dir/deploy/im-test-1/e2ee-backup-rollout-drill.sh"
  "$root_dir/deploy/im-test-1/e2ee-restore-control.sh"
  "$root_dir/deploy/im-test-1/e2ee-restore-window-control.sh"
)
for file in "${deploy_files[@]}"; do [[ -f "$file" ]] || die "缺少部署文件：$file"; done
scp -q "${deploy_files[@]}" "$remote:$remote_dir/"
ssh -o BatchMode=yes -o ConnectTimeout=10 "$remote" \
  "chmod +x '$remote_dir/e2ee-backup-rollout-drill.sh' '$remote_dir/e2ee-restore-control.sh' '$window_control'"
log "已同步隔离恢复控制文件（未同步 .env）"

candidate_identity="$(remote_control candidate-prepare)"
jq -e '.source == "isolated-candidate" and .runtime == "persist/e2ee" and .ready == true' \
  <<<"$candidate_identity" >/dev/null || die "candidate identity 验证失败"

if lsof -tiTCP:18010 -sTCP:LISTEN >/dev/null 2>&1; then
  die "本机 18010 已被占用，请先停止占用进程"
fi
ssh -N -o ExitOnForwardFailure=yes -o BatchMode=yes -o ConnectTimeout=10 \
  -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
  -L 127.0.0.1:18010:127.0.0.1:18010 "$remote" &
tunnel_pid=$!
for _ in $(seq 1 100); do
  [[ "$(curl --connect-timeout 1 --max-time 2 -fsS http://127.0.0.1:18010/healthz 2>/dev/null || true)" == ok ]] && break
  kill -0 "$tunnel_pid" 2>/dev/null || die "SSH tunnel 提前退出"
  sleep 0.1
done
[[ "$(curl --connect-timeout 2 --max-time 5 -fsS http://127.0.0.1:18010/healthz 2>/dev/null || true)" == ok ]] ||
  die "candidate API 未通过 tunnel 就绪"

H5_APP_API_BASE_URL=http://127.0.0.1:18010 \
VITE_API_BASE_URL=http://127.0.0.1:18010 \
VITE_WS_URL=ws://127.0.0.1:18010/ws \
E2EE_LIVE_RUN_ID="$run_id" \
E2EE_LIVE_EVIDENCE_PATH="$live_evidence_path" \
E2EE_RESTORE_SWITCH_ENABLED=1 \
E2EE_RESTORE_SWITCH_READY_PATH="$ready_path" \
E2EE_RESTORE_SWITCH_DONE_PATH="$done_path" \
E2EE_RESTORE_RECOVERY_EVIDENCE_PATH="$recovery_path" \
  "$make_command" -C "$root_dir" h5-app.test.e2ee.restore-live >"$h5_log_path" 2>&1 &
h5_pid=$!

ready_deadline=$((SECONDS + 180))
while [[ ! -s "$ready_path" && "$SECONDS" -lt "$ready_deadline" ]]; do
  kill -0 "$h5_pid" 2>/dev/null || {
    cat "$h5_log_path" >&2
    die "H5 restore switch 场景在 ready 前退出"
  }
  sleep 0.1
done
[[ -s "$ready_path" ]] || die "等待 H5 restore ready marker 超时"
jq -e '.room_id | type == "string"' "$ready_path" >/dev/null || die "H5 ready marker 损坏"

remote_control switch >"$output_dir/switch.json"
restore_identity="$(remote_control verify)"
jq -e --arg run_id "$run_id" \
  '.verified == true and .run_id == $run_id and
    .database_marker == ("redcode-e2ee-restore:" + $run_id) and
    .database_host == "postgres-restore" and .redis_host == "redis-restore" and
    .source_postgres_connections == 0 and .source_redis_connections == 0 and
    .runtime == "persist/e2ee" and .api_url == "http://127.0.0.1:18010"' \
  <<<"$restore_identity" >/dev/null || die "restore identity 验证失败"
jq -S . <<<"$restore_identity" >"$output_dir/restore-identity.json"
printf 'switched\n' >"$done_path"

set +e
wait "$h5_pid"
h5_status=$?
set -e
h5_pid=""
if [[ "$h5_status" != 0 ]]; then
  cat "$h5_log_path" >&2
  die "H5 restore switch live 失败，exit=$h5_status"
fi
jq -e '.history_decrypted_after_restore == true and
  .new_message_decrypted_after_restore == true' "$recovery_path" >/dev/null ||
  die "恢复前后密文证据缺失"
remote_control verify >/dev/null
log "恢复前历史密文与恢复后新密文均已由同一 H5 协议状态解密"
