#!/usr/bin/env bash
# 受控执行本机 dev 或隔离 restore 的 E2EE live，任何退出路径都恢复并清理。
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compose_file="$root_dir/api/docker/dev/docker-compose.yml"
api_base_url="${H5_APP_API_BASE_URL:-http://127.0.0.1:8010}"
ws_url="${H5_APP_WS_URL:-ws://127.0.0.1:8010/ws}"
isolated_restore="${E2EE_LIVE_ISOLATED_RESTORE:-0}"
restore_remote="${E2EE_LIVE_RESTORE_REMOTE:-im-test-1}"
restore_control="${E2EE_LIVE_RESTORE_CONTROL_PATH:-}"
restore_run_id="${E2EE_LIVE_RESTORE_RUN_ID:-}"
source_runtime_url="${E2EE_LIVE_SOURCE_RUNTIME_URL:-https://im-test-1.codelib.cc/settings/general}"
run_id="${E2EE_LIVE_RUN_ID:-c6$(date +%s)}"
make_command="${MAKE:-make}"
evidence_is_temporary=0
if [[ -n "${E2EE_LIVE_EVIDENCE_PATH:-}" ]]; then
  evidence_file="$E2EE_LIVE_EVIDENCE_PATH"
else
  evidence_file="$(mktemp "${TMPDIR:-/tmp}/redcode-e2ee-live-evidence.XXXXXX")"
  evidence_is_temporary=1
fi
redis_monitor_file="$(mktemp "${TMPDIR:-/tmp}/redcode-e2ee-live-redis.XXXXXX")"
log_since="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
redis_monitor_pid=""
tunnel_pid=""

if [[ "$isolated_restore" == "1" ]]; then
  [[ "$api_base_url" == "http://127.0.0.1:18010" && "$ws_url" == "ws://127.0.0.1:18010/ws" ]] || {
    echo "[e2ee-live] isolated restore 仅允许固定 127.0.0.1:18010 HTTP/WS" >&2
    exit 64
  }
  [[ "$restore_run_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] || {
    echo "[e2ee-live] E2EE_LIVE_RESTORE_RUN_ID 无效" >&2
    exit 64
  }
  [[ "$restore_remote" =~ ^([A-Za-z0-9._][A-Za-z0-9._-]*@)?[A-Za-z0-9._][A-Za-z0-9._-]*$ ]] || {
    echo "[e2ee-live] E2EE_LIVE_RESTORE_REMOTE 无效" >&2
    exit 64
  }
  [[ "$restore_control" == /* && "$restore_control" =~ ^/[A-Za-z0-9._/-]+$ &&
     "${restore_control##*/}" == e2ee-restore-control.sh ]] || {
    echo "[e2ee-live] E2EE_LIVE_RESTORE_CONTROL_PATH 必须指向固定 control 脚本" >&2
    exit 64
  }
elif [[ "$api_base_url" != "http://127.0.0.1:8010" ]]; then
  echo "[e2ee-live] 仅允许本机 dev API：http://127.0.0.1:8010" >&2
  exit 64
fi

required_commands=(curl jq rg "$make_command")
if [[ "$isolated_restore" == "1" ]]; then
  required_commands+=(lsof ssh)
else
  required_commands+=(docker)
fi
for command in "${required_commands[@]}"; do
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

remote_control() {
  local operation="$1"
  ssh -o BatchMode=yes -o ConnectTimeout=10 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
    "$restore_remote" \
    "E2EE_RESTORE_RUN_ID='$restore_run_id' '$restore_control' '$operation'"
}

isolated_preflight_cleanup() {
  local exit_code="${1:-$?}"
  trap - EXIT INT TERM
  if [[ -n "$tunnel_pid" ]]; then
    kill "$tunnel_pid" 2>/dev/null || true
    wait "$tunnel_pid" 2>/dev/null || true
  fi
  remote_control rollback >/dev/null 2>&1 || true
  remote_control cleanup >/dev/null 2>&1 || exit_code=1
  rm -f "$redis_monitor_file"
  [[ "$evidence_is_temporary" != "1" ]] || rm -f "$evidence_file"
  exit "$exit_code"
}

if [[ "$isolated_restore" == "1" ]]; then
  trap 'isolated_preflight_cleanup $?' EXIT
  trap 'isolated_preflight_cleanup 130' INT
  trap 'isolated_preflight_cleanup 143' TERM
  restore_identity="$(remote_control verify)"
  jq -e \
    --arg run_id "$restore_run_id" \
    '.verified == true and .run_id == $run_id and
      .database_marker == ("redcode-e2ee-restore:" + $run_id) and
      .project == ("e2ee-restore-" + ($run_id | gsub("[._]"; "-"))) and
      .database_host == "postgres-restore" and .redis_host == "redis-restore" and
      .isolation.api_networks_exclude_source == true and
      .isolation.database_url_points_restore == true and
      .isolation.redis_urls_point_restore == true and
      .runtime == "persist/e2ee" and .api_url == "http://127.0.0.1:18010"' \
    <<<"$restore_identity" >/dev/null || {
      echo "[e2ee-live] restore identity 验证失败" >&2
      exit 65
    }
  if lsof -tiTCP:18010 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "[e2ee-live] 本机 18010 已被占用，请先停止占用进程" >&2
    exit 65
  fi
  ssh -N -o ExitOnForwardFailure=yes -o BatchMode=yes -o ConnectTimeout=10 \
    -o ServerAliveInterval=5 -o ServerAliveCountMax=2 \
    -L 127.0.0.1:18010:127.0.0.1:18010 "$restore_remote" &
  tunnel_pid=$!
  for _ in $(seq 1 100); do
    [[ "$(curl --connect-timeout 1 --max-time 2 -fsS "$api_base_url/healthz" 2>/dev/null || true)" == ok ]] && break
    kill -0 "$tunnel_pid" 2>/dev/null || {
      echo "[e2ee-live] restore SSH tunnel 提前退出" >&2
      exit 1
    }
    sleep 0.1
  done
