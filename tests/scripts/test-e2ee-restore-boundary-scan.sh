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
message_row() {
  local id="$1" room="$2" suffix digest
  suffix="${id##*-}"
  digest="$(printf '%064d' "$((10#$suffix))")"
  [[ "${E2EE_BOUNDARY_TEST_CIPHERTEXT_MISMATCH:-0}" != 1 || "$suffix" != 000000000009 ]] ||
    digest=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
  printf '%s|%s|[加密消息]|t|%s\n' "$id" "$room" "$digest"
}
case "$args" in
  *"compose "*" ps -q --status running redis-restore"*)
    printf 'restore-redis\n'
    ;;
  *"compose "*" exec -T postgres-restore psql "*)
    sql="$args"
    [[ "$sql" != *"content, )"* && "$sql" != *"convert_to(content, UTF8)"* ]] || exit 71
    case "$sql" in
      *"messages WHERE id IN"*)
        message_row 00000000-0000-4000-8000-000000000001 44444444-4444-4444-8444-444444444444
        message_row 00000000-0000-4000-8000-000000000002 44444444-4444-4444-8444-444444444444
        message_row 00000000-0000-4000-8000-000000000003 11111111-1111-4111-8111-111111111111
        message_row 00000000-0000-4000-8000-000000000004 11111111-1111-4111-8111-111111111111
        message_row 00000000-0000-4000-8000-000000000005 22222222-2222-4222-8222-222222222222
        message_row 00000000-0000-4000-8000-000000000006 22222222-2222-4222-8222-222222222222
        if [[ "${E2EE_BOUNDARY_TEST_MESSAGE_ROOM_MISMATCH:-0}" == 1 ]]; then
          message_row 00000000-0000-4000-8000-000000000007 11111111-1111-4111-8111-111111111111
        else
          message_row 00000000-0000-4000-8000-000000000007 22222222-2222-4222-8222-222222222222
        fi
        message_row 00000000-0000-4000-8000-000000000008 33333333-3333-4333-8333-333333333333
        message_row 00000000-0000-4000-8000-000000000009 33333333-3333-4333-8333-333333333333
        ;;
      *"COUNT(*) FROM messages WHERE encrypted_content"*)
        [[ "${E2EE_BOUNDARY_TEST_ENCRYPTED_MARKER:-0}" == 1 ]] && printf '1\n' || printf '0\n'
        ;;
      *"COUNT(*) FROM messages WHERE encryption_metadata"*) printf '0\n' ;;
      *"COUNT(*) FROM messages WHERE"*) printf '0\n' ;;
      *"COUNT(*) FROM e2ee_control_messages"*)
        [[ "${E2EE_BOUNDARY_TEST_CONTROL_MARKER:-0}" == 1 ]] && printf '1\n' || printf '0\n'
        ;;
      *"COUNT(*) FROM push_job_queue"*)
        if [[ ("${E2EE_BOUNDARY_TEST_PUSH_MIXED:-0}" == 1 ||
               "${E2EE_BOUNDARY_TEST_PUSH_NULL:-0}" == 1) && "$sql" == *"NOT (COALESCE(payload"* ]]; then
          printf '1\n'
        else
          printf '0\n'
        fi
        ;;
      *message_attachment_commits*)
        if [[ "${E2EE_BOUNDARY_TEST_OBJECT_ROOM_MISMATCH:-0}" == 1 ]]; then
          printf '11111111-1111-4111-8111-111111111111|00000000-0000-4000-8000-000000000007|messages/22222222-2222-4222-8222-222222222222/files/test.bin\n'
        elif [[ "${E2EE_BOUNDARY_TEST_OBJECT_MESSAGE_MISMATCH:-0}" == 1 ]]; then
          printf '22222222-2222-4222-8222-222222222222|00000000-0000-4000-8000-000000000006|messages/22222222-2222-4222-8222-222222222222/files/test.bin\n'
        else
          printf '22222222-2222-4222-8222-222222222222|00000000-0000-4000-8000-000000000007|messages/22222222-2222-4222-8222-222222222222/files/test.bin\n'
        fi
        ;;
      *push_job_queue*)
        if [[ "${E2EE_BOUNDARY_TEST_PUSH_MIXED:-0}" == 1 ]]; then
          printf '{"snapshot":{"id":"00000000-0000-4000-8000-000000000001","content":"【加密消息】","preview":"你收到一条加密消息"}}\n'
          printf '{"snapshot":{"id":"00000000-0000-4000-8000-000000000002","content":"普通正文","preview":"普通正文"}}\n'
        elif [[ "${E2EE_BOUNDARY_TEST_PUSH_NULL:-0}" == 1 ]]; then
          printf '{"snapshot":{"id":"00000000-0000-4000-8000-000000000001","content":"【加密消息】","preview":null}}\n'
        fi
        ;;
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
    [[ "${E2EE_BOUNDARY_TEST_MISSING_PUBLISH:-}" == 2222 ]] ||
      printf '1.2 [0 api] "PUBLISH" "room:22222222-2222-4222-8222-222222222222" "cipher-two"\n'
    printf '1.3 [0 api] "PUBLISH" "room:33333333-3333-4333-8333-333333333333" "cipher-three%s"\n' \
      "${E2EE_BOUNDARY_TEST_MONITOR_MARKER:-}"
    printf '1.4 [0 api] "PUBLISH" "room:44444444-4444-4444-8444-444444444444" "cipher-four"\n'
    if [[ "${E2EE_BOUNDARY_TEST_MISSING_PUBLISH:-}" == 2222 ]]; then
      printf '1.5 [0 api] "SUBSCRIBE" "room:22222222-2222-4222-8222-222222222222"\n'
      printf '1.6 [0 api] "PUBLISH" "other" "room:22222222-2222-4222-8222-222222222222"\n'
    fi
    while :; do sleep 1; done
    ;;
  *"exec -e REDISCLI_AUTH="*" redis-cli --no-auth-warning PUBLISH "*)
    if [[ "$args" == *":terminal"* && "${E2EE_BOUNDARY_TEST_TERMINAL_PROBE_LOST:-0}" != 1 ]]; then
      run_id="${E2EE_RESTORE_RUN_ID:?}"
      printf '2.0 [0 api] "PUBLISH" "e2ee-restore-monitor-probe:%s:terminal" "terminal"\n' "$run_id" \
        >>"${E2EE_RESTORE_ARTIFACT_ROOT:?}/$run_id/redis-monitor.log"
    fi
    printf '1\n'
    ;;
  *"exec -e REDISCLI_AUTH="*" redis-cli --no-auth-warning --raw --scan"*)
    ;;
  *"run --rm --network e2ee-restore-boundary-test-storage "*)
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
evidence_hmac_key=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
printf '%s\n' "$evidence_hmac_key" >"$artifact_dir/evidence-hmac.key"

