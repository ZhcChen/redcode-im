#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/deploy/im-test-1/e2ee-restore-window-control.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-restore-window.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_WINDOW_TEST_STATE:?}"
printf '%s\n' "$*" >>"$state/docker.log"

if [[ "${1:-}" == compose ]]; then
  shift
  compose_path=""
  while (($#)); do
    case "$1" in
      --env-file) shift 2 ;;
      -f) compose_path="$2"; shift 2 ;;
      *) break ;;
    esac
  done
  [[ "$compose_path" == "${E2EE_RESTORE_DRILL_COMPOSE_FILE:?}" ]] || exit 70
  operation="${1:-}"
  shift || true
  case "$operation" in
    config)
      if [[ "${E2EE_WINDOW_TEST_HANG_CONFIG:-0}" == 1 && ! -e "$state/config-hung" ]]; then
        touch "$state/config-hung"
        sleep 5
      fi
      ;;
    up)
      touch "$state/candidate-postgres" "$state/candidate-redis" "$state/candidate-volume"
      if [[ " $* " == *" api-drill "* ]]; then
        touch "$state/candidate-api"
        cp "$state/runtime" "$state/api-runtime"
      fi
      ;;
    exec)
      [[ "${1:-}" != -T ]] || shift
      service="${1:-}"
      shift || true
      [[ "$service" == postgres-drill ]] || exit 70
      sql="$(cat)"
      if [[ "$sql" == *"message_content_audit_mode', 'e2ee'"* ]]; then
        printf 'e2ee\n' >"$state/runtime"
      elif [[ "$sql" == *"message_content_audit_mode', 'plaintext'"* ]]; then
        printf 'plaintext\n' >"$state/runtime"
      fi
      ;;
    stop) rm -f "$state/candidate-api" ;;
    down)
      rm -f "$state/candidate-postgres" "$state/candidate-redis" \
        "$state/candidate-api" "$state/candidate-volume"
      ;;
    *) exit 70 ;;
  esac
  exit 0
fi

case "${1:-}" in
  ps)
    [[ ! -e "$state/candidate-postgres" && ! -e "$state/candidate-redis" &&
       ! -e "$state/candidate-api" ]] || printf 'candidate-container\n'
    ;;
  volume)
    [[ "${2:-}" == ls ]] || exit 70
    [[ ! -e "$state/candidate-volume" ]] || printf 'candidate-volume\n'
    ;;
  *) exit 70 ;;
esac
SH

cat >"$bin_dir/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_WINDOW_TEST_STATE:?}"
url="${!#}"
[[ -e "$state/candidate-api" ]] || exit 22
case "$url" in
  */healthz) printf 'ok' ;;
  */settings/general)
    printf '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"%s"}}\n' \
      "$(cat "$state/api-runtime")"
    ;;
  *) exit 22 ;;
esac
SH

cat >"$tmp_dir/restore-control.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_WINDOW_TEST_STATE:?}"
operation="${1:-}"
printf '%s\n' "$operation" >>"$state/restore.log"
case "$operation" in
  prepare)
    [[ "${E2EE_WINDOW_TEST_FAIL_RESTORE:-0}" != 1 ]] || exit 29
    [[ -s "${E2EE_RESTORE_DUMP_PATH:?}" ]]
    touch "$state/restore-project"
    printf '{"verified":true}\n'
    ;;
  verify) [[ -e "$state/restore-project" ]] && printf '{"verified":true}\n' ;;
  cleanup) rm -f "$state/restore-project" ;;
  *) exit 70 ;;
esac
SH

cat >"$tmp_dir/backup-control.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_WINDOW_TEST_STATE:?}"
printf '%s\n' "${1:-}" >>"$state/backup.log"
[[ "${E2EE_WINDOW_TEST_FAIL_BACKUP:-0}" != 1 ]] || exit 28
[[ "${1:-}" == backup-restore ]]
mkdir -p "${E2EE_DRILL_ARTIFACT_DIR:?}"
printf 'candidate-dump\n' >"$E2EE_DRILL_ARTIFACT_DIR/database.dump"
printf '{}\n' >"${E2EE_DRILL_REPORT_PATH:?}"
SH

chmod +x "$bin_dir/docker" "$bin_dir/curl" "$tmp_dir/restore-control.sh" \
  "$tmp_dir/backup-control.sh"
cat >"$tmp_dir/deploy.env" <<'ENV'
POSTGRES_USER=redcode
POSTGRES_DB=redcode_im
ENV
touch "$tmp_dir/drill.yml"

new_state() {
  local name="$1" state="$tmp_dir/$1"
  mkdir -p "$state/artifacts"
  printf 'plaintext\n' >"$state/runtime"
  printf 'plaintext\n' >"$state/api-runtime"
  : >"$state/docker.log"
  : >"$state/restore.log"
  : >"$state/backup.log"
  printf '%s' "$state"
}

run_control() {
  local state="$1" operation="$2"
  shift 2
  run_control_as "$state" "${state##*/}" "$operation" "$@"
}

