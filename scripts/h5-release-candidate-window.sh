#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="${H5_RELEASE_DIST:-$root_dir/h5-app/dist}"
remote="${H5_RELEASE_REMOTE:-im-test-1}"
remote_dist="${H5_RELEASE_REMOTE_DIST:-/srv/redcode-h5-candidate}"
remote_staging="${remote_dist}.upload.$$"
remote_caddy="${H5_RELEASE_REMOTE_CADDY:-/etc/caddy/Caddyfile}"
remote_backup="${remote_caddy}.h5-candidate.bak"
remote_temp_caddy="${H5_RELEASE_REMOTE_TEMP_CADDY:-/tmp/redcode-h5-candidate.Caddyfile}"
caddy_candidate="${H5_RELEASE_CADDYFILE:-$root_dir/deploy/im-test-1/Caddyfile.h5-candidate}"
candidate_url="${H5_RELEASE_CANDIDATE_URL:-https://im-test-admin-1.codelib.cc/h5-candidate/}"
runtime_url="${H5_RELEASE_RUNTIME_URL:-https://im-test-1.codelib.cc/settings/general}"
admin_url="${H5_RELEASE_ADMIN_URL:-https://im-test-admin-1.codelib.cc/}"
checksums=""
candidate_response=""
rendered_caddy=""
csp=""
command_pid=""
cleanup_retries="${H5_RELEASE_CLEANUP_RETRIES:-3}"
cleanup_retry_delay="${H5_RELEASE_CLEANUP_RETRY_DELAY:-2}"
cleanup_hard_timeout="${H5_RELEASE_CLEANUP_HARD_TIMEOUT:-45}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[h5-candidate] missing command: $1" >&2
    exit 69
  }
}

validate_remote_path() {
  local path="$1"
  local basename="$2"
  [[ "$path" == /* && "$path" =~ ^/[A-Za-z0-9._/-]+$ ]] || return 1
  [[ "$path" != *"//"* && "$path" != *"/../"* && "$path" != */.. ]] || return 1
  [[ "${path##*/}" == "$basename" && "${path%/*}" != "" && "${path%/*}" != "/" ]]
}

verify_runtime() {
  local runtime
  runtime="$(curl --connect-timeout 10 --max-time 30 -fsS "$runtime_url")"
  jq -e '.message_runtime.server_storage_mode == "persist" and .message_runtime.content_audit_mode == "plaintext"' \
    >/dev/null <<<"$runtime"
}

ssh_with_retry() {
  local attempt=1
  local status=0
  while ((attempt <= cleanup_retries)); do
    if ssh_once_with_timeout "$@"; then
      return 0
    else
      status=$?
    fi
    echo "[h5-candidate] SSH cleanup attempt $attempt/$cleanup_retries failed" >&2
    if ((attempt < cleanup_retries)); then
      sleep "$cleanup_retry_delay"
    fi
    attempt=$((attempt + 1))
  done
  return "$status"
}

ssh_once_with_timeout() {
  local ssh_pid status tick max_ticks timed_out=0
  ssh -o BatchMode=yes -o ConnectTimeout=10 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2 "$@" &
  ssh_pid=$!
  max_ticks=$((cleanup_hard_timeout * 10))
  for ((tick = 0; tick < max_ticks; tick++)); do
    kill -0 "$ssh_pid" 2>/dev/null || break
    sleep 0.1
  done
  if kill -0 "$ssh_pid" 2>/dev/null; then
    timed_out=1
    kill -TERM "$ssh_pid" 2>/dev/null || true
    for ((tick = 0; tick < 20; tick++)); do
      kill -0 "$ssh_pid" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$ssh_pid" 2>/dev/null; then
      kill -KILL "$ssh_pid" 2>/dev/null || true
    fi
  fi
  if wait "$ssh_pid"; then
    status=0
  else
    status=$?
  fi
  if [[ "$timed_out" == "1" ]]; then
    echo "[h5-candidate] SSH cleanup attempt exceeded ${cleanup_hard_timeout}s" >&2
    return 124
  fi
  return "$status"
}