sign_evidence() {
  local si pi message_id marker digest kind object_key hmac
  jq '.scenarios |= map(.message_proofs |= map(.binding_hmac = "pending"))' \
    "$artifact_dir/live.json" >"$artifact_dir/live.tmp"
  mv "$artifact_dir/live.tmp" "$artifact_dir/live.json"
  while IFS=$'\t' read -r si pi message_id marker digest kind object_key; do
    [[ "$object_key" != - ]] || object_key=""
    hmac="$(printf '%s\n%s\n%s\n%s\n%s' "$message_id" "$marker" "$digest" "$kind" "$object_key" |
      openssl dgst -sha256 -mac HMAC -macopt "hexkey:$evidence_hmac_key" | awk '{print $NF}')"
    jq --argjson si "$si" --argjson pi "$pi" --arg hmac "$hmac" \
      '.scenarios[$si].message_proofs[$pi].binding_hmac = $hmac' \
      "$artifact_dir/live.json" >"$artifact_dir/live.tmp"
    mv "$artifact_dir/live.tmp" "$artifact_dir/live.json"
  done < <(jq -r '.scenarios | to_entries[] | .key as $si |
    .value.message_proofs | to_entries[] |
    [$si, .key, .value.message_id, .value.plaintext_marker, .value.ciphertext_sha256,
     .value.kind, (.value.object_key // "-")] | @tsv' "$artifact_dir/live.json")
}

write_evidence() {
  local marker_suffix="${1:-}"
  jq -n --arg run_id "$run_id" --arg marker_suffix "$marker_suffix" '
  def digest($n): (("0000000000000000000000000000000000000000000000000000000000000000" + ($n | tostring)) | .[-64:]); {
    run_id: $run_id,
    scenarios: [
      {name: "restore-continuity", room_id: "44444444-4444-4444-8444-444444444444",
       message_proofs: [
         {message_id: "00000000-0000-4000-8000-000000000001", plaintext_marker: "u10-restore-before-44444444-4444-4444-8444-444444444444", ciphertext_sha256: digest(1), kind: "text"},
         {message_id: "00000000-0000-4000-8000-000000000002", plaintext_marker: "u10-restore-after-44444444-4444-4444-8444-444444444444", ciphertext_sha256: digest(2), kind: "text"}
       ]},
      {name: "h5-h5", room_id: "11111111-1111-4111-8111-111111111111",
       message_proofs: [
         {message_id: "00000000-0000-4000-8000-000000000003", plaintext_marker: (("u5-alice-11111111-1111-4111-8111-111111111111") + $marker_suffix), ciphertext_sha256: digest(3), kind: "text"},
         {message_id: "00000000-0000-4000-8000-000000000004", plaintext_marker: "u5-bob-11111111-1111-4111-8111-111111111111", ciphertext_sha256: digest(4), kind: "text"}
       ]},
      {name: "android-h5", room_id: "22222222-2222-4222-8222-222222222222",
       message_proofs: [
         {message_id: "00000000-0000-4000-8000-000000000005", plaintext_marker: "u5-android-22222222-2222-4222-8222-222222222222", ciphertext_sha256: digest(5), kind: "text"},
         {message_id: "00000000-0000-4000-8000-000000000006", plaintext_marker: "u5-h5-22222222-2222-4222-8222-222222222222", ciphertext_sha256: digest(6), kind: "text"},
         {message_id: "00000000-0000-4000-8000-000000000007", plaintext_marker: "u5-attachment-22222222-2222-4222-8222-222222222222", ciphertext_sha256: digest(7), kind: "attachment", object_key: "messages/22222222-2222-4222-8222-222222222222/files/test.bin"}
       ]},
      {name: "ios-h5", room_id: "33333333-3333-4333-8333-333333333333",
       message_proofs: [
         {message_id: "00000000-0000-4000-8000-000000000008", plaintext_marker: "u5-ios-33333333-3333-4333-8333-333333333333", ciphertext_sha256: digest(8), kind: "text"},
         {message_id: "00000000-0000-4000-8000-000000000009", plaintext_marker: "u5-h5-33333333-3333-4333-8333-333333333333", ciphertext_sha256: digest(9), kind: "text"}
       ]}
    ]
  }' >"$artifact_dir/live.json"
  sign_evidence
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
E2EE_BOUNDARY_TEST_MISSING_PUBLISH=2222 run_scan monitor-start
set +e
run_scan scan >"$tmp_dir/missing-room.log" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]]
rg -q '缺少精确 PUBLISH：room:22222222-2222-4222-8222-222222222222' "$tmp_dir/missing-room.log"
echo '[e2ee-restore-boundary-test] subscribe/payload cannot impersonate publish: fail closed'

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
rg -q '四场景 evidence 结构无效' "$tmp_dir/run-id-mismatch.log"
echo '[e2ee-restore-boundary-test] run id mismatch: fail closed'

reset_monitor
write_evidence
jq '.scenarios[0].message_proofs[0].plaintext_marker = "u10-forged-marker"' \
  "$artifact_dir/live.json" >"$artifact_dir/live.tmp"
mv "$artifact_dir/live.tmp" "$artifact_dir/live.json"
run_scan monitor-start
set +e
run_scan scan >"$tmp_dir/forged-proof.log" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]]
rg -q 'message proof HMAC 不匹配' "$tmp_dir/forged-proof.log"
echo '[e2ee-restore-boundary-test] forged marker proof: fail closed'