else
  docker compose -f "$compose_file" ps --status running postgres api | rg -q 'redcode-dev-postgres'
  docker compose -f "$compose_file" ps --status running postgres api | rg -q 'redcode-dev-api'
fi
curl --connect-timeout 5 --max-time 15 -fsS "$api_base_url/healthz" | rg -q '^ok$'

runtime_before="$(curl --connect-timeout 5 --max-time 15 -fsS "$api_base_url/settings/general")"
printf '%s' "$runtime_before" | rg -q '"server_storage_mode":"persist"' || {
  echo "[e2ee-live] 启动前 server_storage_mode 不是 persist，拒绝覆盖" >&2
  exit 65
}
expected_audit_mode=plaintext
[[ "$isolated_restore" != "1" ]] || expected_audit_mode=e2ee
printf '%s' "$runtime_before" | rg -q "\"content_audit_mode\":\"$expected_audit_mode\"" || {
  echo "[e2ee-live] 启动前 content_audit_mode 不是 $expected_audit_mode，拒绝继续" >&2
  exit 65
}

restore_runtime() {
  if [[ "$isolated_restore" == "1" ]]; then
    local cleanup_failed=0 source_runtime
    remote_control rollback >/dev/null || cleanup_failed=1
    remote_control cleanup >/dev/null || cleanup_failed=1
    if [[ -n "$tunnel_pid" ]]; then
      kill "$tunnel_pid" 2>/dev/null || true
      wait "$tunnel_pid" 2>/dev/null || true
      tunnel_pid=""
    fi
    source_runtime="$(curl --connect-timeout 5 --max-time 15 -fsS "$source_runtime_url")" || return 1
    jq -e '.message_runtime.server_storage_mode == "persist" and
      .message_runtime.content_audit_mode == "plaintext"' <<<"$source_runtime" >/dev/null || return 1
    [[ "$cleanup_failed" == "0" ]]
    return
  fi
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
  runtime_after="$(curl --connect-timeout 5 --max-time 15 -fsS "$api_base_url/settings/general")"
  printf '%s' "$runtime_after" | rg -q '"server_storage_mode":"persist"'
  printf '%s' "$runtime_after" | rg -q '"content_audit_mode":"plaintext"'
  echo "[e2ee-live] runtime 已恢复 persist/plaintext"
}

finish() {
  local exit_code="${1:-$?}"
  trap - EXIT INT TERM
  if [[ -n "$redis_monitor_pid" ]]; then
    kill "$redis_monitor_pid" 2>/dev/null || true
    wait "$redis_monitor_pid" 2>/dev/null || true
  fi
  rm -f "$redis_monitor_file"
  if [[ "$evidence_is_temporary" == "1" ]]; then
    rm -f "$evidence_file"
  fi
  if ! restore_runtime; then
    echo "[e2ee-live] runtime 恢复验证失败" >&2
    exit_code=1
  fi
  exit "$exit_code"
}
trap 'finish $?' EXIT
trap 'finish 130' INT
trap 'finish 143' TERM

if [[ "$isolated_restore" != "1" ]]; then
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

fi

runtime_active="$(curl --connect-timeout 5 --max-time 15 -fsS "$api_base_url/settings/general")"
printf '%s' "$runtime_active" | rg -q '"server_storage_mode":"persist"'
printf '%s' "$runtime_active" | rg -q '"content_audit_mode":"e2ee"'
echo "[e2ee-live] runtime 已临时启用 persist/e2ee，run_id=$run_id"

if [[ "$isolated_restore" != "1" ]]; then
  docker compose -f "$compose_file" exec -T redis \
    redis-cli -a 123456 --no-auth-warning MONITOR >"$redis_monitor_file" 2>&1 &
  redis_monitor_pid=$!
  for _ in $(seq 1 100); do
    rg -q '^OK$' "$redis_monitor_file" 2>/dev/null && break
    kill -0 "$redis_monitor_pid" 2>/dev/null || {
      echo "[e2ee-live] Redis MONITOR 启动失败" >&2
      exit 1
    }
    sleep 0.05
  done
  rg -q '^OK$' "$redis_monitor_file" || {
    echo "[e2ee-live] Redis MONITOR 未就绪" >&2
    exit 1
  }
fi

H5_APP_API_BASE_URL="$api_base_url" \
VITE_API_BASE_URL="$api_base_url" \
VITE_WS_URL="$ws_url" \
E2EE_LIVE_RUN_ID="$run_id" \
E2EE_LIVE_EVIDENCE_PATH="$evidence_file" \
  "$make_command" -C "$root_dir" h5-app.test.e2ee.live

kill "$redis_monitor_pid" 2>/dev/null || true
wait "$redis_monitor_pid" 2>/dev/null || true
redis_monitor_pid=""
if [[ "$isolated_restore" != "1" ]]; then
  "$root_dir/tests/scripts/scan-e2ee-live-boundaries.sh" \
    "$evidence_file" "$log_since" "$redis_monitor_file"
fi
