#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/deploy/im-test-1/e2ee-restore-control.sh"
compose_file="$root_dir/deploy/im-test-1/docker-compose.e2ee-restore.yml"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-restore-control.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_CONTROL_TEST_STATE:?}"

if [[ "${1:-}" == compose ]]; then
  [[ -z "${E2EE_RESTORE_PROJECT_NAME:-}" ]] || printf '%s\n' "$E2EE_RESTORE_PROJECT_NAME" >"$state/project"
  shift
  compose_path=""
  while (($#)); do
    case "$1" in
      --env-file|-p) shift 2 ;;
      -f) compose_path="$2"; shift 2 ;;
      *) break ;;
    esac
  done
  operation="${1:-}"
  shift || true
  case "$operation" in
    config) exit 0 ;;
    up)
      touch "$state/postgres" "$state/redis" "$state/volume"
      if [[ "$*" == *api-restore* ]]; then
        touch "$state/api"
        if [[ "${E2EE_CONTROL_TEST_FAIL_API_UP:-}" == 1 ]]; then
          exit 23
        fi
      fi
      ;;
    exec)
      [[ "${1:-}" != -T ]] || shift
      service="$1"
      shift
      if [[ "$compose_path" == */docker-compose.yml ]]; then
        case "$service" in
          postgres) printf '%s\n' "${E2EE_CONTROL_TEST_SOURCE_PG_CONNECTIONS:-0}" ;;
          redis)
            [[ "${E2EE_CONTROL_TEST_SOURCE_REDIS_CONNECTIONS:-0}" == 0 ]] ||
              printf 'id=1 addr=172.29.240.99:50000 name=restore\n'
            ;;
          *) exit 70 ;;
        esac
        exit 0
      fi
      [[ "$service" == postgres-restore ]]
      if [[ "$*" == *pg_isready* ]]; then
        count=0
        [[ ! -f "$state/pg-ready-count" ]] || count="$(cat "$state/pg-ready-count")"
        count=$((count + 1))
        printf '%s\n' "$count" >"$state/pg-ready-count"
        [[ "$count" -ge "${E2EE_CONTROL_TEST_PG_READY_AFTER:-1}" ]]
      elif [[ "$*" == *pg_restore* ]]; then
        cat >/dev/null
      elif [[ "$*" == *psql* ]]; then
        sql="$(cat)"
        case "$sql" in
          *"shobj_description"*) cat "$state/marker" ;;
          *"COMMENT ON DATABASE"*)
            printf 'redcode-e2ee-restore:%s\n' "${E2EE_RESTORE_RUN_ID:?}" >"$state/marker"
            printf 'e2ee\n' >"$state/runtime"
            ;;
          *"value = 'plaintext'"*) printf 'plaintext\n' >"$state/runtime" ;;
        esac
      fi
      ;;
    ps)
      quiet=0
      while (($#)); do
        case "$1" in
          -q) quiet=1 ;;
          --status) shift ;;
          postgres-restore) [[ ! -e "$state/postgres" ]] || printf 'postgres-id\n' ;;
          redis-restore) [[ ! -e "$state/redis" ]] || printf 'redis-id\n' ;;
          api-restore) [[ ! -e "$state/api" ]] || printf 'api-id\n' ;;
        esac
        shift
      done
      ;;
    down)
      rm -f "$state/postgres" "$state/redis" "$state/api" "$state/volume"
      ;;
    *) exit 70 ;;
  esac
  exit 0
fi

case "${1:-}" in
  inspect)
    format="$3"
    if [[ "$format" == *Config.Labels* ]]; then
      cat "$state/project"
    elif [[ "$format" == *Config.Env* ]]; then
      printf '%s\n' '["DATABASE_URL=postgres://user:secret@postgres-restore:5432/redcode_e2ee_restore","REDIS_SESSION_URL=redis://:secret@redis-restore:6379/0","REDIS_PUBSUB_URL=redis://:secret@redis-restore:6379/0","REDIS_CACHE_URL=redis://:secret@redis-restore:6379/0"]'
    elif [[ "$format" == *NetworkSettings.Networks* ]]; then
      printf '172.29.240.99\n'
    else
      exit 70
    fi
    ;;
  ps)
    [[ ! -e "$state/postgres" && ! -e "$state/redis" && ! -e "$state/api" ]] || printf 'remaining-container\n'
    ;;
  volume)
    [[ "$2" == ls ]]
    [[ ! -e "$state/volume" ]] || printf 'remaining-volume\n'
    ;;
  *) exit 70 ;;
