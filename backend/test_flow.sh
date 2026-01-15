#!/usr/bin/env bash
set -euo pipefail

API_BASE_URL="${API_BASE_URL:-http://localhost:8010}"

log() {
  printf "[test_flow] %s\n" "$*" >&2
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "缺少依赖命令: $1"
    exit 1
  fi
}

require_cmd curl
require_cmd jq

if ! curl -fsS "${API_BASE_URL}/healthz" >/dev/null 2>&1; then
  log "后端不可用，请先启动后端: ${API_BASE_URL}"
  log "示例：cd backend && cargo run"
  exit 1
fi

HTTP_CODE=""
http() {
  local method="$1"
  local path="$2"
  local token="${3:-}"
  local data="${4:-}"

  local url="${API_BASE_URL}${path}"
  local headers=(-H "Content-Type: application/json")
  if [[ -n "${token}" ]]; then
    headers+=(-H "Authorization: Bearer ${token}")
  fi

  local resp=""
  if [[ -n "${data}" ]]; then
    resp="$(curl -sS -X "${method}" "${headers[@]}" -d "${data}" "${url}" -w $'\n%{http_code}')"
  else
    resp="$(curl -sS -X "${method}" "${headers[@]}" "${url}" -w $'\n%{http_code}')"
  fi

  HTTP_CODE="${resp##*$'\n'}"
  printf "%s" "${resp%$'\n'*}"
}

register_user() {
  local username="$1"
  local password="$2"
  local nickname="$3"
  local email="${username}@example.com"

  local payload
  payload="$(jq -n \
    --arg username "${username}" \
    --arg email "${email}" \
    --arg password "${password}" \
    --arg nickname "${nickname}" \
    '{username: $username, email: $email, password: $password, nickname: $nickname}')"

  local body
  body="$(http POST "/auth/register" "" "${payload}")"
  case "${HTTP_CODE}" in
    200)
      log "注册成功: ${username}"
      ;;
    409)
      log "用户已存在，跳过注册: ${username}"
      ;;
    *)
      log "注册失败(${HTTP_CODE}): ${username}"
      log "${body}"
      exit 1
      ;;
  esac
}

login_user() {
  local username="$1"
  local password="$2"

  local payload
  payload="$(jq -n --arg username "${username}" --arg password "${password}" '{username: $username, password: $password}')"

  local body
  body="$(http POST "/auth/login" "" "${payload}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "登录失败(${HTTP_CODE}): ${username}"
    log "${body}"
    exit 1
  fi

  local token user_id
  token="$(printf "%s" "${body}" | jq -r '.token // empty')"
  user_id="$(printf "%s" "${body}" | jq -r '.user.id // empty')"
  if [[ -z "${token}" || -z "${user_id}" ]]; then
    log "登录响应缺少 token/user.id: ${username}"
    log "${body}"
    exit 1
  fi

  printf "%s\n%s" "${token}" "${user_id}"
}

ensure_friendship() {
  local requester_token="$1"
  local requester_id="$2"
  local addressee_token="$3"
  local addressee_id="$4"

  local friends
  friends="$(http GET "/friends" "${requester_token}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "获取好友列表失败(${HTTP_CODE})"
    log "${friends}"
    exit 1
  fi

  if printf "%s" "${friends}" | jq -e --arg id "${addressee_id}" '.[] | select(.id == $id)' >/dev/null 2>&1; then
    log "已是好友: ${requester_id} <-> ${addressee_id}"
    return
  fi

  local create_payload
  create_payload="$(jq -n --arg id "${addressee_id}" --arg msg "自动化测试好友请求" '{target_user_id: $id, message: $msg}')"

  local create_body
  create_body="$(http POST "/friends/requests" "${requester_token}" "${create_payload}")"
  if [[ "${HTTP_CODE}" == "200" ]]; then
    log "已发送好友请求: ${requester_id} -> ${addressee_id}"
  else
    log "发送好友请求失败(${HTTP_CODE})，将尝试直接在接收方列表中寻找待处理请求并 accept（可能已发送过）"
  fi

  local incoming
  incoming="$(http GET "/friends/requests?direction=incoming&status=pending" "${addressee_token}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "获取待处理好友请求失败(${HTTP_CODE})"
    log "${incoming}"
    exit 1
  fi

  local request_id
  request_id="$(printf "%s" "${incoming}" | jq -r --arg rid "${requester_id}" '.[] | select(.requester.id == $rid) | .id' | head -n 1)"
  if [[ -z "${request_id}" || "${request_id}" == "null" ]]; then
    log "未找到待处理好友请求（可能已是好友/已处理）: ${requester_id} -> ${addressee_id}"
    return
  fi

  local respond_payload
  respond_payload="$(jq -n '{action:"accept"}')"
  local respond_body
  respond_body="$(http POST "/friends/requests/${request_id}/respond" "${addressee_token}" "${respond_payload}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "接受好友请求失败(${HTTP_CODE}) request_id=${request_id}"
    log "${respond_body}"
    exit 1
  fi

  log "已接受好友请求: request_id=${request_id}"
}

