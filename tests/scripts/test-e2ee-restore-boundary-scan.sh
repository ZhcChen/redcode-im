#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
script="$root_dir/deploy/im-test-1/e2ee-restore-boundary-scan.sh"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/redcode-e2ee-restore-boundary.XXXXXX")"
trap 'pkill -f "$tmp_dir/bin/docker.*redis-cli.*MONITOR" 2>/dev/null || true; rm -rf "$tmp_dir"' EXIT
bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"

cat >"$bin_dir/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
case "$args" in
  *"compose "*" ps -q --status running redis-restore"*)
    printf 'restore-redis\n'
    ;;
  *"compose "*" exec -T postgres-restore psql "*)
    sql="$args"
    case "$sql" in
      *"messages WHERE id IN"*)
        for index in 1 2 3 4 5 6 7; do
          printf '00000000-0000-4000-8000-%012d|11111111-1111-4111-8111-111111111111|[加密消息]|t|{}\n' "$index"
        done
        ;;
      *e2ee_control_messages*) printf '11111111-1111-4111-8111-111111111111|commit|52434352\n' ;;
      *message_attachment_commits*) printf '22222222-2222-4222-8222-222222222222|messages/22222222-2222-4222-8222-222222222222/files/test.bin|64\n' ;;
      *push_job_queue*) ;;
      *) printf 'unexpected postgres SQL args: %s\n' "$args" >&2; exit 70 ;;
    esac
    ;;
  *"compose "*" logs --since "*)
    printf 'api-restore | encrypted request completed\n'
    ;;
  *"exec -e REDISCLI_AUTH="*" redis-cli --no-auth-warning MONITOR"*)
    run_id="${E2EE_RESTORE_RUN_ID:?}"
    printf 'OK\n'
    printf '1.0 [0 api] "PUBLISH" "e2ee-restore-monitor-probe:%s" "probe"\n' "$run_id"
    printf '1.1 [0 api] "PUBLISH" "room:11111111-1111-4111-8111-111111111111" "cipher\000one"\n'
    [[ "${E2EE_BOUNDARY_TEST_MISSING_ROOM:-0}" == 1 ]] ||
      printf '1.2 [0 api] "PUBLISH" "room:22222222-2222-4222-8222-222222222222" "cipher-two"\n'
    printf '1.3 [0 api] "PUBLISH" "room:33333333-3333-4333-8333-333333333333" "cipher-three%s"\n' \
      "${E2EE_BOUNDARY_TEST_MONITOR_MARKER:-}"
    while :; do sleep 1; done
    ;;
  *"exec -e REDISCLI_AUTH="*" redis-cli --no-auth-warning PUBLISH "*)
    printf '1\n'
    ;;
  *"exec -e REDISCLI_AUTH="*" redis-cli --no-auth-warning --raw --scan"*)
    ;;
  *"run --rm --network im-test-1-network "*)
    printf 'encrypted-object-bytes'
    ;;
  *)
    printf 'unexpected docker args: %s\n' "$args" >&2
    exit 70
    ;;
esac
SH
chmod +x "$bin_dir/docker"

env_file="$tmp_dir/.env"
compose_file="$tmp_dir/restore.yml"
state_root="$tmp_dir/state"
artifact_root="$tmp_dir/artifacts"
run_id=boundary-test
artifact_dir="$artifact_root/$run_id"
mkdir -p "$state_root/$run_id" "$artifact_dir"
cat >"$env_file" <<'ENV'
TZ=UTC
RUSTFS_ACCESS_KEY=test-access
RUSTFS_SECRET_KEY=test-secret
RUSTFS_PRIVATE_BUCKET=private
ENV
touch "$compose_file"
cat >"$state_root/$run_id/control.env" <<'STATE'
E2EE_RESTORE_PASSWORD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
E2EE_RESTORE_REDIS_PASSWORD=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
STATE

