#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/deploy/im-test-1/e2ee-backup-rollout-drill.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-backup-drill.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_TEST_STATE:?}"

inject_after() {
  local boundary="$1" marker
  marker="$state/injected-${boundary}"
  [[ "${E2EE_TEST_TRIGGER:-}" == "$boundary" && ! -e "$marker" ]] || return 0
  touch "$marker"
  case "${E2EE_TEST_ACTION:-fail}" in
    fail) return 23 ;;
    INT|TERM)
      kill -s "$E2EE_TEST_ACTION" "$PPID"
      sleep 0.1
      ;;
    hang) exec sleep 60 ;;
    *) exit 70 ;;
  esac
}

psql_response() {
  local sql
  sql="$(cat)"
  case "$sql" in
    *"SELECT security_review_approved"*) cat "$state/approval" ;;
    *"UPDATE e2ee_runtime_gate SET security_review_approved = TRUE"*)
      inject_after approval-update-before
      printf 't\n' >"$state/approval"
      inject_after approval-update
      ;;
    *"UPDATE e2ee_runtime_gate SET security_review_approved = FALSE"*) printf 'f\n' >"$state/approval" ;;
    *"UPDATE e2ee_runtime_gate SET security_review_approved = TRUE"*) printf 't\n' >"$state/approval" ;;
    *"MAX(name)"*) printf '%s\n' '20260805201000_message_attachment_commit_leases.sql' ;;
    *"WITH required(name)"*) printf '\n' ;;
    *"WITH snapshot AS"*)
      printf '%s\n' '{"account_identities":1,"devices":2,"active_devices":2,"revoked_devices":0,"pending_devices":0,"key_packages":2,"available_key_packages":2,"room_epochs":1,"control_messages":1,"control_receipts":1,"encrypted_messages":1,"rcml_messages":1,"message_parts":1,"attachment_commits":1,"runtime_gate":{"state":"plaintext","required_coverage_percent":100,"key_package_low_watermark":1,"security_review_approved":false},"digest":"same","orphan_control_senders":0,"orphan_room_epochs":0,"orphan_attachment_rooms":0}'
      ;;
    *) printf '\n' ;;
  esac
}

if [[ "${1:-}" == compose ]]; then
  shift
  [[ "${1:-}" != -f ]] || shift 2
  case "${1:-}" in
    config) exit 0 ;;
    ps)
      shift
      quiet=0
      while (($#)); do
        case "$1" in
          -q) quiet=1 ;;
          --status) shift ;;
          postgres-drill)
            ((quiet == 0)) && printf 'postgres-drill running\n' || printf 'postgres-id\n'
            ;;
          api-drill)
            if [[ "$(cat "$state/api")" == running ]]; then
              ((quiet == 0)) && printf 'api-drill running\n' || printf 'api-id\n'
            fi
            ;;
        esac
        shift
      done
      ;;
    stop)
      inject_after api-stop-before
      printf 'stopped\n' >"$state/api"
      inject_after api-stop
      ;;
    start)
      printf 'running\n' >"$state/api"
      ;;
    up)
      printf 'running\n' >"$state/api"
      ;;
    exec)
      shift
      [[ "${1:-}" != -T ]] || shift
      service="$1"
      shift
      command_text="$*"
      if [[ "$service" == postgres-drill && "$command_text" == *psql* ]]; then
        psql_response
      elif [[ "$command_text" == *pg_dump* ]]; then
        head -c 4096 /dev/zero
      elif [[ "$command_text" == *pg_restore* ]]; then
        bytes="$(wc -c | tr -d ' ')"
        ((bytes > 1024))
      fi
      ;;
    *) exit 70 ;;
  esac
  exit $?
fi

case "${1:-}" in
  inspect)
    printf 'sha256:test-image\n'
    ;;
  container)
    [[ "$2" == inspect ]]
    [[ -e "$state/container" ]]
    ;;
  volume)
    case "$2" in
      create)
        inject_after volume-create-before
        touch "$state/volume"
        inject_after volume-create
        [[ "${E2EE_TEST_TRIGGER:-}" != volume-create || "${E2EE_TEST_ACTION:-}" != fail ]] || exit 23
        printf '%s\n' "$3"
        ;;
      inspect) [[ -e "$state/volume" ]] ;;
      rm)
        inject_after volume-remove || exit $?
        rm -f "$state/volume"
        ;;
      *) exit 70 ;;
    esac
    ;;
  run)
    inject_after container-create-before
    touch "$state/container"
    inject_after container-create || exit $?
    printf 'container-id\n'
    ;;
  exec)
    shift
    if [[ "$*" == *pg_isready* ]]; then
      [[ -e "$state/container" ]]
    elif [[ "$*" == *pg_restore* ]]; then
      cat >/dev/null
    elif [[ "$*" == *psql* ]]; then
      psql_response
    fi
    ;;
  rm)
    inject_after container-remove || exit $?
    rm -f "$state/container"
    ;;
  *) exit 70 ;;
esac
SH

