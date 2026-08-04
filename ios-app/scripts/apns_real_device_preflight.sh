#!/usr/bin/env bash
set -euo pipefail

fail() {
  local code="$1"
  shift
  printf '[ios-app] %s\n' "$*" >&2
  exit "$code"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail 127 "缺少命令: $1"
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

trim_trailing_slash() {
  local value="$1"
  while [[ "$value" == */ ]]; do
    value="${value%/}"
  done
  printf '%s' "$value"
}

url_scheme() {
  local value="$1"
  if [[ "$value" != *://* ]]; then
    printf ''
    return
  fi
  printf '%s' "${value%%://*}"
}

url_host() {
  local value="$1"
  local without_scheme="${value#*://}"
  local host_port="${without_scheme%%/*}"
  local host="${host_port%%:*}"
  printf '%s' "$host"
}

is_loopback_host() {
  local host="$1"
  case "$host" in
    localhost|127.*|0.0.0.0|::1|\[::1\])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_url() {
  local name="$1"
  local value="$2"
  local allowed_schemes="$3"
  local scheme
  scheme="$(url_scheme "$value")"
  if [[ -z "$scheme" ]]; then
    fail 66 "$name 必须包含 URL scheme: $value"
  fi
  if [[ " $allowed_schemes " != *" $scheme "* ]]; then
    fail 66 "$name scheme 不支持: $scheme"
  fi
}

resolved_device="$("$script_dir/resolve_real_device.sh")"

api_url="${IOS_APP_API_BASE_URL:-${API_BASE_URL:-}}"
ws_url="${IOS_APP_WS_URL:-${WS_URL:-}}"

if [[ -z "$api_url" ]]; then
  fail 66 "缺少 IOS_APP_API_BASE_URL 或 API_BASE_URL；真机必须使用局域网/公网可访问的 API 地址。"
fi
if [[ -z "$ws_url" ]]; then
  fail 66 "缺少 IOS_APP_WS_URL 或 WS_URL；真机必须使用局域网/公网可访问的 WebSocket 地址。"
fi

api_url="$(trim_trailing_slash "$api_url")"
ws_url="$(trim_trailing_slash "$ws_url")"

validate_url "IOS_APP_API_BASE_URL/API_BASE_URL" "$api_url" "http https"
validate_url "IOS_APP_WS_URL/WS_URL" "$ws_url" "ws wss"

api_host="$(url_host "$api_url")"
ws_host="$(url_host "$ws_url")"
if is_loopback_host "$api_host"; then
  fail 66 "真机不能使用 loopback API 地址: $api_url"
fi
if is_loopback_host "$ws_host"; then
  fail 66 "真机不能使用 loopback WS 地址: $ws_url"
fi

if [[ "${IOS_APNS_PROVIDER_CONFIGURED:-}" != "1" ]]; then
  fail 66 "请先在 Admin Push 设置中配置真实 APNs provider，并设置 IOS_APNS_PROVIDER_CONFIGURED=1 作为验收确认。"
fi

if command -v curl >/dev/null 2>&1; then
  health_url="$api_url/healthz"
  curl --fail --silent --show-error --max-time "${IOS_APP_API_HEALTH_TIMEOUT_SECONDS:-5}" "$health_url" >/dev/null \
    || fail 69 "API 健康检查失败，真机可能无法访问: $health_url"
fi

printf '[ios-app] APNs 真机验收预检通过\n'
printf '[ios-app] DEVICE=%s\n' "$resolved_device"
printf '[ios-app] API_BASE_URL=%s\n' "$api_url"
printf '[ios-app] WS_URL=%s\n' "$ws_url"