ensure_private_chat() {
  local token="$1"
  local friend_user_id="$2"

  local body
  body="$(http POST "/friends/${friend_user_id}/chat" "${token}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "确保私聊房间失败(${HTTP_CODE}) friend_user_id=${friend_user_id}"
    log "${body}"
    exit 1
  fi

  printf "%s" "${body}" | jq -r '.room_id'
}

ensure_group_room() {
  local token="$1"
  local group_name="$2"
  shift 2

  local rooms
  rooms="$(http GET "/rooms" "${token}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "获取房间列表失败(${HTTP_CODE})"
    log "${rooms}"
    exit 1
  fi

  local existing
  existing="$(printf "%s" "${rooms}" | jq -r --arg name "${group_name}" '.[] | select(.room_type == "group" and .name == $name) | .id' | head -n 1)"
  if [[ -n "${existing}" && "${existing}" != "null" ]]; then
    printf "%s" "${existing}"
    return
  fi

  local members_json
  members_json="$(printf "%s\n" "$@" | jq -R . | jq -s '.')"
  local payload
  payload="$(jq -n \
    --arg name "${group_name}" \
    --arg desc "自动化测试群聊（可重复使用）" \
    --argjson members "${members_json}" \
    '{name: $name, description: $desc, member_ids: $members}')"

  local body
  body="$(http POST "/rooms" "${token}" "${payload}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "创建群聊失败(${HTTP_CODE})"
    log "${body}"
    exit 1
  fi

  printf "%s" "${body}" | jq -r '.room.id'
}

send_text_message() {
  local token="$1"
  local room_id="$2"
  local content="$3"

  local payload
  payload="$(jq -n --arg content "${content}" '{content: $content}')"
  local body
  body="$(http POST "/rooms/${room_id}/messages" "${token}" "${payload}")"
  if [[ "${HTTP_CODE}" != "200" ]]; then
    log "发送消息失败(${HTTP_CODE}) room_id=${room_id}"
    log "${body}"
    exit 1
  fi
}

PASS="Test123456"
U1="13800138000"
U2="13800138001"
U3="13800138002"

register_user "${U1}" "${PASS}" "测试用户"
register_user "${U2}" "${PASS}" "测试用户2"
register_user "${U3}" "${PASS}" "测试用户3"

log "登录并获取 token..."
read -r U1_TOKEN U1_ID < <(login_user "${U1}" "${PASS}")
read -r U2_TOKEN U2_ID < <(login_user "${U2}" "${PASS}")
read -r U3_TOKEN U3_ID < <(login_user "${U3}" "${PASS}")

log "确保好友关系（${U1} 与 ${U2}/${U3}）..."
ensure_friendship "${U1_TOKEN}" "${U1_ID}" "${U2_TOKEN}" "${U2_ID}"
ensure_friendship "${U1_TOKEN}" "${U1_ID}" "${U3_TOKEN}" "${U3_ID}"

log "确保私聊房间..."
ROOM_PRIVATE_U1_U2="$(ensure_private_chat "${U1_TOKEN}" "${U2_ID}")"
ROOM_PRIVATE_U1_U3="$(ensure_private_chat "${U1_TOKEN}" "${U3_ID}")"

GROUP_NAME="自动化测试群聊"
log "确保群聊房间: ${GROUP_NAME}"
ROOM_GROUP="$(ensure_group_room "${U1_TOKEN}" "${GROUP_NAME}" "${U2_ID}" "${U3_ID}")"

log "写入一条群聊消息（用于会话列表展示）..."
send_text_message "${U1_TOKEN}" "${ROOM_GROUP}" "自动化测试群聊消息 $(date '+%F %T')"

cat <<EOF

✅ 测试数据准备完成

后端地址: ${API_BASE_URL}

账号:
- ${U1} / ${PASS}
- ${U2} / ${PASS}
- ${U3} / ${PASS}

房间:
- 私聊(U1-U2): ${ROOM_PRIVATE_U1_U2}
- 私聊(U1-U3): ${ROOM_PRIVATE_U1_U3}
- 群聊(${GROUP_NAME}): ${ROOM_GROUP}
EOF

