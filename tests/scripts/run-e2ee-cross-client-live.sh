#!/usr/bin/env bash
# 仅针对本机 Compose dev：临时启用 E2EE live，任何退出路径都恢复 plaintext。
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compose_file="$root_dir/api/docker/dev/docker-compose.yml"
api_base_url="${H5_APP_API_BASE_URL:-http://127.0.0.1:8010}"
ws_url="${H5_APP_WS_URL:-ws://127.0.0.1:8010/ws}"
run_id="${E2EE_LIVE_RUN_ID:-c6$(date +%s)}"
make_command="${MAKE:-make}"

if [[ "$api_base_url" != "http://127.0.0.1:8010" ]]; then
  echo "[e2ee-live] 仅允许本机 dev API：http://127.0.0.1:8010" >&2
  exit 64
fi

for command in docker curl rg "$make_command"; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "[e2ee-live] 缺少命令：$command" >&2
    exit 69
  }
done

if [[ -z "${JAVA_HOME:-}" ]] && [[ -x /usr/libexec/java_home ]]; then
  JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
fi
if [[ -z "${JAVA_HOME:-}" || ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "[e2ee-live] 未找到 JDK 21，请设置 JAVA_HOME" >&2
  exit 69
fi
java_major="$($JAVA_HOME/bin/java -version 2>&1 | sed -nE 's/.*version "([0-9]+).*/\1/p' | head -1)"
if [[ "$java_major" != "21" ]]; then
  echo "[e2ee-live] Android live 必须使用 JDK 21，当前为 $java_major" >&2
  exit 65
fi
export JAVA_HOME

docker compose -f "$compose_file" ps --status running postgres api | rg -q 'redcode-dev-postgres'
docker compose -f "$compose_file" ps --status running postgres api | rg -q 'redcode-dev-api'
curl -fsS "$api_base_url/healthz" | rg -q '^ok$'

runtime_before="$(curl -fsS "$api_base_url/settings/general")"
printf '%s' "$runtime_before" | rg -q '"server_storage_mode":"persist"' || {
  echo "[e2ee-live] 启动前 server_storage_mode 不是 persist，拒绝覆盖" >&2
  exit 65
}
printf '%s' "$runtime_before" | rg -q '"content_audit_mode":"plaintext"' || {
  echo "[e2ee-live] 启动前 content_audit_mode 不是 plaintext，拒绝覆盖" >&2
  exit 65
}

restore_runtime() {
  docker compose -f "$compose_file" exec -T postgres \
    psql -v ON_ERROR_STOP=1 -U postgres -d redcode_im >/dev/null <<'SQL'
BEGIN;
UPDATE general_settings
SET value = 'plaintext', updated_at = NOW(), updated_by = NULL
WHERE key = 'message_content_audit_mode';
UPDATE e2ee_runtime_gate
SET state = 'plaintext', updated_at = NOW(), updated_by = NULL
WHERE id = 1;
COMMIT;
SQL
  local runtime_after
  runtime_after="$(curl -fsS "$api_base_url/settings/general")"
  printf '%s' "$runtime_after" | rg -q '"server_storage_mode":"persist"'
  printf '%s' "$runtime_after" | rg -q '"content_audit_mode":"plaintext"'
  echo "[e2ee-live] runtime 已恢复 persist/plaintext"
}

finish() {
  local exit_code=$?
  trap - EXIT INT TERM
  if ! restore_runtime; then
    echo "[e2ee-live] runtime 恢复验证失败" >&2
    exit_code=1
  fi
  exit "$exit_code"
}
trap finish EXIT INT TERM

docker compose -f "$compose_file" exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U postgres -d redcode_im >/dev/null <<'SQL'
BEGIN;
UPDATE general_settings
SET value = 'persist', updated_at = NOW(), updated_by = NULL
WHERE key = 'message_server_storage_mode';
UPDATE general_settings
SET value = 'e2ee', updated_at = NOW(), updated_by = NULL
WHERE key = 'message_content_audit_mode';
UPDATE e2ee_runtime_gate
SET state = 'active', updated_at = NOW(), updated_by = NULL
WHERE id = 1;
COMMIT;
SQL

runtime_active="$(curl -fsS "$api_base_url/settings/general")"
printf '%s' "$runtime_active" | rg -q '"server_storage_mode":"persist"'
printf '%s' "$runtime_active" | rg -q '"content_audit_mode":"e2ee"'
echo "[e2ee-live] runtime 已临时启用 persist/e2ee，run_id=$run_id"

H5_APP_API_BASE_URL="$api_base_url" \
VITE_API_BASE_URL="$api_base_url" \
VITE_WS_URL="$ws_url" \
E2EE_LIVE_RUN_ID="$run_id" \
  "$make_command" -C "$root_dir" h5-app.test.e2ee.live
