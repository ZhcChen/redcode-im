#!/usr/bin/env bash
set -euo pipefail

fail() {
  local code="$1"
  shift
  printf '[ios-app] %s\n' "$*" >&2
  exit "$code"
}

is_usable_ip() {
  local ip="$1"
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  [[ "$ip" == 127.* ]] && return 1
  [[ "$ip" == 169.254.* ]] && return 1
  [[ "$ip" == 0.* ]] && return 1
  return 0
}

if [[ -n "${IOS_APP_LAN_IP:-}" ]]; then
  if is_usable_ip "$IOS_APP_LAN_IP"; then
    printf '%s\n' "$IOS_APP_LAN_IP"
    exit 0
  fi
  fail 66 "IOS_APP_LAN_IP 不是可用于真机访问的 IPv4 地址: $IOS_APP_LAN_IP"
fi

interfaces=()
if default_interface="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}')"; then
  [[ -n "$default_interface" ]] && interfaces+=("$default_interface")
fi
interfaces+=(en0 en1)

if command -v ifconfig >/dev/null 2>&1; then
  while IFS= read -r interface; do
    [[ -n "$interface" ]] && interfaces+=("$interface")
  done < <(ifconfig -l 2>/dev/null | tr ' ' '\n')
fi

seen=" "
for interface in "${interfaces[@]}"; do
  [[ -n "$interface" ]] || continue
  [[ "$seen" == *" $interface "* ]] && continue
  seen+="$interface "
  ip="$(ipconfig getifaddr "$interface" 2>/dev/null || true)"
  if is_usable_ip "$ip"; then
    printf '%s\n' "$ip"
    exit 0
  fi
done

fail 66 "无法自动解析本机局域网 IPv4；请传 IOS_APP_LAN_IP=<LAN_IP> 后重试。"
