#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/scripts/e2ee-restore-live-window.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-restore-live.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir" "$tmp_dir/jdk21/bin" "$tmp_dir/jdk26/bin"

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
    printf '{"identity":{"verified":true},"candidate_snapshot":{"digest":"0123456789abcdef0123456789abcdef"},"restore_snapshot":{"digest":"0123456789abcdef0123456789abcdef"},"snapshots_match":true}\n'
    ;;
  *"'verify'"*)
    [[ -e "$state/restore" ]]
    source_reachable=false
    [[ "${E2EE_RESTORE_LIVE_TEST_SOURCE_NETWORK:-0}" != 1 ]] || source_reachable=true
    printf '{"run_id":"restore-live","project":"e2ee-restore-restore-live","database_marker":"redcode-e2ee-restore:restore-live","api_url":"http://127.0.0.1:18010","database_host":"postgres-restore","redis_host":"redis-restore","isolation":{"api_networks_exclude_source":%s,"database_url_points_restore":true,"redis_urls_point_restore":true,"storage_network_members_exact":true,"ingress_network_members_exact":true},"runtime":"persist/e2ee","verified":true}\n' "$([[ "$source_reachable" == false ]] && printf true || printf false)"
    ;;
  *"'snapshot'"*)
    [[ -e "$state/restore" ]]
    printf '{"identities":3,"devices":4,"key_packages":30,"room_epochs":3,"control_messages":5,"control_receipts":4,"encrypted_messages":7,"attachment_commits":1,"digest":"abcdef0123456789abcdef0123456789"}\n'
    ;;
  *"e2ee-restore-boundary-scan.sh' 'monitor-start'"*)
    touch "$state/monitor"
    ;;
  *"e2ee-restore-boundary-scan.sh' 'scan'"*)
    [[ -e "$state/monitor" && -e "$state/full-complete" ]]
    report_run_id=restore-live
    report_push=placeholder-verified
    [[ "${E2EE_RESTORE_LIVE_TEST_BAD_BOUNDARY_RUN_ID:-0}" != 1 ]] || report_run_id=different-run
    [[ "${E2EE_RESTORE_LIVE_TEST_BAD_PUSH:-0}" != 1 ]] || report_push=unknown
    printf '{"run_id":"%s","db":"ciphertext-only","redis":"marker-free","logs":"marker-free","push":"%s","rustfs":{"content":"ciphertext-only","sha256":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}}\n' \
      "$report_run_id" "$report_push"
    touch "$state/scanned"
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
  *h5-app.test.e2ee.restore-live*)
    printf '{"room_id":"room","message_id":"before"}\n' >"${E2EE_RESTORE_SWITCH_READY_PATH:?}"
    deadline=$((SECONDS + 10))
    while [[ ! -e "${E2EE_RESTORE_SWITCH_DONE_PATH:?}" && "$SECONDS" -lt "$deadline" ]]; do
      sleep 0.05
    done
    [[ -e "$E2EE_RESTORE_SWITCH_DONE_PATH" ]]
    if [[ "${E2EE_RESTORE_LIVE_FULL_SUITE:-0}" == 1 ]]; then
      [[ -e "$state/monitor" ]] || exit 32
    fi
    [[ "${E2EE_RESTORE_LIVE_TEST_FAIL_H5:-0}" != 1 ]] || exit 31
    printf '{"name":"restore-continuity","room_id":"44444444-4444-4444-8444-444444444444","message_proofs":[{"message_id":"00000000-0000-4000-8000-000000000001","plaintext_marker":"u10-restore-before-proof","ciphertext_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","kind":"text"},{"message_id":"00000000-0000-4000-8000-000000000002","plaintext_marker":"u10-restore-after-proof","ciphertext_sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","kind":"text"}],"history_decrypted_after_restore":true,"new_message_decrypted_after_restore":true}\n' \
      >"${E2EE_RESTORE_RECOVERY_EVIDENCE_PATH:?}"
    touch "$state/h5-complete"
    ;;
  *h5-app.test.e2ee.live*)
    [[ "$JAVA_HOME" == *jdk21 ]]
    printf '{"run_id":"restore-live","scenarios":[{"name":"android-h5","room_id":"22222222-2222-4222-8222-222222222222","message_proofs":[]},{"name":"h5-h5","room_id":"11111111-1111-4111-8111-111111111111","message_proofs":[]},{"name":"ios-h5","room_id":"33333333-3333-4333-8333-333333333333","message_proofs":[]}]}\n' \
      >"${E2EE_LIVE_EVIDENCE_PATH:?}"
    touch "$state/full-complete"
    ;;
  *) exit 70 ;;
