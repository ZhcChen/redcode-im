#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/scripts/h5-release-candidate-window.sh"
temp_root="${TMPDIR:-/tmp}"
tmp_dir="$(mktemp -d "${temp_root%/}/redcode-h5-candidate-test.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
count_file="${H5_TEST_SSH_COUNT:?}"
count=0
[[ ! -f "$count_file" ]] || count="$(cat "$count_file")"
count=$((count + 1))
printf '%s' "$count" >"$count_file"
printf '%s\n' "$*" >>"${H5_TEST_SSH_COMMANDS:?}"
command="${!#}"
case "${H5_TEST_SSH_MODE:-success}" in
  fail-once) [[ "$count" -gt 1 ]] || exit 255 ;;
  fail-always) exit 255 ;;
  hang) exec sleep 60 ;;
  preflight-fail) [[ "$command" == *"restored=0"* ]] || exit 1 ;;
  success) ;;
  *) exit 70 ;;
esac
if [[ "$command" == *"restored=0"* || "$command" == *"mkdir '"*".lock'"* ]]; then
  bash -c "$command"
fi
SH

cat >"$bin_dir/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
url="${!#}"
case "$url" in
  *settings/general)
    printf 'runtime\n' >>"${H5_TEST_CURL_CALLS:?}"
    if [[ "${H5_TEST_RUNTIME_MODE:-plaintext}" == plaintext ]]; then
      printf '%s\n' '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"plaintext"}}'
    else
      printf '%s\n' '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"e2ee"}}'
    fi
    ;;
  *h5-candidate/*)
    printf 'candidate\n' >>"${H5_TEST_CURL_CALLS:?}"
    status="${H5_TEST_CANDIDATE_STATUS:-404}"
    output=""
    for ((i = 1; i <= $#; i++)); do
      if [[ "${!i}" == "-o" ]]; then
        j=$((i + 1))
        output="${!j}"
      fi
    done
    [[ "$status" != error ]] || exit 22
    [[ -z "$output" ]] || {
      if [[ "$status" == 200 ]]; then
        printf '%s\n' '<title>RedCode IM H5</title>' >"$output"
      elif [[ "$status" == admin ]]; then
        printf '%s\n' '<title>IM 管理后台</title>' >"$output"
      else
        : >"$output"
      fi
    }
    [[ "$status" != admin ]] || status=200
    printf '%s' "$status"
    ;;
  *)
    printf 'admin\n' >>"${H5_TEST_CURL_CALLS:?}"
    if [[ "${H5_TEST_ADMIN_MODE:-healthy}" == healthy ]]; then
      printf '%s\n' '<title>IM 管理后台</title>'
    else
      exit 22
    fi
    ;;
esac
SH

chmod +x "$bin_dir/ssh" "$bin_dir/curl"

cat >"$bin_dir/bun" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$bin_dir/scp" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$bin_dir/caddy" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "${H5_TEST_CADDY_FAIL_ONCE_FILE:-}" &&
      ! -f "$H5_TEST_CADDY_FAIL_ONCE_FILE" ]]; then
  touch "$H5_TEST_CADDY_FAIL_ONCE_FILE"
  exit 1
fi
[[ "$1" == validate && "$2" == --config && -f "$3" ]]
SH
cat >"$bin_dir/systemctl" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat >"$bin_dir/rm" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${H5_TEST_REMOTE_RM_LOG:-}" ]] || printf '%s\n' "$*" >>"$H5_TEST_REMOTE_RM_LOG"
if [[ -n "${H5_TEST_RM_FAIL_ONCE_FILE:-}" && ! -f "$H5_TEST_RM_FAIL_ONCE_FILE" &&
      "$*" == *"redcode-h5-candidate"* ]]; then
  touch "$H5_TEST_RM_FAIL_ONCE_FILE"
  exit 1
fi
/bin/rm "$@"
SH
chmod +x "$bin_dir/bun" "$bin_dir/scp" "$bin_dir/caddy" "$bin_dir/systemctl" "$bin_dir/rm"

run_case() {
  local name="$1"
  local expected="$2"
  local ssh_mode="$3"
  local candidate_status="${4:-404}"
  local runtime_mode="${5:-plaintext}"
  local admin_mode="${6:-healthy}"
  local partial_remote_failure="${7:-no}"
  local partial_delete_failure="${8:-no}"
  local hard_timeout="${9:-5}"
  local case_dir="$tmp_dir/$name"
  local remote_dist="$case_dir/remote/srv/redcode-h5-candidate"
  local owner_token="owner-$name"
  local remote_lock="${remote_dist}.lock"
  local remote_caddy="$case_dir/remote/etc/caddy/Caddyfile"
  local remote_temp_base="$case_dir/remote/tmp/redcode-h5-candidate.Caddyfile"
  local remote_temp="${remote_temp_base}.${owner_token}"
  mkdir -p "$remote_dist" "${remote_dist}.upload.${owner_token}" \
    "${remote_dist}.upload.other" "$remote_lock" \
    "${remote_caddy%/*}" "${remote_temp%/*}"
  printf '%s\n' "$owner_token" >"$remote_lock/owner"
  printf '%s\n' 'candidate h5-candidate route' >"$remote_caddy"
  printf '%s\n' 'original admin route' >"${remote_caddy}.h5-candidate.bak"
  printf '%s\n' 'temporary candidate config' >"$remote_temp"
  : >"$case_dir/ssh-count"
  : >"$case_dir/ssh-commands"
  : >"$case_dir/curl-calls"
  : >"$case_dir/remote-rm.log"
  set +e
  PATH="$bin_dir:$PATH" \
  H5_TEST_SSH_COUNT="$case_dir/ssh-count" \
  H5_TEST_SSH_COMMANDS="$case_dir/ssh-commands" \
  H5_TEST_CURL_CALLS="$case_dir/curl-calls" \
  H5_TEST_SSH_MODE="$ssh_mode" \
  H5_TEST_CANDIDATE_STATUS="$candidate_status" \
  H5_TEST_RUNTIME_MODE="$runtime_mode" \
  H5_TEST_ADMIN_MODE="$admin_mode" \
  H5_TEST_CADDY_FAIL_ONCE_FILE="$(
    [[ "$partial_remote_failure" == yes ]] && printf '%s' "$case_dir/caddy-failed" || true
  )" \
  H5_TEST_RM_FAIL_ONCE_FILE="$(
    [[ "$partial_delete_failure" == yes ]] && printf '%s' "$case_dir/rm-failed" || true
  )" \
  H5_TEST_REMOTE_RM_LOG="$case_dir/remote-rm.log" \
  H5_RELEASE_CLEANUP_RETRIES=3 \
  H5_RELEASE_CLEANUP_RETRY_DELAY=0 \
  H5_RELEASE_CLEANUP_HARD_TIMEOUT="$hard_timeout" \
  H5_RELEASE_REMOTE_DIST="$remote_dist" \
  H5_RELEASE_REMOTE_LOCK="$remote_lock" \
  H5_RELEASE_REMOTE_CADDY="$remote_caddy" \
  H5_RELEASE_REMOTE_TEMP_CADDY="$remote_temp_base" \
  H5_RELEASE_OWNER_TOKEN="$owner_token" \
    "$script" recover >"$case_dir/output.log" 2>&1
  status=$?
  set -e
  if [[ "$expected" == pass && "$status" -ne 0 ]]; then
    cat "$case_dir/output.log" >&2
    echo "[h5-candidate-test] $name 应通过" >&2
    exit 1
  fi
  if [[ "$expected" == fail && "$status" -eq 0 ]]; then
    cat "$case_dir/output.log" >&2
    echo "[h5-candidate-test] $name 应失败" >&2
    exit 1
  fi
  for call in admin candidate runtime; do
    grep -Fxq "$call" "$case_dir/curl-calls" || {
      cat "$case_dir/output.log" >&2
      echo "[h5-candidate-test] $name 未执行 $call 验证" >&2
      exit 1
    }
  done
  grep -q 'redcode-h5-candidate' "$case_dir/ssh-commands"
  grep -q 'h5-candidate.bak' "$case_dir/ssh-commands"
  if [[ "$expected" == pass ]]; then
    ! grep -q h5-candidate "$remote_caddy"
    [[ ! -e "$remote_dist" && ! -e "${remote_dist}.upload.${owner_token}" &&
       -e "${remote_dist}.upload.other" && ! -e "$remote_lock" &&
       ! -e "${remote_caddy}.h5-candidate.bak" && ! -e "$remote_temp" ]]
  fi
  echo "[h5-candidate-test] $name: $expected"
}

run_case "ssh-fail-once" pass fail-once
[[ "$(cat "$tmp_dir/ssh-fail-once/ssh-count")" == 2 ]]
run_case "ssh-fail-always" fail fail-always
[[ "$(cat "$tmp_dir/ssh-fail-always/ssh-count")" == 3 ]]
run_case "ssh-command-timeout" fail hang 404 plaintext healthy no no 1
[[ "$(cat "$tmp_dir/ssh-command-timeout/ssh-count")" == 3 ]]
run_case "partial-remote-failure" pass success 404 plaintext healthy yes
[[ "$(cat "$tmp_dir/partial-remote-failure/ssh-count")" == 2 ]]
run_case "partial-delete-failure" pass success 404 plaintext healthy no yes
[[ "$(cat "$tmp_dir/partial-delete-failure/ssh-count")" == 2 ]]
grep -q 'redcode-h5-candidate.Caddyfile' "$tmp_dir/partial-delete-failure/remote-rm.log"
run_case "candidate-remains" fail success 200
run_case "admin-fallback-after-cleanup" pass success admin
run_case "candidate-check-error" fail success error
run_case "runtime-drift" fail success 404 e2ee
run_case "admin-unavailable" fail success 404 plaintext unavailable

owner_dir="$tmp_dir/non-owner-cleanup"
owner_dist="$owner_dir/remote/srv/redcode-h5-candidate"
owner_lock="${owner_dist}.lock"
owner_caddy="$owner_dir/remote/etc/caddy/Caddyfile"
mkdir -p "$owner_dist" "$owner_lock" "${owner_caddy%/*}" "$owner_dir/remote/tmp"
printf '%s\n' owner-original >"$owner_lock/owner"
printf '%s\n' 'candidate h5-candidate route' >"$owner_caddy"
printf '%s\n' 'original admin route' >"${owner_caddy}.h5-candidate.bak"
: >"$owner_dir/ssh-count"
: >"$owner_dir/ssh-commands"
: >"$owner_dir/curl-calls"
set +e
PATH="$bin_dir:$PATH" \
H5_TEST_SSH_COUNT="$owner_dir/ssh-count" \
H5_TEST_SSH_COMMANDS="$owner_dir/ssh-commands" \
H5_TEST_CURL_CALLS="$owner_dir/curl-calls" \
H5_TEST_SSH_MODE=success \
H5_RELEASE_REMOTE_DIST="$owner_dist" \
H5_RELEASE_REMOTE_LOCK="$owner_lock" \
H5_RELEASE_REMOTE_CADDY="$owner_caddy" \
H5_RELEASE_REMOTE_TEMP_CADDY="$owner_dir/remote/tmp/redcode-h5-candidate.Caddyfile" \
H5_RELEASE_OWNER_TOKEN=owner-intruder \
H5_RELEASE_CLEANUP_RETRY_DELAY=0 \
  "$script" recover >"$owner_dir/output.log" 2>&1
owner_status=$?
set -e
[[ "$owner_status" != 0 && -d "$owner_dist" && -d "$owner_lock" ]]
grep -q 'lock owner mismatch' "$owner_dir/output.log"
grep -q h5-candidate "$owner_caddy"
echo "[h5-candidate-test] non-owner cleanup: fail closed"

run_case "first-recovery" pass success
first_dir="$tmp_dir/first-recovery"
set +e
PATH="$bin_dir:$PATH" \
H5_TEST_SSH_COUNT="$first_dir/ssh-count" \
H5_TEST_SSH_COMMANDS="$first_dir/ssh-commands" \
H5_TEST_CURL_CALLS="$first_dir/curl-calls" \
H5_TEST_SSH_MODE=success \
H5_RELEASE_CLEANUP_RETRIES=3 \
H5_RELEASE_CLEANUP_RETRY_DELAY=0 \
H5_RELEASE_CLEANUP_HARD_TIMEOUT=5 \
H5_RELEASE_REMOTE_DIST="$first_dir/remote/srv/redcode-h5-candidate" \
H5_RELEASE_REMOTE_LOCK="$first_dir/remote/srv/redcode-h5-candidate.lock" \
H5_RELEASE_REMOTE_CADDY="$first_dir/remote/etc/caddy/Caddyfile" \
H5_RELEASE_REMOTE_TEMP_CADDY="$first_dir/remote/tmp/redcode-h5-candidate.Caddyfile" \
H5_RELEASE_OWNER_TOKEN=owner-first-recovery \
  "$script" recover >>"$first_dir/output.log" 2>&1
second_status=$?
set -e
[[ "$second_status" == 0 ]]
[[ "$(cat "$first_dir/ssh-count")" == 2 ]]
echo "[h5-candidate-test] second-idempotent-recovery: pass"

normal_dir="$tmp_dir/normal-command-failure"
mkdir -p "$normal_dir/dist" "$normal_dir/tmp"
mkdir -p "$normal_dir/remote/etc/caddy" "$normal_dir/remote/tmp" "$normal_dir/remote/srv"
printf '%s\n' 'original admin route' >"$normal_dir/remote/etc/caddy/Caddyfile"
printf '%s\n' '{"assets":[]}' >"$normal_dir/dist/release-manifest.json"
printf '%s\n' '{"content-security-policy":"default-src '\''none'\''; connect-src '\''self'\''"}' >"$normal_dir/dist/security-headers.json"
printf '%s\n' 'header Content-Security-Policy "{{H5_CANDIDATE_CSP}}"' >"$normal_dir/Caddyfile"
: >"$normal_dir/ssh-count"
: >"$normal_dir/ssh-commands"
: >"$normal_dir/curl-calls"
set +e
PATH="$bin_dir:$PATH" \
TMPDIR="$normal_dir/tmp" \
H5_TEST_SSH_COUNT="$normal_dir/ssh-count" \
H5_TEST_SSH_COMMANDS="$normal_dir/ssh-commands" \
H5_TEST_CURL_CALLS="$normal_dir/curl-calls" \
H5_TEST_SSH_MODE=success \
H5_RELEASE_DIST="$normal_dir/dist" \
H5_RELEASE_CADDYFILE="$normal_dir/Caddyfile" \
H5_RELEASE_REMOTE_DIST="$normal_dir/remote/srv/redcode-h5-candidate" \
H5_RELEASE_REMOTE_LOCK="$normal_dir/remote/srv/redcode-h5-candidate.lock" \
H5_RELEASE_REMOTE_CADDY="$normal_dir/remote/etc/caddy/Caddyfile" \
H5_RELEASE_REMOTE_TEMP_CADDY="$normal_dir/remote/tmp/redcode-h5-candidate.Caddyfile" \
H5_RELEASE_OWNER_TOKEN=normal-owner \
H5_RELEASE_CLEANUP_RETRY_DELAY=0 \
H5_RELEASE_CLEANUP_HARD_TIMEOUT=5 \
  "$script" bash -c 'exit 23' >"$normal_dir/output.log" 2>&1
normal_status=$?
set -e
[[ "$normal_status" == 23 ]] || {
  cat "$normal_dir/output.log" >&2
  echo "[h5-candidate-test] 审计失败退出码未保留" >&2
  exit 1
}
for call in admin candidate runtime; do
  grep -Fxq "$call" "$normal_dir/curl-calls"
done
if find "$normal_dir/tmp" -type f | grep -q .; then
  echo "[h5-candidate-test] cleanup 后仍有本地临时文件" >&2
  find "$normal_dir/tmp" -type f >&2
  exit 1
fi
echo "[h5-candidate-test] command failure trap: pass"

preflight_dir="$tmp_dir/preflight-failure"
mkdir -p "$preflight_dir/dist" "$preflight_dir/tmp" \
  "$preflight_dir/remote/etc/caddy" "$preflight_dir/remote/tmp"
mkdir -p "$preflight_dir/remote/srv"
printf '%s\n' '{"assets":[]}' >"$preflight_dir/dist/release-manifest.json"
printf '%s\n' '{"content-security-policy":"default-src '\''none'\''; connect-src '\''self'\''"}' >"$preflight_dir/dist/security-headers.json"
printf '%s\n' 'header Content-Security-Policy "{{H5_CANDIDATE_CSP}}"' >"$preflight_dir/Caddyfile"
printf '%s\n' 'original admin route' >"$preflight_dir/remote/etc/caddy/Caddyfile"
: >"$preflight_dir/ssh-count"
: >"$preflight_dir/ssh-commands"
: >"$preflight_dir/curl-calls"
set +e
PATH="$bin_dir:$PATH" \
TMPDIR="$preflight_dir/tmp" \
H5_TEST_SSH_COUNT="$preflight_dir/ssh-count" \
H5_TEST_SSH_COMMANDS="$preflight_dir/ssh-commands" \
H5_TEST_CURL_CALLS="$preflight_dir/curl-calls" \
H5_TEST_SSH_MODE=preflight-fail \
H5_RELEASE_DIST="$preflight_dir/dist" \
H5_RELEASE_CADDYFILE="$preflight_dir/Caddyfile" \
H5_RELEASE_REMOTE_DIST="$preflight_dir/remote/srv/redcode-h5-candidate" \
H5_RELEASE_REMOTE_LOCK="$preflight_dir/remote/srv/redcode-h5-candidate.lock" \
H5_RELEASE_REMOTE_CADDY="$preflight_dir/remote/etc/caddy/Caddyfile" \
H5_RELEASE_REMOTE_TEMP_CADDY="$preflight_dir/remote/tmp/redcode-h5-candidate.Caddyfile" \
H5_RELEASE_OWNER_TOKEN=preflight-owner \
H5_RELEASE_CLEANUP_RETRY_DELAY=0 \
H5_RELEASE_CLEANUP_HARD_TIMEOUT=5 \
  "$script" >"$preflight_dir/output.log" 2>&1
preflight_status=$?
set -e
[[ "$preflight_status" != 0 ]]
if find "$preflight_dir/tmp" -type f | grep -q .; then
  echo "[h5-candidate-test] preflight 失败后仍有临时文件" >&2
  exit 1
fi
for call in admin candidate runtime; do
  grep -Fxq "$call" "$preflight_dir/curl-calls"
done
echo "[h5-candidate-test] preflight failure trap: pass"

for signal_case in "INT:130" "TERM:143"; do
  signal_name="${signal_case%%:*}"
  expected_status="${signal_case##*:}"
  signal_dir="$tmp_dir/signal-${signal_name}"
  mkdir -p "$signal_dir/dist" "$signal_dir/tmp" \
    "$signal_dir/remote/etc/caddy" "$signal_dir/remote/tmp"
  mkdir -p "$signal_dir/remote/srv"
  printf '%s\n' '{"assets":[]}' >"$signal_dir/dist/release-manifest.json"
  printf '%s\n' '{"content-security-policy":"default-src '\''none'\''; connect-src '\''self'\''"}' >"$signal_dir/dist/security-headers.json"
  printf '%s\n' 'header Content-Security-Policy "{{H5_CANDIDATE_CSP}}"' >"$signal_dir/Caddyfile"
  printf '%s\n' 'original admin route' >"$signal_dir/remote/etc/caddy/Caddyfile"
  : >"$signal_dir/ssh-count"
  : >"$signal_dir/ssh-commands"
  : >"$signal_dir/curl-calls"
  set +e
  PATH="$bin_dir:$PATH" \
  TMPDIR="$signal_dir/tmp" \
  H5_TEST_SSH_COUNT="$signal_dir/ssh-count" \
  H5_TEST_SSH_COMMANDS="$signal_dir/ssh-commands" \
  H5_TEST_CURL_CALLS="$signal_dir/curl-calls" \
  H5_TEST_SSH_MODE=success \
  H5_RELEASE_DIST="$signal_dir/dist" \
  H5_RELEASE_CADDYFILE="$signal_dir/Caddyfile" \
  H5_RELEASE_REMOTE_DIST="$signal_dir/remote/srv/redcode-h5-candidate" \
  H5_RELEASE_REMOTE_LOCK="$signal_dir/remote/srv/redcode-h5-candidate.lock" \
  H5_RELEASE_REMOTE_CADDY="$signal_dir/remote/etc/caddy/Caddyfile" \
  H5_RELEASE_REMOTE_TEMP_CADDY="$signal_dir/remote/tmp/redcode-h5-candidate.Caddyfile" \
  H5_RELEASE_OWNER_TOKEN="signal-${signal_name}" \
  H5_RELEASE_CLEANUP_RETRY_DELAY=0 \
  H5_RELEASE_CLEANUP_HARD_TIMEOUT=5 \
    "$script" bash -c 'kill -s "$1" "$PPID"; sleep 0.1' _ "$signal_name" \
    >"$signal_dir/output.log" 2>&1
  signal_status=$?
  set -e
  [[ "$signal_status" == "$expected_status" ]] || {
    cat "$signal_dir/output.log" >&2
    echo "[h5-candidate-test] $signal_name 退出码错误：$signal_status" >&2
    exit 1
  }
  for call in admin candidate runtime; do
    grep -Fxq "$call" "$signal_dir/curl-calls"
  done
  if find "$signal_dir/tmp" -type f | grep -q .; then
    echo "[h5-candidate-test] $signal_name cleanup 后仍有临时文件" >&2
    exit 1
  fi
  echo "[h5-candidate-test] signal $signal_name cleanup: pass"
done

for unsafe_path in /srv "/srv/redcode-h5-candidate'bad" /srv/../redcode-h5-candidate; do
  set +e
  PATH="$bin_dir:$PATH" H5_RELEASE_REMOTE_DIST="$unsafe_path" \
    "$script" recover >/dev/null 2>&1
  unsafe_status=$?
  set -e
  [[ "$unsafe_status" == 64 ]]
done
echo "[h5-candidate-test] unsafe remote paths: fail"
for unsafe_remote in -V -G bad@-host 'bad host'; do
  set +e
  PATH="$bin_dir:$PATH" H5_RELEASE_REMOTE="$unsafe_remote" \
    "$script" recover >/dev/null 2>&1
  unsafe_status=$?
  set -e
  [[ "$unsafe_status" == 64 ]]
done
echo "[h5-candidate-test] unsafe SSH targets: fail"

set +e
PATH="$bin_dir:$PATH" H5_RELEASE_OWNER_TOKEN= \
  "$script" recover >/dev/null 2>&1
missing_owner_status=$?
set -e
[[ "$missing_owner_status" == 64 ]]
echo "[h5-candidate-test] recover without owner token: fail"

bash -n "$script"
echo "[h5-candidate-test] 19 个 cleanup/recover/owner 场景全部通过"