for proof_fault in ciphertext object key; do
  reset_monitor
  write_evidence
  case "$proof_fault" in
    ciphertext)
      jq '.scenarios[0].message_proofs[0].ciphertext_sha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' \
        "$artifact_dir/live.json" >"$artifact_dir/live.tmp"
      ;;
    object)
      jq '.scenarios[2].message_proofs[2].object_key = "messages/22222222-2222-4222-8222-222222222222/files/other.bin"' \
        "$artifact_dir/live.json" >"$artifact_dir/live.tmp"
      ;;
    key) printf '%064d\n' 0 >"$artifact_dir/evidence-hmac.key" ;;
  esac
  [[ "$proof_fault" == key ]] || mv "$artifact_dir/live.tmp" "$artifact_dir/live.json"
  run_scan monitor-start
  set +e
  run_scan scan >"$tmp_dir/proof-$proof_fault.log" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]]
  rg -q 'message proof HMAC 不匹配' "$tmp_dir/proof-$proof_fault.log"
  printf '%s\n' "$evidence_hmac_key" >"$artifact_dir/evidence-hmac.key"
  echo "[e2ee-restore-boundary-test] forged $proof_fault proof: fail closed"
done

for fault in message-room ciphertext object-room object-message control-marker encrypted-marker push-mixed push-null terminal-probe; do
  reset_monitor
  write_evidence
  run_scan monitor-start
  env_name=""
  expected=""
  case "$fault" in
    message-room)
      env_name=E2EE_BOUNDARY_TEST_MESSAGE_ROOM_MISMATCH=1
      expected='message-room-ciphertext proof 不匹配'
      ;;
    ciphertext)
      env_name=E2EE_BOUNDARY_TEST_CIPHERTEXT_MISMATCH=1
      expected='message-room-ciphertext proof 不匹配'
      ;;
    object-room)
      env_name=E2EE_BOUNDARY_TEST_OBJECT_ROOM_MISMATCH=1
      expected='attachment object-message-room proof 不匹配'
      ;;
    object-message)
      env_name=E2EE_BOUNDARY_TEST_OBJECT_MESSAGE_MISMATCH=1
      expected='attachment object-message-room proof 不匹配'
      ;;
    control-marker)
      env_name=E2EE_BOUNDARY_TEST_CONTROL_MARKER=1
      expected='e2ee_control_messages.envelope 命中 plaintext marker'
      ;;
    encrypted-marker)
      env_name=E2EE_BOUNDARY_TEST_ENCRYPTED_MARKER=1
      expected='messages.encrypted_content 命中 plaintext marker'
      ;;
    push-mixed)
      env_name=E2EE_BOUNDARY_TEST_PUSH_MIXED=1
      expected='Push 存在非 E2EE 占位记录'
      ;;
    push-null)
      env_name=E2EE_BOUNDARY_TEST_PUSH_NULL=1
      expected='Push 存在非 E2EE 占位记录'
      ;;
    terminal-probe)
      env_name=E2EE_BOUNDARY_TEST_TERMINAL_PROBE_LOST=1
      expected='Redis MONITOR 未捕获末端 probe'
      ;;
  esac
  set +e
  if [[ "$fault" == terminal-probe ]]; then
    E2EE_BOUNDARY_TEST_TERMINAL_PROBE_LOST=1 run_scan scan >"$tmp_dir/$fault.log" 2>&1
  else
    run_scan scan env "$env_name" >"$tmp_dir/$fault.log" 2>&1
  fi
  status=$?
  set -e
  [[ "$status" -ne 0 ]]
  rg -q "$expected" "$tmp_dir/$fault.log"
  echo "[e2ee-restore-boundary-test] $fault: fail closed"
