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
        api_up_count=0
        [[ ! -f "$state/api-up-count" ]] || api_up_count="$(cat "$state/api-up-count")"
        api_up_count=$((api_up_count + 1))
        printf '%s\n' "$api_up_count" >"$state/api-up-count"
        if [[ "${E2EE_CONTROL_TEST_FAIL_API_UP:-}" == 1 ]]; then
          exit 23
        fi
        if [[ "$api_up_count" -ge "${E2EE_CONTROL_TEST_FAIL_API_UP_AFTER:-999}" ]]; then
          exit 24
        fi
        if [[ "$api_up_count" -ge 2 ]]; then
          if [[ -f "$state/runtime-persisted" ]]; then
            cat "$state/runtime-persisted" >"$state/runtime"
          else
            printf 'plaintext\n' >"$state/runtime"
          fi
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
          *"component_digests"*)
            printf '%s\n' '{"identities":2,"devices":2,"key_packages":20,"room_epochs":1,"control_messages":1,"control_receipts":1,"encrypted_messages":1,"attachment_commits":0,"digest":"0123456789abcdef0123456789abcdef"}'
            ;;
          *"COMMENT ON DATABASE"*)
            [[ "${E2EE_CONTROL_TEST_FAIL_RUNTIME_SQL:-0}" != 1 ]] || exit 25
            printf 'redcode-e2ee-restore:%s\n' "${E2EE_RESTORE_RUN_ID:?}" >"$state/marker"
            printf 'e2ee\n' >"$state/runtime"
            if [[ "$sql" == *"INSERT INTO general_settings"* &&
                  "$sql" == *"ON CONFLICT (key) DO UPDATE"* ]]; then
              printf 'e2ee\n' >"$state/runtime-persisted"
            fi
            ;;
          *"value = 'plaintext'"*) printf 'plaintext\n' >"$state/runtime" ;;
        esac
      fi
      ;;
    ps)
      if [[ "$compose_path" == */docker-compose.yml && "$*" == *rustfs* ]]; then
        printf 'rustfs-id\n'
        exit 0
      fi
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
    elif [[ "$format" == *'{{json .NetworkSettings.Networks}}'* ]]; then
      project="$(cat "$state/project")"
      printf '{"%s_restore-internal":{},"%s-storage":{},"%s-ingress":{}}\n' \
        "$project" "$project" "$project"
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
  network)
    operation="$2"
    case "$operation" in
      create)
        network="${!#}"
        network_key="${network##*-}"
        [[ ! -e "$state/network-$network_key" ]] || exit 1
        printf '%s\n' "$network" >"$state/network-$network_key"
        printf '%s\n' "${E2EE_RESTORE_RUN_ID:?}" >"$state/network-$network_key-owner"
        ;;
      connect) touch "$state/network-connected" ;;
      disconnect) rm -f "$state/network-connected" ;;
      inspect)
        network="${!#}"
        network_key="${network##*-}"
        [[ -e "$state/network-$network_key" ]] || exit 1
        if [[ " $* " == *" -f "* ]]; then
          cat "$state/network-$network_key-owner"
        elif [[ "$network_key" == storage ]]; then
          if [[ "${E2EE_CONTROL_TEST_STORAGE_EXTRA_MEMBER:-0}" == 1 ]]; then
            containers='{"api-id":{},"rustfs-id":{},"unexpected-id":{}}'
          else
            containers='{"api-id":{},"rustfs-id":{}}'
          fi
          printf '[{"Internal":%s,"Labels":{"redcode.e2ee.restore.run_id":"%s"},"Containers":%s}]\n' \
            "${E2EE_CONTROL_TEST_STORAGE_INTERNAL:-true}" \
            "${E2EE_CONTROL_TEST_NETWORK_OWNER_OVERRIDE:-$(cat "$state/network-storage-owner")}" \
            "$containers"
        else
          printf '[{"Internal":%s,"Labels":{"redcode.e2ee.restore.run_id":"%s"},"Containers":{"api-id":{}}}]\n' \
            "${E2EE_CONTROL_TEST_INGRESS_INTERNAL:-false}" \
            "${E2EE_CONTROL_TEST_NETWORK_OWNER_OVERRIDE:-$(cat "$state/network-ingress-owner")}"
        fi
        ;;
      rm)
        network="${!#}"
        network_key="${network##*-}"
        rm -f "$state/network-$network_key" "$state/network-$network_key-owner"
        [[ "$network_key" != storage ]] || rm -f "$state/network-connected"
        ;;
      *) exit 70 ;;
    esac
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
  E2EE_RESTORE_SNAPSHOT_FILE="$root_dir/deploy/im-test-1/e2ee-restore-snapshot.sql" \
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
[[ -e "$success_state/network-storage" && -e "$success_state/network-ingress" &&
   -e "$success_state/network-connected" ]]
