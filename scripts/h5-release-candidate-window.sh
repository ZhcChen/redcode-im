#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist="${H5_RELEASE_DIST:-$root_dir/h5-app/dist}"
remote="${H5_RELEASE_REMOTE:-im-test-1}"
remote_dist="${H5_RELEASE_REMOTE_DIST:-/srv/redcode-h5-candidate}"
remote_staging="${remote_dist}.upload.$$"
remote_caddy="${H5_RELEASE_REMOTE_CADDY:-/etc/caddy/Caddyfile}"
remote_backup="${remote_caddy}.h5-candidate.bak"
caddy_candidate="${H5_RELEASE_CADDYFILE:-$root_dir/deploy/im-test-1/Caddyfile.h5-candidate}"
candidate_url="${H5_RELEASE_CANDIDATE_URL:-https://im-test-admin-1.codelib.cc/h5-candidate/}"
runtime_url="${H5_RELEASE_RUNTIME_URL:-https://im-test-1.codelib.cc/settings/general}"
admin_url="${H5_RELEASE_ADMIN_URL:-https://im-test-admin-1.codelib.cc/}"
checksums=""

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[h5-candidate] missing command: $1" >&2
    exit 69
  }
}

verify_runtime() {
  local runtime
  runtime="$(curl -fsS "$runtime_url")"
  jq -e '.message_runtime.server_storage_mode == "persist" and .message_runtime.content_audit_mode == "plaintext"' \
    >/dev/null <<<"$runtime"
}

cleanup() {
  local exit_code="${1:-$?}"
  trap - EXIT INT TERM
  ssh "$remote" "set -eu; if test -f '$remote_backup'; then install -m 0644 '$remote_backup' '$remote_caddy'; caddy validate --config '$remote_caddy' >/dev/null; systemctl reload caddy; systemctl is-active --quiet caddy; fi; rm -rf '$remote_dist' '$remote_staging'; rm -f '$remote_backup'"
  rm -f "${checksums:-}"
  if ! curl -fsS "$admin_url" | rg -q '<title>IM 管理后台'; then
    echo "[h5-candidate] Admin root verification failed after cleanup" >&2
    exit_code=1
  fi
  if ! verify_runtime; then
    echo "[h5-candidate] runtime is not persist/plaintext after cleanup" >&2
    exit_code=1
  fi
  echo "[h5-candidate] candidate window cleaned"
  exit "$exit_code"
}

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
checksums="$(mktemp "${TMPDIR:-/tmp}/redcode-h5-candidate.XXXXXX")"
jq -r '.assets[] | "\(.sha256)  \(.path)"' "$dist/release-manifest.json" >"$checksums"
printf '%s  release-manifest.json\n' "$(shasum -a 256 "$dist/release-manifest.json" | awk '{print $1}')" >>"$checksums"

ssh "$remote" "set -eu; test ! -e '$remote_backup'; test ! -e '$remote_dist'; test ! -e '$remote_staging'"
trap 'cleanup $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
ssh "$remote" "set -eu; cp '$remote_caddy' '$remote_backup'; install -d -m 0755 '$remote_staging'"
scp -q -r "$dist/." "$remote:$remote_staging/"
scp -q "$checksums" "$remote:$remote_staging/.candidate-sha256"
scp -q "$caddy_candidate" "$remote:/tmp/redcode-h5-candidate.Caddyfile"
ssh "$remote" "set -eu; cd '$remote_staging'; sha256sum -c .candidate-sha256 >/dev/null; expected=\$(wc -l <.candidate-sha256); actual=\$(find . -type f ! -name .candidate-sha256 | wc -l); test \"\$expected\" -eq \"\$actual\"; rm .candidate-sha256; mv '$remote_staging' '$remote_dist'; caddy validate --config /tmp/redcode-h5-candidate.Caddyfile >/dev/null; install -m 0644 /tmp/redcode-h5-candidate.Caddyfile '$remote_caddy'; rm -f /tmp/redcode-h5-candidate.Caddyfile; systemctl reload caddy; systemctl is-active --quiet caddy"

if [[ "$#" -gt 0 ]]; then
  "$@"
else
  cd "$root_dir/h5-app"
  H5_RELEASE_CANDIDATE_URL="$candidate_url" bun scripts/release-browser-audit.ts
fi