run_control_as() {
  local state="$1" run_id="$2" operation="$3"
  shift 3
  PATH="$bin_dir:$PATH" \
  E2EE_WINDOW_TEST_STATE="$state" \
  E2EE_RESTORE_RUN_ID="$run_id" \
  E2EE_RESTORE_API_IMAGE=redcode-im-api:test \
  E2EE_RESTORE_ENV_FILE="$tmp_dir/deploy.env" \
  E2EE_RESTORE_DRILL_COMPOSE_FILE="$tmp_dir/drill.yml" \
  E2EE_RESTORE_CONTROL_PATH="$tmp_dir/restore-control.sh" \
  E2EE_RESTORE_BACKUP_CONTROL_PATH="$tmp_dir/backup-control.sh" \
  E2EE_RESTORE_ARTIFACT_ROOT="$state/artifacts" \
    "$@" "$script" "$operation"
}

assert_clean() {
  local state="$1"
  [[ ! -e "$state/candidate-postgres" && ! -e "$state/candidate-redis" &&
     ! -e "$state/candidate-api" && ! -e "$state/candidate-volume" &&
     ! -e "$state/restore-project" ]]
  [[ -z "$(find "$state/artifacts" -mindepth 1 -print -quit)" ]]
}

success_state="$(new_state success)"
E2EE_RESTORE_ALLOW_CANDIDATE=yes run_control "$success_state" candidate-prepare \
  >"$success_state/prepare.json"
jq -e '.source == "isolated-candidate" and .runtime == "persist/e2ee" and .ready == true' \
  "$success_state/prepare.json" >/dev/null
[[ -e "$success_state/candidate-api" && "$(cat "$success_state/runtime")" == e2ee ]]
E2EE_RESTORE_ALLOW_SWITCH=yes run_control "$success_state" switch \
  >"$success_state/switch.json"
[[ ! -e "$success_state/candidate-api" && -e "$success_state/restore-project" ]]
[[ "$(cat "$success_state/runtime")" == plaintext ]]
run_control "$success_state" verify >/dev/null
run_control "$success_state" cleanup
assert_clean "$success_state"
echo '[e2ee-restore-window-test] candidate prepare/switch/verify/cleanup: pass'

for failure in backup restore; do
  failure_state="$(new_state "$failure-failure")"
  E2EE_RESTORE_ALLOW_CANDIDATE=yes run_control "$failure_state" candidate-prepare >/dev/null
  set +e
  if [[ "$failure" == backup ]]; then
    E2EE_RESTORE_ALLOW_SWITCH=yes E2EE_WINDOW_TEST_FAIL_BACKUP=1 \
      run_control "$failure_state" switch >"$failure_state/output.log" 2>&1
  else
    E2EE_RESTORE_ALLOW_SWITCH=yes E2EE_WINDOW_TEST_FAIL_RESTORE=1 \
      run_control "$failure_state" switch >"$failure_state/output.log" 2>&1
  fi
  status=$?
  set -e
  [[ "$status" -ne 0 ]]
  assert_clean "$failure_state"
  echo "[e2ee-restore-window-test] $failure failure cleanup: pass"
done

cleanup_state="$(new_state idempotent-cleanup)"
E2EE_RESTORE_ALLOW_CANDIDATE=yes run_control "$cleanup_state" candidate-prepare >/dev/null
run_control "$cleanup_state" cleanup
run_control "$cleanup_state" cleanup
assert_clean "$cleanup_state"
echo '[e2ee-restore-window-test] idempotent cleanup: pass'

concurrent_state="$(new_state concurrent-owner)"
E2EE_RESTORE_ALLOW_CANDIDATE=yes \
  run_control_as "$concurrent_state" first-run candidate-prepare >/dev/null
set +e
E2EE_RESTORE_ALLOW_CANDIDATE=yes \
  run_control_as "$concurrent_state" second-run candidate-prepare \
    >"$concurrent_state/second-prepare.log" 2>&1
second_prepare_status=$?
run_control_as "$concurrent_state" second-run cleanup \
  >"$concurrent_state/second-cleanup.log" 2>&1
second_cleanup_status=$?
set -e
[[ "$second_prepare_status" -ne 0 && "$second_cleanup_status" -ne 0 ]]
[[ -e "$concurrent_state/candidate-api" ]]
run_control_as "$concurrent_state" first-run cleanup
assert_clean "$concurrent_state"
echo '[e2ee-restore-window-test] cross-run ownership: fail closed'

timeout_state="$(new_state command-timeout)"
set +e
E2EE_RESTORE_ALLOW_CANDIDATE=yes E2EE_WINDOW_TEST_HANG_CONFIG=1 \
E2EE_RESTORE_WINDOW_COMMAND_TIMEOUT=1 \
  run_control "$timeout_state" candidate-prepare >"$timeout_state/output.log" 2>&1
timeout_status=$?
set -e
[[ "$timeout_status" -ne 0 ]]
assert_clean "$timeout_state"
echo '[e2ee-restore-window-test] command timeout cleanup: pass'

if rg -n 'docker-compose\.yml.*(stop|down|up|update)|(stop|down|up|update).*docker-compose\.yml' \
  "$tmp_dir"/*/docker.log >/dev/null; then
  echo '[e2ee-restore-window-test] 失败：检测到旧主 Compose 写操作' >&2
  exit 1
fi

bash -n "$script"
echo '[e2ee-restore-window-test] 6 类 restore window 场景全部通过'