esac
SH

cat >"$bin_dir/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state="${E2EE_CONTROL_TEST_STATE:?}"
url="${!#}"
[[ -e "$state/api" ]] || exit 22
case "$url" in
  */healthz) printf 'ok' ;;
  */settings/general)
    printf '{"message_runtime":{"server_storage_mode":"persist","content_audit_mode":"%s"}}\n' \
      "$(cat "$state/runtime")"
    ;;
  *) exit 22 ;;
esac
SH
chmod +x "$bin_dir/docker" "$bin_dir/curl"

env_file="$tmp_dir/deploy.env"
cat >"$env_file" <<'ENV'
TZ=Asia/Shanghai
E2EE_DRILL_API_IMAGE=redcode-im-api:contract
RUST_LOG=info
DATABASE_MAX_CONNECTIONS=5
DATABASE_MIN_CONNECTIONS=1
DATABASE_ACQUIRE_TIMEOUT_SECONDS=10
POSTGRES_USER=redcode
POSTGRES_DB=redcode_im
REDIS_PASSWORD=source-redis-password
API_PUBLIC_HOST=im-test-1.codelib.cc
RUSTFS_REGION=us-east-1
RUSTFS_ACCESS_KEY=contract-access
RUSTFS_SECRET_KEY=contract-secret
RUSTFS_PRIVATE_BUCKET=private
RUSTFS_PUBLIC_BUCKET=public
JWT_SECRET=contract-jwt
DATA_ENCRYPTION_KEY=contract-data-key
WS_OUTBOUND_QUEUE_SIZE=128
METRICS_CHANNEL_CAPACITY=128
METRICS_FLUSH_BATCH_SIZE=10
METRICS_FLUSH_INTERVAL_SECONDS=1
METRICS_SAMPLE_RATE=1.0
ENV

new_state() {
  local name="$1" state
  state="$tmp_dir/$name"
  mkdir -p "$state/runtime-state"
  printf 'plaintext\n' >"$state/runtime"
  : >"$state/database.dump"
  printf '%s' "$state"
}

run_control() {
  local state="$1" run_id="$2" operation="$3"
  shift 3
  PATH="$bin_dir:$PATH" \
  E2EE_CONTROL_TEST_STATE="$state" \
  E2EE_RESTORE_RUN_ID="$run_id" \
  E2EE_RESTORE_STATE_ROOT="$state/runtime-state" \
  E2EE_RESTORE_ENV_FILE="$env_file" \
  E2EE_RESTORE_COMPOSE_FILE="$compose_file" \
  E2EE_RESTORE_SOURCE_COMPOSE_FILE="$root_dir/deploy/im-test-1/docker-compose.yml" \
    "$@" "$script" "$operation"
}

success_state="$(new_state success)"
E2EE_RESTORE_ALLOW_PREPARE=yes E2EE_RESTORE_DUMP_PATH="$success_state/database.dump" \
E2EE_CONTROL_TEST_PG_READY_AFTER=2 \
  run_control "$success_state" success prepare >"$success_state/prepare.json"
jq -e '.verified == true and .database_marker == "redcode-e2ee-restore:success"' \
  "$success_state/prepare.json" >/dev/null
