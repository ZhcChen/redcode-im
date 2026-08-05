#!/usr/bin/env bash
# 扫描受控 E2EE live 的 DB、Redis、API log、Push queue 与 S3-compatible 对象。
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
compose_file="$root_dir/api/docker/dev/docker-compose.yml"
evidence_file="${1:?缺少 evidence JSON}"
log_since="${2:?缺少日志起始时间}"
redis_monitor_file="${3:?缺少 Redis MONITOR 输出}"

for command in docker curl jq rg shasum; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "[e2ee-scan] 缺少命令：$command" >&2
    exit 69
  }
done

jq -e '
  (.run_id | type == "string" and length > 0) and
  (.scenarios | type == "array" and length == 3) and
  ([.scenarios[].name] | sort == ["android-h5", "h5-h5", "ios-h5"]) and
  (all(.scenarios[]; (.room_id | type == "string" and length > 0))) and
  (all(.scenarios[]; (.message_ids | type == "array" and length > 0))) and
  (all(.scenarios[]; (.plaintext_markers | type == "array" and length > 0))) and
  (.scenarios[] | select(.name == "android-h5") |
    (.object_key | type == "string" and length > 0) and
    (.attachment_marker | type == "string" and length > 0))
' "$evidence_file" >/dev/null

run_id="$(jq -r '.run_id' "$evidence_file")"
object_key="$(jq -r '.scenarios[] | select(.name == "android-h5") | .object_key' "$evidence_file")"
attachment_marker="$(jq -r '.scenarios[] | select(.name == "android-h5") | .attachment_marker' "$evidence_file")"
room_ids=()
while IFS= read -r value; do
  room_ids+=("$value")
done < <(jq -r '.scenarios[].room_id' "$evidence_file")
message_ids=()
while IFS= read -r value; do
  message_ids+=("$value")
done < <(jq -r '.scenarios[].message_ids[]' "$evidence_file")
markers=()
while IFS= read -r value; do
  markers+=("$value")
done < <(jq -r '.scenarios[].plaintext_markers[]' "$evidence_file")

uuid_pattern='^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
for value in "${room_ids[@]}" "${message_ids[@]}"; do
  [[ "$value" =~ $uuid_pattern ]] || {
    echo "[e2ee-scan] evidence 包含非法 UUID" >&2
    exit 1
  }
done
[[ "$object_key" =~ ^messages/[0-9a-f-]+/[A-Za-z0-9._/-]+$ ]] || {
  echo "[e2ee-scan] evidence 包含非法 object key" >&2
  exit 1
}

attachment_room_id="$(jq -r '.scenarios[] | select(.name == "android-h5") | .room_id' "$evidence_file")"
expected_prefix="messages/$attachment_room_id/"
[[ "$object_key" == "$expected_prefix"* ]] || {
  echo "[e2ee-scan] object key 不属于 evidence room" >&2
  exit 1
}

message_csv="$(printf "'%s'," "${message_ids[@]}")"
message_csv="${message_csv%,}"
room_csv="$(printf "'%s'," "${room_ids[@]}")"
room_csv="${room_csv%,}"

db_rows="$(docker compose -f "$compose_file" exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U postgres -d redcode_im -AtF $'\t' -c \
  "SELECT id, room_id, content, encrypted_content IS NOT NULL, COALESCE(encryption_metadata::text, '')
   FROM messages WHERE id IN ($message_csv) ORDER BY id")"
[[ "$(printf '%s\n' "$db_rows" | sed '/^$/d' | wc -l | tr -d ' ')" == "${#message_ids[@]}" ]] || {
  echo "[e2ee-scan] DB 未找到全部 evidence messages" >&2
  exit 1
}
printf '%s\n' "$db_rows" | awk -F '\t' '$3 != "[加密消息]" || $4 != "t" { exit 1 }' || {
  echo "[e2ee-scan] DB 消息不是密文占位或缺少 encrypted_content" >&2
  exit 1
}
printf '%s\n' "$db_rows" | rg -a -q '"(dek|nonce|rcst|private_key|root_private|credential)"' && {
  echo "[e2ee-scan] DB 命中明文 marker 或敏感字段" >&2
  exit 1
}
for marker in "${markers[@]}"; do
  printf '%s\n' "$db_rows" | rg -a -F -q "$marker" && {
    echo "[e2ee-scan] DB 命中明文 marker" >&2
    exit 1
  }
done
while IFS=$'\t' read -r message_id message_room_id _; do
  expected_room_id="$(jq -r --arg id "$message_id" \
    '.scenarios[] | select(.message_ids | index($id)) | .room_id' "$evidence_file")"
  [[ -n "$expected_room_id" && "$message_room_id" == "$expected_room_id" ]] || {
    echo "[e2ee-scan] message $message_id 与 evidence room 不匹配" >&2
    exit 1
  }
done <<<"$db_rows"

control_rows="$(docker compose -f "$compose_file" exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U postgres -d redcode_im -AtF $'\t' -c \
  "SELECT room_id, content_type, encode(envelope, 'hex')
   FROM e2ee_control_messages WHERE room_id IN ($room_csv) ORDER BY room_id, created_at")"
[[ -n "$control_rows" ]] || {
  echo "[e2ee-scan] DB 未找到关联 E2EE control messages" >&2
  exit 1
}
for room_id in "${room_ids[@]}"; do
  printf '%s\n' "$control_rows" | rg -F -q "$room_id" || {
    echo "[e2ee-scan] DB 缺少 room $room_id 的 control message" >&2
    exit 1
  }