cat >"$bin_dir/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_TEST_STATE:?}"
url="${!#}"
case "$url" in
  */healthz)
    [[ "$(cat "$state/api")" == running ]]
    printf 'ok'
    ;;
  */settings/general)
    audit="$(cat "$state/runtime")"
    printf '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"%s"}}\n' "$audit"
    ;;
  */prepare) printf '%s\n' '{"state":"prepare","readiness":{"ready":true,"blocking_reasons":[]}}' ;;
  */active)
    printf 'e2ee\n' >"$state/runtime"
    printf '%s\n' '{"state":"active","content_audit_mode":"e2ee"}'
    ;;
  */gate) printf '%s\n' '{"state":"active","content_audit_mode":"e2ee"}' ;;
  */rollback)
    printf 'plaintext\n' >"$state/runtime"
    printf '%s\n' '{"state":"plaintext","content_audit_mode":"plaintext"}'
    ;;
  *) exit 22 ;;
esac
SH

chmod +x "$bin_dir/docker" "$bin_dir/curl"

new_state() {
  local name="$1" state
  state="$tmp_dir/$name"
  mkdir -p "$state/artifacts"
  printf 'running\n' >"$state/api"
  printf 'f\n' >"$state/approval"
  printf 'plaintext\n' >"$state/runtime"
  printf '%s' "$state"
}

assert_clean() {
  local state="$1"
  if [[ "$(cat "$state/api")" != running || "$(cat "$state/approval")" != f ||
        "$(cat "$state/runtime")" != plaintext || -e "$state/container" ||
        -e "$state/volume" || -e "$state/artifacts/recovery-state" ||
        -e "$state/artifacts.lock" ]]; then
    printf '[e2ee-backup-drill-test] 状态未清理：api=%s approval=%s runtime=%s container=%s volume=%s recovery=%s\n' \
      "$(cat "$state/api")" "$(cat "$state/approval")" "$(cat "$state/runtime")" \
      "$([[ -e "$state/container" ]] && printf yes || printf no)" \
      "$([[ -e "$state/volume" ]] && printf yes || printf no)" \
      "$([[ -e "$state/artifacts/recovery-state" ]] && printf yes || printf no)" >&2
    return 1
  fi
}

run_interrupted_case() {
  local name="$1" mode="$2" boundary="$3" action="$4"
  local state status
  state="$(new_state "$name")"
  set +e
  PATH="$bin_dir:$PATH" \
  E2EE_TEST_STATE="$state" \
  E2EE_TEST_TRIGGER="$boundary" \
  E2EE_TEST_ACTION="$action" \
  E2EE_DRILL_RUN_ID="$name" \
  E2EE_DRILL_ARTIFACT_DIR="$state/artifacts" \
  E2EE_DRILL_REPORT_PATH="$state/artifacts/report.json" \
  E2EE_DRILL_ALLOW_API_STOP=yes \
  E2EE_DRILL_ALLOW_ACTIVE=yes \
  E2EE_DRILL_ADMIN_TOKEN=test-token \
    "$script" "$mode" >"$state/output.log" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]] || {
    cat "$state/output.log" >&2
    echo "[e2ee-backup-drill-test] $name 应失败" >&2
    exit 1
  }
  case "$action" in
    INT) [[ "$status" == 130 ]] ;;
    TERM) [[ "$status" == 143 ]] ;;
  esac
  assert_clean "$state"
  echo "[e2ee-backup-drill-test] $name: cleanup pass"
}

for action in fail INT TERM; do
  action_label="$(printf '%s' "$action" | tr '[:upper:]' '[:lower:]')"
  run_interrupted_case "api-stop-$action_label" backup-restore api-stop "$action"
  run_interrupted_case "volume-create-$action_label" backup-restore volume-create "$action"
  run_interrupted_case "container-create-$action_label" backup-restore container-create "$action"
  run_interrupted_case "approval-update-$action_label" full approval-update "$action"
done
for boundary in api-stop volume-create container-create approval-update; do
  mode=backup-restore
  [[ "$boundary" != approval-update ]] || mode=full
  run_interrupted_case "${boundary}-before-fail" "$mode" "${boundary}-before" fail
done

success_state="$(new_state full-success)"
PATH="$bin_dir:$PATH" \
E2EE_TEST_STATE="$success_state" \
E2EE_DRILL_RUN_ID=full-success \
E2EE_DRILL_ARTIFACT_DIR="$success_state/artifacts" \
E2EE_DRILL_REPORT_PATH="$success_state/artifacts/report.json" \
E2EE_DRILL_ALLOW_API_STOP=yes \
E2EE_DRILL_ALLOW_ACTIVE=yes \
E2EE_DRILL_ADMIN_TOKEN=test-token \
  "$script" full >"$success_state/output.log" 2>&1
assert_clean "$success_state"
jq -e '.backup_restore.snapshots_match == true and .rollout.rollback == true' \
  "$success_state/artifacts/report.json" >/dev/null
echo "[e2ee-backup-drill-test] full success: pass"