run_control "$success_state" success verify >"$success_state/verify.json"
jq -e '.project == "e2ee-restore-success" and .database_host == "postgres-restore"' \
  "$success_state/verify.json" >/dev/null
for network_fault in owner storage-internal storage-member ingress-internal; do
  set +e
  if [[ "$network_fault" == owner ]]; then
    E2EE_CONTROL_TEST_NETWORK_OWNER_OVERRIDE=different-run \
      run_control "$success_state" success verify >"$success_state/$network_fault.log" 2>&1
  elif [[ "$network_fault" == storage-internal ]]; then
    E2EE_CONTROL_TEST_STORAGE_INTERNAL=false \
      run_control "$success_state" success verify >"$success_state/$network_fault.log" 2>&1
  elif [[ "$network_fault" == storage-member ]]; then
    E2EE_CONTROL_TEST_STORAGE_EXTRA_MEMBER=1 \
      run_control "$success_state" success verify >"$success_state/$network_fault.log" 2>&1
  else
    E2EE_CONTROL_TEST_INGRESS_INTERNAL=true \
      run_control "$success_state" success verify >"$success_state/$network_fault.log" 2>&1
  fi
  network_status=$?
  set -e
  [[ "$network_status" -ne 0 ]]
  rg -q 'network 隔离/owner/成员合同不匹配' "$success_state/$network_fault.log"
  echo "[e2ee-restore-control-test] $network_fault mismatch: fail closed"
done
run_control "$success_state" success snapshot >"$success_state/snapshot.json"
jq -e '.digest == "0123456789abcdef0123456789abcdef" and .identities == 2 and .key_packages == 20' \
  "$success_state/snapshot.json" >/dev/null
run_control "$success_state" success rollback
[[ "$(cat "$success_state/runtime")" == plaintext ]]
run_control "$success_state" success cleanup
[[ ! -e "$success_state/postgres" && ! -e "$success_state/redis" &&
   ! -e "$success_state/api" && ! -e "$success_state/volume" &&
   ! -e "$success_state/network-storage" && ! -e "$success_state/network-ingress" &&
   ! -e "$success_state/network-connected" &&
   ! -e "$success_state/runtime-state/success/control.env" ]]
echo "[e2ee-restore-control-test] prepare/verify/rollback/cleanup: pass"

empty_state="$(new_state empty-candidate)"
E2EE_RESTORE_ALLOW_EMPTY_PREPARE=yes \
  run_control "$empty_state" empty-candidate prepare-empty >"$empty_state/prepare.json"
jq -e '.verified == true and .database_marker == "redcode-e2ee-restore:empty-candidate"' \
  "$empty_state/prepare.json" >/dev/null
[[ "$(cat "$empty_state/runtime")" == e2ee ]]
[[ "$(cat "$empty_state/runtime-persisted")" == e2ee ]]
[[ "$(cat "$empty_state/api-up-count")" == 2 ]]
[[ -f "$empty_state/runtime-state/empty-candidate/control.env" ]]
[[ -e "$empty_state/network-storage" && -e "$empty_state/network-ingress" &&
   -e "$empty_state/network-connected" ]]
