#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/scripts/e2ee-restore-live-window.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-restore-live.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir" "$tmp_dir/jdk/bin"

cat >"$bin_dir/scp" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_RESTORE_LIVE_TEST_STATE:?}"
printf '%s\n' "$*" >>"$state/scp.log"
[[ " $* " != *" .env "* && " $* " != *"/.env "* ]]
SH

cat >"$bin_dir/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_RESTORE_LIVE_TEST_STATE:?}"
if [[ " $* " == *" -N "* ]]; then
  touch "$state/tunnel"
  trap 'rm -f "$state/tunnel"; exit 0' EXIT INT TERM
  while :; do sleep 1; done
fi
command="${!#}"
printf '%s\n' "$command" >>"$state/ssh.log"
case "$command" in
  *"candidate-prepare"*)
    touch "$state/candidate"
    printf '{"source":"isolated-candidate","runtime":"persist/e2ee","ready":true}\n'
    ;;
  *"'switch'"*)
    [[ "${E2EE_RESTORE_LIVE_TEST_FAIL_SWITCH:-0}" != 1 ]] || exit 29
    [[ -e "$state/candidate" ]]
    rm -f "$state/candidate"
    touch "$state/restore"
    printf '{"verified":true}\n'
    ;;
  *"'verify'"*)
    [[ -e "$state/restore" ]]
    printf '{"run_id":"restore-live","project":"e2ee-restore-restore-live","database_marker":"redcode-e2ee-restore:restore-live","api_url":"http://127.0.0.1:18010","database_host":"postgres-restore","redis_host":"redis-restore","source_postgres_connections":0,"source_redis_connections":0,"runtime":"persist/e2ee","verified":true}\n'
    ;;
  *"'cleanup'"*)
    rm -f "$state/candidate" "$state/restore"
    touch "$state/cleaned"
    ;;
  *"chmod +x"*) touch "$state/synced" ;;
  *) exit 70 ;;
esac
SH

cat >"$bin_dir/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_RESTORE_LIVE_TEST_STATE:?}"
url="${!#}"
if [[ "$url" == https://source-runtime/* ]]; then
  printf '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"plaintext"}}\n'
elif [[ "$url" == */healthz ]]; then
  [[ -e "$state/tunnel" ]]
  printf 'ok'
else
  exit 22
fi
SH

cat >"$bin_dir/lsof" <<'SH'
#!/usr/bin/env bash
exit 1
SH

cat >"$bin_dir/make" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_RESTORE_LIVE_TEST_STATE:?}"
case "$*" in
  *h5-app.test.e2ee.restore-live*) ;;
  *) exit 70 ;;
esac
printf '{"room_id":"room","message_id":"before"}\n' >"${E2EE_RESTORE_SWITCH_READY_PATH:?}"
deadline=$((SECONDS + 10))
while [[ ! -e "${E2EE_RESTORE_SWITCH_DONE_PATH:?}" && "$SECONDS" -lt "$deadline" ]]; do
  sleep 0.05
done
[[ -e "$E2EE_RESTORE_SWITCH_DONE_PATH" ]]
[[ "${E2EE_RESTORE_LIVE_TEST_FAIL_H5:-0}" != 1 ]] || exit 31
printf '{"history_decrypted_after_restore":true,"new_message_decrypted_after_restore":true}\n' \
  >"${E2EE_RESTORE_RECOVERY_EVIDENCE_PATH:?}"
printf '{"run_id":"restore-live","scenarios":[]}\n' >"${E2EE_LIVE_EVIDENCE_PATH:?}"
touch "$state/h5-complete"
SH

cat >"$tmp_dir/jdk/bin/java" <<'SH'
#!/usr/bin/env bash
printf 'openjdk version "21.0.1"\n' >&2
SH
chmod +x "$bin_dir"/* "$tmp_dir/jdk/bin/java"

run_case() {
  local name="$1" expected="$2"
  shift 2
  local state="$tmp_dir/$name" status
  mkdir -p "$state"
  : >"$state/scp.log"
  : >"$state/ssh.log"
  set +e
  PATH="$bin_dir:$PATH" \
  JAVA_HOME="$tmp_dir/jdk" \
  MAKE="$bin_dir/make" \
  E2EE_RESTORE_LIVE_TEST_STATE="$state" \
  E2EE_RESTORE_LIVE_RUN_ID=restore-live \
  E2EE_RESTORE_LIVE_API_IMAGE=redcode-im-api:test \
  E2EE_RESTORE_LIVE_REMOTE=im-test-1 \
  E2EE_RESTORE_LIVE_REMOTE_DIR=/srv/redcode-im/deploy/im-test-1 \
  E2EE_RESTORE_LIVE_SOURCE_RUNTIME_URL=https://source-runtime/settings/general \
  E2EE_RESTORE_LIVE_OUTPUT_DIR="$state/output" \
    "$@" "$script" >"$state/output.log" 2>&1
  status=$?
  set -e
  if [[ "$expected" == pass ]]; then
    [[ "$status" == 0 ]] || { cat "$state/output.log" >&2; return 1; }
    [[ -e "$state/h5-complete" ]]
    jq -e '.history_decrypted_after_restore == true and .new_message_decrypted_after_restore == true' \
      "$state/output/recovery.json" >/dev/null
    jq -e '.verified == true and .database_host == "postgres-restore" and
      .source_postgres_connections == 0' "$state/output/restore-identity.json" >/dev/null
  else
    [[ "$status" -ne 0 ]]
  fi
  [[ -e "$state/cleaned" && ! -e "$state/candidate" && ! -e "$state/restore" &&
     ! -e "$state/tunnel" ]]
  ! rg -n '(^|/)\.env([[:space:]]|$)' "$state/scp.log" >/dev/null
  echo "[e2ee-restore-live-test] $name: $expected"
}

run_case success pass
run_case switch-failure fail E2EE_RESTORE_LIVE_TEST_FAIL_SWITCH=1
run_case h5-failure fail E2EE_RESTORE_LIVE_TEST_FAIL_H5=1

bash -n "$script"
echo '[e2ee-restore-live-test] 3 个同步/切换/cleanup 场景全部通过'