done
for marker in "${markers[@]}"; do
  marker_hex="$(printf '%s' "$marker" | xxd -p -c 256)"
  printf '%s\n' "$control_rows" | rg -a -F -q "$marker_hex" && {
    echo "[e2ee-scan] DB control message 命中明文 marker" >&2
    exit 1
  }
done

attachment_rows="$(docker compose -f "$compose_file" exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U postgres -d redcode_im -AtF $'\t' -c \
  "SELECT mac.room_id, mac.object_key, mac.file_size,
          fur.status, COALESCE(fur.content_type, '')
   FROM message_attachment_commits mac
   LEFT JOIN file_upload_records fur ON fur.object_key = mac.object_key
   WHERE mac.object_key = '$object_key'")"
[[ -n "$attachment_rows" ]] || {
  echo "[e2ee-scan] DB 未找到关联附件 commit/upload record" >&2
  exit 1
}
for marker in "${markers[@]}"; do
  printf '%s\n' "$attachment_rows" | rg -a -F -q "$marker" && {
    echo "[e2ee-scan] DB 附件记录命中明文 marker" >&2
    exit 1
  }
done

push_rows="$(docker compose -f "$compose_file" exec -T postgres \
  psql -v ON_ERROR_STOP=1 -U postgres -d redcode_im -At -c \
  "SELECT payload::text FROM push_job_queue
   WHERE $(printf "payload::text LIKE '%%%s%%' OR " "${message_ids[@]}" | sed 's/ OR $//')")"
if [[ -n "$push_rows" ]]; then
  printf '%s' "$push_rows" | rg -a -q '"(dek|nonce|rcst|private_key|root_private|credential)"' && {
    echo "[e2ee-scan] Push queue 命中明文 marker 或敏感字段" >&2
    exit 1
  }
  for marker in "${markers[@]}"; do
    printf '%s' "$push_rows" | rg -a -F -q "$marker" && {
      echo "[e2ee-scan] Push queue 命中明文 marker" >&2
      exit 1
    }
  done
  printf '%s' "$push_rows" | rg -q '【加密消息】|你收到一条加密消息' || {
    echo "[e2ee-scan] Push queue 未使用 E2EE 占位" >&2
    exit 1
  }
  push_status="placeholder-verified"
else
  push_status="not-observed-live"
fi

rg -q '^OK$' "$redis_monitor_file" || {
  echo "[e2ee-scan] Redis MONITOR 没有就绪证据" >&2
  exit 1
}
for room_id in "${room_ids[@]}"; do
  rg -a -F -q "room:$room_id" "$redis_monitor_file" || {
    echo "[e2ee-scan] Redis MONITOR 未捕获 room $room_id 的 live 流量" >&2
    exit 1
  }
done
for marker in "${markers[@]}"; do
  rg -a -F -q "$marker" "$redis_monitor_file" && {
    echo "[e2ee-scan] Redis MONITOR 命中明文 marker" >&2
    exit 1
  }
done
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  for marker in "${markers[@]}"; do
    if docker compose -f "$compose_file" exec -T redis \
      redis-cli -a 123456 --no-auth-warning --raw DUMP "$key" | rg -a -F -q "$marker"; then
      echo "[e2ee-scan] Redis key $key 命中明文 marker" >&2
      exit 1
    fi
  done
done < <(docker compose -f "$compose_file" exec -T redis \
  redis-cli -a 123456 --no-auth-warning --raw --scan)

api_logs="$(docker compose -f "$compose_file" logs --since "$log_since" --no-color api)"
printf '%s' "$api_logs" | rg -a -q '\b(dek|nonce|rcst|root_private_key|private_key_p8)\b' && {
  echo "[e2ee-scan] API runtime log 命中明文 marker 或敏感字段" >&2
  exit 1
}
for marker in "${markers[@]}"; do
  printf '%s' "$api_logs" | rg -a -F -q "$marker" && {
    echo "[e2ee-scan] API runtime log 命中明文 marker" >&2
    exit 1
  }
done
"$root_dir/scripts/scan-e2ee-log-denylist.sh"

object_file="$(mktemp "${TMPDIR:-/tmp}/redcode-e2ee-object.XXXXXX")"
trap 'rm -f "$object_file"' EXIT
curl -fsS "http://127.0.0.1:19080/mock-bucket/$object_key" -o "$object_file"
[[ -s "$object_file" ]] || {
  echo "[e2ee-scan] S3-compatible 对象为空" >&2
  exit 1
}
rg -a -F -q "$attachment_marker" "$object_file" && {
  echo "[e2ee-scan] S3-compatible 对象包含附件明文 marker" >&2
  exit 1
}
object_sha256="$(shasum -a 256 "$object_file" | awk '{print $1}')"

jq -n \
  --arg run_id "$run_id" \
  --argjson room_ids "$(printf '%s\n' "${room_ids[@]}" | jq -Rsc 'split("\n")[:-1]')" \
  --arg object_key "$object_key" \
  --arg object_sha256 "$object_sha256" \
  --arg push "$push_status" \
  '{run_id: $run_id, room_ids: $room_ids, object_key: $object_key,
    db: "ciphertext-only", redis: "marker-free", logs: "marker-and-denylist-free",
    push: $push, s3: {content: "ciphertext-only", sha256: $object_sha256}}'