run_control "$empty_state" empty-candidate cleanup
[[ ! -e "$empty_state/postgres" && ! -e "$empty_state/redis" &&
   ! -e "$empty_state/api" && ! -e "$empty_state/volume" &&
   ! -e "$empty_state/network-storage" && ! -e "$empty_state/network-ingress" ]]
echo "[e2ee-restore-control-test] empty candidate prepare/verify/cleanup: pass"

for empty_failure in initial-api runtime-sql recreate-api; do
  failed_empty_state="$(new_state "empty-$empty_failure")"
  set +e
  if [[ "$empty_failure" == initial-api ]]; then
    E2EE_RESTORE_ALLOW_EMPTY_PREPARE=yes E2EE_CONTROL_TEST_FAIL_API_UP=1 \
      run_control "$failed_empty_state" "empty-$empty_failure" prepare-empty \
      >"$failed_empty_state/output.log" 2>&1
  elif [[ "$empty_failure" == runtime-sql ]]; then
    E2EE_RESTORE_ALLOW_EMPTY_PREPARE=yes E2EE_CONTROL_TEST_FAIL_RUNTIME_SQL=1 \
      run_control "$failed_empty_state" "empty-$empty_failure" prepare-empty \
      >"$failed_empty_state/output.log" 2>&1
  else
    E2EE_RESTORE_ALLOW_EMPTY_PREPARE=yes E2EE_CONTROL_TEST_FAIL_API_UP_AFTER=2 \
      run_control "$failed_empty_state" "empty-$empty_failure" prepare-empty \
      >"$failed_empty_state/output.log" 2>&1
  fi
  failed_empty_status=$?
  set -e
  [[ "$failed_empty_status" -ne 0 ]]
  [[ ! -e "$failed_empty_state/postgres" && ! -e "$failed_empty_state/redis" &&
     ! -e "$failed_empty_state/api" && ! -e "$failed_empty_state/volume" &&
     ! -e "$failed_empty_state/network-storage" && ! -e "$failed_empty_state/network-ingress" ]]
  echo "[e2ee-restore-control-test] empty candidate $empty_failure failure cleanup: pass"
done

failure_state="$(new_state api-start-failure)"
set +e
E2EE_RESTORE_ALLOW_PREPARE=yes E2EE_RESTORE_DUMP_PATH="$failure_state/database.dump" \
E2EE_CONTROL_TEST_FAIL_API_UP=1 \
  run_control "$failure_state" api-start-failure prepare >"$failure_state/output.log" 2>&1
failure_status=$?
set -e
[[ "$failure_status" -ne 0 ]]
[[ ! -e "$failure_state/postgres" && ! -e "$failure_state/redis" &&
   ! -e "$failure_state/api" && ! -e "$failure_state/volume" &&
   ! -e "$failure_state/network-storage" && ! -e "$failure_state/network-ingress" &&
   ! -e "$failure_state/network-connected" ]]
echo "[e2ee-restore-control-test] API start failure cleanup: pass"

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

unowned_state="$(new_state unowned-network)"
touch "$unowned_state/network-storage"
printf 'different-run\n' >"$unowned_state/network-storage-owner"
set +e
run_control "$unowned_state" unowned-network cleanup >"$unowned_state/output.log" 2>&1
unowned_status=$?
set -e
[[ "$unowned_status" -ne 0 && -e "$unowned_state/network-storage" ]]
rg -q '不属于当前 run，拒绝删除' "$unowned_state/output.log"
echo "[e2ee-restore-control-test] unowned storage network: fail closed"

snapshot_file="$root_dir/deploy/im-test-1/e2ee-restore-snapshot.sql"
for row_alias in identity_row device_row package_row epoch_row message_row receipt_row attachment_row; do
  rg -q "md5\($row_alias::text\)" "$snapshot_file"
done
[[ "$(rg -c 'md5\(message_row::text\)' "$snapshot_file")" == 2 ]]
! rg -q 'concat_ws\(' "$snapshot_file"
echo "[e2ee-restore-control-test] snapshot complete-row digest contract: pass"

bash -n "$script"
echo "[e2ee-restore-control-test] 13 个 restore control/network 场景与 snapshot 合同全部通过"