[[ "$(cat "$success_state/runtime")" == e2ee ]]
[[ -f "$success_state/pg-ready-count" ]] || {
  echo '[e2ee-restore-control-test] prepare 未等待 PostgreSQL ready' >&2
  exit 1
}
[[ "$(cat "$success_state/pg-ready-count")" -ge 2 ]]
[[ -f "$success_state/runtime-state/success/control.env" ]]
run_control "$success_state" success verify >"$success_state/verify.json"
jq -e '.project == "e2ee-restore-success" and .database_host == "postgres-restore"' \
  "$success_state/verify.json" >/dev/null
run_control "$success_state" success rollback
[[ "$(cat "$success_state/runtime")" == plaintext ]]
run_control "$success_state" success cleanup
[[ ! -e "$success_state/postgres" && ! -e "$success_state/redis" &&
   ! -e "$success_state/api" && ! -e "$success_state/volume" &&
   ! -e "$success_state/runtime-state/success/control.env" ]]
echo "[e2ee-restore-control-test] prepare/verify/rollback/cleanup: pass"

failure_state="$(new_state api-start-failure)"
set +e
E2EE_RESTORE_ALLOW_PREPARE=yes E2EE_RESTORE_DUMP_PATH="$failure_state/database.dump" \
E2EE_CONTROL_TEST_FAIL_API_UP=1 \
  run_control "$failure_state" api-start-failure prepare >"$failure_state/output.log" 2>&1
failure_status=$?
set -e
[[ "$failure_status" -ne 0 ]]
[[ ! -e "$failure_state/postgres" && ! -e "$failure_state/redis" &&
   ! -e "$failure_state/api" && ! -e "$failure_state/volume" ]]
echo "[e2ee-restore-control-test] API start failure cleanup: pass"

for source_kind in pg redis; do
  source_state="$(new_state "source-$source_kind-connection")"
  source_pg=0
  source_redis=0
  [[ "$source_kind" != pg ]] || source_pg=1
  [[ "$source_kind" != redis ]] || source_redis=1
  set +e
  E2EE_RESTORE_ALLOW_PREPARE=yes E2EE_RESTORE_DUMP_PATH="$source_state/database.dump" \
  E2EE_CONTROL_TEST_SOURCE_PG_CONNECTIONS="$source_pg" \
  E2EE_CONTROL_TEST_SOURCE_REDIS_CONNECTIONS="$source_redis" \
    run_control "$source_state" "source-$source_kind-connection" prepare \
      >"$source_state/output.log" 2>&1
  source_status=$?
  set -e
  [[ "$source_status" -ne 0 ]]
  [[ ! -e "$source_state/postgres" && ! -e "$source_state/redis" &&
     ! -e "$source_state/api" && ! -e "$source_state/volume" ]]
  echo "[e2ee-restore-control-test] source $source_kind connection: fail closed"
done

corrupt_state="$(new_state corrupt-state)"
mkdir -p "$corrupt_state/runtime-state/corrupt-state"
printf '%s\n' 'broken=true' >"$corrupt_state/runtime-state/corrupt-state/control.env"
touch "$corrupt_state/postgres" "$corrupt_state/redis" "$corrupt_state/api" "$corrupt_state/volume"
set +e
run_control "$corrupt_state" corrupt-state cleanup >"$corrupt_state/output.log" 2>&1
corrupt_status=$?
set -e
[[ "$corrupt_status" -ne 0 ]]
[[ ! -e "$corrupt_state/postgres" && ! -e "$corrupt_state/redis" &&
   ! -e "$corrupt_state/api" && ! -e "$corrupt_state/volume" ]]
echo "[e2ee-restore-control-test] corrupt state forced cleanup: pass"

missing_state="$(new_state missing-state)"
touch "$missing_state/postgres" "$missing_state/redis" "$missing_state/api" "$missing_state/volume"
run_control "$missing_state" missing-state cleanup >"$missing_state/output.log" 2>&1
[[ ! -e "$missing_state/postgres" && ! -e "$missing_state/redis" &&
   ! -e "$missing_state/api" && ! -e "$missing_state/volume" ]]
echo "[e2ee-restore-control-test] missing state forced cleanup: pass"

bash -n "$script"
echo "[e2ee-restore-control-test] 6 个 restore control 场景全部通过"