done

reset_monitor
write_evidence
run_scan monitor-start
monitor_pid="$(cat "$artifact_dir/redis-monitor.pid")"
kill "$monitor_pid"
wait "$monitor_pid" 2>/dev/null || true
set +e
run_scan scan >"$tmp_dir/monitor-exit.log" 2>&1
status=$?
set -e
[[ "$status" -ne 0 ]]
rg -q 'Redis MONITOR 在扫描前已退出' "$tmp_dir/monitor-exit.log"
echo '[e2ee-restore-boundary-test] monitor early exit: fail closed'

for duplicate in room message marker; do
  reset_monitor
  write_evidence
  case "$duplicate" in
    room) jq '.scenarios[3].room_id = .scenarios[2].room_id' "$artifact_dir/live.json" >"$artifact_dir/live.tmp" ;;
    message) jq '.scenarios[3].message_proofs[0].message_id = .scenarios[2].message_proofs[0].message_id' "$artifact_dir/live.json" >"$artifact_dir/live.tmp" ;;
    marker) jq '.scenarios[3].message_proofs[0].plaintext_marker = .scenarios[2].message_proofs[0].plaintext_marker' "$artifact_dir/live.json" >"$artifact_dir/live.tmp" ;;
  esac
  mv "$artifact_dir/live.tmp" "$artifact_dir/live.json"
  sign_evidence
  run_scan monitor-start
  set +e
  run_scan scan >"$tmp_dir/duplicate-$duplicate.log" 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 ]]
  rg -q "$duplicate.*必须全局唯一|scenario room_id 必须全局唯一|plaintext marker 必须全局唯一" \
    "$tmp_dir/duplicate-$duplicate.log"
  echo "[e2ee-restore-boundary-test] duplicate $duplicate: fail closed"
done

reset_monitor
bash -n "$script"
echo '[e2ee-restore-boundary-test] 22 个 proof/归属/bytea/PUBLISH/Push/MONITOR 场景全部通过'