cleanup_remote() {
  ssh_with_retry "$remote" "
set +e
status=0
restored=0
if test -f '$remote_backup'; then
  if install -m 0644 '$remote_backup' '$remote_caddy' &&
     caddy validate --config '$remote_caddy' >/dev/null &&
     systemctl reload caddy &&
     systemctl is-active --quiet caddy; then
    restored=1
  else
    echo '[h5-candidate] remote Caddy restore failed' >&2
    status=1
  fi
else
  restored=1
fi
rm -rf '$remote_dist' '$remote_dist'.upload.* || status=1
rm -f '$remote_temp_caddy' || status=1
caddy validate --config '$remote_caddy' >/dev/null || status=1
systemctl is-active --quiet caddy || status=1
if grep -q h5-candidate '$remote_caddy'; then status=1; fi
if test -e '$remote_dist'; then status=1; fi
set -- '$remote_dist'.upload.*
if test -e \"\$1\"; then status=1; fi
if test \"\$status\" -eq 0 && test \"\$restored\" -eq 1; then
  rm -f '$remote_backup' || status=1
fi
if test -e '$remote_backup'; then status=1; fi
exit \"\$status\"
"
}

verify_admin() {
  curl --connect-timeout 10 --max-time 30 -fsS "$admin_url" |
    rg -q '<title>IM 管理后台'
}

verify_candidate_removed() {
  local status
  candidate_response="$(mktemp "${TMPDIR:-/tmp}/redcode-h5-candidate-response.XXXXXX")"
  if ! status="$(curl --connect-timeout 10 --max-time 30 -sS \
    -o "$candidate_response" -w '%{http_code}' "$candidate_url")"; then
    rm -f "$candidate_response"
    candidate_response=""
    return 1
  fi
  if [[ "$status" != "404" ]] || rg -q '<title>RedCode IM H5' "$candidate_response"; then
    rm -f "$candidate_response"
    candidate_response=""
    return 1
  fi
  rm -f "$candidate_response"
  candidate_response=""
}

cleanup() {
  local exit_code="${1:-$?}"
  local cleanup_failed=0
  trap - EXIT
  trap '' INT TERM
  if [[ "$command_pid" =~ ^[1-9][0-9]*$ ]] && kill -0 "$command_pid" 2>/dev/null; then
    kill -TERM "$command_pid" 2>/dev/null || true
    wait "$command_pid" 2>/dev/null || true
  fi
  command_pid=""
  if ! cleanup_remote; then
    echo "[h5-candidate] remote cleanup failed" >&2
    cleanup_failed=1
  fi
  rm -f "${checksums:-}"
  rm -f "${candidate_response:-}"
  rm -f "${rendered_caddy:-}"
  if ! verify_admin; then
    echo "[h5-candidate] Admin root verification failed after cleanup" >&2
    cleanup_failed=1
  fi
  if ! verify_candidate_removed; then
    echo "[h5-candidate] candidate route or response remains after cleanup" >&2
    cleanup_failed=1
  fi
  if ! verify_runtime; then
    echo "[h5-candidate] runtime is not persist/plaintext after cleanup" >&2
    cleanup_failed=1
  fi
  if [[ "$cleanup_failed" == "1" ]]; then
    exit_code=1
  else
    echo "[h5-candidate] candidate window cleaned"
  fi
  exit "$exit_code"
}

