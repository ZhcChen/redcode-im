#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
driver="$root_dir/tests/scripts/run-e2ee-cross-client-live.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-isolated-live.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir" "$tmp_dir/jdk/bin"

cat >"$bin_dir/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_ISOLATED_TEST_STATE:?}"
if [[ " $* " == *" -N "* ]]; then
  touch "$state/tunnel"
  trap 'rm -f "$state/tunnel"; exit 0' INT TERM EXIT
  while :; do sleep 1; done
fi
operation="${!#}"
case "$operation" in
  *"'verify'"*)
    if [[ "${E2EE_ISOLATED_TEST_IDENTITY:-valid}" == valid ]]; then
      printf '%s\n' '{"run_id":"restore-run","project":"e2ee-restore-restore-run","database_marker":"redcode-e2ee-restore:restore-run","api_container_id":"api-id","api_url":"http://127.0.0.1:18010","database_host":"postgres-restore","redis_host":"redis-restore","isolation":{"api_networks_exclude_source":true,"database_url_points_restore":true,"redis_urls_point_restore":true,"storage_network_members_exact":true,"ingress_network_members_exact":true},"runtime":"persist/e2ee","verified":true}'
    else
      printf '%s\n' '{"run_id":"restore-run","project":"wrong-project","database_marker":"wrong","api_url":"http://127.0.0.1:18010","database_host":"postgres","redis_host":"redis","isolation":{"api_networks_exclude_source":false},"runtime":"persist/e2ee","verified":true}'
    fi
    ;;
  *"'rollback'"*) printf 'rollback\n' >>"$state/control.log" ;;
  *"'cleanup'"*)
    printf 'cleanup\n' >>"$state/control.log"
    touch "$state/cleaned"
    ;;
  *) exit 70 ;;
esac
SH

cat >"$bin_dir/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_ISOLATED_TEST_STATE:?}"
url="${!#}"
if [[ "$url" == *source-runtime* ]]; then
  printf '%s\n' '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"plaintext"}}'
elif [[ "$url" == */healthz ]]; then
  [[ -e "$state/tunnel" ]]
  printf 'ok'
else
  [[ -e "$state/tunnel" ]]
  printf '%s\n' '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"e2ee"}}'
fi
SH

cat >"$bin_dir/lsof" <<'SH'
#!/usr/bin/env bash
exit 1
SH

cat >"$bin_dir/make" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${E2EE_ISOLATED_TEST_MAKE:-success}" == success ]] || exit 23
printf '%s\n' '{"run_id":"live-run","scenarios":[]}' >"${E2EE_LIVE_EVIDENCE_PATH:?}"
SH

cat >"$tmp_dir/jdk/bin/java" <<'SH'
#!/usr/bin/env bash
printf '%s\n' 'openjdk version "21.0.1"' >&2
SH
chmod +x "$bin_dir/ssh" "$bin_dir/curl" "$bin_dir/lsof" "$bin_dir/make" "$tmp_dir/jdk/bin/java"

run_case() {
  local name="$1" identity="$2" make_mode="$3" expected="$4"
  local state="$tmp_dir/$name" status
  mkdir -p "$state"
  : >"$state/control.log"
  set +e
  PATH="$bin_dir:$PATH" \
  JAVA_HOME="$tmp_dir/jdk" \
  MAKE="$bin_dir/make" \
  E2EE_ISOLATED_TEST_STATE="$state" \
  E2EE_ISOLATED_TEST_IDENTITY="$identity" \
  E2EE_ISOLATED_TEST_MAKE="$make_mode" \
  E2EE_LIVE_ISOLATED_RESTORE=1 \
  E2EE_LIVE_RESTORE_REMOTE=im-test-1 \
  E2EE_LIVE_RESTORE_CONTROL_PATH=/srv/redcode-im/deploy/im-test-1/e2ee-restore-control.sh \
  E2EE_LIVE_RESTORE_RUN_ID=restore-run \
  E2EE_LIVE_SOURCE_RUNTIME_URL=http://source-runtime/settings/general \
  E2EE_LIVE_RUN_ID=live-run \
  E2EE_LIVE_EVIDENCE_PATH="$state/evidence.json" \
  H5_APP_API_BASE_URL=http://127.0.0.1:18010 \
  H5_APP_WS_URL=ws://127.0.0.1:18010/ws \
    "$driver" >"$state/output.log" 2>&1
  status=$?
  set -e
  if [[ "$expected" == pass ]]; then
    [[ "$status" == 0 ]] || {
      cat "$state/output.log" >&2
      return 1
    }
  else
    [[ "$status" != 0 ]] || return 1
  fi
  [[ -e "$state/cleaned" && ! -e "$state/tunnel" ]]
  [[ "$(sed -n '$p' "$state/control.log")" == cleanup ]]
  echo "[e2ee-isolated-live-test] $name: $expected"
}

run_case success valid success pass
run_case identity-tampered invalid success fail
run_case live-failure valid failure fail

bash -n "$driver"
echo "[e2ee-isolated-live-test] 3 个 identity/tunnel/cleanup 场景全部通过"
