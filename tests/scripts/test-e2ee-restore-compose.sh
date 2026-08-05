#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compose_file="$root_dir/deploy/im-test-1/docker-compose.e2ee-restore.yml"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-restore-compose.XXXXXX")"
trap 'rm -rf "$tmp_dir"' EXIT
config="$tmp_dir/config.json"

env \
  E2EE_RESTORE_PROJECT_NAME=e2ee-restore-contract \
  E2EE_RESTORE_PASSWORD=restore-password \
  E2EE_RESTORE_REDIS_PASSWORD=restore-redis-password \
  E2EE_RESTORE_STORAGE_NETWORK=e2ee-restore-contract-storage \
  E2EE_RESTORE_INGRESS_NETWORK=e2ee-restore-contract-ingress \
  E2EE_DRILL_API_IMAGE=redcode-im-api:contract \
  TZ=Asia/Shanghai \
  RUST_LOG=info \
  DATABASE_MAX_CONNECTIONS=5 \
  DATABASE_MIN_CONNECTIONS=1 \
  DATABASE_ACQUIRE_TIMEOUT_SECONDS=10 \
  API_PUBLIC_HOST=im-test-1.codelib.cc \
  RUSTFS_REGION=us-east-1 \
  RUSTFS_ACCESS_KEY=contract-access \
  RUSTFS_SECRET_KEY=contract-secret \
  RUSTFS_PRIVATE_BUCKET=private \
  RUSTFS_PUBLIC_BUCKET=public \
  JWT_SECRET=contract-jwt \
  DATA_ENCRYPTION_KEY=contract-data-key \
  WS_OUTBOUND_QUEUE_SIZE=128 \
  METRICS_CHANNEL_CAPACITY=128 \
  METRICS_FLUSH_BATCH_SIZE=10 \
  METRICS_FLUSH_INTERVAL_SECONDS=1 \
  METRICS_SAMPLE_RATE=1.0 \
  docker compose -f "$compose_file" config --format json >"$config"

jq -e '
  (.name == "e2ee-restore-contract") and
  ([.services | keys[]] | sort == ["api-restore", "postgres-restore", "redis-restore"]) and
  (.services["postgres-restore"].ports == null) and
  (.services["redis-restore"].ports == null) and
  (.services["api-restore"].ports == [{"mode":"ingress","target":8010,"published":"18010","protocol":"tcp","host_ip":"127.0.0.1"}]) and
  (.services["api-restore"].environment.DATABASE_URL | contains("@postgres-restore:5432/redcode_e2ee_restore")) and
  (.services["api-restore"].environment.REDIS_SESSION_URL | contains("@redis-restore:6379/0")) and
  (.services["api-restore"].environment.REDIS_PUBSUB_URL | contains("@redis-restore:6379/0")) and
  (.services["api-restore"].environment.REDIS_CACHE_URL | contains("@redis-restore:6379/0")) and
  (.services["api-restore"].environment.REDCODE_IM_B2_ENDPOINT == "rustfs:9000") and
  (.services["api-restore"].environment.METRICS_ENABLED == "false") and
  ([.services["api-restore"].networks | keys[]] | sort == ["ingress-isolated", "restore-internal", "storage-isolated"]) and
  ([.services["postgres-restore"].networks | keys[]] == ["restore-internal"]) and
  ([.services["redis-restore"].networks | keys[]] == ["restore-internal"]) and
  (.networks["restore-internal"].internal == true) and
  (.networks["storage-isolated"].external == true) and
  (.networks["storage-isolated"].name == "e2ee-restore-contract-storage") and
  (.networks["ingress-isolated"].external == true) and
  (.networks["ingress-isolated"].name == "e2ee-restore-contract-ingress")
' "$config" >/dev/null

rg -q 'docker network create --internal' "$root_dir/deploy/im-test-1/e2ee-restore-control.sh"
rg -q 'has\("im-test-1-network"\) \| not' "$root_dir/deploy/im-test-1/e2ee-restore-control.sh"

if rg -n '0\.0\.0\.0|5432:|6379:' "$config" >/dev/null; then
  echo "[e2ee-restore-compose-test] restore 栈暴露了非预期监听地址或数据端口" >&2
  exit 1
fi

echo "[e2ee-restore-compose-test] restore API/PG/Redis 隔离合同通过"