cleanup_failure_state="$(new_state cleanup-delete-failure)"
touch "$cleanup_failure_state/container" "$cleanup_failure_state/volume"
set +e
PATH="$bin_dir:$PATH" \
E2EE_TEST_STATE="$cleanup_failure_state" \
E2EE_TEST_TRIGGER=container-remove \
E2EE_TEST_ACTION=fail \
E2EE_DRILL_RUN_ID=cleanup-delete-failure \
E2EE_DRILL_ARTIFACT_DIR="$cleanup_failure_state/artifacts" \
  "$script" recover >"$cleanup_failure_state/first.log" 2>&1
first_status=$?
set -e
[[ "$first_status" -ne 0 && -e "$cleanup_failure_state/container" ]]
set +e
PATH="$bin_dir:$PATH" \
E2EE_TEST_STATE="$cleanup_failure_state" \
E2EE_DRILL_RUN_ID=cleanup-delete-failure \
E2EE_DRILL_ARTIFACT_DIR="$cleanup_failure_state/artifacts" \
  "$script" recover >"$cleanup_failure_state/second.log" 2>&1
second_status=$?
set -e
if [[ "$second_status" -ne 0 ]]; then
  cat "$cleanup_failure_state/second.log" >&2
  echo "[e2ee-backup-drill-test] 二次 recover 应通过" >&2
  exit 1
fi
assert_clean "$cleanup_failure_state"
echo "[e2ee-backup-drill-test] cleanup failure + retry: pass"

timeout_state="$(new_state cleanup-timeout)"
touch "$timeout_state/container"
set +e
PATH="$bin_dir:$PATH" \
E2EE_TEST_STATE="$timeout_state" \
E2EE_TEST_TRIGGER=container-remove \
E2EE_TEST_ACTION=hang \
E2EE_DRILL_CLEANUP_HARD_TIMEOUT=1 \
E2EE_DRILL_RUN_ID=cleanup-timeout \
E2EE_DRILL_ARTIFACT_DIR="$timeout_state/artifacts" \
  "$script" recover >"$timeout_state/first.log" 2>&1
timeout_status=$?
set -e
[[ "$timeout_status" -ne 0 && -e "$timeout_state/container" ]]
PATH="$bin_dir:$PATH" \
E2EE_TEST_STATE="$timeout_state" \
E2EE_DRILL_CLEANUP_HARD_TIMEOUT=1 \
E2EE_DRILL_RUN_ID=cleanup-timeout \
E2EE_DRILL_ARTIFACT_DIR="$timeout_state/artifacts" \
  "$script" recover >"$timeout_state/second.log" 2>&1
assert_clean "$timeout_state"
echo "[e2ee-backup-drill-test] cleanup timeout + retry: pass"

PATH="$bin_dir:$PATH" \
E2EE_TEST_STATE="$cleanup_failure_state" \
E2EE_DRILL_RUN_ID=cleanup-delete-failure \
E2EE_DRILL_ARTIFACT_DIR="$cleanup_failure_state/artifacts" \
  "$script" recover >"$cleanup_failure_state/third.log" 2>&1
assert_clean "$cleanup_failure_state"
echo "[e2ee-backup-drill-test] repeated cleanup: pass"

for invalid_timeout in 0 invalid 301; do
  set +e
  E2EE_DRILL_CLEANUP_HARD_TIMEOUT="$invalid_timeout" "$script" preflight >/dev/null 2>&1
  invalid_status=$?
  set -e
  [[ "$invalid_status" == 64 ]]
done
echo "[e2ee-backup-drill-test] invalid timeout values: fail closed"

lock_state="$(new_state active-lock)"
mkdir "$lock_state/artifacts.lock"
printf '%s\n' "$$" >"$lock_state/artifacts.lock/pid"
set +e
PATH="$bin_dir:$PATH" E2EE_TEST_STATE="$lock_state" \
E2EE_DRILL_RUN_ID=active-lock E2EE_DRILL_ARTIFACT_DIR="$lock_state/artifacts" \
  "$script" recover >/dev/null 2>&1
lock_status=$?
set -e
[[ "$lock_status" == 73 && -e "$lock_state/artifacts.lock" ]]
rm -rf "$lock_state/artifacts.lock"
echo "[e2ee-backup-drill-test] active run lock: fail closed"

stale_lock_state="$(new_state stale-lock)"
mkdir "$stale_lock_state/artifacts.lock"
printf '%s\n' '99999999' >"$stale_lock_state/artifacts.lock/pid"
PATH="$bin_dir:$PATH" E2EE_TEST_STATE="$stale_lock_state" \
E2EE_DRILL_RUN_ID=stale-lock E2EE_DRILL_ARTIFACT_DIR="$stale_lock_state/artifacts" \
  "$script" recover >/dev/null 2>&1
assert_clean "$stale_lock_state"
echo "[e2ee-backup-drill-test] stale run lock: recovered"

bash -n "$script"
echo "[e2ee-backup-drill-test] 25 个 success/failure/signal/recover 场景全部通过"