[[ "$cleanup_retries" =~ ^[1-9][0-9]*$ ]] || {
  echo "[h5-candidate] H5_RELEASE_CLEANUP_RETRIES must be a positive integer" >&2
  exit 64
}
[[ "$cleanup_retry_delay" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
  echo "[h5-candidate] H5_RELEASE_CLEANUP_RETRY_DELAY must be non-negative" >&2
  exit 64
}
[[ "$cleanup_hard_timeout" =~ ^[1-9][0-9]*$ ]] || {
  echo "[h5-candidate] H5_RELEASE_CLEANUP_HARD_TIMEOUT must be a positive integer" >&2
  exit 64
}
[[ "$remote" =~ ^([A-Za-z0-9._][A-Za-z0-9._-]*@)?[A-Za-z0-9._][A-Za-z0-9._-]*$ ]] || {
  echo "[h5-candidate] H5_RELEASE_REMOTE is unsafe" >&2
  exit 64
}
validate_remote_path "$remote_dist" redcode-h5-candidate || {
  echo "[h5-candidate] H5_RELEASE_REMOTE_DIST is unsafe" >&2
  exit 64
}
validate_remote_path "$remote_caddy" Caddyfile || {
  echo "[h5-candidate] H5_RELEASE_REMOTE_CADDY is unsafe" >&2
  exit 64
}
validate_remote_path "$remote_temp_caddy" redcode-h5-candidate.Caddyfile || {
  echo "[h5-candidate] H5_RELEASE_REMOTE_TEMP_CADDY is unsafe" >&2
  exit 64
}

operation="${1:-run}"
if [[ "$operation" == "cleanup" || "$operation" == "recover" ]]; then
  for command in curl jq rg ssh; do require_command "$command"; done
  cleanup 0
fi

for command in bun curl jq rg scp ssh; do require_command "$command"; done
[[ -f "$dist/release-manifest.json" && -f "$dist/security-headers.json" ]] || {
  echo "[h5-candidate] finalized dist is required" >&2
  exit 66
}
[[ -f "$caddy_candidate" ]] || {
  echo "[h5-candidate] candidate Caddyfile is required" >&2
  exit 66
}

cd "$root_dir/h5-app"
bun run release:check
verify_runtime
trap 'cleanup $?' EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM
checksums="$(mktemp "${TMPDIR:-/tmp}/redcode-h5-candidate.XXXXXX")"
rendered_caddy="$(mktemp "${TMPDIR:-/tmp}/redcode-h5-candidate-caddy.XXXXXX")"
jq -r '.assets[] | "\(.sha256)  \(.path)"' "$dist/release-manifest.json" >"$checksums"
printf '%s  release-manifest.json\n' "$(shasum -a 256 "$dist/release-manifest.json" | awk '{print $1}')" >>"$checksums"
csp="$(jq -er '.["content-security-policy"] | select(type == "string" and length > 0)' \
  "$dist/security-headers.json")"
[[ "$csp" != *$'\n'* && "$csp" != *$'\r'* && "$csp" != *'"'* && "$csp" != *'\\'* ]] || {
  echo "[h5-candidate] candidate CSP contains unsafe Caddy template characters" >&2
  exit 66
}
csp="$(printf '%s' "$csp" | sed -e 's/[&|]/\\&/g')"
sed "s|{{H5_CANDIDATE_CSP}}|$csp|" "$caddy_candidate" >"$rendered_caddy"
! rg -q '\{\{H5_CANDIDATE_CSP\}\}' "$rendered_caddy" || {
  echo "[h5-candidate] candidate CSP template rendering failed" >&2
  exit 66
}

ssh "$remote" "set -eu; test ! -e '$remote_backup'; test ! -e '$remote_dist'; test ! -e '$remote_staging'"
ssh "$remote" "set -eu; cp '$remote_caddy' '$remote_backup'; install -d -m 0755 '$remote_staging'"
scp -q -r "$dist/." "$remote:$remote_staging/"
scp -q "$checksums" "$remote:$remote_staging/.candidate-sha256"
scp -q "$rendered_caddy" "$remote:$remote_temp_caddy"
ssh "$remote" "set -eu; cd '$remote_staging'; sha256sum -c .candidate-sha256 >/dev/null; expected=\$(wc -l <.candidate-sha256); actual=\$(find . -type f ! -name .candidate-sha256 | wc -l); test \"\$expected\" -eq \"\$actual\"; rm .candidate-sha256; mv '$remote_staging' '$remote_dist'; caddy validate --config '$remote_temp_caddy' >/dev/null; install -m 0644 '$remote_temp_caddy' '$remote_caddy'; rm -f '$remote_temp_caddy'; systemctl reload caddy; systemctl is-active --quiet caddy"

if [[ "$#" -gt 0 ]]; then
  "$@" &
else
  cd "$root_dir/h5-app"
  H5_RELEASE_CANDIDATE_URL="$candidate_url" bun scripts/release-browser-audit.ts &
fi
command_pid=$!
if wait "$command_pid"; then
  command_status=0
else
  command_status=$?
fi
command_pid=""
exit "$command_status"