write_evidence() {
  local marker_suffix="${1:-}"
  jq -n --arg run_id "$run_id" --arg marker_suffix "$marker_suffix" '{
    run_id: $run_id,
    scenarios: [
      {name: "h5-h5", room_id: "11111111-1111-4111-8111-111111111111",
       message_ids: ["00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000002"],
       plaintext_markers: [("u5-alice-11111111-1111-4111-8111-111111111111" + $marker_suffix)]},
      {name: "android-h5", room_id: "22222222-2222-4222-8222-222222222222",
       message_ids: ["00000000-0000-4000-8000-000000000003", "00000000-0000-4000-8000-000000000004", "00000000-0000-4000-8000-000000000005"],
       object_key: "messages/22222222-2222-4222-8222-222222222222/files/test.bin",
       attachment_marker: "u5-attachment-22222222-2222-4222-8222-222222222222",
       plaintext_markers: ["u5-android-22222222-2222-4222-8222-222222222222"]},
      {name: "ios-h5", room_id: "33333333-3333-4333-8333-333333333333",
       message_ids: ["00000000-0000-4000-8000-000000000006", "00000000-0000-4000-8000-000000000007"],
       plaintext_markers: ["u5-ios-33333333-3333-4333-8333-333333333333"]}
    ]
  }' >"$artifact_dir/live.json"
}

run_scan() {
  local operation="$1"
  shift
  PATH="$bin_dir:$PATH" \
  E2EE_RESTORE_RUN_ID="$run_id" \
  E2EE_RESTORE_EVIDENCE_PATH="$artifact_dir/live.json" \
  E2EE_RESTORE_ENV_FILE="$env_file" \
  E2EE_RESTORE_COMPOSE_FILE="$compose_file" \
  E2EE_RESTORE_STATE_ROOT="$state_root" \
  E2EE_RESTORE_ARTIFACT_ROOT="$artifact_root" \
  E2EE_DRILL_API_IMAGE=test-api \
    "$@" "$script" "$operation"
}

reset_monitor() {
  local pid
  pid="$(cat "$artifact_dir/redis-monitor.pid" 2>/dev/null || true)"
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] && kill "$pid" 2>/dev/null || true
  rm -f "$artifact_dir/monitor-ready" "$artifact_dir/redis-monitor."*
}

write_evidence
run_scan monitor-start
run_scan scan >"$tmp_dir/success.json"
jq -e '.db == "ciphertext-only" and .redis == "marker-free" and
  .logs == "marker-free" and .push == "not-observed-live" and
  .rustfs.content == "ciphertext-only"' "$tmp_dir/success.json" >/dev/null
grep -aFq 'cipher-three' "$artifact_dir/redis-monitor.snapshot"
echo '[e2ee-restore-boundary-test] binary snapshot before stop: pass'

reset_monitor
write_evidence
E2EE_BOUNDARY_TEST_MISSING_ROOM=1 run_scan monitor-start
set +e
run_scan scan >"$tmp_dir/missing-room.log" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]]
rg -q '缺少 room 流量：22222222-2222-4222-8222-222222222222' "$tmp_dir/missing-room.log"
echo '[e2ee-restore-boundary-test] missing room: fail closed'

reset_monitor
marker=u5-ios-33333333-3333-4333-8333-333333333333
write_evidence
E2EE_BOUNDARY_TEST_MONITOR_MARKER="$marker" run_scan monitor-start
set +e
run_scan scan >"$tmp_dir/plaintext-marker.log" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]]
rg -q 'Redis MONITOR 命中 plaintext marker' "$tmp_dir/plaintext-marker.log"
echo '[e2ee-restore-boundary-test] plaintext marker: fail closed'

reset_monitor
write_evidence
jq '.run_id = "different-run"' "$artifact_dir/live.json" >"$artifact_dir/live.tmp"
mv "$artifact_dir/live.tmp" "$artifact_dir/live.json"
run_scan monitor-start
set +e
run_scan scan >"$tmp_dir/run-id-mismatch.log" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]]
rg -q '三端 evidence 结构无效' "$tmp_dir/run-id-mismatch.log"
echo '[e2ee-restore-boundary-test] run id mismatch: fail closed'

reset_monitor
bash -n "$script"
echo '[e2ee-restore-boundary-test] 4 个 snapshot/room/marker/run-id 场景全部通过'