esac
SH

cat >"$tmp_dir/jdk21/bin/java" <<'SH'
#!/usr/bin/env bash
printf 'openjdk version "21.0.1"\n' >&2
SH
cat >"$tmp_dir/jdk26/bin/java" <<'SH'
#!/usr/bin/env bash
printf 'openjdk version "26.0.1"\n' >&2
SH
chmod +x "$bin_dir"/* "$tmp_dir/jdk21/bin/java" "$tmp_dir/jdk26/bin/java"

run_case() {
  local name="$1" expected="$2"
  shift 2
  local state="$tmp_dir/$name" status
  mkdir -p "$state"
  : >"$state/scp.log"
  : >"$state/ssh.log"
  set +e
  PATH="$bin_dir:$PATH" \
  JAVA_HOME="${E2EE_RESTORE_LIVE_TEST_JAVA_HOME:-$tmp_dir/jdk21}" \
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
    [[ -e "$state/h5-complete" ]] || return 1
    if [[ "${E2EE_RESTORE_LIVE_FULL_SUITE:-0}" == 1 ]]; then
      [[ -e "$state/full-complete" ]] || return 1
      jq -e '.attachment_commits == 1 and .encrypted_messages == 7' \
        "$state/output/post-live-snapshot.json" >/dev/null || return 1
      jq -e '.db == "ciphertext-only" and .redis == "marker-free" and
        .rustfs.content == "ciphertext-only"' "$state/output/boundary-scan.json" >/dev/null || return 1
      [[ -e "$state/scanned" ]] || return 1
      jq -e '(.scenarios | length == 4) and
        ([.scenarios[].name] | sort == ["android-h5", "h5-h5", "ios-h5", "restore-continuity"])' \
        "$state/output/live.json" >/dev/null || return 1
    fi
    jq -e '.history_decrypted_after_restore == true and .new_message_decrypted_after_restore == true' \
      "$state/output/recovery.json" >/dev/null || return 1
    jq -e '.verified == true and .database_host == "postgres-restore" and
      .isolation.api_networks_exclude_source == true' "$state/output/restore-identity.json" >/dev/null || return 1
  else
    [[ "$status" -ne 0 ]] || return 1
  fi
  [[ ! -e "$state/candidate" && ! -e "$state/restore" && ! -e "$state/tunnel" ]] || return 1
  if [[ ! -e "$state/cleaned" ]]; then
    [[ ! -s "$state/ssh.log" ]] || return 1
  fi
  ! rg -n '(^|/)\.env([[:space:]]|$)' "$state/scp.log" >/dev/null || return 1
  echo "[e2ee-restore-live-test] $name: $expected"
}

run_case success pass
E2EE_RESTORE_LIVE_FULL_SUITE=1 run_case full-suite pass
E2EE_RESTORE_LIVE_FULL_SUITE=1 E2EE_RESTORE_LIVE_TEST_JAVA_HOME="$tmp_dir/jdk26" \
  run_case wrong-jdk fail
E2EE_RESTORE_LIVE_FULL_SUITE=1 run_case bad-boundary-run fail \
  E2EE_RESTORE_LIVE_TEST_BAD_BOUNDARY_RUN_ID=1
E2EE_RESTORE_LIVE_FULL_SUITE=1 run_case bad-push fail E2EE_RESTORE_LIVE_TEST_BAD_PUSH=1
E2EE_RESTORE_LIVE_FULL_SUITE=1 run_case source-network fail \
  E2EE_RESTORE_LIVE_TEST_SOURCE_NETWORK=1
run_case switch-failure fail E2EE_RESTORE_LIVE_TEST_FAIL_SWITCH=1
run_case h5-failure fail E2EE_RESTORE_LIVE_TEST_FAIL_H5=1

bash -n "$script"
echo '[e2ee-restore-live-test] 8 个同步/切换/JDK/boundary/network/cleanup 场景全部通过'
